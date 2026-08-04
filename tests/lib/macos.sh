# shellcheck shell=sh
# shellcheck disable=SC3043  # 'local' is supported by every shell this test runs under
# macOS (Darwin) backend for the graphpath regression harness.
#
# macOS has NO network-namespace / vnet equivalent, so there is no hermetic
# isolation: we create feth(4) virtual interfaces and add routes + static
# ARP/NDP entries on the REAL stack, then tear them down. Consequences:
#
#   * Not isolated. A pre-existing route to one of the test subnets on the host
#     will perturb the result. The test address ranges (198.18/15, 2001:db8::)
#     are chosen to be unlikely to collide, but this is best-effort.
#   * Interfaces cannot be renamed to test0/test1 as on FreeBSD/Linux; feth
#     units are used with fixed high numbers (feth100/feth101) so the golden
#     files are still deterministic. macOS golden files therefore show
#     `feth100`/`feth101` where the others show `test0`/`test1`.
#
# Implements the same net_* contract as lib/freebsd.sh.
#
# UNVERIFIED: written from documented ifconfig/route/arp/ndp behaviour; not run
# on this FreeBSD host. Regenerate golden/macos/ with `sudo tests/run.sh
# --update` on macOS, and review for real-stack interference.

_FETHS=""     # feth units created, for teardown
_ROUTES=""    # "net gw" pairs added, for teardown
_ARPS=""      # ip addresses pinned, for teardown

_MAC0="02:00:00:00:01:01"
_MAC1="02:00:00:00:01:02"
_UNIT0="100"
_UNIT1="101"

net_setup() {
	local nifaces="$1"
	local i=0
	while [ "${i}" -lt "${nifaces}" ]; do
		eval "local unit=\${_UNIT$i}"
		eval "local mac=\${_MAC$i}"
		# shellcheck disable=SC2154  # unit/mac assigned via the evals above
		ifconfig "feth${unit}" create 2>/dev/null || true
		_FETHS="${_FETHS} feth${unit}"
		# shellcheck disable=SC2154
		ifconfig "feth${unit}" lladdr "${mac}"
		ifconfig "feth${unit}" up
		i=$((i + 1))
	done
}

# Map the logical test0/test1 the scenarios use onto feth units.
_dev() {
	case "$1" in
	test0) echo "feth${_UNIT0}" ;;
	test1) echo "feth${_UNIT1}" ;;
	*) echo "$1" ;;
	esac
}

net_iface_addr() {
	local dev
	dev=$(_dev "$1")
	case "$2" in
	*:*) ifconfig "${dev}" inet6 "$2" up ;;
	*)   ifconfig "${dev}" inet  "$2" up ;;
	esac
}

net_route_add() {
	_ROUTES="${_ROUTES}
$1 $2"
	case "$2" in
	*:*) route -q add -inet6 -net "$1" "$2" ;;
	*)   route -q add -net "$1" "$2" ;;
	esac
}

net_arp_add() {
	_ARPS="${_ARPS} $1"
	case "$1" in
	*:*) ndp -s "$1" "$2" >/dev/null ;;
	*)   arp -S "$1" "$2" >/dev/null ;;
	esac
}

net_forwarding() {
	sysctl -w net.inet.ip.forwarding="$1" >/dev/null
	sysctl -w net.inet6.ip6.forwarding="$1" >/dev/null
}

net_run() {
	# graphpath exits 1 even on correct output; ignore its exit code.
	sh "${GRAPHPATH}" "$1" "$2" 2>/dev/null || true
}

net_teardown() {
	# Remove fabricated routes first, then ARP/NDP, then interfaces.
	printf '%s\n' "${_ROUTES}" | while read -r net gw; do
		[ -n "${net}" ] || continue
		case "${gw}" in
		*:*) route -q delete -inet6 -net "${net}" "${gw}" 2>/dev/null || true ;;
		*)   route -q delete -net "${net}" "${gw}" 2>/dev/null || true ;;
		esac
	done
	local a
	for a in ${_ARPS}; do
		case "${a}" in
		*:*) ndp -d "${a}" 2>/dev/null || true ;;
		*)   arp -d "${a}" 2>/dev/null || true ;;
		esac
	done
	local f
	for f in ${_FETHS}; do
		ifconfig "${f}" destroy 2>/dev/null || true
	done
	_FETHS=""
	_ROUTES=""
	_ARPS=""
}

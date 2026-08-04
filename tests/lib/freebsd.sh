# shellcheck shell=sh
# shellcheck disable=SC3043  # 'local' is supported by every shell this test runs under
# FreeBSD backend for the graphpath regression harness.
#
# Isolation primitive: a vnet jail (private, empty network stack) plus one or
# two epair(4) interfaces moved into it. graphpath never sends a packet, so we
# fabricate the whole topology with static routes (route add) and static
# ARP/NDP entries (arp -s / ndp -s) pointing at gateways that do not exist.
#
# Implements the net_* contract consumed by scenarios.sh and run.sh. All state
# is the jail name held in _JAIL; every command runs inside the jail via jexec.
#
# VERIFIED on FreeBSD 16.0-CURRENT.

_JAIL=""
_EPAIRS=""   # space-separated list of host-side epair basenames to destroy

# Pinned MACs so the golden files are byte-stable (epair MACs are random).
_MAC0="02:00:00:00:01:01"
_MAC1="02:00:00:00:01:02"

net_setup() {
	# $1 = number of interfaces to create (1 or 2)
	local nifaces="$1"
	# Jail name is fixed (not PID-based) so it is still deterministic and a
	# stale one from a crashed run can be reclaimed. Reclaim defensively.
	_JAIL="graphpath_test"
	jail -r "${_JAIL}" 2>/dev/null || true
	jail -c name="${_JAIL}" vnet persist
	jexec "${_JAIL}" ifconfig lo0 inet 127.0.0.1/8 up

	local i=0
	while [ "${i}" -lt "${nifaces}" ]; do
		local ep
		ep=$(ifconfig epair create)   # e.g. epair0a
		ep=${ep%a}                    # -> epair0
		_EPAIRS="${_EPAIRS} ${ep}"
		ifconfig "${ep}a" vnet "${_JAIL}"
		eval "local mac=\${_MAC$i}"
		jexec "${_JAIL}" ifconfig "${ep}a" name "test${i}" >/dev/null
		# shellcheck disable=SC2154  # mac assigned via the eval above
		jexec "${_JAIL}" ifconfig "test${i}" ether "${mac}"
		jexec "${_JAIL}" ifconfig "test${i}" up
		i=$((i + 1))
	done
}

net_iface_addr() {
	# $1 = iface (test0/test1), $2 = address/prefix (inet or inet6)
	case "$2" in
	*:*) jexec "${_JAIL}" ifconfig "$1" inet6 "$2" up ;;
	*)   jexec "${_JAIL}" ifconfig "$1" inet  "$2" up ;;
	esac
}

net_route_add() {
	# $1 = destination net (CIDR), $2 = gateway IP
	case "$2" in
	*:*) jexec "${_JAIL}" route -q add -inet6 -net "$1" "$2" ;;
	*)   jexec "${_JAIL}" route -q add -net "$1" "$2" ;;
	esac
}

net_arp_add() {
	# $1 = IP, $2 = MAC.  Static ARP for IPv4, static NDP for IPv6.
	case "$1" in
	*:*) jexec "${_JAIL}" ndp -s "$1" "$2" >/dev/null ;;
	*)   jexec "${_JAIL}" arp -s "$1" "$2" >/dev/null ;;
	esac
}

net_forwarding() {
	# $1 = 0 or 1 ; sets both v4 and v6 forwarding
	jexec "${_JAIL}" sysctl net.inet.ip.forwarding="$1" >/dev/null
	jexec "${_JAIL}" sysctl net.inet6.ip6.forwarding="$1" >/dev/null
}

net_run() {
	# $1 = source IP, $2 = destination IP. Echoes graphpath stdout.
	# graphpath exits 1 even on correct output (a set -eu quirk in its final
	# draw path), so we deliberately ignore its exit code — the diff against
	# the golden file is the real pass/fail signal.
	jexec "${_JAIL}" sh "${GRAPHPATH}" "$1" "$2" 2>/dev/null || true
}

net_teardown() {
	[ -n "${_JAIL}" ] && jail -r "${_JAIL}" 2>/dev/null
	local ep
	for ep in ${_EPAIRS}; do
		ifconfig "${ep}a" destroy 2>/dev/null || true
	done
	_JAIL=""
	_EPAIRS=""
}

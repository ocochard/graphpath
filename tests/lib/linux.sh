# shellcheck shell=sh
# shellcheck disable=SC3043  # 'local' is supported by every shell this test runs under
# Linux backend for the graphpath regression harness.
#
# Isolation primitive: a network namespace (ip netns) — the Linux equivalent of
# a FreeBSD vnet jail. veth pairs replace epair; one end is moved into the
# namespace and renamed to test0/test1. Fake gateways get permanent neighbour
# (ARP/NDP) entries and static routes, exactly as on FreeBSD.
#
# Implements the same net_* contract as lib/freebsd.sh.
#
# UNVERIFIED: written from documented `ip` behaviour; not run on this FreeBSD
# host. Regenerate golden/linux/ with `sudo tests/run.sh --update` on Linux.

_NS="graphpath_test"
_VETHS=""    # host-side veth names to delete on teardown

_MAC0="02:00:00:00:01:01"
_MAC1="02:00:00:00:01:02"

_ns() { ip netns exec "${_NS}" "$@"; }

net_setup() {
	local nifaces="$1"
	ip netns del "${_NS}" 2>/dev/null || true
	ip netns add "${_NS}"
	_ns ip link set lo up

	local i=0
	while [ "${i}" -lt "${nifaces}" ]; do
		local host="gpveth${i}"       # host-side name (temporary)
		_VETHS="${_VETHS} ${host}"
		# create a veth pair: host end + peer that we push into the ns as testN
		ip link add "${host}" type veth peer name "test${i}"
		ip link set "test${i}" netns "${_NS}"
		eval "local mac=\${_MAC$i}"
		# shellcheck disable=SC2154  # mac assigned via the eval above
		_ns ip link set dev "test${i}" address "${mac}"
		_ns ip link set dev "test${i}" up
		i=$((i + 1))
	done
}

net_iface_addr() {
	# ip addr add works for both inet and inet6 (CIDR form)
	_ns ip addr add "$2" dev "$1"
}

net_route_add() {
	# $1 = dest net (CIDR), $2 = gateway
	_ns ip route add "$1" via "$2"
}

net_arp_add() {
	# permanent neighbour entry so the lladdr column is deterministic.
	# Unlike FreeBSD arp/ndp, `ip neigh` needs the device explicitly, so pick
	# the interface whose connected route covers this address.
	local dev
	dev=$(_ns ip route get "$1" 2>/dev/null | sed -n 's/.* dev \([^ ]*\).*/\1/p' | head -1)
	[ -n "${dev}" ] || dev=$(_ns ip -o addr show | awk '$3 ~ /^test/ {print $2; exit}')
	_ns ip neigh replace "$1" lladdr "$2" nud permanent dev "${dev}"
}

net_forwarding() {
	_ns sysctl -w net.ipv4.ip_forward="$1" >/dev/null
	_ns sysctl -w net.ipv6.conf.all.forwarding="$1" >/dev/null
}

net_run() {
	# graphpath exits 1 even on correct output; ignore its exit code (diff is
	# the real signal). Run it inside the namespace.
	_ns sh "${GRAPHPATH}" "$1" "$2" 2>/dev/null || true
}

net_teardown() {
	ip netns del "${_NS}" 2>/dev/null || true
	local v
	for v in ${_VETHS}; do
		ip link del "${v}" 2>/dev/null || true
	done
	_VETHS=""
}

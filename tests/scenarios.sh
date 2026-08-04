# shellcheck shell=sh
# shellcheck disable=SC2034  # SCENARIOS/SRC/DST are consumed by run.sh
# Scenario table for the graphpath regression harness.
#
# Each scenario is a shell function that fabricates a topology using ONLY the
# net_* contract (implemented per-OS in lib/<os>.sh) and then sets SRC and DST
# for run.sh to feed to graphpath. Because scenarios touch no OS-specific
# command, the same table drives FreeBSD, Linux and macOS.
#
# Address plan (RFC2544 / RFC3849 documentation ranges, matching README):
#   test0 subnet : 198.18.0.0/24     (2001:db8:18::/64)
#   test1 subnet : 198.19.0.0/24
#   far subnets  : 198.20.0.0/24 , 198.21.0.0/24   (reached via fake routers)
# Fake gateway MACs are fixed so ARP/NDP columns are deterministic.
#
# THIS_IP0 / THIS_IP1 are the local interface IPs; src/dst must differ from
# them or graphpath collapses the corresponding host box (graphpath:562,567).

SCENARIOS="fam1_src_direct fam1_dst_direct fam2_shared_router fam2_right_pad fam2_left_pad fam2_two_routers host_label fam1_inet6"

GW_MAC_A="00:0d:b9:3c:a0:aa"
GW_MAC_B="00:0d:b9:3c:a0:bb"
HOST_MAC="00:0d:b9:3c:a0:cc"

# --- Family 1: source and destination exit different interfaces ---

# src directly connected on test0; dst reached via a router on test1.
fam1_src_direct() {
	net_setup 2
	net_forwarding 1
	net_iface_addr test0 198.18.0.1/24
	net_iface_addr test1 198.19.0.1/24
	net_arp_add 198.18.0.50 "${HOST_MAC}"     # the source host, on-link
	net_arp_add 198.19.0.100 "${GW_MAC_A}"    # router towards dst
	net_route_add 198.20.0.0/24 198.19.0.100
	SRC=198.18.0.50
	DST=198.20.0.10
}

# Mirror: src reached via a router on test0; dst directly connected on test1.
fam1_dst_direct() {
	net_setup 2
	net_forwarding 1
	net_iface_addr test0 198.18.0.1/24
	net_iface_addr test1 198.19.0.1/24
	net_arp_add 198.18.0.100 "${GW_MAC_A}"    # router towards src
	net_arp_add 198.19.0.50 "${HOST_MAC}"     # the destination host, on-link
	net_route_add 198.20.0.0/24 198.18.0.100
	SRC=198.20.0.10
	DST=198.19.0.50
}

# --- Family 2: source and destination exit the SAME interface (test0) ---

# Both reached via the SAME router (src_gw == dst_gw): single shared ROUTER box.
fam2_shared_router() {
	net_setup 1
	net_forwarding 1
	net_iface_addr test0 198.18.0.1/24
	net_arp_add 198.18.0.100 "${GW_MAC_A}"
	net_route_add 198.20.0.0/24 198.18.0.100
	net_route_add 198.21.0.0/24 198.18.0.100
	SRC=198.20.0.10
	DST=198.21.0.10
}

# src via a router, dst directly connected — exercises draw_block "right" pad.
fam2_right_pad() {
	net_setup 1
	net_forwarding 1
	net_iface_addr test0 198.18.0.1/24
	net_arp_add 198.18.0.100 "${GW_MAC_A}"    # router towards src
	net_arp_add 198.18.0.50 "${HOST_MAC}"     # dst host, on-link
	net_route_add 198.20.0.0/24 198.18.0.100
	SRC=198.20.0.10
	DST=198.18.0.50
}

# dst via a router, src directly connected — exercises draw_block "left" pad.
fam2_left_pad() {
	net_setup 1
	net_forwarding 1
	net_iface_addr test0 198.18.0.1/24
	net_arp_add 198.18.0.50 "${HOST_MAC}"     # src host, on-link
	net_arp_add 198.18.0.100 "${GW_MAC_A}"    # router towards dst
	net_route_add 198.20.0.0/24 198.18.0.100
	SRC=198.18.0.50
	DST=198.20.0.10
}

# Both via DIFFERENT routers on the same interface — exercises draw_2blocks.
fam2_two_routers() {
	net_setup 1
	net_forwarding 1
	net_iface_addr test0 198.18.0.1/24
	net_arp_add 198.18.0.100 "${GW_MAC_A}"    # router towards src
	net_arp_add 198.18.0.200 "${GW_MAC_B}"    # router towards dst
	net_route_add 198.20.0.0/24 198.18.0.100
	net_route_add 198.21.0.0/24 198.18.0.200
	SRC=198.20.0.10
	DST=198.21.0.10
}

# forwarding disabled => THIS HOST label instead of THIS ROUTER (same as fam1).
host_label() {
	net_setup 2
	net_forwarding 0
	net_iface_addr test0 198.18.0.1/24
	net_iface_addr test1 198.19.0.1/24
	net_arp_add 198.18.0.50 "${HOST_MAC}"
	net_arp_add 198.19.0.100 "${GW_MAC_A}"
	net_route_add 198.20.0.0/24 198.19.0.100
	SRC=198.18.0.50
	DST=198.20.0.10
}

# --- IPv6 variant of fam1_src_direct: box_w=50, NDP parsing ---

fam1_inet6() {
	net_setup 2
	net_forwarding 1
	net_iface_addr test0 2001:db8:18::1/64
	net_iface_addr test1 2001:db8:19::1/64
	net_arp_add 2001:db8:18::50 "${HOST_MAC}"
	net_arp_add 2001:db8:19::100 "${GW_MAC_A}"
	net_route_add 2001:db8:20::/64 2001:db8:19::100
	SRC=2001:db8:18::50
	DST=2001:db8:20::10
}

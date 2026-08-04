# graphpath regression tests

Golden-file regression harness for `graphpath`. It builds a private, controlled
network stack, fabricates a routing topology, runs `graphpath` against it, and
diffs the ASCII output against a saved reference. This catches both parse
regressions in the OS-specific data layer and the whitespace-exact alignment
bugs the renderer is prone to (a one-column drift fails the diff).

## Why this works

`graphpath` never sends a packet: it only *reads* the local routing table,
`ifconfig`/`ip`, the ARP/NDP cache, and forwarding sysctls. So the tests
**fabricate** a topology — static routes and static ARP/NDP entries pointing at
gateways that do not exist — and `graphpath` renders it deterministically. No
peer host is ever needed.

## Running

```sh
sudo tests/run.sh              # run all scenarios, diff against golden
sudo tests/run.sh --update     # (re)generate the golden files for this OS
sudo tests/run.sh fam1_inet6   # run only the named scenario(s)
```

Root is required: creating the isolation container (vnet jail / netns / feth)
needs privilege. Golden files written under `sudo --update` are chowned back to
`$SUDO_USER` so they stay committable.

Pass/fail is the **stdout diff only**. `graphpath` exits 1 even on correct
output (a `set -eu` quirk in its final draw path); the harness deliberately
ignores its exit code. This is a known `graphpath` issue, not a test bug.

## Layout

```
tests/
  run.sh          OS detect, root check, scenario loop, diff, --update
  scenarios.sh    the 8 scenarios as OS-agnostic net_* calls (the test matrix)
  lib/freebsd.sh  backend: vnet jail + epair          (verified on 16.0-CURRENT)
  lib/linux.sh    backend: ip netns + veth            (verified on Ubuntu/6.x)
  lib/macos.sh    backend: feth on the real stack      (UNVERIFIED)
  golden/<os>/    per-OS reference output
```

`run.sh` and `scenarios.sh` are OS-agnostic; each `lib/<os>.sh` implements the
same `net_*` contract (`net_setup`, `net_iface_addr`, `net_route_add`,
`net_arp_add`, `net_forwarding`, `net_run`, `net_teardown`). To add an OS,
implement that contract and capture `golden/<os>/` with `--update`.

## Scenario matrix

Each scenario targets a distinct branch of `graphpath`'s render logic:

| id | family | exercises |
|----|--------|-----------|
| fam1_src_direct    | 1 | src direct / dst via router, different interfaces |
| fam1_dst_direct    | 1 | mirror of the above |
| fam2_shared_router | 2 | same interface, one shared router (LAN line) |
| fam2_right_pad     | 2 | same interface, src via / dst direct (right padding) |
| fam2_left_pad      | 2 | same interface, dst via / src direct (left padding) |
| fam2_two_routers   | 2 | same interface, two different routers (draw_2blocks) |
| host_label         | 1 | forwarding disabled -> THIS HOST instead of THIS ROUTER |
| fam1_inet6         | 1 | IPv6: wide boxes (box_w=50), NDP parsing |

## Golden files are per-OS

The same logical topology renders differently per OS, so each OS has its own
golden set:

- FreeBSD shows `net:` + a separate `mask:` line; Linux folds the prefix into
  `net: .../64` and omits `mask:`.
- Interface names: `test0`/`test1` on FreeBSD and Linux; macOS cannot rename
  virtual interfaces, so its backend uses fixed `feth100`/`feth101` units and
  its golden files show those names.

## Per-OS caveats

- **FreeBSD / Linux** — fully isolated (vnet jail / netns). Deterministic.
- **macOS** — no namespace/vnet equivalent. The backend adds routes and ARP/NDP
  entries on the **real** stack, so the run is *not* hermetic: a pre-existing
  route to a test subnet on the host will perturb the result. The test ranges
  (`198.18.0.0/15`, `2001:db8::/32`) are chosen to be unlikely to collide, but
  review macOS output before trusting it. macos.sh is unverified — capture and
  sanity-check `golden/macos/` on a real Mac.

## Regenerating after an intentional change

If you deliberately change `graphpath`'s layout, regenerate the affected OS's
golden files with `sudo tests/run.sh --update` and commit the diff. Review that
diff carefully — it is the record of what your change did to every diagram.

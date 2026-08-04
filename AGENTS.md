# AGENTS.md

This file provides guidance to AI tools when working with code in this repository.

## What this is

`graphpath` is a single POSIX `/bin/sh` script (no other source files) that renders an ASCII network diagram showing the routing path between a source IP and a destination IP, as seen from the routing table of the host it runs on. Part of the [BSDRP](https://bsdrp.net) toolset. Zero dependencies beyond the base-system networking tools.

## Running

```sh
./graphpath <source-IP> <destination-IP>   # IPv4 or IPv6
./graphpath -v                             # print version
```

Both arguments are required and must differ. IPv6 mode is auto-detected by a `:` in the source address. The script must run on the router/host whose route table you want to inspect — it reads the *local* forwarding state, so its output reflects that machine's view of the path, not an arbitrary one.

## Testing / linting

There is no test suite and no CI. Validate changes two ways:

1. `shellcheck graphpath` (available at `/usr/local/bin/shellcheck`).
2. Run against real addresses on a multi-homed host and eyeball the ASCII output against the reference diagrams in `README.md`. The layout is whitespace-exact; a one-column drift is a bug.

## Architecture

The script has two cleanly separated concerns: **data gathering** (OS-specific) and **rendering** (OS-agnostic). They communicate only through a fixed set of `src_*` / `dst_*` shell variables.

### Data gathering — the OS abstraction layer

`uname` dispatches (bottom of script) to one of:
- `get_bsd()` — FreeBSD / OpenBSD / NetBSD / Darwin. Parses `route -n get`, `ifconfig`, `arp`/`ndp`. Has per-OS special cases (e.g. `route` takes `-inet6`/`-inet` on FreeBSD/Darwin only; OpenBSD's `arp` output column differs).
- `get_linux()` — parses `ip route get`, `ip route show to match`, `ip neigh`, `ip link`. Linux `ip` output is positional and inconsistent across route types (`via` / `dev` / `from`), so parsing branches on the third token.

Each populates the same contract of variables for `i` in `src` and `dst`:
`${i}_ip`, `${i}_routeto`, `${i}_destination` (dest subnet), `${i}_mask`, `${i}_gateway` (literal string `direct` when directly connected), `${i}_gateway_arp` (MAC, or `empty`), `${i}_interface`, `${i}_interface_ip`, `${i}_interface_mac`. Also global `forwarding` / `forwarding6` booleans (decide `ROUTER` vs `HOST` label).

When adding OS support or fixing a parse bug, this is the only layer to touch — the renderer never calls a networking tool.

### Rendering — the diagram engine

Read the **Concept documentation** comment block at the top of the script first: it enumerates the two diagram *families* and the box primitives, and is the design spec the code implements.

- **Family 1** (`src_interface != dst_interface`): source and destination exit different interfaces — a tall single-column stack with `THIS ROUTER` in the middle showing both interfaces.
- **Family 2** (`src_interface == dst_interface`): both exit the same interface — a branched layout with a shared LAN line.

Box primitives (all rely on the globals `box_w`, `box_hw`, `ADD_RES`):
- `draw_block` — one host/router box; `position` (`left`/`right`) controls side padding vertical lines.
- `draw_2blocks` — two boxes side by side (Family 2).
- `draw_me` — the `THIS ROUTER`/`THIS HOST` box; mirrors interface info top-and-bottom in Family 1.
- `draw_block_line`, `draw_2blocks_line`, `draw_connector`, `draw_dual_connectors`, `draw_lan_line` — line/connector helpers.

### Box width is the layout invariant

`box_w` is set once from address family: **28 for IPv4, 50 for IPv6** (`box_hw = box_w/2 - 1`). Every `printf` format string computes field widths from `box_w`/`box_hw` via `eval`. If you change spacing, widths, or labels, you must keep all primitives consistent or the ASCII art misaligns. The heavy use of `eval` + `printf '%*s'` is deliberate (dynamic field widths in POSIX sh) — preserve the pattern rather than rewriting to another quoting style.

## Conventions

- Strict mode: `set -eu` is on. A referenced-but-unset variable aborts the script.
- Errors go through `die()` (prints `EXIT:` to stderr, exits 1).
- Keep it POSIX `/bin/sh` — no bashisms. It ships in BSDRP and must run on the base shell of every supported OS.

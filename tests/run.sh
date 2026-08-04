#!/bin/sh
#
# graphpath regression harness.
#
# Builds a private, controlled network stack (vnet jail on FreeBSD, netns on
# Linux, feth on macOS), fabricates a topology per scenario, runs graphpath,
# and diffs its output against a per-OS golden file. graphpath only reads the
# LOCAL routing/ARP state, so a fabricated table renders deterministically —
# see tests/README.md.
#
#   sudo tests/run.sh            # run all scenarios, diff against golden
#   sudo tests/run.sh --update   # (re)generate the golden files
#   sudo tests/run.sh <id>...    # run only the named scenario(s)
#
# Requires root: jexec / ip netns / feth setup all need privilege.

set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
GRAPHPATH="${HERE}/../graphpath"
export GRAPHPATH

[ "$(id -u)" -eq 0 ] || {
	echo "EXIT: must run as root (network isolation needs privilege)." >&2
	echo "  sudo $0 $*" >&2
	exit 1
}

case "$(uname)" in
FreeBSD)      OS=freebsd ;;
Linux)        OS=linux ;;
Darwin)       OS=macos ;;
*) echo "EXIT: unsupported OS $(uname)" >&2; exit 1 ;;
esac

# shellcheck source=/dev/null
. "${HERE}/lib/${OS}.sh"
# shellcheck source=/dev/null
. "${HERE}/scenarios.sh"

GOLDEN_DIR="${HERE}/golden/${OS}"
mkdir -p "${GOLDEN_DIR}"

UPDATE=false
WANT=""
for arg in "$@"; do
	case "${arg}" in
	--update) UPDATE=true ;;
	-*) echo "EXIT: unknown flag ${arg}" >&2; exit 1 ;;
	*) WANT="${WANT} ${arg}" ;;
	esac
done
[ -n "${WANT}" ] || WANT="${SCENARIOS}"

# Always tear down the current scenario's stack, even on failure/interrupt.
trap 'net_teardown' EXIT INT TERM

n=0
idx=0
fail=0
for name in ${SCENARIOS}; do
	idx=$((idx + 1))
	# skip scenarios not requested
	case " ${WANT} " in *" ${name} "*) : ;; *) continue ;; esac

	n=$((n + 1))
	num=$(printf '%02d' "${idx}")
	golden="${GOLDEN_DIR}/${num}-$(echo "${name}" | tr '_' '-').txt"

	SRC=""; DST=""
	net_teardown              # clear any leftover before building
	"${name}"                 # fabricate topology, set SRC/DST
	actual=$(net_run "${SRC}" "${DST}")
	net_teardown

	if "${UPDATE}"; then
		printf '%s\n' "${actual}" > "${golden}"
		# We run as root; hand the golden file back to the invoking user so
		# it stays writable/committable outside sudo.
		[ -n "${SUDO_USER:-}" ] && chown "${SUDO_USER}" "${golden}"
		echo "UPDATED ${name} -> ${golden##*/}"
		continue
	fi

	if [ ! -f "${golden}" ]; then
		echo "FAIL    ${name}: no golden file (${golden##*/}); run --update"
		fail=$((fail + 1))
		continue
	fi

	if printf '%s\n' "${actual}" | diff -u "${golden}" - >/tmp/gp_diff.$$ 2>&1; then
		echo "PASS    ${name}"
	else
		echo "FAIL    ${name}"
		cat /tmp/gp_diff.$$
		fail=$((fail + 1))
	fi
	rm -f /tmp/gp_diff.$$
done

echo "----"
if "${UPDATE}"; then
	echo "${n} golden file(s) written."
	exit 0
fi
if [ "${fail}" -eq 0 ]; then
	echo "${n} scenario(s): all PASS"
	exit 0
else
	echo "${n} scenario(s): ${fail} FAIL"
	exit 1
fi

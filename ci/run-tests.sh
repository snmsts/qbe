#!/usr/bin/env bash
# CI test runner for qbe-cl, split by what the host can actually execute.
#
#   ci/run-tests.sh linux   # host-agnostic golden/unit (both targets) +
#                           # amd64 native-exec + amd64 byte-exact-vs-`as`
#   ci/run-tests.sh macos   # arm64/Apple native-exec + arm64 byte-exact-vs-`as`
#                           # (needs an Apple Silicon host)
#   ci/run-tests.sh windows # host-agnostic golden/unit + arm64_win native-exec
#                           # (needs a Windows ARM64 host whose `cc` is an
#                           #  aarch64-*-windows one -- e.g. MSYS2 CLANGARM64.
#                           #  The amd64 tests are SysV + ELF pseudo-ops, which
#                           #  a native Windows `as` cannot assemble at all, so
#                           #  they are simply not part of this group.)
#
# Every listed test is a self-contained `--script` that exits 0 on success, with
# ONE exception: `rega` is a partial parity metric (qbe-cl's -dR vs real QBE's
# exact allocation + edge-split naming); it is gated on a structural-match
# baseline instead of exit code.  See commit 57daab8.
set -uo pipefail
cd "$(dirname "$0")/.."                       # repo root
OS="${1:?usage: run-tests.sh (linux or macos)}"
REGA_BASELINE="${REGA_BASELINE:-154}"         # of 180 functions

pass=0; fail=0; failed=()

run() {                                       # run NAME  -> hard gate (exit 0)
  local t="$1" f="test/$1.lisp" log="/tmp/ci-$1.log"
  if [ ! -f "$f" ]; then echo "  MISS $t"; failed+=("$t(missing)"); fail=$((fail+1)); return; fi
  if ros -Q run --non-interactive -- --script "$f" >"$log" 2>&1; then
    echo "  PASS $t   $(grep -aE '===|passed|match|BYTE-EXACT' "$log" | tail -1)"
    pass=$((pass+1))
  else
    echo "  FAIL $t"; tail -15 "$log"; failed+=("$t"); fail=$((fail+1))
  fi
}

rega_metric() {                               # rega: pass iff norm >= baseline
  local log=/tmp/ci-rega.log
  ros -Q run --non-interactive -- --script test/rega.lisp >"$log" 2>&1 || true
  local n
  n=$(grep -aoE 'norm \(structure\): +[0-9]+/[0-9]+' "$log" | grep -oE '[0-9]+/[0-9]+' | cut -d/ -f1)
  if [ "${n:-0}" -ge "$REGA_BASELINE" ]; then
    echo "  PASS rega (norm ${n}/180 >= ${REGA_BASELINE} baseline)"; pass=$((pass+1))
  else
    echo "  FAIL rega (norm ${n:-?}/180 < ${REGA_BASELINE} baseline)"; tail -10 "$log"
    failed+=("rega"); fail=$((fail+1))
  fi
}

echo "=== qbe-cl CI: $OS ==="
# -dP + per-pass golden/unit for BOTH targets.  Pure computation: no external
# tool is needed, so every host runs these.  `arm64-win` self-skips its native
# section unless `cc` is an aarch64-*-windows one.
PURE="run ssa gvn gcm dom live spill coalesce isel simplcfg promote loadopt \
      depth abi arm64-isel arm64-abi arm64-rega arm64-win"

case "$OS" in
  linux)
    for t in $PURE; do run "$t"; done
    for t in emit m1; do run "$t"; done       # need a working amd64 `cc`/`as`
    rega_metric
    # amd64-native: runs x86-64 code / diffs vs the host `as`
    for t in e2e corpus-e2e minic-e2e encode encode-corpus; do run "$t"; done
    ;;
  macos)
    # arm64/Apple only: executes native arm64 / diffs vs Apple's `as`
    for t in arm64-m1 arm64-corpus-e2e arm64-minic-e2e arm64-jit-smoke \
             arm64-encode arm64-encode-corpus arm64-encode-data; do run "$t"; done
    ;;
  windows)
    for t in $PURE; do run "$t"; done
    rega_metric
    # arm64_win native-exec: the corpus programs actually run and print
    run arm64-win-corpus-e2e
    ;;
  *) echo "usage: $0 {linux|macos|windows}"; exit 2;;
esac

echo "=================================================="
echo "$OS: $pass passed, $fail failed${failed:+  (${failed[*]})}"
exit $(( fail > 0 ? 1 : 0 ))

# qbe-cl

A reimplementation of the [QBE](https://c9x.me/compile/) compiler backend in
idiomatic Common Lisp.

QBE is not the source being translated — it is the **specification and the
differential oracle**. qbe-cl reads QBE IL (textual SSA), runs the mid-end
optimizations and target lowering, and emits assembly (or machine code
directly).

Two separate claims are made here, and they are tested differently. **Fidelity**
— that a pass reproduces what upstream QBE does — is checked by diffing against
the real `qbe`'s `-d` debug dumps over QBE's own test corpus (77 files, 180
functions). Every pass through instruction selection matches byte for byte;
register allocation deliberately does not (see below). **Correctness** — that
the emitted code computes the right thing — is checked by assembling, linking
and running the corpus programs natively, which is what "the backend is done"
means here. The two claims are kept apart on purpose: a pass can be correct
without being byte-identical, and the tables below say which is which.

The full chain **C → `minic` → QBE IL → qbe-cl → native executable** runs, on
`amd64_sysv` and `arm64_apple`, for the four C programs QBE ships as `minic`
samples (collatz, euler9, prime, queen).

## Targets

| Target | Host | Status |
|---|---|---|
| `amd64_sysv` | x86-64 Linux | corpus 47/47 native, `minic` programs 4/4 |
| `amd64_apple` | x86-64 macOS (incl. Rosetta 2 on Apple Silicon) | corpus 52/0/0 native (the 47 driver programs + 5 self-contained ones, incl. `tls.ssa`) |
| `arm64_apple` | Apple Silicon | corpus 45/0/2 native, `minic` programs 4/4 |
| `arm64_win` | Windows on ARM64 | corpus 45/0/2 native. No TLS. Frames large enough to need a `__chkstk` probe are **refused, not miscompiled** |
| `amd64_win` | Windows x64 (incl. ARM64 emulation) | corpus 45/0/3 native. No TLS |

Corpus scores are *passed / failed / skipped* over the 47 corpus files that
carry a C driver. Every skip is the corpus's own `# skip` marker for something
outside this backend — POSIX signals, pthreads, or an architecture the program
cannot run on — so these are ceilings, not partial scores.

Upstream QBE targets `amd64_sysv`, `amd64_apple`, `amd64_win`, `arm64`,
`arm64_apple` and `rv64`. qbe-cl implements four of those six; `arm64` (ELF)
and `rv64` are not written. (`amd64_apple` is the SysV ABI under a mach-o
dialect — `_` prefixes, `L` locals, `__TEXT` literal sections, `@tlvp` TLS —
so it shares every pass with `amd64_sysv` and differs only in the target
record and the emitter's dialect branches; see `test/amd64-apple.lisp`.)

`arm64_win` is the exception in the other direction: **upstream has no Windows
on ARM64 target at all**, so no fidelity claim is made for it — there is nothing
to be faithful to. Its assembler dialect and its vararg rules are pinned
textually with clang as the oracle instead, and its correctness rests on the
corpus running natively (`test/arm64-win.lisp`,
`test/arm64-win-corpus-e2e.lisp`).

`amd64` and `arm64` each also have an **assembler-less machine-code encoder**
(`src/{amd64,arm64}-encode.lisp`), producing bytes plus relocations rather than
assembly text. Each is diffed against the host `as` over every corpus function
— byte-identical on amd64, and on arm64 modulo two expected differences that
are counted separately (ops the encoder does not cover yet, and local `bl`s that
`as` resolves but the encoder leaves as a relocation). On Apple Silicon the
emitted bytes are also mapped executable and called, in `test/arm64-jit-smoke.lisp`.

## How it is verified

**Fidelity — per-pass byte-exactness** against `qbe -d…`. The mid-end passes
are target-independent and shared; the numbers below are over all 180 corpus
functions.

| Pass | Oracle | Result |
|---|---|---|
| parse → print | `-dP` | 180/180, 77/77 files |
| dominators / SSA construction | `-dN` | 180/180 |
| slot promotion (mem2reg) | `-dM` | 180/180 |
| load elimination | `-dM` | 180/180 |
| slot coalescing | `-dM` | 180/180 |
| GVN / GCM / simplcfg | `-dG`, `-dC` | 180/180 |
| ABI lowering | `-dA` | 180/180 × `amd64_sysv`, `arm64_apple`, `amd64_win` — structs, stack args, varargs, `env` |
| instruction selection | `-dI` | 180/180 × `amd64_sysv`, `arm64_apple` |
| liveness / spill costs | `-dL`, `-dS` | 180/180 |
| spilling | `-dS` | 180/180 |
| register allocation | `-dR` | 154/180 structural (see below) |

Register allocation is the one pass that does not reach parity: it picks
different registers than QBE for some functions. Nothing suggests those
allocations are wrong — every end-to-end test below passes — but that is
behavioural evidence, not the byte-exact parity the other rows report. CI gates
this row on the 154 baseline rather than on equality.

**Correctness — native execution**, which is what "the backend is done"
actually means:

- hand-written programs (`test/e2e.lisp`) — arithmetic, division, shifts, loops,
  phis, calls, callee-save, SIB addressing, float constants, float→uint, struct
  by value and by return, varargs.
- QBE's own corpus programs (`test/*corpus-e2e.lisp`) — compiled, linked against
  the embedded C driver, run, and checked on exit code and stdout.
- real C programs (`test/*minic-e2e.lisp`) — collatz, euler9, prime, queen,
  compiled by QBE's sample C compiler `minic`, run through this backend, and
  compared against the output of a C compiler on the same source.

## Running the tests

SBCL via [Roswell](https://roswell.github.io/). Golden dumps are checked in, so
**the full regression runs without a `qbe` binary**.

```sh
ci/run-tests.sh linux      # shared golden/unit + amd64 native exec + as-diff
ci/run-tests.sh macos      # arm64_apple native exec + as-diff (Apple Silicon)
                           # + amd64_apple native exec (Rosetta 2)
ci/run-tests.sh windows    # shared golden/unit + arm64_win / amd64_win native exec
```

Each test is also a self-contained script that exits 0 on success:

```sh
ros -Q run -- --script test/run.lisp             # parse/print       (-dP)
ros -Q run -- --script test/ssa.lisp             # SSA construction  (-dN)
ros -Q run -- --script test/gvn.lisp             # GVN               (-dG)
ros -Q run -- --script test/abi.lisp             # SysV ABI lowering (-dA)
ros -Q run -- --script test/winabi.lisp          # Win64 ABI lowering
ros -Q run -- --script test/isel.lisp            # instruction selection
ros -Q run -- --script test/corpus-e2e.lisp      # corpus programs, natively
ros -Q run -- --script test/minic-e2e.lisp       # real C programs, natively
```

Regenerating goldens, or diffing a new `.ssa`, needs the real QBE:

```sh
git clone git://c9x.me/qbe.git && cd qbe && make
export QBE_BIN=$PWD/qbe
```

## Design

- **CLOS for structure, data tables for opcodes.** `module` / `fn` / `blk` /
  `phi` / `ins` / `typ` are classes; the ~80 opcodes are keywords plus a
  property table derived from `ops.h`, not a class hierarchy.
- **Refs are real object references.** A temporary is a `tmp`, a constant a
  `con`, an addressing mode a `mem`. Liveness and interference still go through
  each temp's stable id as a bitset, the way QBE does.
- **Faithful port where there is an oracle, rewritten where there is not.** The
  hard passes — isel, spill, rega, ABI lowering, load elimination — are ported
  closely enough to match the `-d` dumps byte for byte. Everything else is
  written the way Common Lisp wants to be written.

```
src/
  packages.lisp ops.lisp ir.lisp        ; op table + IR model
  target.lisp                           ; the per-target protocol
  parse.lisp print.lisp                 ; IL text <-> IR  (byte-exact vs -dP)
  cfg.lisp ssa.lisp mem.lisp            ; rpo/dom/frontier, SSA, promotion
  gvn.lisp gcm.lisp ifopt.lisp          ; GVN + GCM + if-conversion
  load.lisp                             ; alias analysis, loadopt, coalescing
  backend.lisp spill.lisp rega.lisp     ; shared backend: liveness, spill, rega
  amd64.lisp amd64-abi.lisp             ; x86-64 register model, SysV ABI
  amd64-winabi.lisp                     ;   Microsoft x64 ABI
  amd64-isel.lisp amd64-emit.lisp       ;   selection, asm output
  amd64-encode.lisp amd64-targ.lisp     ;   machine code, target instances
  arm64.lisp arm64-abi.lisp             ; AArch64 register model, AAPCS64/Apple
  arm64-isel.lisp arm64-emit.lisp       ;   selection, asm output
  arm64-encode.lisp arm64-targ.lisp     ;   machine code, target instances
  driver.lisp
test/
  corpus/  minic/                       ; QBE test/*.ssa + minic-generated IL (MIT)
  golden*/                              ; per-pass -d goldens, per target
  *.lisp                                ; the diff oracles and e2e runners
```

Longer notes: [`DESIGN.md`](DESIGN.md) for the overall design and milestone
history, [`src/AMD64-WIN-PORT.md`](src/AMD64-WIN-PORT.md) for the Win64 port
(correspondence table with `amd64/winabi.c`, pitfalls, open items).

## Known gaps

None of these affect the correctness of what is generated today.

- **Register selection parity** (154/180) — benign, see above. Closing it would
  need a trace of the real QBE's allocator.
- **TLS** — unimplemented on the Windows targets, where upstream QBE also
  `die`s, and on `amd64_sysv`, where the emit path (`%fs:sym@tpoff`) is
  unwritten. On `amd64_apple` it is implemented (the mach-o `@tlvp`
  descriptor-call sequence) and `tls.ssa` runs natively.
- **`extern` data through the GOT** on `amd64_sysv` — no corpus program uses
  it. (On both Windows targets `extern` addresses do work, through a COFF
  `.refptr` COMDAT, and on `amd64_apple` through `@gotpcrel`, checked against
  the C compiler natively.)
- **Large frames** on the Windows targets — a frame that reaches a guard page
  needs a `__chkstk` probe, which is a frame-layout change, not a prologue
  tweak. `arm64_win` refuses such frames rather than emitting code that faults.
- **The JIT encoders assume SysV**, so they are not usable from the Windows
  targets yet.

License: MIT, the same as QBE.

# qbe-cl design document (v0)

Reimplement the architecture of [QBE](https://c9x.me/compile/) in idiomatic
Common Lisp. QBE itself is not the source being translated — it is the
**specification and the differential oracle**.

Reference source: `git://c9x.me/qbe.git` (MIT). This document was written while
reading the real sources (`all.h` / `main.c` / `ops.h` / `parse.c` and the rest,
~9k lines).

> **On reading this document.** Sections 1–5 are the original v0 design. Where
> the implementation later went somewhere else, the original text is kept and
> followed by a **Superseded** note saying what actually shipped and why — the
> v0 reasoning is worth keeping as a record, but on its own it would now be
> wrong. Section 6 is the milestone log, updated as milestones landed.

---

## 1. Goals and non-goals

- **Goal**: read QBE IL (textual SSA) in pure CL and emit arm64 assembly text.
  An AOT leaf tool that assembles and links via `as`/`cc`. Host-independent (developed
  on SBCL, usable as a portable library from dotcl or standalone).
- **Performance goal**: QBE's own — "70% of LLVM's performance in 10% of the
  code". Correctness first, speed second.
- **First target**: **arm64 only**, for dogfooding on a Snapdragon machine.
  amd64/rv64 come later.
- **Non-goal**: a runtime JIT (patching live callbacks in). Shelling out to `as`
  is too slow for that. The JIT half belongs to a separate project (emitting
  straight into executable pages, or Cranelift). Keep the division.
- **Non-goal (for now)**: line-by-line transliteration of C bitset/pointer code.
  That leaves only the ugly parts. Rewrite those as data-to-data transformations.

> **Superseded — first target.** amd64 shipped first, not arm64: the development
> machine was x86-64 only, with no arm64 `as` or qemu available. arm64 followed
> as a second implementation of the target protocol (§6, M6) once hardware was
> at hand. There are now four targets: `amd64_sysv`, `amd64_win`, `arm64_apple`,
> `arm64_win`.
>
> **Superseded — the JIT non-goal, partly.** The division still holds: the
> loader/linker (symbol and relocation resolution, data pages) is
> [solder](https://github.com/snmsts/solder)'s job, not this project's. But
> qbe-cl does now emit machine code directly, not only assembly text —
> `src/{amd64,arm64}-encode.lisp` produce bytes plus fixups, which is exactly
> what solder consumes. `test/arm64-jit-smoke.lisp` maps those bytes executable
> and calls them, but only for leaf functions that need no fixups.

---

## 2. Oracle strategy (the heart of this design)

Run QBE at each stage and diff the output. Not having to fear the "designed from
nothing" failure mode is the whole point of this project.

### 2.1 Per-pass intermediate dumps (`qbe -d<FLAG>`)

The `debug[]` flags in `main.c` mark the points where QBE dumps IL through
`printfn` after each pass. Those dump points are directly usable as
**differential oracles for the intermediate stages**:

| flag | dump point | pass |
|------|------------|------|
| `P` | after parsing | parse |
| `M` | memory optimization | promote / coalesce |
| `N` | ssa construction | ssa (Braun et al.) |
| `C` | copy elimination | copy |
| `G` | gvn / gcm | gvn, gcm |
| `K` | if-conversion | ifconvert (only on a `cansel` target) |
| `A` | abi lowering | abi0/abi1 (per-target) |
| `I` | instruction selection | isel (per-target) |
| `L` | liveness | filllive |
| `S` | spilling | spill |
| `R` | register allocation | rega |

**Implication**: build a pretty-printer that is **byte-identical to QBE's
textual dumper** (`printfn`/`printref`, parse.c) at the very start. The entire
diff strategy rests on it. Known normalization differences (uniquifying names
and so on) are absorbed by an allow-list.

### 2.2 End-to-end golden tests

Reuse QBE's own `test/*.ssa` as the golden corpus. Each file embeds a driver and
the expected output:

```
# >>> driver
#   ... the C main() that calls in ...
# <<<
# >>> output
#   expected stdout
# <<<
```

The harness (a CL equivalent of `tools/test.sh`) does:
`qbe-cl foo.ssa → foo.s` → `cc foo.s driver.c` → run → compare stdout against the
expected value. On top of that, cross-check the runtime behaviour against real
QBE's output as well (a second oracle).

> **Resolved.** The harness lives in CL alone (`test/harness.lisp` plus one
> `--script` runner per pass); `tools/test.sh` is not wrapped. Goldens are
> checked into `test/golden*/`, so the whole regression runs without a `qbe`
> binary present.

---

## 3. The authoritative pass pipeline

The order in `main.c: func()` is the only truth. The `fill*` routines recompute
analysis information (they are derived facts, not data-to-data transforms), so
in CL they are either values computed on demand or explicit analysis objects.

```
abi0                     ; per-target ABI preprocessing (elimsb and friends)
fillcfg / filluse
promote                  ; mem→reg (memory optimization)
ssa                      ; SSA construction  ← Braun et al.
ssacheck
fillalias / loadopt      ; load optimization
coalesce                 ; slot coalescing
filldom
gvn                      ; global value numbering
simplcfg
gcm                      ; global code motion
[ifconvert]              ; only when T.cansel
abi1                     ; per-target ABI lowering (calling convention/struct/varargs)
simpl
isel                     ; per-target instruction selection
filllive / fillloop / fillcost
spill                    ; spilling
rega                     ; register allocation
simpljmp                 ; jump simplification
emitfn                   ; asm text output (per-target)
```

**Where the work actually is** (honestly):

- Light: SSA construction, cfg/dom, copy, fold — all well understood.
- **Heavy (the bulk of it)**: `abi1` + `isel` + `emit` (the per-target grind,
  which has to be faithful) and `spill` + `rega`. Without a diff oracle this is
  where the project dies.
- That is the reason for narrowing to arm64 alone.

> **Superseded.** The narrowing happened, but to amd64 rather than arm64 (§1).
> The prediction itself held up exactly: `abi1`/`isel`/`emit`/`spill`/`rega` were
> the bulk of the work on every target, and the `-d` oracle is what made them
> finishable. Notably, the second and later targets were far cheaper than the
> first — arm64 reused the whole mid-end, and `arm64_win` reuses the arm64
> register model, isel, abi1 and emit verbatim, differing only in assembler
> dialect and vararg rules.

---

## 4. The IR data model (CLOS)

### 4.1 The key decision: "CLOS for structure nodes, data tables for opcodes"

QBE itself does **not** give each opcode its own struct. `Ins` is a single struct
(an `op` enum, two arguments, one result), and the properties that distinguish
arithmetic from comparison from memory live in a shared property table,
`optab[]` (`ops.h`). There are ~80 opcodes.

→ **Do not make a CLOS subclass per opcode** (80 classes would collapse under
their own weight). Instead:

- **Only structure nodes become CLOS classes**, where dispatch and per-target
  polymorphism earn their keep: `module` / `target` / `fn` / `blk` / `phi` /
  `ins` / `con` / `typ`.
- **Opcodes are keyword symbols** (`:add`, `:loadw`, `:ceqw`, …) held in a slot
  of `ins`.
- Opcode properties are looked up in a **data table `*optab*`** (keyword → op
  descriptor) ported from `ops.h`. Passes then do "generic dispatch on the node
  class, branch on the opcode (case or table lookup)".

This matches QBE's own design, and it is idiomatic in CL too (table-driven code
alongside generic functions).

### 4.2 Class hierarchy (skeleton)

```
module        ; top-level aggregate: functions, data-defs, type-defs, target
  target      ; per-target strategy, dispatched through generic functions:
              ;   target-isel / target-abi0 / target-abi1 / target-emit
              ;   ret-regs / arg-regs / gpr-set / fpr-set / caller-save …
              ; ← QBE's Target (a struct of function pointers); where CLOS shines
  fn          ; start-blk, tmps, cons, retty, flags (vararg/leaf/dynalloc)
    blk       ; phis, ins (growable vector), jmp (terminator), s1/s2, preds,
              ;   derived: idom/dom/fron/loop, liveness sets (bitset)
      phi     ; to, cls, a sequence of (blk . val)
      ins     ; op (keyword), cls, to (ref), arg[2] (ref)
  con         ; :undef | :bits | :addr, sym, value (int/double/float)
  typ         ; aggregate: name, union?, align, size, fields
```

The `jmp` terminator is a slot on `blk` (type + arg), as in QBE. The `Jxxx` enum
becomes keywords.

> **Superseded — `target` is not a CLOS class.** It is a `defstruct` with
> function-valued slots (`src/target.lisp`). QBE's design *is* a struct of
> function pointers, and mirroring that 1:1 keeps the source correspondence with
> `targ.c` while staying lighter than a class hierarchy. The generic backend
> passes read the register model through thin `tg-*` accessors over `*target*`
> instead of through generic-function dispatch. Every other class above landed
> as described.

### 4.3 Representing values (Ref) — an idiomatic divergence

QBE's `Ref` is a 3-bit tag plus a 29-bit value (RTmp/RCon/RInt/RType/RSlot/
RCall/RMem), where the value is an index into a per-function array. **In CL, use
real object references rather than indices**:

- a referenced temporary → the `tmp` instance itself
- a constant → the `con` instance
- small tagged values like RSlot/RInt/RType → a lightweight wrapper struct

But **liveness and the interference graph run over bitsets keyed by temp id**,
so `tmp` carries a stable integer `id` slot (an object *and* an id — identity
and index used side by side). The bitset passes (`live`/`spill`/`rega`) are the
one place ported faithfully from the C, going through ids.

### 4.4 The op descriptor (porting ops.h)

The one part of `ops.h` that genuinely is a table. Keyword → descriptor:

```
name, argcls[result class (w/l/s/d)][arg 0..1],
canfold, hasid, idval, commutes, assoc, idemp,
cmpeqwl, cmplgtewl, eqval, pinned
```

The type classes are `Kw/Kl/Ks/Kd` (= `:w :l :s :d`, with `Kx` = `:x`, top).
Generate the table from a single DSL sheet equivalent to `ops.h` via a macro —
do not transcribe it by hand.

### 4.5 The type system (from the IL specification)

- base: `w` (i32), `l` (i64), `s` (f32), `d` (f64). Extended: `b` (i8),
  `h` (i16). Sub-word params/returns: `sb ub sh uh`. Subtyping: an `l` may be
  used in a `w` context (its low 32 bits).
- sigils: `:` aggregate type, `$` global, `%` temporary, `@` block label.
- instruction categories: arithmetic/bitwise, load/store, alloc, blit,
  comparison (`c*`), conversion (`ext*`/`*tof`/`*tosi`), cast/copy, call
  (with `env` and variadic `...`), vastart/vaarg, phi, jmp/jnz/ret/hlt.

---

## 5. Package and system layout (as built)

An ASDF system. SBCL is assumed but nothing is host-specific (pure CL, with
`as`/`ld` subprocesses as the only external dependency). The originally sketched
`opt.lisp` and `arm64/` subdirectory gave way, as the implementation grew, to
the flat layout below: one file per pass, per-target files carrying an
`amd64-` prefix.

```
qbe-cl.asd
src/
  packages.lisp ops.lisp ir.lisp        ; the §4 CLOS classes + ops.h table + ref
  target.lisp                           ; the per-target protocol
  parse.lisp print.lisp                 ; IL text <-> module (byte-exact vs -dP)
  cfg.lisp                              ; rpo/preds/dom/fron + depth/loop
  ssa.lisp mem.lisp                     ; Braun SSA + fill-use/live, promote
  gvn.lisp gcm.lisp ifopt.lisp          ; GVN (fold/copyref width analysis/assoccon) + GCM + ifconvert
  load.lisp                             ; alias analysis + loadopt + coalesce
  backend.lisp spill.lisp rega.lisp     ; materialize-regs, live/spill/rega
  amd64.lisp amd64-abi.lisp             ; x86-64 register model, SysV ABI
  amd64-winabi.lisp                     ;   Microsoft x64 ABI
  amd64-isel.lisp amd64-emit.lisp       ;   selection, asm output (emit.c omap)
  amd64-encode.lisp amd64-targ.lisp     ;   machine code, target instances
  arm64.lisp arm64-abi.lisp             ; AArch64 register model, AAPCS64/Apple
  arm64-isel.lisp arm64-emit.lisp       ;   selection, asm output
  arm64-encode.lisp arm64-targ.lisp     ;   machine code, target instances
  driver.lisp                           ; module -> asm -> as/ld -> run
test/
  harness.lisp                          ; the §2.2 golden runner + §2.1 pass-diff runner
  corpus/  minic/                       ; QBE test/*.ssa + minic-generated IL
  golden*/                              ; per-pass -d goldens, per target
  *.lisp                                ; the diff oracles and e2e runners
ci/
  run-tests.sh                          ; the test groups, split by what a host can execute
```

Naming: the package is `qbe`. Per-target files were to stay flat under an
`amd64-` prefix for the time being, with the intent of factoring them into
generic functions in `target.lisp` once arm64 arrived. C type names
(Fn/Blk/Ins/Ref/Con/Typ) are kept as `fn`/`blk`/`ins`/`ref`/`con`/`typ` on the CL
side, to keep source correspondence easy.

> **Superseded — how the factoring went.** `target.lisp` did arrive with arm64
> (milestone G0), but as a struct of function-valued slots rather than generic
> functions (§4.2). The flat `amd64-`/`arm64-` prefixes stayed; no subdirectories
> were introduced.

---

## 6. Milestones (a walking skeleton first, vertically)

Go deep (end to end) before going wide (each pass perfected). Have the diff
harness and one working function on day 1, then keep replacing naive with clever
while staying green throughout.

- **M0 foundation** ✅ **done (2026-07-05)**: IR classes + ops table + parse +
  print. `parse→print` is **byte-identical to real QBE `-dP` across the entire
  test corpus plus the regression fixtures: 180/180 functions, 77/77 files**.
  Goldens are saved under `test/golden/`, so regressions run without qbe.
  Normalizations reproduced: params→`par`, call args→`arg*`,
  `ret`→`ret<cls>`/`ret0`/`retc`, `blit`→`blit0`+`blit1`, `loadw`→`loadsw`,
  omitted fall-through jmps, constant dedup (`newcon` ignores the float →
  `d_0`/`s_0`→`0`), C `%f` for floats, and signed-int64 wrapping of integer
  literals (`getint`; `2^63`→negative, regression-tested by `intwrap.ssa`).
- **M1 walking skeleton** ✅ **done (2026-07-05)**: lower one single-block,
  integer-only (w/l), straight-line function to **amd64**, assemble and link it
  with `cc`, **run it natively**, and verify through the exit code — a closed
  loop (`test/m1.lisp`, 7/7). isel and rega use the most naive scheme available
  (every temp gets a stack slot; each instruction loads into a scratch register,
  computes, stores back), which sidesteps allocation entirely. Ops covered:
  par/copy/add/sub/mul/and/or/xor/neg/ret. **The target is amd64 because the
  development environment is x86-64 only** (no arm64 `as`, no qemu); arm64 comes
  later as a second implementation of the target protocol. Anything out of
  scope — unknown ops, multiple blocks, phi — raises rather than miscompiles.
- **M1-B extended codegen** ✅ **done (2026-07-05)**: same naive scheme, now with
  **multiple blocks and control flow**. jmp/jnz, integer comparisons
  (`c{eq,ne,slt..,ult..}{w,l}` → 0/1), load/store/alloc, and **phi lowered to
  edge copies** (two-phase staging to handle parallel-copy hazards). SSA
  *construction* is still M2's job; phi *lowering* is done in codegen. Programs
  with branches, loops and memory run, and agree with real QBE (amd64) on exit
  code. `test/m1.lisp` 12/12 (branch/loop-sum/fact/mem/phi-swap added). Calls,
  floats and blit are not covered yet.
- **M2 real SSA** (driven by the byte-exact oracle, split A1–A4):
  - **A1 cfg + dom + fron** ✅ **done (2026-07-05)**: fill-rpo (DFS postorder →
    RPO, unreachable blocks dropped) / fill-preds / fill-dom
    (Cooper-Harvey-Kennedy) / fill-fron. **The dominator tree is checked against
    `qbe -dN`'s `> Dominators:` dump and matches across the whole corpus:
    180/180 functions, 77/77 files** (promote and abi0 do not change CFG shape,
    so the comparison can be done on freshly parsed IR). `newtmp` names follow
    `"%s.%d"` with a module-wide static counter.
  - **A2 filllive + A3 ssa** ✅ **done (2026-07-05)**: bitsets (CL `bit-vector`
    keyed by dense id), a temp registry (`fn-tmp`/`fn-ntmp`, materialized during
    parse) plus `newtmp` (run-global `*tmp-counter*`), `fill-use` (with a phicls
    union-find), `fill-live` (with `live-on`; the pre-isel liveness that lets
    `phiins` prune inside `ssa()` — RCall/RMem/rglob do not exist before isel and
    are skipped), `phiins`, and `renblk` (a Name stack).
    `ssa` = filldom→fillfron→filllive→phiins→renblk. The key point: `fill-live`
    is a component of `ssa()`, not a downstream pass, which makes the A2→A3 order
    inevitable. `src/ssa.lisp`, `test/ssa.lisp`.
  - **A4 promote** ✅ **done (2026-07-06)**: promote (mem2reg) from `src/mem.c`.
    Walk the allocs in the start block; if every use is a load or store of
    consistent size and class, rewrite alloc→nop, store→copy (making the slot a
    def), and load→copy/cast/ext. Slots that become multi-def are turned into
    phis by the later `ssa`. `src/mem.lisp`, `test/promote.lisp`. **Byte-identical
    to `qbe -dM`'s "> After slot promotion:" across the whole corpus: 180/180
    functions, 77/77 files.** For promote+ssa, `-dN`'s "> After SSA construction:"
    matches **structurally on all 180/180** (after normalizing temp suffixes);
    raw byte equality is 168/180, and the residue is purely a `newtmp` counter
    offset: qbe runs each function all the way through the backend (isel/rega,
    which generate `%isel.N`) before parsing the next one, so a later function's
    `.N` has the earlier functions' isel temps accumulated into it. Resolved at
    M3/isel. Not an SSA or promote bug.
- **C (mid-end)** ✅ **done (2026-07-06 – 07-11)**: the `-dA`/`-dI` diffs are gated
  on the mid-end (gcm's code motion, gvn's commutative normalization
  `add 1,%x`→`add %x,1`), so the mid-end was pulled ahead of ABI and isel.
  **gvn** (gvn.c 508 lines + fold.c: normins/copyref/foldref/gvndup (CSE)/
  dedupphi/dedupjmp/rebuildcfg, including copyref's width analysis
  usewidthle/defwidthle and assoccon) + **simplcfg** + **gcm** (schedearly/late/
  gcmmove/sink), diffed against `-dG`/`-dC`. **loadopt** (load.c + alias.c:
  backward walk from the def to forward stores into loads, shift/mask/or for
  partial overlaps, phi synthesis) + **coalesce** (mem.c: slot fusion by linear
  liveness, dead-store removal) + **ifconvert** (ifopt.c, T.cansel).
  **`-dG`/`-dC`/`-dM` (load elimination and slot coalescing) are byte-identical
  on all 180 functions.** `src/{gvn,gcm,ifopt,load}.lisp`.
- **M3 amd64 ABI + isel, faithfully** ✅ **done (2026-07-06 – 07-11)**: diffed
  against `-dA`/`-dI`. **abi1** (a faithful port of sysv.c: register/stack/memory
  aggregate classification, scalar arguments spilling to the stack, hidden
  struct returns, `retc`, `env`, and varargs' va_start/va_arg as block splitting
  plus phis) → **`-dA` byte-exact 180/180**. **isel** (amd64/isel.c: scalar
  integers, div/rem, variable shifts, cmov (selsel), comparison→flag/jf,
  table-driven addressing through mgen (seladdr/amatch/runmatch), fast-local and
  salloc, float constants materialized into `.Lfp` memory, stoui/dtoui, blit
  expansion) → **`-dI` byte-exact 180/180**. **amd64 was made the first target
  because the development environment was x86-64 only** (arm64 was the original
  §M6). `src/amd64-*.lisp`.
- **M4 spill + rega** ✅ **done (2026-07-06)**: the bitset passes ported
  faithfully, going through temp ids. `materialize-regs` bridges into QBE's
  "registers are temp ids in [0,Tmp0)" space. **filllive/fillcost** (`-dL`/`-dS`)
  + **spill** (slot packing, limit/limit2) + **rega** (RMap, phicls hints,
  parallel moves, the 4-phase driver) + **simpljmp** + **emit** (emit.c's omap in
  full). `-dL`/`-dS`/`-dR` (rega reaches 154/180; the residue is a difference in
  register selection order, **shown to be benign by e2e**).
  `src/{backend,spill,rega,amd64-emit}.lisp`.
- **M5 corpus green** ✅ **done (2026-07-11)**: all 47 driver-carrying `test/*.ssa`
  files — including data definitions, salloc and dynalloc — emitted, run through
  `cc`, **executed natively**, and verified on exit code and stdout (47/47). On
  top of that, IL emitted by QBE's bundled C compiler **minic** from real C
  (collatz/prime/queen/euler9) runs natively and matches the C reference output
  (4/4). The hand-written e2e suite is 15/15.
  `test/{corpus-e2e,minic-e2e,e2e}.lisp`.
- **M3b/M3c amd64 machine code** ✅ **done**: an assembler-less encoder producing
  bytes plus fixups (`src/amd64-encode.lisp`), diffed against the host `as` over
  every corpus function (`test/encode.lisp`, `test/encode-corpus.lisp`).
- **M6 arm64** ✅ **done (G0–G6)**: the original design's first target, added as a
  second implementation of the target protocol.
  **G0** extracted the register model into `target.lisp`;
  **G1** a naive arm64 code generator running natively on Apple Silicon;
  **G2** abi0 (`apple_extsb`) and abi1 in three stages (scalars → structs and
  stack arguments → Apple varargs) to **`-dA` 180/180**;
  **G3** isel mirroring arm64/isel.c to **`-dI` byte-exact 180/180**;
  **G4** a real port of arm64/emit.c — the corpus runs natively;
  **G5** minic's real C programs run natively 4/4;
  **G6** an AArch64 machine-code encoder (`src/arm64-encode.lisp`) diffed against
  Apple's `as` over the corpus, plus a JIT smoke test that executes the emitted
  bytes. `src/arm64-*.lisp`.
- **M7 the Windows targets** ✅ **done**:
  **`arm64_win`** (Windows on ARM64) shares arm64's register model, isel, abi1
  and emit with Apple verbatim; only the assembler dialect, the vararg rules and
  a COFF fp-constant pool differ. It has **no upstream counterpart** — QBE has no
  Windows-on-ARM64 target — so clang stands in as the oracle and correctness
  rests on native execution (45 passed / 0 failed / 2 skipped).
  **`amd64_win`** (Microsoft x64) ports `amd64/winabi.c`, with
  `qbe -t amd64_win -dA` as a per-pass oracle: **`-dA` 180/180**, corpus 45/0/3
  running through the OS's x64 emulation on an ARM64 host. Working notes for the
  Win64 port are in [`src/AMD64-WIN-PORT.md`](src/AMD64-WIN-PORT.md).
- **Not written**: of upstream QBE's six targets (`amd64_sysv`, `amd64_apple`,
  `amd64_win`, `arm64`, `arm64_apple`, `rv64`), three are implemented here.
  `amd64_apple` (mach-o x86-64) and `arm64` (ELF AArch64) are mostly dialect and
  vararg deltas against targets that already exist; `rv64` is a whole backend.
  The remaining amd64 details (rega byte-exactness, TLS emit, extern-GOT) are on
  hold as either irrelevant to correctness or untestable.

The acceptance criterion at every stage is "the diff against real QBE is empty
(or contains only known, allowed differences)". **For amd64 and arm64 alike, the
mid-end, ABI lowering, isel and spill/liveness are byte-identical across all 180
corpus functions, and the whole QBE test suite plus real C programs run
correctly — a verified, complete backend.**

---

## 7. Worth reading alongside

- The QBE IL specification: https://c9x.me/compile/doc/il.html
- The QBE source (oracle and specification): `git://c9x.me/qbe.git`
- Braun et al., "Simple and Efficient SSA Construction" (the basis of QBE's SSA)

---

## 8. Open questions (originally: to be settled next)

All five have since been settled by the implementation:

- **The final representation of `ref`** — where the line falls between raw object
  references and lightweight tagged structs. → Real object references for `tmp`
  and `con`; lightweight structs for the small tagged values (§4.3). `tmp` also
  carries a stable id so the bitset passes can key on it.
- **Bitsets** — is CL's `bit-vector` enough, or is a dedicated implementation
  needed for this id density? → `bit-vector` was enough.
- **The print normalization allow-list** — which differences count as equivalent
  (temp numbering and so on). → Resolved per pass; the residual `-dN` numbering
  offset turned out to be an artifact of qbe's per-function pipeline order and
  disappeared at M3 (§6, A4).
- **Whether to run the golden harness from CL alone or wrap `tools/test.sh`** →
  CL alone (§2.2).
- **The granularity of the target protocol** — one protocol class or a set of
  mixins? → Neither: a `defstruct` with function-valued slots, mirroring QBE's
  own struct of function pointers (§4.2).

# qbe-cl 設計ドキュメント (v0)

QBE (https://c9x.me/compile/) のアーキテクチャを idiomatic な Common Lisp で
再実装する。QBE 本体は「移植元」ではなく **仕様 + 差分オラクル** として使う。

参照ソース: `git://c9x.me/qbe.git` (MIT)。本ドキュメントは実ソース
(`all.h` / `main.c` / `ops.h` / `parse.c` ほか, ~9k行) を読んで書いている。

---

## 1. ゴールと非ゴール

- **ゴール**: 純 CL で QBE IL (テキスト SSA) を読み、arm64 アセンブリテキストを吐く。
  `as`/`cc` でアセンブル&リンクする AOT leaf ツール。host 非依存
  (SBCL で開発、dotcl/standalone どちらからも使える可搬ライブラリ)。
- **性能目標**: QBE 同様「LLVM の ~7割を極小の複雑さで」。まず正しさ、次に速度。
- **最初のターゲット**: **arm64 一本**で dogfood(手元 Snapdragon)。amd64/rv64 は後。
- **非ゴール**: 実行時 JIT(生きた callback 挿入)。asm→as subprocess は遅い。
  JIT 半分は別プロジェクト(exec-pages 直吐き or Cranelift)。棲み分け維持。
- **非ゴール(当面)**: C の bitset/ポインタ操作の逐行トランスリテレーション。
  醜い部分だけが残る。データ→データ変換として書き直す。

---

## 2. オラクル戦略(この設計の心臓部)

QBE を各段で走らせて出力を diff する。「ゼロから設計」の恐怖が無いのが本プロジェクトの肝。

### 2.1 パスごとの中間ダンプ (`qbe -d<FLAG>`)

`main.c` の `debug[]` フラグ = 各パス後に `printfn` で IL をダンプする点。
これがそのまま **中間段の diff オラクル**になる:

| flag | 段階 (dump point) | 対応パス |
|------|------------------|---------|
| `P` | after parsing | parse |
| `M` | memory optimization | promote / coalesce |
| `N` | ssa construction | ssa (Braun et al.) |
| `C` | copy elimination | copy |
| `G` | gvn / gcm | gvn, gcm |
| `K` | if-conversion | ifconvert (cansel target のみ) |
| `A` | abi lowering | abi0/abi1 (per-target) |
| `I` | instruction selection | isel (per-target) |
| `L` | liveness | filllive |
| `S` | spilling | spill |
| `R` | register allocation | rega |

**含意**: QBE の textual dumper (`printfn`/`printref`, parse.c) と
**バイト一致する pretty-printer を最初期に作る**。diff 戦略の全体がこれに乗る。
既知の正規化差(名前付けの一意化など)は許容リストで吸収。

### 2.2 エンドツーエンドの golden test

QBE の `test/*.ssa` をそのまま golden corpus に流用する。各ファイルに
ドライバと期待出力が埋め込まれている:

```
# >>> driver
#   ... C の main(呼び出し側) ...
# <<<
# >>> output
#   期待 stdout
# <<<
```

harness (`tools/test.sh` 相当を CL 側に用意):
`qbe-cl foo.ssa → foo.s` → `cc foo.s driver.c` → 実行 → stdout を期待値と比較。
さらに **実 QBE の出力ともバイナリ挙動を突き合わせる**(二重オラクル)。

---

## 3. 権威的なパスパイプライン

`main.c: func()` の順序が唯一の正。`fill*` は解析情報の再計算
(データ→データではなく副次情報)なので、CL では「その場で計算する派生値」
または明示的な analysis オブジェクトとして持つ。

```
abi0                     ; per-target ABI 前処理 (elimsb 等)
fillcfg / filluse
promote                  ; mem→reg (memory opt)
ssa                      ; SSA 構築  ← Braun et al.
ssacheck
fillalias / loadopt      ; load 最適化
coalesce                 ; slot coalescing
filldom
gvn                      ; global value numbering
simplcfg
gcm                      ; global code motion
[ifconvert]              ; T.cansel のときだけ
abi1                     ; per-target ABI lowering(呼出規約/struct/可変長)
simpl
isel                     ; per-target 命令選択
filllive / fillloop / fillcost
spill                    ; スピル
rega                     ; レジスタ割当
simpljmp                 ; jump 簡約
emitfn                   ; asm テキスト出力(per-target)
```

**工数の分布**(正直に):
- 軽い: SSA 構築, cfg/dom, copy, fold — well-understood。
- **重い(工数の本体)**: `abi1` + `isel` + `emit`(per-target のグラインド、
  忠実再現が要る)と `spill`+`rega`。ここは diff オラクル無しでは死ぬ。
- arm64 一本に絞るのはこのため。

---

## 4. IR データモデル (CLOS)

### 4.1 最重要判断: 「構造ノードは CLOS / opcode はデータ表」

QBE 自身が **opcode ごとに struct を分けていない**。`Ins` は単一 struct
(`op` enum + 引数2本 + 結果) で、算術/比較/メモリ等の性質は共有プロパティ表
`optab[]` (`ops.h`) が持つ。~80 opcode ある。

→ **opcode ごとに CLOS サブクラスを作らない**(80クラスは破綻)。代わりに:

- **構造ノードだけ CLOS クラス**にする。dispatch と per-target 多態が効く所:
  `module` / `target` / `fn` / `blk` / `phi` / `ins` / `con` / `typ`。
- **opcode は keyword シンボル** (`:add`, `:loadw`, `:ceqw` …) で `ins` の slot に持つ。
- opcode の性質は `ops.h` を移した**データ表 `*optab*`** (keyword → op-descriptor)
  から引く。パスは「ノードクラスで generic dispatch + opcode で分岐(case/表引き)」。

これは QBE 自身の設計と一致し、CL でも idiomatic(表駆動 + 総称関数の併用)。

### 4.2 クラス階層(骨子)

```
module        ; トップレベル集約: functions, data-defs, type-defs, target
  target      ; per-target 戦略。CLOS で総称関数を dispatch:
              ;   target-isel / target-abi0 / target-abi1 / target-emit
              ;   ret-regs / arg-regs / gpr-set / fpr-set / caller-save …
              ; ← QBE の Target(関数ポインタの構造体)= CLOS が一番輝く所
  fn          ; start-blk, tmps, cons, retty, flags(vararg/leaf/dynalloc)
    blk       ; phis, ins(可変ベクタ), jmp(終端), s1/s2, preds,
              ;   派生: idom/dom/fron/loop, liveness sets(bitset)
      phi     ; to, cls, (blk . val) の列
      ins     ; op(keyword), cls, to(ref), arg[2](ref)
  con         ; :undef | :bits | :addr, sym, 値(int/double/float)
  typ         ; aggregate: name, union?, align, size, fields
```

終端 `jmp` は QBE 同様 `blk` の slot(type + arg)。Jxxx enum は keyword 化。

### 4.3 値 (Ref) の表現 — idiomatic な逸脱

QBE の `Ref` は 3bit tag + 29bit val(RTmp/RCon/RInt/RType/RSlot/RCall/RMem)、
`val` は fn 内の配列 index。**CL では index ではなく実オブジェクト参照**を使う:

- temporary の被参照 → `tmp` インスタンスそのもの。
- constant → `con` インスタンス。
- RSlot/RInt/RType 等の小さなタグ付き値だけ軽量ラッパ(struct)。

ただし **liveness/干渉グラフは bitset を temp id で回す**ので、`tmp` は安定な
整数 `id` slot を持つ(オブジェクトかつ id 付き = identity と id 併用)。
bitset パス(`live`/`spill`/`rega`)はここだけ id 経由で C 版を忠実移植。

### 4.4 op-descriptor (ops.h の移植)

`ops.h` の唯一「本当に表」な部分。keyword → descriptor:

```
name, argcls[結果class(w/l/s/d)][arg 0..1],
canfold, hasid, idval, commutes, assoc, idemp,
cmpeqwl, cmplgtewl, eqval, pinned
```

型クラスは `Kw/Kl/Ks/Kd` (= :w :l :s :d、`Kx` = :x top)。生成はマクロで
`ops.h` 相当の DSL を一枚書いて展開(手写しにしない)。

### 4.5 型システム(IL 仕様より)

- base: `w`(i32) `l`(i64) `s`(f32) `d`(f64)。extended: `b`(i8) `h`(i16)。
  sub-word param/ret: `sb ub sh uh`。subtyping: l は w 文脈で使える(下位32bit)。
- sigil: `:`集約型 / `$`グローバル / `%`一時 / `@`ブロックラベル。
- 命令カテゴリ: 算術/ビット, load/store, alloc, blit, 比較(c*), 変換(ext*/*tof/*tosi),
  cast/copy, call(env/可変長 `...`), vastart/vaarg, phi, jmp/jnz/ret/hlt。

---

## 5. パッケージ / システム構成(案)

ASDF system。SBCL 前提だが host 非依存(純 CL + `as`/`ld` subprocess のみ外部)。

```
qbe-cl.asd
src/
  packages.lisp
  ir.lisp          ; §4 の CLOS クラス群 + ref
  ops.lisp         ; ops.h 移植 + *optab* + マクロ
  parse.lisp       ; IL テキスト → module  (parse.c)
  print.lisp       ; module → IL テキスト  (printfn/printref, §2.1 の要)
  cfg.lisp         ; rpo/preds/dom/fron/loop
  ssa.lisp         ; promote + Braun SSA + copy
  opt.lisp         ; fold/gvn/gcm/load/alias/simpl
  target.lisp      ; target プロトコル(総称関数)
  arm64/
    isel.lisp abi.lisp emit.lisp targ.lisp
  regalloc.lisp    ; live/spill/rega
  driver.lisp      ; main 相当 + as/ld subprocess
test/
  harness.lisp     ; §2.2 golden runner + §2.1 pass-diff runner
  corpus/          ; QBE test/*.ssa をベンダリング
```

命名: パッケージ `qbe`(+ `qbe/arm64`)。C の型名 (Fn/Blk/Ins/Ref/Con/Typ) は
CL 側でも `fn`/`blk`/`ins`/`ref`/`con`/`typ` を踏襲し、ソース対応を取りやすく保つ。

---

## 6. マイルストーン(縦に貫く walking skeleton 優先)

横(パスごとに完璧)より縦(端まで貫通)を先に。diff ハーネスと「動く1関数」を
Day 1 に手に入れ、以降は naive→賢いの差し替えで常に緑を保つ。

- **M0 基盤** ✅ **達成 (2026-07-05)**: IR クラス + ops 表 + parse + print。
  `parse→print` が実 QBE `-dP` と **QBE 全テストコーパス + 回帰フィクスチャで
  180/180 関数・77/77 ファイル バイト一致**。golden を `test/golden/` に保存済みで
  qbe 無しでも回帰可能。
  再現した正規化: params→`par`、call args→`arg*`、`ret`→`ret<cls>`/`ret0`/`retc`、
  `blit`→`blit0`+`blit1`、`loadw`→`loadsw`、jmp fall-through 省略、
  定数 dedup(`newcon` の flt 無視 → `d_0`/`s_0`→`0`)、float の C `%f`、
  整数リテラルの符号付き int64 ラップ(`getint`、`2^63`→負。`intwrap.ssa` で回帰)。
- **M1 walking skeleton** ✅ **達成 (2026-07-05)**: 単一ブロック・整数(w/l)・
  straight-line の1関数を **amd64** に下ろし `cc` で as/ld して**ネイティブ実行**、
  exit code でクローズドループ検証(`test/m1.lisp`、7/7)。isel/rega は
  「全 temp をスタックスロット、命令ごとにスクラッチへロード→計算→ストア」の
  最ナイーブ方式(割当問題を回避)。対応 op: par/copy/add/sub/mul/and/or/xor/neg/ret。
  **ターゲットが amd64 なのは開発環境が x86-64 のみ(arm64 の as/qemu 不在)のため。**
  arm64 は target プロトコルの別実装として後で追加(実機 Snapdragon or qemu で検証)。
  範囲外の op/多ブロック/phi はエラーにして誤コード生成を防ぐ。
- **M1-B codegen 拡張** ✅ **達成 (2026-07-05)**: 同じ最ナイーブ方式のまま
  **多ブロック + 制御フロー**へ。jmp/jnz、整数比較(c{eq,ne,slt..,ult..}{w,l}→0/1)、
  load/store/alloc、**phi を edge copy に下ろす**(2-phase staging で並列コピー
  ハザード対応)。SSA *構築* は M2 のまま、phi *下ろし*は codegen 側で実装。
  分岐・ループ・メモリを使うプログラムが走り、実 QBE(amd64)と exit code 一致。
  `test/m1.lisp` 12/12(branch/loop-sum/fact/mem/phi-swap 追加)。call/float/blit は未対応。
- **M2 SSA を本物に**(byte-exact オラクル駆動、A1–A4 に分割):
  - **A1 cfg + dom + fron** ✅ **達成 (2026-07-05)**: fill-rpo(DFS 後行順→RPO、
    到達不能ブロック除去)/ fill-preds / fill-dom(Cooper-Harvey-Kennedy)/
    fill-fron。**支配木を `qbe -dN` の `> Dominators:` ダンプと突き合わせ、全コーパス
    180/180 関数・77/77 ファイル一致**(promote/abi0 は CFG 構造を変えないので parse 済み
    IR で全件比較可)。`newtmp` の命名は `"%s.%d"`(モジュール横断の static counter)。
  - **A2 filllive + A3 ssa** ✅ **達成 (2026-07-05)**: bitset(CL bit-vector、
    dense id キー)、temp レジストリ(`fn-tmp`/`fn-ntmp`、parse で materialize)+
    `newtmp`(run-global `*tmp-counter*`)、`fill-use`(+phicls union-find)、
    `fill-live`(+`live-on`。ssa() 内で phiins を pruned させる pre-isel 生存。
    RCall/RMem/rglob は isel 前で無効なので省略)、`phiins`、`renblk`(Name
    スタック)。`ssa`=filldom→fillfron→filllive→phiins→renblk。要点: filllive は
    下流でなく ssa() の構成要素 → A2→A3 順は必然。`src/ssa.lisp`、`test/ssa.lisp`。
  - **A4 promote** ✅ **達成 (2026-07-06)**: `src/mem.c` の promote(mem2reg)。
    start ブロックの alloc を走査し、全 use が一貫サイズ/クラスの load/store のみなら
    alloc→nop、store→copy(slot を def 化)、load→copy/cast/ext に書換え。multi-def
    になった slot を後段 ssa が phi 化。`src/mem.lisp`、`test/promote.lisp`。
    **`qbe -dM` の "> After slot promotion:" と全コーパス 180/180 関数・77/77 ファイル
    byte 一致**。promote+ssa の `-dN` "> After SSA construction:" は**構造が全 180/180
    一致**(temp サフィックス正規化後)。生の byte 一致は 168/180 — 残差は純粋に
    newtmp カウンタのずれで、qbe は各関数を**バックエンド(isel/rega、`%isel.N` を
    生成)まで通してから次関数をパース**するため、後続関数の `.N` に先行関数の isel
    temp が累積する(M3/isel で解消)。SSA/promote のバグではない。
- **M3 arm64 ABI + isel を忠実に**: `abi1`/`isel` を `-dA`/`-dI` と diff。
  呼出規約・struct 渡し・可変長。← 工数の山。
- **M4 spill + rega**: `-dS`/`-dR` と diff。bitset パスは id 経由で忠実移植。
- **M5 corpus 緑化**: `test/*.ssa` を段階的に通す。fold/gvn/gcm/load 最適化を追加。
- **M6+**: amd64 / rv64 を target プロトコルの追加実装として。

各段の受け入れ基準は「実 QBE との diff が空(or 既知許容差のみ)」。

---

## 7. 併読すべき参照

- QBE IL 仕様: https://c9x.me/compile/doc/il.html
- QBE ソース(オラクル/仕様): `git://c9x.me/qbe.git`
- Braun et al. "Simple and Efficient SSA Construction"(QBE の SSA の下敷き)

---

## 8. 未決事項(次に詰める)

- `ref` の最終表現: 生オブジェクト参照 vs 軽量タグ付き struct の境界線を確定。
- bitset: CL の `bit-vector` で足りるか、id 密度的に専用実装が要るか。
- print の正規化許容リスト: どの差異を「同値」と見なすか(temp 名の付番等)。
- golden harness を CL 単体で回すか、`tools/test.sh` を wrap するか。
- target プロトコルの総称関数の粒度(1 protocol class か mixin 群か)。

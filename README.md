# qbe-cl

QBE ([c9x.me/compile](https://c9x.me/compile/)) のコンパイラバックエンドを
idiomatic な Common Lisp で再実装するプロジェクト。QBE 本体は「移植元」ではなく
**仕様 + 差分オラクル**として使う。設計は [`DESIGN.md`](DESIGN.md)。

## 現状: M0 + M1 達成

**M0** — IR データモデル(CLOS)+ opcode 表 + QBE IL パーサ + プリンタ。
`parse → print` の出力が実 QBE の `-dP`(after-parsing ダンプ)と、
**QBE 全テストコーパス + 回帰フィクスチャで 180/180 関数・77/77 ファイル バイト一致**。

**M1 + B** — walking skeleton を **amd64** で。最ナイーブ codegen(全 temp
スタックスロット、命令ごとにスクラッチ経由、レジスタ割当なし)で、
**多ブロック + 制御フロー(jmp/jnz)+ 整数比較 + load/store/alloc + phi(edge
copy に下ろす)** まで対応。分岐・ループ・メモリを使うプログラムが `cc` で
ネイティブ実行され、実 QBE と exit code 一致(`test/m1.lisp`、12/12)。
ターゲットが amd64 なのは開発環境が x86-64 のみのため。arm64 は後で target
プロトコルの別実装として追加(§M3)。未対応: call/float/blit。

```
src/
  packages.lisp
  ops.lisp     ; ops.h をデータ表に(opcode は keyword、CLOS サブクラスにしない)
  ir.lisp      ; module/fn/blk/phi/ins/typ = CLOS、tmp/con = struct、Ref = 実オブジェクト
  parse.lisp   ; IL text -> module（内部形の正規化を parse.c に忠実に再現）
  print.lisp   ; module -> IL text（printfn/printref と byte 一致）
  cfg.lisp     ; M2/A1: rpo/preds/dominators/frontier（data->data 解析）
  ssa.lisp     ; M2/A2+A3: bitset/newtmp/fill-use/fill-live/phiins/renblk/ssa
  mem.lisp     ; M2/A4: promote（mem2reg: alloc->nop, store->copy, load->copy/ext）
  amd64.lisp   ; M1: module -> amd64 asm（最ナイーブ codegen）
  driver.lisp  ; module -> asm -> cc -> 実行
test/
  corpus/      ; QBE の test/*.ssa をベンダリング(MIT)
  golden/      ; `qbe -dP` を保存した golden(qbe 無しで回帰可能)
  golden-dn/   ; `qbe -dN`（Dominators + After SSA construction）
  golden-dm/   ; `qbe -dM`（After slot promotion ほか）
  harness.lisp ; M0 diff ハーネス（live / golden 両対応）
  run.lisp     ; M0 回帰ランナー
  m1.lisp      ; M1 e2e テスト（cc で実行し exit code 検証）
  dom.lisp     ; A1: 支配木を qbe -dN の Dominators と diff
  ssa.lisp     ; A2+A3+A4: SSA 構築を qbe -dN の After SSA construction と diff
  promote.lisp ; A4: promote を qbe -dM の After slot promotion と diff
```

## 実行

処理系は SBCL(Roswell 経由 `ros -Q run`)。

```sh
# golden に対して回帰(qbe バイナリ不要)
ros -Q run -- --script test/run.lisp

# オラクル QBE を用意して golden を再取得する場合
QBE_BIN=/path/to/qbe ros -Q run -- --script test/run.lisp capture

# 任意の .ssa を実 qbe と直接 diff
QBE_BIN=/path/to/qbe ros -Q run -- --script test/run.lisp foo.ssa

# M1 の e2e テスト(ネイティブ cc で実行、qbe 不要)
ros -Q run -- --script test/m1.lisp
```

オラクル QBE の入手(golden 再取得や新規 diff に必要):

```sh
git clone git://c9x.me/qbe.git && cd qbe && make
export QBE_BIN=$PWD/qbe
```

## M2 達成(SSA)

cfg/dom(A1)+ filllive/phiins/renblk(A2+A3)+ promote(A4)。
promote は `qbe -dM` の "After slot promotion" と **180/180 関数・77/77 ファイル
byte 一致**。promote+SSA 構築は `qbe -dN` の "After SSA construction" と**構造が
全 180/180 一致**(temp サフィックス正規化後)。生 byte 一致 168/180 の残差は、
qbe が各関数をバックエンド(isel が `%isel.N` を生成)まで通してから次関数を
パースするための newtmp カウンタ累積で、M3/isel で解消する既知差。

## 次(M3 以降)

`DESIGN.md` §6 のとおり:
M3 = arm64/amd64 ABI/isel を `-dA`/`-dI` と diff、M4 = spill/rega を
`-dS`/`-dR` と diff。各段は `qbe -d{A,I,S,R}` の中間ダンプを diff オラクルにする。

ライセンス: MIT(QBE と同じ)。

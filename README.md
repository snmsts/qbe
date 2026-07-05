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
  amd64.lisp   ; M1: module -> amd64 asm（最ナイーブ codegen）
  driver.lisp  ; module -> asm -> cc -> 実行
test/
  corpus/      ; QBE の test/*.ssa をベンダリング(MIT)
  golden/      ; `qbe -dP` を保存した golden(qbe 無しで回帰可能)
  harness.lisp ; M0 diff ハーネス（live / golden 両対応）
  run.lisp     ; M0 回帰ランナー
  m1.lisp      ; M1 e2e テスト（cc で実行し exit code 検証）
  dom.lisp     ; A1: 支配木を qbe -dN の Dominators と diff（要 QBE_BIN）
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

## 次(M2 以降)

`DESIGN.md` §6 のとおり縦貫通を維持しつつパスを本物に:
M2 = Braun SSA + cfg/dom(phi/jnz/loop、`qbe -dN` と diff)、
M3 = arm64 ABI/isel を `-dA`/`-dI` と diff、M4 = spill/rega を `-dS`/`-dR` と diff。
各段は `qbe -d{N,A,I,S,R}` の中間ダンプを diff オラクルにする。

ライセンス: MIT(QBE と同じ)。

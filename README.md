# qbe-cl

QBE ([c9x.me/compile](https://c9x.me/compile/)) のコンパイラバックエンドを
idiomatic な Common Lisp で再実装するプロジェクト。QBE 本体は「移植元」ではなく
**仕様 + 差分オラクル**として使う。設計は [`DESIGN.md`](DESIGN.md)。

## 現状: M0 達成

IR データモデル(CLOS)+ opcode 表 + QBE IL パーサ + プリンタ。
`parse → print` の出力が実 QBE の `-dP`(after-parsing ダンプ)と、
**QBE 全テストコーパス + 回帰フィクスチャで 180/180 関数・77/77 ファイル バイト一致**。

```
src/
  packages.lisp
  ops.lisp     ; ops.h をデータ表に(opcode は keyword、CLOS サブクラスにしない)
  ir.lisp      ; module/fn/blk/phi/ins/typ = CLOS、tmp/con = struct、Ref = 実オブジェクト
  parse.lisp   ; IL text -> module（内部形の正規化を parse.c に忠実に再現）
  print.lisp   ; module -> IL text（printfn/printref と byte 一致）
test/
  corpus/      ; QBE の test/*.ssa をベンダリング(MIT)
  golden/      ; `qbe -dP` を保存した golden(qbe 無しで回帰可能)
  harness.lisp ; diff ハーネス（live / golden 両対応）
  run.lisp     ; 回帰ランナー
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
```

オラクル QBE の入手(golden 再取得や新規 diff に必要):

```sh
git clone git://c9x.me/qbe.git && cd qbe && make
export QBE_BIN=$PWD/qbe
```

## 次(M1 以降)

`DESIGN.md` §6 のとおり縦貫通(walking skeleton)を優先:
最小 SSA → 最ナイーブ isel/rega → arm64 emit で 1 関数を `as`/`ld` まで通す。
各段は `qbe -d{N,A,I,S,R}` の中間ダンプを diff オラクルにする。

ライセンス: MIT(QBE と同じ)。

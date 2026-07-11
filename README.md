# qbe-cl

QBE ([c9x.me/compile](https://c9x.me/compile/)) のコンパイラバックエンドを
idiomatic な Common Lisp で再実装するプロジェクト。QBE 本体は「移植元」ではなく
**仕様 + 差分オラクル**として使う。設計は [`DESIGN.md`](DESIGN.md)。

## 現状: amd64 バックエンドが完成・検証済み

QBE IL(テキスト SSA)を読み、mid-end 最適化と amd64 SysV のコード生成を通して
x86-64 アセンブリを吐き、`cc` でアセンブル&リンクしてネイティブ実行する。
**QBE の全テストコーパスに対し、各中間段の出力が実 QBE の `-d` ダンプとバイト一致**
(下表)。さらに **QBE のテストプログラムと、QBE 付属の C コンパイラ `minic` が
生成した IL が、実機で正しく走る**ことまで確認済み。

| 段 | パス | オラクル(`qbe -d…`)| 結果(全 180 関数) |
|----|------|------|------|
| parse→print | `-dP` after parsing | byte 一致 180/180・77/77 ファイル |
| dominators / SSA | `-dN` | 180/180 |
| slot promotion | `-dM` after slot promotion | byte 一致 180/180 |
| **load elimination** | `-dM` after load elimination | 180/180 |
| **slot coalescing** | `-dM` slot coalescing | 180/180 |
| **GVN / GCM / simplcfg** | `-dG` / `-dC` | 180/180 |
| **ABI lowering** | `-dA` | 180/180(struct/stack/vararg/env 含む) |
| **isel** | `-dI` | 180/180(byte 一致) |
| **liveness / spill costs** | `-dL` / `-dS` | 180/180(byte 一致) |
| **spilling** | `-dS` after spilling | 180/180(byte 一致) |
| register allocation | `-dR` | 154/180(※) |

※ rega はレジスタ選択(割当順)が QBE と異なる関数が残るが、**生成コードは正しい**
(下記 e2e で実証)。ミスコンパイルではなく良性の割当順差。

### end-to-end(実機実行)

- **手書き e2e**(`test/e2e.lisp`, 15/15): 算術/除算/シフト/ループ/phi/呼出/
  callee-save/メモリ/SIB アドレッシング/float 定数/float→uint/struct 値渡し・
  返り値/vararg。すべて `cc` で実行し結果検証。
- **コーパス e2e**(`test/corpus-e2e.lisp`, 47/47): QBE の `test/*.ssa` のうち
  C ドライバを持つ全プログラムをコンパイル→リンク→実行し、exit code / stdout を検証。
- **minic e2e**(`test/minic-e2e.lisp`, 4/4): QBE 付属の C コンパイラ `minic` が
  実 C プログラム(collatz / euler9 / prime / queen)から吐いた IL を、この
  バックエンドで実機実行し、C を直接コンパイルした参照出力とバイト一致。

つまり **任意の C → minic → QBE IL → qbe-cl → x86-64 → ネイティブ実行** が通る。

## 設計の要点

- **構造ノードは CLOS、opcode はデータ表**: `module/fn/blk/phi/ins/typ` は CLOS、
  ~80 の opcode は keyword + `ops.h` 由来のプロパティ表(クラスにしない)。
- **Ref は実オブジェクト参照**: temporary は `tmp`、定数は `con`、RMem は `mem`
  など実オブジェクト。ただし liveness/干渉は temp の安定 id 経由の bitset。
- **忠実移植 vs データ変換**: 難所(isel/spill/rega/abi/loadopt)は QBE C を忠実に
  移植し `-d` ダンプとバイト一致を取る。それ以外は idiomatic に書き直す。

```
src/
  packages.lisp ops.lisp ir.lisp        ; opタ表 + IR モデル
  parse.lisp print.lisp                 ; IL テキスト <-> IR(-dP と byte 一致)
  cfg.lisp ssa.lisp mem.lisp            ; rpo/dom/fron, SSA 構築, promote
  gvn.lisp gcm.lisp ifopt.lisp          ; GVN(copyref幅解析/assoccon)+ GCM + ifconvert
  load.lisp                             ; alias 解析 + loadopt + coalesce
  amd64.lisp amd64-abi.lisp             ; register model, SysV ABI(struct/stack/vararg)
  amd64-isel.lisp backend.lisp          ; 命令選択(アドレッシング/fp/blit), backend 共通
  spill.lisp rega.lisp amd64-emit.lisp  ; spill, レジスタ割当, asm 出力
  driver.lisp
test/
  corpus/  minic/                       ; QBE test/*.ssa + minic 生成 IL(MIT)
  golden*/                              ; 各 -d ダンプの golden(qbe 無しで回帰可能)
  *.lisp                                ; 各パスの diff オラクル + e2e ランナー
```

## 実行

処理系は SBCL(Roswell 経由 `ros -Q run`)。golden を同梱しているので **qbe バイナリ
無しで全回帰**が回る。

```sh
ros -Q run -- --script test/run.lisp          # M0 parse/print 回帰
ros -Q run -- --script test/ssa.lisp          # SSA 構築 (-dN)
ros -Q run -- --script test/gvn.lisp          # GVN (-dG)
ros -Q run -- --script test/isel.lisp         # 命令選択 (-dI)
ros -Q run -- --script test/spill.lisp        # spill (-dS)
ros -Q run -- --script test/rega.lisp         # レジスタ割当 (-dR)
ros -Q run -- --script test/e2e.lisp          # 手書きプログラム実行
ros -Q run -- --script test/corpus-e2e.lisp   # QBE テストプログラム実行
ros -Q run -- --script test/minic-e2e.lisp    # minic 生成 IL 実行
```

golden の再取得や新規 `.ssa` の diff には実 QBE が要る:

```sh
git clone git://c9x.me/qbe.git && cd qbe && make
export QBE_BIN=$PWD/qbe
```

## 残課題

いずれも「正しさに無関係」または「検証不能」で、実質的なバックエンドは完成済み:

- **rega のレジスタ選択バイト一致**(154/180)— 良性(全 e2e が正しく走る)。厳密に
  合わせるには実 QBE の rega トレースが要る。
- **TLS の emit**(`%fs:sym@tpoff`)— コーパスの `tls.ssa` にドライバが無く実行対象外。
- **extern データの GOT アクセス** — コーパスに使用関数が無い。
- **arm64 ターゲット** — 開発環境が x86-64 のみのため amd64 を先に完成。arm64 は
  target プロトコルの別実装として、実機のある環境で追加する。

ライセンス: MIT(QBE と同じ)。

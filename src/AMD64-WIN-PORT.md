# amd64_win 移植の作業メモ

`arm64_win` と同じやり方で、本家 `amd64/winabi.c` を移植している途中の記録。
**次に触る人（あるいは記憶を失った自分）がここから再開できること**が目的。

## いまどこまで

| | 状態 | どこ |
|---|---|---|
| レジスタモデル (`rsave` / `rclob` / `retregs` / `argregs`) | **済** | `src/amd64-winabi.lisp` 前半 |
| 引数の分類 (`classify_arguments` 一式) | **済** | 同 後半 |
| `lower_call` | 未 | `winabi.c:259-483` |
| `lower_block_return` | 未 | `winabi.c:484-518` |
| `lower_vastart` / `lower_vaarg` | 未 | `winabi.c:522-554` |
| `lower_func_parameters` | 未 | `winabi.c:619-739` |
| `amd64_winabi_abi` (入口) | 未 | `winabi.c:740-763` |
| `amd64_winabi_emitfn` | 未 | `amd64/emit.c:789` |
| `*amd64-win-target*` | 未 | `src/amd64-targ.lisp` に足す |
| コーパス e2e | 未 | `test/arm64-win-corpus-e2e.lisp` の双子 |

検証: `ros -Q run -- --script test/winabi-smoke.lisp` (18 件、全通過)

## 本家と qbe-cl の対応（毎回これを探すことになるので）

| winabi.c | qbe-cl |
|---|---|
| `emit(op, cls, to, a0, a1)` | `(emit op cls to a0 a1)` — push するので**本家と同じ順に書けば同じ順に出る** |
| `emiti(*instr)` | `(push i *emitted*)` |
| `curi = &insb[NIns]` … `idup` | `(let ((*emitted* nil)) …)` の束縛と `(setf (blk-ins b) …)` |
| `newtmp("abi", Kl, fn)` | `(newtmp "abi" :l fn)` |
| `getcon(n, fn)` | `(getcon n fn)` |
| `TMP(RCX)` | `(rg +rcx+)` |
| `CALL(v)` | `(make-call-ref v)` |
| `SLOT(-n)` | `(make-slot-ref (- n))` |
| `R` (空 Ref) | `nil` |
| `typ[i]` / `type->size` | 型は ins に**オブジェクトとして**入っている。`(ins-arg0 i)` が `typ`、`(typ-size ty)` `(typ-isdark ty)` |
| `Kw Kl Ks Kd` | `:w :l :s :d`。`KBASE(k)` は `(cls-base k)` |
| `Oadd` `Ocopy` `Ostorel` `Oload` `Oalloc8` `Oblit0/1` `Osalloc` `Ocall` `Ocast` | `:add :copy :storel :load :alloc8 :blit0 :blit1 :salloc :call :cast` |
| `blk->jmp.type` / `.arg` | `(blk-jmp-type b)` / `(blk-jmp-arg b)` |
| `func->retty` `retr` `reg` `vararg` | `(fn-retty fn)` `(fn-retr fn)` `(fn-reg fn)` `(fn-vararg fn)` |
| `ExtraAlloc` の連結リスト | SysV 側の `*abi-ral*` と同じ形でよい (`abi-push-ral` 参照) |

**SysV 側 (`src/amd64-abi.lisp`) の `sel-call` / `sel-par` / `amd64-abi` が最良の
お手本**。やっていることは違うが、IR をいじる作法は全部そこにある。

## 構造の違いに注意

`winabi.c` は `sysv.c` の改造ではなく**別人による書き直し**なので、関数の切り方が
違う。SysV 側の `sel-call` に対応するものを探すのではなく、`winabi.c` の関数を
そのまま1つずつ写す方が早い（オラクルがバイト差分なので、構造を合わせる利益もある）。

特に:

- SysV は `argsclass` が引数と返り値をまとめて見るが、Windows は
  `lower_func_parameters` が返り値を先に処理してから `classify_arguments` を呼ぶ
- Windows は**ブロックの走査順が逆**: `func->start->link` から回して、
  **start ブロックを最後**に処理する（他ブロックが足した alloca を start の頭に
  積むため）。SysV 側も同じことをしているので `amd64-abi` の形が使える

## 既に踏んだもの

- **RSI/RDI が Windows では callee-save。** SysV の `rsave` を使い回せない
- **int と float がカウンタを共有する。** `f(int,double)` は RCX と **XMM1**。
  だから RCall マスクは個数の対ではなく**使用中レジスタのビットマップ**
- **1/2/4/8 バイト以外の集約は必ずポインタ渡し。** 5 バイトの構造体は「入る」のに
  コピーされる
- 上流の `amd64_winabi_argregs` は `p[0]/p[1]` に popcount を返す (TODO 付き)。
  **直さずそのまま写す** — オラクルがバイト差分なので、バグまで一致させる
- 上流の `winabi.c` は subword par (`parsb`/`parub`/`parsh`/`paruh`) を扱わない。
  こちらは黙って通さず `abi-unsupported` で止めている
- 上流の `retregs` は `nf` に `r.val & 2` を返す (0 か 2、0/1 ではない)。写してある

## 検証の道具立て（確認済み）

### ★ パス単位のオラクルが効く（これが一番大事）

**`qbe -t amd64_win -dA` が ABI lowering 直後のダンプを出す。** つまり
いま移植しているパスそのものに、コーパス全ファイルで使えるバイト比較オラクルが
ある。**e2e が動くまで待つ必要は無い。**

```
~/work/qbe-upstream/qbe -t amd64_win -dA -o /dev/null test/corpus/x.ssa
```

`test/abi.lisp` が SysV 版でまさにこれをやっている（`qbe -dA` を走らせ、
我々の `amd64-abi` の出力と突き合わせ、`raw` / `norm` の2段で比較。未対応は
mismatch ではなく skip として数える）。**`test/winabi.lisp` はその複製でよい** —
`(qbe:amd64-abi fn)` を `(qbe:amd64-winabi-abi fn)` に、`-dA` に `-t amd64_win`
を足すだけ。

これがあるので `lower_call` を写した時点で「77 本中いくつ一致するか」が測れる。
`lower_block_return` を足せばまた増える。**今日 ime 側でやっていた「段ごとに
数字が出る」やり方が、そのまま使える。**

### e2e（最後の砦）

- **x64 バイナリはこの ARM64 機でビルドも実行もできる**
  `PATH=/c/msys64/ucrt64/bin:$PATH; gcc x.c -o x.exe && ./x.exe` が通る
- コーパスは `test/corpus/*.ssa` 77 本。各々に C ドライバと期待出力が埋まっている。
  基準は「組み上がる」ではなく「**走って正しく出力する**」
  (`test/arm64-win-corpus-e2e.lisp` の冒頭コメント参照)
- こちらは `emitfn` と `*amd64-win-target*` が要るので後

## 次の一手

1. **`test/winabi.lisp` を `test/abi.lisp` から複製する**（これを先にやる）。
   `amd64-winabi-abi` はまだ無いので全件エラー = 0/77 から始まる。**その 0 が
   出発点の計測になる。**
2. `winabi.c:740` の `amd64_winabi_abi` の骨格 + `lower_func_parameters` を写す。
   引数を取らない関数だけでも一致し始めるはず。
3. `lower_block_return` → `lower_call` → vararg の順に足し、そのたびに
   `test/winabi.lisp` の一致数を見る。
4. 一致数が頭打ちになったら `amd64_winabi_emitfn` と `*amd64-win-target*` を作り、
   `test/amd64-win-corpus-e2e.lisp` で実際に走らせる。

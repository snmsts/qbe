# amd64_win 移植の作業メモ

`arm64_win` と同じやり方で、本家 `amd64/winabi.c` を移植した記録。
**次に触る人（あるいは記憶を失った自分）がここから再開できること**が目的。

## いまどこまで

| | 状態 | どこ |
|---|---|---|
| レジスタモデル (`rsave` / `rclob` / `retregs` / `argregs`) | **済** | `src/amd64-winabi.lisp` 前半 |
| 引数の分類 (`classify_arguments` 一式) | **済** | 同 |
| `lower_call` | **済** | 同 後半 |
| `lower_block_return` | **済** | 同 |
| `lower_vastart` / `lower_vaarg` | **済** | 同 |
| `lower_func_parameters` | **済** | 同 |
| `amd64_winabi_abi` (入口) | **済** | 同 末尾 |
| `amd64_winabi_emitfn` | **済** | `src/amd64-emit.lisp` に `T.windows` 分岐として畳んだ |
| `*amd64-win-target*` | **済** | `src/amd64-targ.lisp` |
| コーパス e2e | **済** | `test/amd64-win-corpus-e2e.lisp` — 45 passed / 0 failed / 3 skipped |
| extern アドレス (COFF `.refptr`) | **済**（本家より先） | `src/amd64-isel.lisp` fixarg [E] + `be-emit-addr-op` / `emit-refptrs` |
| TLS | 未（本家も `die`） | |

検証:

- `ros -Q run -- --script test/winabi-smoke.lisp` (18 件、全通過)
- `ros -Q run -- --script test/winabi.lisp` — `qbe -t amd64_win -dA` とのパス単位オラクル。
  **180/180 functions が norm 一致**（raw 152/180 は下記の newtmp カウンタずれ）
- `AMD64_CC=… ros -Q run -- --script test/amd64-win.lisp` — 方言 / Win64 固有の
  規則 / extern の 27 件。**各項目に SysV 側の対の検査**を付けてあるので、ELF 側を
  一緒にリファクタで消すと落ちる
- `AMD64_CC=… ros -Q run -- --script test/amd64-win-corpus-e2e.lisp`

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
| `INT(n)` | 整数そのもの (RInt) |
| `R` (空 Ref) | `nil` |
| `typ[i]` / `type->size` | 型は ins に**オブジェクトとして**入っている。`(ins-arg0 i)` が `typ`、`(typ-size ty)` `(typ-isdark ty)` |
| `Kw Kl Ks Kd` | `:w :l :s :d`。`KBASE(k)` は `(cls-base k)`。`emit(…, 0, …)` の `0` は `:w` |
| `Oadd` `Ocopy` `Ostorel` `Oload` `Oalloc8` `Oblit0/1` `Osalloc` `Ocall` `Ocast` | `:add :copy :storel :load :alloc8 :blit0 :blit1 :salloc :call :cast` |
| `blk->jmp.type` / `.arg` | `(blk-jmp-type b)` / `(blk-jmp-arg b)` |
| `func->retty` `retr` `reg` `vararg` | `(fn-rettyp fn)` `(fn-retr fn)` `(fn-reg fn)` `(fn-vararg fn)`。**`retty >= 0` は `(fn-rettyp fn)` が non-nil** |
| `ExtraAlloc` の連結リスト | `*win-extra-alloc*`（SysV 側 `*abi-ral*` と同じ形。push が head なので、start ブロックで `(dolist … (push … *emitted*))` すると本家と同じ順に落ちる） |

**SysV 側 (`src/amd64-abi.lisp`) の `sel-call` / `sel-par` / `amd64-abi` が最良の
お手本**。やっていることは違うが、IR をいじる作法は全部そこにある。

## 構造の違いに注意

`winabi.c` は `sysv.c` の改造ではなく**別人による書き直し**なので、関数の切り方が
違う。SysV 側の `sel-call` に対応するものを探すのではなく、`winabi.c` の関数を
そのまま1つずつ写す方が早い（オラクルがバイト差分なので、構造を合わせる利益もある）。
実際そうやって、`win-lower-call` / `win-lower-block-return` / `win-lower-vastart` /
`win-lower-vaarg` / `win-lower-args-for-block` / `win-lower-func-parameters` と
本家の関数名を1対1で残してある。

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
- **golden を採るときは `tr -d '\r'` を通す。** `qbe.exe` の stderr は Windows の
  テキストモードで CRLF になり、行比較が全部外れて 0/180 になる（1回これで溶かした）

### emitfn 側で踏んだもの

- `T.asloc` が amd64_win では **`"L"`（`.L` ではない）**。`Lbb0` / `Lfp0` になる。
  `amd64-isel.lisp` の fp 定数プールのラベルも `(tg-asloc)` 経由にした
- 可変長引数の退避は**プロローグの一番最初**、`pushq %rbp` より前。
  積み先は呼び出し元が確保した shadow space なので `0x8(%rsp)`〜`0x20(%rsp)`
- したがって `winabi_framesz` に SysV の `176*vararg` 項が無い。`be-slot` の
  vararg 分岐（`-176 + …`）も Windows では通らない
- `amd64_winabi_emitfn` は `.p2align 4` を出さず、`elf_emitfnfin`
  （`.type` / `.size`）も呼ばない。`pe_emitfin` は `.note.GNU-stack` を出さない
- 分岐の反転条件だけ SysV と違う: `if (b->link == b->s2 || c >= NCmpI)`。
  浮動小数比較は否定が補集合にならないので常に swap する

### extern (COFF `.refptr`) で踏んだもの

- **COMDAT の書き方が aarch64 gas と x86 gas で違う。** arm64_win は
  `.section .rdata$.refptr.sym,"dr",discard,.refptr.sym` で通るが、i386/x86-64 の
  PE バックエンドはこれを解釈せず、`.section` の行で
  `junk at end of line, first unrecognized character is ','` と言う。x86 側は
  `.linkonce discard` を別の行として書く（mingw の gcc 自身もこの形）。
  どちらも `LINK_ONCE_DISCARD` の同じセクションになる
- 呼び出しには indirection が要らない。COFF では直接 `callq sym` でリンカが解決し、
  相手が import なら thunk を合成してくれる。`@plt` は ELF だけの飾り
- isel 側 (`fixarg` [E]) はオフセットを別の `add` に切り出す必要がある
  （indirection はシンボル自体しか名指せない）。ここは `qbe -dI` と
  **一時変数の番号まで含めてバイト一致**を確認した（`%isel.2 =l addr extern $g`
  → `%isel.1 =l add %isel.2, 8` の順序も同じ）
- SysV 側はこの実装で ELF の `@gotpcrel` を通るようになった（以前は isel が
  `abi-unsupported` を出していたので、動いていたものは何も変わらない）

## 検証の道具立て（確認済み）

### ★ パス単位のオラクルが効く（これが一番大事）

**`qbe -t amd64_win -dA` が ABI lowering 直後のダンプを出す。** つまり
移植しているパスそのものに、コーパス全ファイルで使えるバイト比較オラクルが
ある。**e2e が動くまで待つ必要は無い。**

```
~/work/qbe-upstream/qbe -t amd64_win -dA -o /dev/null test/corpus/x.ssa
```

`test/winabi.lisp` がこれをやっている（`test/abi.lisp` の複製）。golden は
`test/golden-win-da/*.da` に採ってある。差分が出たら `SHOW=1` を付けると
ours / theirs を並べて出す。

`raw` が 152/180 なのは SysV 側 (151/180) と同じ理由 — QBE の newtmp カウンタが
run 単位のグローバルで、先行する関数の backend 一時変数の分だけ番号がずれる。
構造の信号は `norm` の方。

### e2e（最後の砦）

- **x64 バイナリはこの ARM64 機でビルドも実行もできる。** ただし
  **`/c/msys64/ucrt64/bin` を PATH に入れること** — mingw の gcc は自分の隣の
  DLL を読むので、PATH に無いと**何のメッセージも出さずに exit 1** する
  （`test/amd64-win-corpus-e2e.lisp` は cc のディレクトリを自分で PATH に足す）
- コーパスは `test/corpus/*.ssa` 77 本、うち driver 付きが 47 本。基準は
  「組み上がる」ではなく「**走って正しく出力する**」
- 現状 **45 passed / 0 failed / 3 skipped**。skip 3 本はすべて corpus 側の
  `# skip amd64_win` マーカーで、しかも**理由がこちらのバックエンドではない**:
  conaddr は「no signals on win32」(driver が POSIX シグナルを使う)、dark は
  arch (`# skip arm64 arm64_apple rv64 amd64_win`)、tls は「pthread and tls not
  implemented」。**つまり e2e は既に天井** — 走ると宣言されている 45 本が
  全部走っている。arm64_win と同じ水準

## 次の一手

ABI とコード生成は一巡した。残っているのは:

1. **TLS。** 本家は amd64_win で `die("extern/thread unsupported on amd64_win")`。
   extern は `.refptr` で通した（arm64_win と同じ）が、TLS は arm64_win でも
   未着手。Windows の TLS は `_tls_index` と TEB (`gs:0x58`) を辿る必要があり、
   ELF の `@tpoff` / `@gottpoff` とは別物。なお `emit.c` の ELF TLS 2 形
   (SThr / SExtThr) も qbe-cl の amd64 には無い（SThr は素の `lea` に落ちる）
2. **`amd64-encode.lisp`（JIT/オブジェクト直吐き）は SysV 固定。** `*rclob*` を
   直接見ているので、Windows で JIT したくなったらここも `(tg-rclob)` に回す
3. 大きいフレームの `__chkstk`。arm64_win では拒否する形で決着させた
   （`:stack-probe 4096`）。amd64_win の target にはまだ入れていない

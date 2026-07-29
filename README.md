※ rega はレジスタ選択(割当順)が QBE と異なる関数が残るが、**生成コードは正しい**

## amd64_win (Microsoft x64 ABI)

ARM64 Windows で走る x64 エミュレーションのアプリを覆うための移植。
本家 `amd64/winabi.c` が移植元、`qbe -t amd64_win -dA` がパス単位のオラクル。

**作業メモ・対応表・残件は [`src/AMD64-WIN-PORT.md`](src/AMD64-WIN-PORT.md)。**
冷たい状態から再開するときはまずそれを読むこと。

一巡した。ABI lowering は `qbe -t amd64_win -dA` に対して **180/180 functions
一致** (`test/winabi.lisp`)、コーパスは **45 passed / 0 failed / 3 skipped**
で実際に走る (`test/amd64-win-corpus-e2e.lisp`)。skip 3 本は corpus 側の
`# skip amd64_win` マーカーで、理由はどれもこちらのバックエンドではない。
方言・Win64 固有の規則・extern は `test/amd64-win.lisp` が 27 件（うち 6 件は
実際にリンクして走らせる）。extern アドレスは本家が `die` するところを COFF の
`.refptr` COMDAT で通してある。

残: TLS（本家も `die`。arm64_win でも未着手）、`amd64-encode.lisp` (JIT) の
SysV 固定、大フレームの `__chkstk`。

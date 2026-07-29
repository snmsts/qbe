※ rega はレジスタ選択(割当順)が QBE と異なる関数が残るが、**生成コードは正しい**

## 進行中: amd64_win (Microsoft x64 ABI)

ARM64 Windows で走る x64 エミュレーションのアプリを覆うための移植。
本家 `amd64/winabi.c` が移植元、`qbe -t amd64_win -dA` がパス単位のオラクル。

**作業メモ・対応表・次の一手は [`src/AMD64-WIN-PORT.md`](src/AMD64-WIN-PORT.md)。**
冷たい状態から再開するときはまずそれを読むこと。

済: レジスタモデル / 引数の分類 (`test/winabi-smoke.lisp` 18 件)
未: lowering (call/ret/param/vararg) / emitfn / target / e2e

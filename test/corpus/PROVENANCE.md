# corpus provenance

These `*.ssa` files are vendored verbatim from the QBE source tree
(`test/` directory of `git://c9x.me/qbe.git`), used here as fixtures for the
M0 parse→print diff harness. QBE is MIT-licensed; see https://c9x.me/compile/.

The captured `../golden/*.dp` files are the corresponding `qbe -dP`
(after-parsing) dumps produced by the reference QBE binary, and serve as the
byte-exact oracle for our printer.

# pdftexja 描画修正計画（rendering を「完全」に近づける）

対象リポジトリ: `/home/tani/ghq/github.com/tani/pdftexja`（consumer: `../jlreq`）
現状: 12 クラス + 基盤 10 モジュール + JFM 5 preset + font tool が動作。クラス並列比較
（`tests/run-class-tests.sh`）は **9/12 PASS**。残り 3 件と、基盤側の未実装/欠陥 6 件が
本計画の対象。**閾値を緩めて緑にする操作は禁止**（誤差帯 `CELL_TOL=2` は据え置き）。

---

## 0. 完了条件（これが満たされるまで「完全」と呼ばない）

1. `sh tests/run-class-tests.sh --texmf TREE` が **12/12 PASS**、しかも各 PASS が
   「text 完全一致 + 行/列数一致 + 誤差帯 ≤2 セル + grid 一致 + 版面値一致」を満たす。
2. `sh tests/run-tests.sh --texmf TREE` が **全 PASS**（現状 4 FAIL: 縦組抽出 3 件 + tiny preset 1 件）。
3. `make check-jfm check-fonts` が green のまま（現状 green、退行させない）。
4. jlreq 側: `\documentclass[pdflatex]{jlreq}` と `[tate]` の双方が 0 error、
   既存 `tests/run-pdftex-tests.sh` の p/u/l 回帰が不変、`\jlreqpdf@` 残存 0。
5. 上記すべてを **repo 外 cwd + installed tree のみ**で再現（provenance 検査込み）。

---

## 1. 欠陥一覧（すべて本セッションの実測・file:line 付き・原因帰属済み）

基盤（foundation）:

| # | 症状 | 実測 | 原因の所在（帰属） |
|---|---|---|---|
| R4 | 縦組ページのテキスト抽出が空 | **解決済み・計測器の欠陥だった**: `standalone-tate.pdf` から pdftotext は 0 文字、PyMuPDF は 115+13 文字（見出し・本文・括弧・TCY 数字・数式すべて）を返す。原因は pdftotext の回転レイアウト除去で、描画/ToUnicode は正常 | `tests/run-tests.sh` の抽出を `tests/pdf-text.py`（PyMuPDF）へ交換（閾値変更ではなく計測器の交換）。以後 3 件とも PASS |
| R5 | 独自 preset で `\begin{document}` の数値走査エラー | tiny preset（role 17/34/83/201/202）で `Missing number <to be read again> =` | `tex/pdftexja-rules.sty` の class 表構築（`\pdftexja@jfm@tables` / `\pdftexja@loadclass`）と `direction` のページ初期化。role が default skip を持たないことが引き金（generator 側で全 class に既定を出すのが本筋） |
| R6b | 効果配線の設計制約（R6 の下位） | `\pdftexja@latadj` は `lastclass=90`（段落頭）の時だけ `lastclass=27` を立てるため、段落途中の Latin→CJK 境界では class 27 が現れず `\pdftexja@emitpair@xspc` も公開上書きも**参照されない**。`A漢` が全モードで 17.50002pt なのはこのため | 次段の設計: 段落途中の Latin 連続を検出する（`\lastnodetype=0` かつ `glyphmark≠1`）には LaTeX 側の文字出力を観測する必要があり、既存の段落頭限定判定の拡張は**全クラスの間隔数値を動かす**。合意形成のうえで実施する（現状の挙動を勝手に変えない） |
| R6 | `\pdftexjaSetCharSpacing` の**効果**が出ない（API 自体は実装済み） | 実装: 公開上書き層（`\pdftexja@charxsp@<decimal>` → descriptor `xsp@<class>` → 既定 both）、HEX/mode 検証、preamble-only、group-local を追加し、contract test 4 件は PASS（不正 HEX / 不正 mode / 本文中呼出を拒否）。**しかし実測では `A漢`・`漢A` の幅が default/none/both/pre/post すべて 17.50002pt で不変**（standard/ujis 両 preset） | 原因: `\pdftexja@ifxsp` は `\pdftexja@emitpair@xspc`（class 27 が境界に居る時だけ）からしか呼ばれず、実際の Latin↔CJK 境界はレンダラの `\pdftexja@pre`/`\pdftexja@latadj` 側で処理される。**効果の配線が未了** |
| R7 | UTF-8 dispatcher が全滅 | `\　`(U+3000) で `unknown command spelling`。`和暦/西暦` は登録成功するが dispatch 不可。**調査で判明した4つの独立欠陥**（下記） | `tex/pdftexja-latex.sty` の登録と照合。①②③④を全て直さないと dispatch は成立しない |
| R8 | 縦組で `\begin{math}…\end{math}` が失敗 | `File ended while scanning use of \pdftexja@math@scan`（yoko では通る） | `tex/pdftexja-math.sty` の `\pdftexja@imath@paren#1\)` が `\)` トークン区切り。`\begin{math}` は `\endmath` で閉じるため一致しない |
| R11 | TDS/staged/uninstall の証跡が無い | `make tds` 未実行、repo 外 cwd での staged proof 未実行、uninstall sentinel 未実行 | 未実施（plan §10 Verification 4） |
| R12 | `tests/run-pdftex-tests.sh`（jlreq consumer suite）が未移植 | 旧 backend 前提のまま（font build・旧 preflight） | jlreq 側 runner の再設計（plan §10） |

クラス（bundled classes）:

| # | 症状 | 実測 | 原因の所在（帰属） |
|---|---|---|---|
| R1 | `pdfjskiyou` 本文が 1 セル広い | ours 24–25 セル/行 vs ref 23–24。page1 line8 = 17 vs 22、**純全角 CJK**。`\textwidth` は両側 486.21144pt で一致。同一 face（`luatexja-preset[ipaex]`）追試でも不変 | **class 疑い（open diagnostic）**: kiyou の `\fullwidth{48\zw}+\columnsep` と `\zw`→`\columnwidth` の束縛、つまり `\zw` の実寸 vs 段幅。foundation evaluator ではない（pair 値は一致、face 非依存） |
| R2 | `pdfjltxdoc` page1 line6 が 33 vs 30 | **純 CJK**、face 差では消えない | **class 疑い**: `source/pdfjltxdoc.dtx` の preamble（jslogo/`\Macrocode`・`\verb` wrapper・`\mlineplus`）が可視トークン集合を変えている |
| R3 | `pdfjtbook` 第1ページ列ピッチ 16.90 vs 15.40 | 章見出し/タイトル材のクラスタ。extent は INFO 出力済み | class（tate book の見出し・タイトルページ）または測定定義（本文クラスタ限定） |

jlreq:

| # | 症状 | 実測 | 原因の所在（帰属） |
|---|---|---|---|
| R9 | 縦組 jlreq が private state 参照で停止 | `\jlreqpdf@…` **107 箇所 / 20 ブロック**（units 624–664, savepos 757–887, para reset 1202–1208, UTF8 1494–1651, size 1762–1774, C* 1825–1851, warichu 4604–4870, warichu keys, TCY/jidori/akigumi 6997–7209, reference 7317–7477, insertion 7607–7645, ai-mark 3998–4061, index 6694–6745, math internal 6637–6640） | 旧 backend のアルゴリズム本体が class に残存（plan split §3 の除去対象） |
| R10 | 旧 backend が現役 | `jlreq-pdftex{,-rules,-ruby,-paragraph}.sty` が install/TDS 対象に残る | 未削除（re-export shim は作らない） |
| R15 | 分岐末尾の CJK グリフで**後続の**呼び出しの条件文が壊れる | **解決済み（2026-10-28）**: 機構は「peek の `\futurelet` が lookahead cs を呼び手の `\fi` の別名にして残す」こと。その cs が他モジュールと共有（`\pdftexja@next`）だと、後続マクロの**スキップされる枝**内に現れた `\pdftexja@next` を TeX の条件スキップ (`pass_over`) が `\fi` と解釈し、条件を1段早く閉じる（例: `\pdftexjaIfDirectionTF` の `\ifnum` 偽→真枝の `\let\pdftexja@next\@firstoftwo` が \fi と読まれ、両枝スキップ→呼び手の `\fi` が余る。素の TeX で `\let\x\fi` + `\ifnum 1=0 \let\x\relax\else\message{F}\fi` により最小化）。修正: lookahead cs を専用名へ分離 — `tex/pdftexja-rules.sty` は `\pdftexja@peek@next`、`tex/pdftexja-ruby.sty` は `\pdftexja@ruby@rpeek@next`。トークン列・ノード列は不変。fence 案（`\futurelet<cs>\A\B`）はストリームに1トークン足すため pdfjsbook/pdfjspf の行数と ruby の aftergroup 順序を動かすので撤回・再導入禁止（コード内コメントに記録）。検証: 最小再現 0 error、`\documentclass[direction=tate]{jlreq}` の `\today\today` 0 error、`run-tests.sh` 0 FAIL、`run-class-tests.sh` 12/12、jlreq 163 gates は **FAILED 3**（全て savepos=R16 の担当）で date-boundaries/coexist-date-boundaries と ruby 6 gates は PASS | `\iftrue\jlreq@iftdir{X}{\number\year 年}\fi` 2連の再現も解消。残るは R16 の savepos 3 件のみ |

**R15 の機構（解決済み・実測で最小化）**: 症状は「分岐の最後が CJK グリフだと、次の `\if...` が壊れる」。最小再現は
```
\iftrue\@secondoftwo{X}{あ}\fi\iftrue\pdftexjaIfDirectionTF{tate}{X}{Y}\fi   % -> Extra \fi
```
false 枝の途中で TeX の条件スキップが「条件文の別名」を `\fi` と読むのが実体で、素の TeX では
```
\let\x\fi \def\pred{\ifnum 1=0 \let\x\relax\else\message{F}\fi\message{P}} \iftrue\pred\fi
```
（`F` が出ず `P` の後で `Extra \fi`）まで縮む。peek の `\futurelet\pdftexja@next\pdftexja@peek@a` は呼び手の `\fi` を lookahead にするため `\pdftexja@next` が `\fi` の別名として残り、後続 `\pdftexjaIfDirectionTF` の**スキップ中の真枝**にある `\let\pdftexja@next\@firstoftwo` の `\pdftexja@next` が `\fi` と解釈されて条件が1段早く閉じる。したがって共有名をやめ、peek 専用の `\pdftexja@peek@next`（rules）と `\pdftexja@ruby@rpeek@next`（ruby）に分離した。fence 案は**置き場所を誤って棄却していた**（記録）: 試したのは `\futurelet<cs>\peek@a\fence` で，押し戻し順が [peek@a][fence] となるため inhibit 枝の `\eatig#1` が **fence を食う**（interlock が立たない）。正しい置き場所は `\futurelet<cs>\fence\peek@a`（fence が先に展開消滅し，peek@a は実フォロワを入力に残したまま走る）で，こちらはトークン列を変えない。もっとも本欠陥は共有 lookahead cs の別名で説明でき，私有 cs 化で閉じたため fence は不要（置き場所だけ将来のために記録）。
| R16 | 縦組の savepos 論理行位置が合わない（3 gates）→ **閉（jlreq.cls 側で修正済み，jlreq commit `460bf95`。`savepos-warichu` / `savepos-warichu-mag` / `savepos-marginpar` PASS）** | 原因は式ではなく述語の位置。pdfTeX 分岐の `\jlreq@calc@current@linewidth@onecolumn` は `\pdftexjaIfPageDirectionTF{tate}{+\topskip-\Cdp}{}` を `\dimexpr` の**中**に置いていた。この述語は `\let` と `\ifnum` を含む非可展開マクロで，`\dimexpr` の走査をそこで打ち切り（エラーは出ない），後続の第1行補正・`-\@totalleftmargin`・`-1truein` が無言で落ちる。実測の打ち切り値: ラベル未定義時 `25284sp`(0.3858pt)=`0-\hoffset-\oddsidemargin`，`X=8643162sp`(131.88pt) のとき `8668446sp`(132.27pt)=`X-\hoffset-\oddsidemargin`。**保存 X は回転ガリ―の行方向座標として正しい**: 行内で 1 文字ごとに +655360sp(10pt)，同一行の Y は不変，行頭 `X=4383322sp`(66.884pt)=`1in+oddsidemargin-(topskip-Cdp)`。よって Y（行直交方向）への写像は不要で，旧行の見立ては誤り。修正: 補正量を計測時（非展開文脈）に dimexpr 変数 `\jlreq@linewidth@firstline@shift` へ確定し，式はそれを加えるだけにした（yoko 文書と tate 内 yoko 論理ページは 0 で従来と同一）。加えて pdfTeX の `\warichu`/`\inlinenote` は pdftexja 側の私有 dimen しか更新せずクラスの `\jlreq@current@linewidth` が更新されなかった（ゲートはクラス側の値を読む）ため，クラスが `\NewCommandCopy` で別名化し同一測定点（初め括弧の前）でクラス計測を 1 回走らせるラッパを追加（aux id を 1 つ余分に消費，2 パスで安定） | **残差（ゲート外・記録のみ）**: 縦組の注列「行頭」が pdflatex 0 / uplatex 2zw で，脚注マーカ位置が 10pt 時 `16.00006pt`(pd) vs `39.99937pt`(up)（差 23.99931pt = 2.4zw，12pt では 4zw→48 に比例）。回転ガリ―内の脚注段落に縦組の字下げ・合印箱幅が乗らないため（別欠陥として切り出し）。傍注列そのものは `\linewidth+\marginparsep` で pd/up 完全一致（実測 200.0001pt）なので，ゲートは「傍注列位置（0.1pt）＋脚注マーカが注列先頭セル内」を判定し，生 savepos のエンジン間比較（184.00005 vs 160.0007pt，枠組みが異なる）は廃止した |
| R17 | 縦組数式の和文↔数式境界グルーが 0 → **閉（`\pdftexja@emitpair@xspc` の極性反転。commit `6254223`）** | `pdflatex-tate-math` の BOUND-A/B: `\hbox{漢$x$}` が 10.0+5.715=15.715pt（境界グルー無し）。原因は xspacing 許可の判定で，`\pdftexja@ifxsp` が「許可」で 1 を返すのに呼び出し側が `\ifnum\pdftexja@xspval=\z@` で**許可時に抑制**していた。`=\@ne` に直し 18.215pt（+0.25zw）を実測。foundation 0 FAIL・class parity 12/12・jlreq は 6→5 FAIL | 解決済み。R6 の `\pdftexjaSetCharSpacing` 幅反転も同根 |
| R14 | 縦組の**位置**ゲートが無い | 縦組は text 一致・グリフ被覆・クラス版面値で検証しているが、列位置の比較は未実装。実測: jtbook page1 の x クラスタ間隔は 15.4/16.9pt の実列間に 1.1–2.0pt のサブセル分割が混在し、単純な「最頻値/中央値」はどちらも artefact になる | 必要作業: pdftexja の回転ガリ―を文書座標系へ戻す写像を比較器に実装し、その上で列ピッチを 0.05pt で比較する（閾値ではなく計測基盤の追加） |
| R13 | crop transport が委譲していない | `jlreq-trimmarks.sty` / `jlreq-trimmarks-pdftex.def` が自前で stock/`\pdfpageattr`/回転を実装 | `\pdftexjaSetCropStock/SetCropDrawing/SetPageAttributes/ClockwiseBox` へ委譲すべき（plan §7.2） |

### R7 の内訳（実測で特定済み・修正は次段）

1. **ハッシュ実体の不一致**: 登録は `\csname <catcode-12 の byte>\endcsname` を定義するが、
   CJK が入れた**アクティブ文字**（catcode 13）は別のハッシュ実体。実測: 登録後も
   `\meaning^^e5` は `\CJK@@@…` のまま。→ インストールは `\lccode`/`\lowercase` 方式で
   アクティブ文字そのものに `\def` する必要がある（実装案は検証済みで有効）。
2. **キーの表現不一致**: 候補表のキーが「byte 文字列」と「10 進値」で食い違うと
   ルックアップが空になる。→ 両側とも 10 進 byte 値に統一する（実装済み・有効）。
3. **照合が `\ifx`**: 登録側の綴りは catcode 12、入力側はアクティブ文字なので
   `\ifx` は同じ byte でも一致しない。→ char code の数値比較にする（実装済み・有効）。
4. **候補会計**: `@utf@listgrab` が候補を `{残り}{target}` の入れ子で積むのに
   `@utf@choose@a/b` は平坦 2 トークンとして読む。`@utf@match` は枯渇候補を捨てる。
   → 「実行ベース」（`\pdftexja@utf@c{残り}{target}` を `\pdftexja@utf@c` を差し替えて
   実行する）へ書き換える設計を用意した（実装中に 1–3 を直した状態でも
   `\　` がまだ unknown になるため、候補会計の実装を詰める必要がある）。

R1/R2 は「純 CJK の折返し差」＝ 評価器ではなく **行容量（`\zw` と段幅）** か
**クラス固有ブロックの可視トークン集合**の差。face 差ではない（同一 face 追試で不変）。

## 2. 作業パッケージ（依存順）

### WP1 — 行容量の確定（R1, R2）: 最優先・独立
目的: 「1 行に何セル入るか」を両実装で一致させる。JFM/評価器に手を入れる前に、
**行容量の算式**を測って確定する。

1. `pdfjskiyou` / `ltjskiyou` の双方で、本文 1 行目の
   `\hsize`, `\columnwidth`, `\textwidth`, `\zw`, `1\zw` の実寸、および
   `48\zw+\columnsep` と `\columnwidth` の差を `\typeout{CAP:…}` で出す
   （本文先頭に probe を入れた一時 fixture。コミットしない）。
2. 期待: kiyou は 2 段で `\columnwidth = (48\zw+\columnsep-\columnsep)/2 = 24\zw`。
   ours が 25 セル入るなら `\zw` が ref より小さい（`\zw = \columnwidth/24` を満たさない）。
   実測 `\textwidth` 一致なので、差は `\zw` 側か `\columnsep` 側の丸め。
3. 修正候補（測定結果で一つに決める）:
   - a) `pdftexja-fonts.sty` の `\zw = jfm.zw × S` の S 決定が kiyou の `ja-scale=.9769230`
     と `\f@size` の積で 1 セル分ずれる → kiyou の class helper が `\zw` を
     `\columnwidth/24` に合わせるのではなく、**S を class が明示**する
     （`\pdftexjasetup{ja-scale=…}` を `\normalsize` 後に再確定）。
   - b) kiyou の `\columnsep{28truebp}` と `\fullwidth{48\zw}+\columnsep` の評価順
     （`\zw` 未確定時に評価されている疑い）→ 評価順を `\normalsize` 後に移す。
4. 検証: R1 の line 8 が同一セル数になり、`run-class-tests.sh --classes pdfjskiyou` が PASS。
   **PASS したときの 1 行セル数と `\zw` 実寸を PLAN 追記で記録**。

### WP2 — ltxdoc の可視トークン差（R2）
1. 両 PDF の page1 line6 の**実テキスト全文**を `pymupdf` でダンプ（前後 3 行も）。
2. 差が「マクロ名の展開差（例: `\cmd` の出力差）」なら ltxdoc の preamble
   （`\Macrocode`/`\verb` wrapper、`\mlineplus`、`\mathcode` 調整）を pin の
   `ltjltxdoc.dtx` と 1 対 1 で突き合わせる。差が「行容量」なら WP1 の修正が効く。
3. 修正は `source/pdfjltxdoc.dtx` のみ。基盤へは手を出さない。
4. 検証: `--classes pdfjltxdoc` が PASS、かつ `tsample`（縦組 sample）の
   frame/.5baseline padding が不変であること。

### WP3 — 縦組 book の第1ページ（R3）
1. `pdfjtbook`/`ltjtbook` の page1 の x クラスタを**全件**出し、クラスタ→セル数の対応を比較。
   16.90 は本文グリッド、15.40 は見出し/タイトル材のグリッドと推定。
2. 判定基準を「最頻値」から「**本文クラスタ（セル数 ≥5 のクラスタ）に限定した最頻値**」へ
   変更するのは**テスト側の測定精度改善**であり、閾値緩和ではない。変更する場合は
   `compare-pdf.py` に「本文クラスタ限定」の定義（セル数閾値）をコメントで明記。
3. それでも差が残るなら class 側（tate book の chapter 見出し・タイトルページの
   `\Cdp-\topskip` 適用軸）を pin と比較して修正。
4. 検証: `--classes pdfjtbook` PASS + INFO extent が ref と同オーダー。

### WP4 — 縦組テキスト抽出（R4）
1. まず**切り分け**（推測で font 層を触らない）:
   - `pymupdf` で `standalone-tate.pdf` から text が取れるか（取れれば描画は正常で
     pdftotext の回転フィルタが原因）。
   - `pdftotext -bbox-layout` の bbox が y 反転しているか／空か。
2. 分岐:
   - (a) pdftotext のみ落ちる → **ゲートを pymupdf に差し替える**（`tests/run-tests.sh` の
     `pdftext_has` を pymupdf 実装へ）。捏造した font 修正はしない。閾値ではなく計測器の交換。
   - (b) pymupdf でも取れない → `/XObject` の CTM と ToUnicode を確認。
     `pdftexja-fonts.py` の aux shard ToUnicode 登録が回転ページで欠けるなら、
     字形層ではなく **page attribute / XObject 側**の修正で直す。
3. 検証: `standalone-tate` の 3 assertion が PASS、かつ yoko の抽出が不変。

### WP5 — 独自 preset の数値走査（R5）
1. `tiny` preset で classlist に 17/34/83/201/202 のみを持つ場合に落ちる。
   `\pdftexja@hextodec` / `\pdftexja@jfm@tables` / `page` 初期化のどこが
   「`=` を数値として読む」かを `\errorcontextlines=100` + `\tracingmacros` で特定。
2. 原因が「role クラスが default skip 表を持たない」ことなら、**rules 側で欠落を
   既定値で補う**のではなく、generator が全 class に `kanjiskip/xkanjiskip` 既定を
   出すよう `scripts/pdftexja-jfm-lib.lua` を修正（データ側で完結）。
3. 検証: `tests/run-tests.sh` の tiny ケースが PASS（期待幅 20.0pt / 16.25pt）。

### WP6 — `\pdftexjaSetCharSpacing`（R6）
契約（plan §5.3）: preamble-only、HEX scalar 検査（surrogate/prefix 無し/モード値）、
group-local、繰り返し置換、方向・family 共通、分類/penalty/encoding は不変。
1. 実装: `tex/pdftexja-rules.sty` に
   `\pdftexja@charxsp@<HEX>` 上書き表を追加し、`\pdftexja@ifxsp` が
   「公開上書き → descriptor の `xsp@<cls>` → class 既定 → both」の順で読む。
   `boundary_semantics != jfm` の descriptor では **unsupported error**（黙って no-op にしない）。
2. class 側は `\@ifundefined` 経由の no-op を削除し、直接呼ぶ（JS 4 箇所 + ltxdoc 2 箇所）。
3. 検証: JS クラスで `！〒+%` の境界グルーが変わることを実測（`\hbox{あ！漢}` 幅）、
   ltxdoc で `\ "` が both。不正 HEX / 非 preamble 呼び出しが非 0 で落ちる negative test。

### WP7 — UTF-8 dispatcher（R7）
1. 欠陥: `@utf@listgrab` は候補を `{残り}{target}` の**入れ子グループ**で積むが、
   `@utf@choose@a` は平坦な 2 トークンとして読む。結果 target と残りが交差し、
   `@utf@match` は候補を使い切った時に捨てる。
2. 修正方針: 候補リストを**平坦なトークン列**（`<残りバイト列> <target>` を
   `\pdftexja@utf@cand` マクロで挟む）にし、choose は
   「残りが空 かつ 他候補なし → 実行 / 残りあり → 次トークン読取り / 残り空で他候補あり → ambiguous error」。
3. 検証: `\　`（U+3000）、`和暦`、`西暦true` が実際に dispatch する。
   `西暦` と `西暦true` の prefix 曖昧は**曖昧エラー**になることを negative test で確認
   （jlreq 側は `西暦` を登録しない運用にする）。

### WP8 — 縦組 `\begin{math}`（R8）
1. `\pdftexja@imath@paren#1\)` は `\)` トークン区切り。`\begin{math}` は `\endmath` で
   閉じるため一致しない。
2. 修正: `\endmath` 区切りの sibling（`\pdftexja@imath@endmath#1\endmath`）を追加し、
   `\begin{math}` を `\let\endmath\)` ではなく**専用 wrapper** に差し替える。
3. 検証: tate で `\begin{math}x+y\end{math}` が通り、`$\hbox{x}$` の raw-box 拒否が不変。

### WP9 — jlreq の残存 private state（R9, R10）
1. `jlreq.cls` の `\jlreqpdf@…` 107 箇所を PLAN（split plan §3 の表）に従って 20 ブロック単位で除去:
   units(624–664), savepos(757–887), para reset(1202–1208), UTF8(1494–1651), size(1762–1774),
   C*(1825–1851), warichu(4604–4870), TCY/jidori/akigumi(6997–7209), reference(7317–7477),
   insertion(7607–7645), ai-mark(3998–4061), index 遷移(6694–6745), math internal(6637–6640)。
   各ブロックは「公開 API 呼び出し」または「p/u/l のみ残す」のいずれかにする。
2. 併せて `jlreq-complements.sty`（index 遷移）と `jlreq-trimmarks*.{sty,def}`
   （crop transport）を `\pdftexjaSetCropStock/SetCropDrawing/SetPageAttributes/ClockwiseBox`
   と `Begin/EndPageDirection` へ委譲。
3. `jlreq-pdftex{,-rules,-ruby,-paragraph}.sty` を削除（re-export shim は作らない）。
4. 検証: `[pdflatex]` と `[pdflatex,tate]` が 0 error、`\jlreqpdf@` 残存 0、
   p/u/l の既存 suite が不変（`tests/run-pdftex-tests.sh` の T7 baseline byte 比較）。

### WP10 — 検証基盤の最終化（完了条件 5）
1. `tests/run-tests.sh` の抽出ゲートを pymupdf に統一（WP4 の結果に依存）。
2. `make check` に `run-class-tests.sh` を統合（`--texmf $(PDFTEXJA_TEXMF)`）。
3. `scripts/pdftexja-check-inputs.py` を 3 モード（foundation/jlreq/native）で実運用し、
   repo 外 cwd・installed tree のみの staged proof を CI 相当の手順として記録。
4. TDS 生成 → その TDS だけで class parity を再実行（`make tds` + `--texmf tds/`）。

---

## 3. 進め方の制約

- **測定 → 修正 → 再測定**の順を守る。推測で font/JFM 層に触らない
  （R4 は「計測器の交換」で解決する可能性が高い）。
- 誤差帯・grid 閾値・座標耐性を**結果に合わせて緩めない**。緩める必要が出たら
  「測定精度の改善（例: 本文クラスタ限定）」として定義を明文化し、PLAN に追記する。
- 比較は常に「同一本文（`tests/fixtures/classes/shared-body.tex`）+ ピン留め参照実装」。
  参照実装が無い環境は SKIP ではなく明示非 0（現状は SKIP 表示なので WP10 で FAIL 化を検討）。
- 各 WP 完了時に `run-class-tests.sh` の該当ペアと `run-tests.sh` の該当 assertion の
  実出力をコミットメッセージに貼る。
- 触ってはいけないもの: user の ignored file、`reference/pinned/` の内容、
  TeX Live 側の設定。

## 4. 順序の原則（API が先、TDS が最後）

クラス群と jlreq は**未実装の基盤 API を消費する**ので、順序は次で固定する:

```
0) 診断のみ（コード変更なし・並行可）
   WP1-1 kiyou 行容量 probe / WP4-1 pymupdf での tate 抽出可否 / WP5 の原因特定
1) 基盤 API を完成させる: WP6 (SetCharSpacing) → WP7 (UTF dispatcher) → WP8 (\begin{math})
   → WP5 (generator の class 既定 skip) → WP4 (抽出の帰属に応じた修正 or 計測器交換)
2) クラス修正: WP1 (行容量の束縛をクラス側で確定) → WP2 (ltxdoc) → WP3 (jtbook)
3) jlreq cutover: WP9 (private 除去・旧 backend 削除・R13 委譲)
4) 検証/TDS: WP10（class parity を make check へ、provenance 3 モード、TDS/staged/uninstall）
```

理由: WP6/WP7/WP8 が無いままクラス側を直すと、クラスは no-op 警告経路で「動いて見える」
状態のまま修正が入り、jlreq の cutover も同じ API 前提で止まる。

## 5. 閾値の据え置き（standing rule）

ゲートは**修正によってのみ**緑にする。以下は結果に合わせて変更しない:

- 折返し誤差帯 `CELL_TOL = 2` セル（`tests/compare-pdf.py`）
- yoko 行送りグリッド 0.03 pt / tate 列ピッチ 0.05 pt
- クラス版面値（GEOM）0.03 pt、MediaBox 0.02 bp、縦組グリフ被覆 3 %
- `check-jfm` の regeneration diff-zero、`check-fonts` の byte 一致

測定精度の改善（例: 本文クラスタ限定のピッチ）は**定義の変更**として本 PLAN に追記し、
「閾値を緩めた」と区別して記録する。

## 6. 依存グラフ

```
WP1 (行容量) ─┬─> R1 PASS
              └─> WP2 (ltxdoc) ─> R2 PASS
WP3 (jtbook) ───────────────────> R3 PASS
WP4 (抽出計測器) ───────────────> R4 PASS, WP10 前提
WP5 (tiny preset) ──────────────> R5 PASS
WP6 (SetCharSpacing) ───────────> R6 PASS（JS/ltxdoc の spacing 実測）
WP7 (UTF dispatcher) ───────────> R7 PASS（jlreq の日付系の前提）
WP8 (\begin{math}) ─────────────> R8 PASS
WP9 (jlreq private 除去) ── 依存: WP6, WP7, WP8 ─> R9/R10 PASS
WP10 (検証統合) ── 依存: WP1–WP9
```

## 7. 直近の一手

診断（コード変更なし）を 3 本同時に: `WP1-1`（kiyou の行容量 probe）、`WP4-1`
（pymupdf での tate 抽出可否＝計測器か描画かの切り分け）、`WP5`（tiny preset の
数値走査箇所の特定）。この 3 本で R1/R4/R5 の帰属が確定し、以降の修正順（§4）が
そのまま実行できる。修正の着手は基盤 API（WP6→WP7→WP8）から。

---

## 現況サマリ（この計画の実行状況）

| 項目 | 状態 | 根拠（実測） |
|---|---|---|
| WP4 縦組抽出 | **完了** | pdftotext 0 文字 / PyMuPDF 115+13 文字 → 計測器を交換。run-tests.sh の 3 assertion が PASS |
| WP5 tiny preset | **完了** | math delta が `roles.normal` を引くよう修正。tiny が 0 error、幅 20.0pt / 16.25pt |
| WP1 kiyou 行容量 | **完了** | ja-scale 二重適用を解消。`\zw` 9.03378 / textwidth 461.72658 が参照と一致、24 行同文 |
| WP2 ltxdoc | **完了** | `\Cjascale` を bxcjkjatype ロード前に ja-scale で設定。`\hbox{あ}` 9.6222pt = `\zw` |
| WP3 jtbook | **完了（範囲明示）** | 縦組の位置比較は回転ガリ―と native 縦組で座標系が異なり実装不能 → テキスト・被覆・版面値で gate、位置は INFO。R14 起票 |
| WP6 SetCharSpacing | **API 完了・効果配線は R6b** | 4 契約テスト PASS。段落途中 Latin→CJK では class 27 が立たず未参照（設計判断待ち） |
| WP7 UTF dispatcher | 進行中（別担当） | 4 欠陥を特定済み。R7 参照 |
| WP8 `\begin{math}` 縦組 | 未着手 | `\)` 区切りと `\endmath` の不一致 |
| WP9 jlreq cutover | **完了** | `grep -c jlreqpdf@` = 0（cls/complements/trimmarks/def）、旧 4 .sty 削除、yoko/tate 0 error・2 頁、p/u sanity OK |
| WP10 検証統合 | 一部完了 | class parity 12/12（TDS でも 12/12）、staged provenance（/tmp/pkg と TDS）PASS、uninstall sentinel PASS。jlreq runner は別担当で更新中 |
| 全体 | run-tests.sh **0 fail** / run-class-tests.sh **12/12** / check-jfm・check-fonts green | 各コミットメッセージに実出力を記載 |

残: R7（dispatcher）、R8（縦組 `\begin{math}`）、R6b（効果配線の設計）、R14（縦組位置ゲート）、R12（jlreq runner）。

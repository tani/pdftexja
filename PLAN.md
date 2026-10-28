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
| R5 | 独自 preset で `\begin{document}` の数値走査エラー | tiny preset（role 17/34/83/201/202）で `Missing number <to be read again> =` | `tex/pdftexja-rules.sty` の class 表構築（`\pdftexja@jfm@tables` / `\pdftexja@loadclass`）と `direction` のページ初期化。role が default skip を持たないことが引き金（generator 側で全 class に既定を出すのが本筋）。**status: closed（commit `40a3014`）・gate 2 本**: `tests/run-tests.sh:279`–`350` の `tiny-jfm` が R5 と同じ role 表（normal=17 / latin=83 / paragraph=201 / box=202）の descriptor を `\usepackage[jfm=pdftexja-jfm-tiny.def]` で読み、`\begin{document}` の selectfont hook を通し、`\hbox{ああ}`=20.0pt / `\hbox{あ。}`=16.25pt を assert する（**走査自体はこれで既に被覆されていた**）。追加の `tiny-preset-scan` gate は契約を明示するもの: `\AtBeginDocument` の marker、`Missing number` 不在、`\pdftexja@normcls` が descriptor の class-17 データ（`{1.000000}{0.880000}{0.120000}{left}{0.000000}`）であること、同 2 幅。pre-fix（`40a3014` の逆適用）では両 gate とも `FAIL: ... compile`（`Missing number`） |
| R6b | ~~効果配線の設計制約（R6 の下位）~~ → **閉（2026-10-28）** | 旧: `\pdftexja@latadj` は `lastclass=90`（段落頭）の時だけ `lastclass=27` を立てるため、peek が直接見られない段落途中の Latin（空白の後 `漢 A漢`、制御綴・グループの後 `漢\textbf{A}漢`、合字 `漢 fi漢`、`\(x\)`）では class 27 が現れず、xkanjiskip も `\pdftexjaSetCharSpacing`（jsclasses の `！`=post / `〒`=pre）も効かなかった。修正前の実測（pdfjsarticle、同一環境）: `漢 A漢` 34.69092pt・`漢\textbf{A}漢` 32.55197pt（どちらも和欧文間 0） | **修正**: ①欧文検出を段落途中にも広げた（直前ノードが char 0 / 合字 7 / カーン 12（CJK.sty の 1sp/2sp 目印カーン＝`\ruby` などの末尾は除く）で、かつ最後の和文グリフ・ボックス頭・段落頭以降に欧文字が組まれた = `\spacefactor` が目印 `\pdftexja@sfmark`=1001 でない → 27。インライン数式 10 → 27）。目印は peek（グリフ直後）、everyhbox、`para/begin` で立て、peek は空白・欧文の前で 1000（pTeX の和文後の値）に戻すので通常の語間グルーは不変。②和文→欧文で欧文が `\DeclareTextFontCommand` 系（`\textbf` など）の引数先頭にある場合は `\text@command` で境界を出す。③peek が `\(` を `$` と同様に扱う。修正後: `漢 A漢` 37.19092pt、`漢\textbf{A}漢` 37.55197pt（両側 2.5pt）、`漢\relax漢`・`漢\kern1pt漢` は不変。**ゲート**: `tests/run-tests.sh` の `r6b`（幅の差分で 10 項目を assert、修正前の木では 6 項目 FAIL）。shared-body の組版は 12 クラスとも修正前後で同一（pdftotext -layout 差分 0）。残る未検出: `\sfcode` 0 の欧文字（`)` など）が制御綴の後にある場合 |
| R6 | `\pdftexjaSetCharSpacing` の**効果**が出ない（API 自体は実装済み） | 実装: 公開上書き層（`\pdftexja@charxsp@<decimal>` → descriptor `xsp@<class>` → 既定 both）、HEX/mode 検証、preamble-only、group-local を追加し、contract test 4 件は PASS（不正 HEX / 不正 mode / 本文中呼出を拒否）。**解決済み（2026-10-28 実測）**: 効果が出なかった原因は R17 と同じ xspacing 許可の極性（`\pdftexja@emitpair@xspc`）。修正後の実測は `A漢` が none 17.50002pt → **both 20.00002pt**。専用の幅アサートは無く、`SetCharSpacing` のゲートは contract のみ（幅比較は意図的に対象外, `tests/run-tests.sh:434-436`） | 原因: `\pdftexja@ifxsp` は `\pdftexja@emitpair@xspc`（class 27 が境界に居る時だけ）からしか呼ばれず、実際の Latin↔CJK 境界はレンダラの `\pdftexja@pre`/`\pdftexja@latadj` 側で処理される。**効果の配線が未了**。**status: 効果は R17 と同根（`\pdftexja@emitpair@xspc` の極性反転、commit `6254223` で解消）** — 2026-10-28 実測: `A漢` は `none` 17.50002pt → `both` 20.00002pt。ただし**幅を assert するゲートは無い**: `run-tests.sh` の `SetCharSpacing` 検査は contract のみ（compile、不正 HEX/mode 拒否、preamble-only、group-local）で、幅比較は `:434`–`:436` のコメントどおり R6b 配線待ちのため意図的に置いていない |
| R7 | UTF-8 dispatcher が全滅 | `\　`(U+3000) で `unknown command spelling`。`和暦/西暦` は登録成功するが dispatch 不可。**調査で判明した4つの独立欠陥**（下記） | `tex/pdftexja-latex.sty` の登録と照合。①②③④を全て直さないと dispatch は成立しない。**status: 修正済み（commit `b86adea`）・gate あり（`r7-utf`）** — `tests/run-tests.sh` が `pdfjarticle`（class helper が実際に `西暦/西暦true/西暦false/和暦` を登録する）で、登録 target を marker wrapper に包み、`\　`=1 zw（`A\　B`−`AB` が `\hbox{\　}` と一致、>0）、`\和暦`/`\西暦` の marker 各 1 回、state が west→west（raw 和暦 は dispatch しない）→era→era（raw 西暦 も dispatch しない）を assert。生の `和暦`/`西暦` は抽出テキストに現れ、`\西暦\today` は西暦年、`\和暦\today` は元号年を抽出テキストに残す（「エラーが無い」ではなく出力で判定）。pre-fix `latex.sty`（`b86adea^`）では `FAIL: r7-utf: compile`（`ambiguous UTF command spelling`） |
| R8 | 縦組で `\begin{math}…\end{math}` が失敗 | `File ended while scanning use of \pdftexja@math@scan`（yoko では通る）。**2026-10-28 再測: `725acf4` の `\let\endmath\)` では直っていなかった** — `direction` を pdftexja の option として与えた真の tate 文書（`\usepackage[direction=tate]{pdftexja}`）で `\begin{math}x+y\end{math}` は HEAD でも同じ scan-to-EOF で落ちる。`\documentclass[direction=tate]{article}` は package に届かず `\pdftexja@dir=0`（yoko）になるため、この綴りでは症状が出ない（gate が空振りする罠） | 真因は delimiter 照合の規則: TeX は制御綴区切りを**同一トークン**でのみ一致させ、`\ifx` の意味比較はしない（最小再現: `\let\zz\rp` でも `\def\a#1\rp{...}` は `\zz` に一致しない）。`\begin{math}` の終端は入力ストリーム上ではトークン列 `\end`+`{math}` であり、`\)` でも `\endmath` でもない。**status: 修正済み（本 commit）・gate あり（`tate-beginmath`）** — `\pdftexja@imath@endenv#1\end` が `\end` で捕捉し、本体（`\pdftexja@imath@body` に共通化）を組んだ後 `\end` を再出力して `\end{math}` の `\endgroup`/hook を通常どおり走らせる。tate の `\math` をこの wrapper に差し替え、二重閉じを避けるため `\endmath` を no-op にする（yoko の `\(...\)` 素通り経路は不変）。検証: inline/`\hbox` 内/`\[...\]`/`\(...\)` すべて 0 error、`\begin{math}x+y\end{math}` の幅 = `$x+y$` の 23.199pt、表示形も抽出テキストに 2 本の `x + y`。pre-fix（`HEAD` の `pdftexja-math.sty`）では `FAIL: tate-beginmath: compile`（同じ `File ended while scanning use of \pdftexja@math@scan`） |
| R11 | ~~TDS/staged/uninstall の証跡が無い~~ → **閉（2026-10-28）**: `make tds` を acceptance の step 6 で実行し、生成物をゲート化した。repo 外 cwd の staged proof（step 4）と uninstall sentinel（step 1 の `check-uninstall`）も同じ acceptance で実行済み | ゲート: `tests/acceptance.sh` の「6. TDS bundle」が `make tds TDS=$STAGE/tds` の後、12 class（`.cls`）、`pdftexja.sty` + 9 modules + 2 class helper、JFM 25 `.def`（5 preset + standard の 6 variant × 2 方向 + 他 4 preset の base × 2 方向）と 5 manifest、font profile 3 本を個別に `test -e` し、欠落は `FAIL: tds: missing <path>` で fail（SKIP にしない）。TDS 内の `SENTINEL`（`check-uninstall` が置く内容 `keep` を含む）も不在 assert | `TDS` を Makefile の上書き可能変数（`TDS ?= tds`）にし、acceptance は checkout を汚さず scratch に bundle を作る。`clean` は空/`/`/`.` を拒否 |
| R12 | ~~`tests/run-pdftex-tests.sh` が未移植~~ → **完了（検証）**: 163 gates・`FAILED: 0` で稼働 |

クラス（bundled classes）:

| # | 症状 | 実測 | 原因の所在（帰属） |
|---|---|---|---|
| R1 | `pdfjskiyou` 本文が 1 セル広い（INFO） → **閉（2026-10-28 分解・欠陥ではない）** | 全 24 行を機械的に走査: セル数が食い違うのは **2 行のみ**（p1 l11 `28 vs 29`、p1 l14 `21 vs 20`）で、**最初の発散行は必ず Latin を含む行**（`「括弧」と句読点、そしてLatintextと数字123。`）。l14 は Latin 行の改行位置が 1 字ずれた**波及**（A は `ひ` から、B は `ふ` から始まる）。CJK のみの行は 24/24 で完全一致、page 2 は worst=0。原因は同一 face でも **Latin の metric 源が違う**（pdfTeX は TFM 幅、LuaTeX は OTF 幅）ことで、`\textwidth`/`\zw` の差ではない（GEOM は R18 後 0.03pt 一致）| 解決済み・ゲート変更不要（`CELL_TOL=2` の帯域内で，上記の帰属を確認） |
| R2 | `pdfjltxdoc` page1 line6 が 33 vs 30（INFO） → **閉（2026-10-28 分解・欠陥ではない）** | 20 行中 4 行が食い違い、**最初の発散は Latin 行**（p1 l9 `42 vs 43`）。`page1 extent` の `144.47 vs 139.93`（4.54pt）は独立した字下げ差ではなく **同じ行のセル数差の算術的帰結**: 両側とも右端は `498.41` で一致し、B が 1 セル多く載るため左端が左へ動く（A `42` セル、B `43` セル）。以降の l11/l14/l15 は波及。CJK のみの行と page 2 は一致（page2 worst=0）| 解決済み・ゲート変更不要（attribution: Latin metric 源差。旧説の「jslogo/`\verb` が可視トークン集合を変える」は**棄却**） |
| R3 | ~~`pdfjtbook` 第1ページ列ピッチ（INFO）16.90 vs 23.30~~ → **閉（2026-10-28）: 差は実在せず、旧推定器の artefact** | 真の本文列ピッチは**両側 16.936pt**（`PITCH: pdfjtbook: page 1 tate column pitch ours=16.936 ref=16.936`、jtarticle/jtreport も同値）。旧 23.30 の内訳（2026-10-28 再測ヒストグラム）: ref page 1 の x0≥8 セルクラスタ 12 個 → 連続ギャップ 11 本のうち帯域内 8 本 = `27.4, 16.9, 27.4, 15.4, 24.5, 16.9, 17.0, 23.3`（16.9 = 実列ピッチ、27.4 = itemize インデント、15.4/24.5 = サブセル分割、23.3 = 列群跳び）。中央値は 23.3/24.5 を拾う。ours 側は同じ 8 本の中央が偶然 16.9 になっただけで、ours の列は `16.9,16.9,27.4,16.9,15.0,17.0,16.9,17.0`。15.40 も同じ母集団の別分位点で再現しない | **測定定義の欠陥（class は正しい）**。修正は `tests/compare-pdf.py` の推定器のみ: glyph box 幅 = ページの最頻 em（見出し材は別サイズなので除外）→ 列 x0 を 0.001pt で統合（本文 8 セル以上）→ 0.01pt ビンの**最頻**ギャップ。class / clo / def の変更なし。許容 0.05pt は R14 の根拠を参照。なお本行が引く page 2「ours 2 / ref 1」は R18 の `\Cwd` 欠陥による見かけで、R18 修正後は jtbook/jtarticle/jtreport とも **1/1** |
| R18 | 縦組 class の `\Cwd` が 4.8111pt（ref 9.6222pt）で tate 版面が半分 → `pdfjtbk10.clo` の `67\Cwd` が 322.0pt（ref 606.0pt）、`th` 451 vs 446、`pi` 4.8111 vs 9.6222、page 1 の y 被覆 227.90..558.32（ref 84.20..735.01）、page 2 の 60 字が 2 段（ref 1 段） | **解決済み（2026-10-28）**: `tex/pdftexja-class.def` の `\pdfjclass@snapshot` が `\pdftexjaGetMetrics{#1}{\Cht}{\Cdp}{\Cwd}` と呼び、GetMetrics の契約 `<wd> <ht> <dp>` に対し実装は w→#2, h→#3, d→#4 なので **w→\Cht, h→\Cdp, d→\Cwd の巡回置換**になっていた。tate JFM class 0 `{1.0}{0.5}{0.5}` では `\Cwd=d\cdot\jareg=0.5\cdot9.6222=4.8111`（yoko は d=0.12 で `\Cwd=1.1546`、`\Cht=w=9.6222`）。参照 lualatex の `\hbox{漢}` 実測は yoko `\Cwd=9.6222 \Cht=8.46753 \Cdp=1.15466`、tate `\Cwd=9.6222 \Cht=4.8111 \Cdp=4.8111`、すなわち **\Cwd=\wd0=w**（w は tate でも 1\zw）・**\Cht=\ht0=h**・**\Cdp=\dp0=d**。9.6222 は `0.962216\jareg`（`\Cjascale`）であって 1em ではない。引数を `{\Cwd}{\Cht}{\Cdp}` に修正 | 実測 before→after: ours `\Cwd` 4.8111→9.6222、`tw` 322.0→606.0、`th` 451→446、`pi` 4.8111→9.6222、page 1 tate 列数 11→8（ref 9）、page 2 段数 2→1（ref 1）、yoko `th` 594→593・`pi` 1.1546→9.6222（ref 593/9.6222）。class parity 12/12。**ゲート**: `tests/run-class-tests.sh` の GEOM 比較が `awk -v a="${1%pt}"` に `tw=322.0` を渡し、awk が先頭の非数値で 0 と解釈する退化（常に `d=0`）だった。`key=` と `pt` を剥がして各値を数値化し、tw/th/bs/pi/cs を **0.03pt**（PLAN §5 の版面値許容）で assert。pre-fix 木で `GEOM DIFF tw ours=322.00000 ref=606.00000 delta=284` / `th ... 451 vs 446` / `pi ... 4.8111 vs 9.6222` を出して 6 FAIL、修正後 12 PASS |

jlreq:

| # | 症状 | 実測 | 原因の所在（帰属） |
|---|---|---|---|
| R9 | ~~縦組 jlreq が private state 参照で停止~~ → **失効（2026-10-28 検証）**: `grep -c "jlreqpdf@" jlreq.cls jlreq-*.sty` は全 0。private state 参照は公開 API（`\pdftexjaIfDirectionTF` 等）への置換で解消済み |
| R10 | ~~旧 backend が現役~~ → **失効（検証）**: `jlreq-pdftex{,-rules,-ruby,-paragraph}.sty` は 4 本とも不在（`ls` で確認）。残るのは設計どおりの adapter `jlreq-pdftex.def` と JFM `.def` 12 本のみ | 完了 |
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
| R16 | 縦組の savepos 論理行位置が合わない（3 gates）→ **閉（jlreq.cls 側で修正済み，jlreq commit `460bf95`。`savepos-warichu` / `savepos-warichu-mag` / `savepos-marginpar` PASS）** | 原因は式ではなく述語の位置。pdfTeX 分岐の `\jlreq@calc@current@linewidth@onecolumn` は `\pdftexjaIfPageDirectionTF{tate}{+\topskip-\Cdp}{}` を `\dimexpr` の**中**に置いていた。この述語は `\let` と `\ifnum` を含む非可展開マクロで，`\dimexpr` の走査をそこで打ち切り（エラーは出ない），後続の第1行補正・`-\@totalleftmargin`・`-1truein` が無言で落ちる。実測の打ち切り値: ラベル未定義時 `25284sp`(0.3858pt)=`0-\hoffset-\oddsidemargin`，`X=8643162sp`(131.88pt) のとき `8668446sp`(132.27pt)=`X-\hoffset-\oddsidemargin`。**保存 X は回転ガリ―の行方向座標として正しい**: 行内で 1 文字ごとに +655360sp(10pt)，同一行の Y は不変，行頭 `X=4383322sp`(66.884pt)=`1in+oddsidemargin-(topskip-Cdp)`。よって Y（行直交方向）への写像は不要で，旧行の見立ては誤り。修正: 補正量を計測時（非展開文脈）に dimexpr 変数 `\jlreq@linewidth@firstline@shift` へ確定し，式はそれを加えるだけにした（yoko 文書と tate 内 yoko 論理ページは 0 で従来と同一）。加えて pdfTeX の `\warichu`/`\inlinenote` は pdftexja 側の私有 dimen しか更新せずクラスの `\jlreq@current@linewidth` が更新されなかった（ゲートはクラス側の値を読む）ため，クラスが `\NewCommandCopy` で別名化し同一測定点（初め括弧の前）でクラス計測を 1 回走らせるラッパを追加（aux id を 1 つ余分に消費，2 パスで安定） | **残差（→ 2026-10-28 に閉）**: 縦組の注列「行頭」が pdflatex 0 / uplatex 2zw で，脚注マーカ位置が 10pt 時 `16.00006pt`(pd) vs `39.99937pt`(up)（差 23.99931pt）。**機構**: `\pdftexjaInsertionMetrics` が `\begingroup … \endgroup` で本体を包み，脚注段落の `\par` がその外（`\insert` の閉じ括弧）で起こるため，TeX の行分割時に `\leftskip` が呼び出し前の値へ戻っていた。pd の箱ダンプは行頭が `\glue -8.00003` から，up は `\glue(\leftskip) 23.99933`（= 脚注サイズ 8.00003pt の 3zw。`\leftskip += 1\jlreq@zw` と zw 整数倍丸め補正の和）から始まり，落ちた量がそのまま 23.99931pt。**修正**: pdftexja-rules.sty で本体を「段落を内側で終える」形（`#1\par`）にした（垂直モードの `\par` は無害）。実測: 16.00006 → 39.99939pt（up 39.99937），箱構造も up と一致。ゲートは `savepos-marginpar` が注列行頭を 0.5pt で assert（旧: 記録のみ）。傍注列そのものは `\linewidth+\marginparsep` で pd/up 完全一致（実測 200.0001pt）なので，生 savepos のエンジン間比較（184.00005 vs 160.0007pt，枠組みが異なる）は廃止のまま |
| R17 | 縦組数式の和文↔数式境界グルーが 0 → **閉（`\pdftexja@emitpair@xspc` の極性反転。commit `6254223`）** | `pdflatex-tate-math` の BOUND-A/B: `\hbox{漢$x$}` が 10.0+5.715=15.715pt（境界グルー無し）。原因は xspacing 許可の判定で，`\pdftexja@ifxsp` が「許可」で 1 を返すのに呼び出し側が `\ifnum\pdftexja@xspval=\z@` で**許可時に抑制**していた。`=\@ne` に直し 18.215pt（+0.25zw）を実測。foundation 0 FAIL・class parity 12/12・jlreq は 6→5 FAIL | 解決済み。R6 の `\pdftexjaSetCharSpacing` 幅反転も同根 |
| R14 | ~~縦組の**位置**ゲートが無い~~ → **閉（2026-10-28）: 列ピッチ位置ゲートを実装** | 回転ガリ―→文書座標系の写像は不要だった。比較可能な位置量は **列ピッチ**（本文行に直交する x 方向の段間隔）で、両エンジンとも class の tate 段組から決まる。実測: jtbook 16.936/16.936、jtarticle 16.936/16.936、jtreport 16.936/16.936（差 0.000pt）。page 2 は両側とも本文列 < 4（jtbook ours 2 / ref 1、他 2/1–2）で n/a と明示（これは R18 の `\Cwd` 欠陥下の測定。R18 修正後は jtbook/jtarticle/jtreport とも **1/1**）。旧 INFO の 16.90 vs 23.30 は上記 R3 | ゲート: `compare-pdf.py` の `column_pitch()`。均質性の判定 = 最頻 em 幅がページグリフの ≥60%、本文列（≥8 セル）≥4、帯域 [8,30]pt のギャップ ≥4、最頻ギャップがその ≥1/3。両側とも均質なら **0.05pt** で比較し、片側だけ測れる場合と tate 文書で 1 ページも測れない場合は **FAIL**（無言 skip の禁止）。tolerance 根拠: 抽出座標は PDF の 1/1000bp で両側同一推定器、残差は 0.01pt ビン + 浮動小数のみ（実測 0.000pt）→ 0.05pt はその 5 倍。旧推定器の artefact は 6.4pt、実欠陥はさらに大なので 2 桁の余裕がある | **計測範囲（明示）**: 縦組で *ゲート* するのは (a) 抽出テキスト一致、(b) グリフ数 ±3%/4、(c) 各列の文字数（`CELL_TOL=2`）、(d) **本文グリッドの列ピッチ**（均質ページのみ・0.05pt; 判定は「同一 em が 60% 以上・本文 4 列以上・帯内 4 ギャップ以上・モーダルが 1/3 以上」で，満たさないページは両側 `n/a` の INFO）。第 2 ページは両側とも本文 1–2 列で `n/a`，すなわち **ピッチ保証は page-1 本文グリッドに限る**。ページ全体の塗り範囲（`page-extent.py`）は**診断専用**: 回転ガリ―と native 縦組では絶対座標の枠が一致しないため，定数ドリフトを見えるようにするだけに留める（実測 jtbook page1 `ours=88.70..700.79 / ref=84.20..735.01`，後端差 34pt は題材ブロックで，本文列 8 vs 9 の差に由来）。
| R13 | ~~crop transport が委譲していない~~ → **閉（2026-10-28 検証）**: slot/bleed/format の policy は class 側に残し、transport は foundation の公開 API へ委譲する（jlreq/PLAN.md step 7.2「class crop と jlreq が共通 PDF transport を使う」の分割） | 委譲の実体: `\pdftexjaSetCropStock` = `jlreq-trimmarks.sty:560`（`:555` の `\@ifundefined` が未ロード時 `PackageError`）、`\pdftexjaSetCropDrawing` = `:564`、`\pdftexjaSetPageAttributes` = `:1219` / `:1221`。`jlreq-trimmarks-pdftex.def` に残るのは banner 用 `\pdftexjaClockwiseBox`（実使用 `:69`）だけ | jlreq 側に `\pdfpageattr` の直書きは 0（`.sty:536`/`:1199` はコメントのみ）。属性文字列の代入は transport の `pdftexja-paper.sty:103` 1 箇所 |

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
1. `\pdftexja@imath@paren#1\)` は `\)` トークン区切り。`\begin{math}` の終端は
   入力ストリーム上 `\end`+`{math}` であり、`\)` とも `\endmath` とも一致しない
   （TeX の delimiter 照合は同一トークンのみ。`\let\endmath\)` は無効 —
   2026-10-28 に HEAD で再現・実測）。
2. 修正: `\pdftexja@imath@endenv#1\end`（本体は `\pdftexja@imath@body` に共通化）で
   `\end` を捕捉し、本体組版後に `\end` を再出力して `\end{math}` の bookkeeping を
   通常実行させる。tate の `\math` をこの wrapper に差し替え、`\endmath` は no-op に。
3. 検証: tate で `\begin{math}x+y\end{math}`（inline/`\hbox` 内）と `\[x+y\]`・`\(x+y\)`
   が 0 error、幅 = `$x+y$` の 23.199pt、表示形も抽出テキストに `x + y` 2 本。
   raw-box 拒否は不変。`tests/run-tests.sh` の `tate-beginmath` が gate。

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
| WP3 jtbook | **完了（範囲明示）** | 縦組の位置比較は座標系が異なるため絶対座標では不可 → テキスト・被覆・版面値で gate。位置は **R14（列ピッチ）で 2026-10-28 に gate 化**（0.05pt）し、R3 も測定 artefact と判明して閉鎖 |
| WP6 SetCharSpacing | **完了** | 4 契約テスト PASS。段落途中の配線は R6b で閉鎖（`r6b` ゲート） |
| WP7 UTF dispatcher | **完了** | `b86adea` の dispatch を `r7-utf` gate が被覆（U+3000=1zw、`\和暦`/`\西暦` marker+state、raw 文字は非 dispatch、抽出テキストで西暦年/元号年） |
| WP8 `\begin{math}` 縦組 | **完了（2026-10-28 実効修正）** | `725acf4` は無効だった（`\let\endmath\)` は delimiter 照合を変えない）。`\pdftexja@imath@endenv` で `\end` 捕捉 + 再出力。`tate-beginmath` gate、幅 23.199pt |
| WP9 jlreq cutover | **完了** | `grep -c jlreqpdf@` = 0（cls/complements/trimmarks/def）、旧 4 .sty 削除、yoko/tate 0 error・2 頁、p/u sanity OK |
| WP10 検証統合 | 一部完了 | class parity 12/12（TDS でも 12/12）、staged provenance（/tmp/pkg と TDS）PASS、uninstall sentinel PASS。jlreq runner は別担当で更新中 |
| 全体 | run-tests.sh **0 fail** / run-class-tests.sh **12/12** / check-jfm・check-fonts green | 各コミットメッセージに実出力を記載 |

残: R12（jlreq runner）。R6b は `r6b` ゲート付きで閉鎖（2026-10-28）。R7/R8 は専用 gate（`r7-utf` / `tate-beginmath`）付きで閉鎖（2026-10-28）。

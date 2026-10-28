%%
%% This is file `pdfjltxdoc.cls',
%% generated with the docstrip utility.
%%
%% The original source files were:
%%
%% pdfjltxdoc.dtx  (with options: `class')
%% 
%% IMPORTANT NOTICE:
%% 
%% For the copyright see the source file.
%% 
%% Any modified versions of this file must be renamed
%% with new filenames distinct from pdfjltxdoc.cls.
%% 
%% For distribution of the original source see the terms
%% for copying and modification in the file pdfjltxdoc.dtx.
%% 
%% This generated file may be distributed as long as the
%% original source files, as listed above, are part of the
%% same distribution. (The sources need not necessarily be
%% in the same archive or directory.)
%%
%% File: pdfjltxdoc.dtx
%%  -----------------------------------------
%%  This file is part of pdftexja, a pdfLaTeX direct-PDF Japanese
%%  typesetting foundation.  It is a port of the LuaTeX-ja source
%%  ltjltxdoc.dtx (LuaTeX-ja 20260130.1) to the pdftexja public API:
%%  the LuaTeX-ja/pTeX font, direction, glue and position primitives are
%%  replaced by pdftexja operations.  The original notices and licence
%%  conditions below are retained unchanged; they are not weakened or
%%  replaced.
%%
%%  Copyright (c) 2026 the pdftexja project
%%  SPDX-License-Identifier: BSD-3-Clause (original) AND BSD-2-Clause (pdftexja additions)
%%  -----------------------------------------
%%
%% File: pdfjltxdoc.dtx

\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{pdfjltxdoc}[2021-10-24 v1.0d-ltj-4 Standard LuaLaTeX-ja file]
\DeclareOption*{\PassOptionsToClass{\CurrentOption}{ltxdoc}}
\ProcessOptions
\LoadClass{ltxdoc}
\input{pdftexja-class.def}
\input{pdftexja-class-crop.def}
\pdfjclass@classsetup{0.962216}{pdftexja-jfm-ujis}{yoko}{false}{}
\pdfjclass@postload{0pt plus .4pt minus .5pt}{2.40554pt plus 1pt minus 1pt}
\pdfjclass@crop@apply
\def\Cjascale{0.962216}
\renewcommand{\normalsize}{%
    \@setfontsize\normalsize\@xpt{15}%
  \abovedisplayskip 10\p@ \@plus2\p@ \@minus5\p@
  \abovedisplayshortskip \z@ \@plus3\p@
  \belowdisplayshortskip 6\p@ \@plus3\p@ \@minus3\p@
   \belowdisplayskip \abovedisplayskip
   \let\@listi\@listI}
\renewcommand{\small}{%
  \@setfontsize\small\@ixpt{11}%
  \abovedisplayskip 8.5\p@ \@plus3\p@ \@minus4\p@
  \abovedisplayshortskip \z@ \@plus2\p@
  \belowdisplayshortskip 4\p@ \@plus2\p@ \@minus2\p@
  \def\@listi{\leftmargin\leftmargini
              \topsep 4\p@ \@plus2\p@ \@minus2\p@
              \parsep 2\p@ \@plus\p@ \@minus\p@
              \itemsep \parsep}%
  \belowdisplayskip \abovedisplayskip}
\normalsize
\pdfjclass@snapshot{yoko}
\setlength\parindent{1\zw}
\providecommand*{\file}[1]{\texttt{#1}}
\providecommand*{\pstyle}[1]{\textsl{#1}}
\providecommand*{\Lcount}[1]{\textsl{\small#1}}
\providecommand*{\Lopt}[1]{\textsf{#1}}
\providecommand\dst{{\normalfont\scshape docstrip}}
\providecommand\NFSS{\textsf{NFSS}}
\newcounter{@clineno}
\def\mlineplus#1{\setcounter{@clineno}{\arabic{CodelineNo}}%
   \addtocounter{@clineno}{#1}\arabic{@clineno}}
\def\tsample#1{%
  \hbox to\linewidth\bgroup\vrule width.1pt\hss
    \vbox\bgroup\hrule height.1pt
      \vskip.5\baselineskip
      \pdftexjavbox{tate}{#1}{\linewidth}}
\def\endtsample{%
        \endpdftexjavbox
      \vskip.5\baselineskip
    \hrule height.1pt\egroup
  \hss\vrule width.1pt\egroup}
\def\verb{\relax\ifmmode\hbox\else\leavevmode\vadjust{}\fi
  \bgroup \let\do\do@noligs \verbatim@nolig@list
    \ttfamily \verb@eol@error \let\do\@makeother \dospecials
    \@ifstar{\@sverb}{\@vobeyspaces \frenchspacing \@sverb}}
\pdfjclass@charspacing{005C}{both} %% \
\pdfjclass@charspacing{0022}{both} %% "
\def\mod@math@codes{\mathcode`\|="207C \mathcode`\&="2026
                    \mathcode`\-="702D \mathcode`\+="702B
                    \mathcode`\:="703A \mathcode`\=="703D }
\endinput
%%
%% End of file `pdfjltxdoc.cls'.

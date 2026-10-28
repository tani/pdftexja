%%
%% This is file `pdfjtarticle.cls',
%% generated with the docstrip utility.
%%
%% The original source files were:
%%
%% pdfjclasses.dtx  (with options: `article,tate')
%% 
%% IMPORTANT NOTICE:
%% 
%% For the copyright see the source file.
%% 
%% Any modified versions of this file must be renamed
%% with new filenames distinct from pdfjtarticle.cls.
%% 
%% For distribution of the original source see the terms
%% for copying and modification in the file pdfjclasses.dtx.
%% 
%% This generated file may be distributed as long as the
%% original source files, as listed above, are part of the
%% same distribution. (The sources need not necessarily be
%% in the same archive or directory.)
%%
%% File: pdfjclasses.dtx
%%  -----------------------------------------
%%  This file is part of pdftexja, a pdfLaTeX direct-PDF Japanese
%%  typesetting foundation.  It is a port of the LuaTeX-ja source
%%  ltjclasses.dtx (LuaTeX-ja 20260130.1) to the pdftexja public API:
%%  the LuaTeX-ja/pTeX font, direction, glue and position primitives are
%%  replaced by pdftexja operations.  The original notices and licence
%%  conditions below are retained unchanged; they are not weakened or
%%  replaced.
%%
%%  Copyright (c) 2026 the pdftexja project
%%  SPDX-License-Identifier: BSD-3-Clause (original) AND BSD-2-Clause (pdftexja additions)
%%  -----------------------------------------
%%
%% File: pdfjclasses.dtx
\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{pdfjtarticle}
  [2025-03-28 v1.8f-ltj-25
 Standard LuaLaTeX-ja class]
\input{pdftexja-class.def}
\input{pdftexja-class-crop.def}
\newif\ifpdfj@tate
\pdfj@tatetrue
\newif\ifpdfj@disablejfam \pdfj@disablejfamfalse
\def\Cjascale{0.962216}
\newcounter{@paper}
\newif\if@landscape \@landscapefalse
\newcommand{\@ptsize}{}
\newif\if@restonecol
\newif\if@titlepage
\@titlepagefalse
\hour\time \divide\hour by 60\relax
\@tempcnta\hour \multiply\@tempcnta 60\relax
\minute\time \advance\minute-\@tempcnta
\newif\if@stysize \@stysizefalse
\newif\if@mathrmmc \@mathrmmcfalse
\DeclareOption{a4paper}{\setcounter{@paper}{1}%
  \setlength\paperheight {297mm}%
  \setlength\paperwidth  {210mm}}
\DeclareOption{a5paper}{\setcounter{@paper}{2}%
  \setlength\paperheight {210mm}
  \setlength\paperwidth  {148mm}}
\DeclareOption{b4paper}{\setcounter{@paper}{3}%
  \setlength\paperheight {364mm}
  \setlength\paperwidth  {257mm}}
\DeclareOption{b5paper}{\setcounter{@paper}{4}%
  \setlength\paperheight {257mm}
  \setlength\paperwidth  {182mm}}
\DeclareOption{a4j}{\setcounter{@paper}{1}\@stysizetrue
  \setlength\paperheight {297mm}%
  \setlength\paperwidth  {210mm}}
\DeclareOption{a5j}{\setcounter{@paper}{2}\@stysizetrue
  \setlength\paperheight {210mm}
  \setlength\paperwidth  {148mm}}
\DeclareOption{b4j}{\setcounter{@paper}{3}\@stysizetrue
  \setlength\paperheight {364mm}
  \setlength\paperwidth  {257mm}}
\DeclareOption{b5j}{\setcounter{@paper}{4}\@stysizetrue
  \setlength\paperheight {257mm}
  \setlength\paperwidth  {182mm}}
\DeclareOption{a4p}{\setcounter{@paper}{1}\@stysizetrue
  \setlength\paperheight {297mm}%
  \setlength\paperwidth  {210mm}}
\DeclareOption{a5p}{\setcounter{@paper}{2}\@stysizetrue
  \setlength\paperheight {210mm}
  \setlength\paperwidth  {148mm}}
\DeclareOption{b4p}{\setcounter{@paper}{3}\@stysizetrue
  \setlength\paperheight {364mm}
  \setlength\paperwidth  {257mm}}
\DeclareOption{b5p}{\setcounter{@paper}{4}\@stysizetrue
  \setlength\paperheight {257mm}
  \setlength\paperwidth  {182mm}}
\if@compatibility
  \renewcommand{\@ptsize}{0}
\else
  \DeclareOption{10pt}{\renewcommand{\@ptsize}{0}}
\fi
\DeclareOption{11pt}{\renewcommand{\@ptsize}{1}}
\DeclareOption{12pt}{\renewcommand{\@ptsize}{2}}
\DeclareOption{landscape}{\@landscapetrue
  \setlength\@tempdima{\paperheight}%
  \setlength\paperheight{\paperwidth}%
  \setlength\paperwidth{\@tempdima}}
\DeclareOption{tombow}{%
  \tombowtrue \tombowdatetrue
  \setlength{\@tombowwidth}{.1\p@}%
  \@bannertoken{%
     \jobname\space(\number\year-\two@digits\month-\two@digits\day
     \space\two@digits\hour:\two@digits\minute)}%
  \maketombowbox}
\DeclareOption{tombo}{%
  \tombowtrue \tombowdatefalse
  \setlength{\@tombowwidth}{.1\p@}%
  \maketombowbox}
\DeclareOption{mentuke}{%
  \tombowtrue \tombowdatefalse
  \setlength{\@tombowwidth}{\z@}%
  \maketombowbox}
\DeclareOption{tate}{%
  \pdfj@tatetrue
  % ^^e5^^85^^83^^e3^^81^^ae \message{^^e3^^80^^8a^^e7^^b8^^a6^^e7^^b5^^84^^e3^^83^^a2^^e3^^83^^bc^^e3^^83^^89^^e3^^80^^8b} ^^e3^^81^^af UTF-8 ^^e5^^ae^^9f^^e6^^96^^87^^e5^^ad^^97^^e3^^82^^92 \message ^^e3^^81^^ae^^e5^^b1^^95^^e9^^96^^8b^^e3^^81^^ab
  % ^^e9^^80^^9a^^e3^^81^^99^^e3^^81^^9f^^e3^^82^^81 8-bit ^^e3^^82^^a8^^e3^^83^^b3^^e3^^82^^b8^^e3^^83^^b3^^e3^^81^^a7^^e3^^81^^af decoder ^^e3^^82^^92^^e5^^ae^^9f^^e8^^a1^^8c^^e3^^81^^97^^e3^^81^^a6^^e3^^81^^97^^e3^^81^^be^^e3^^81^^86^^e3^^80^^82ASCII ^^e3^^81^^ae
  % ^^e8^^a8^^ba^^e6^^96^^ad^^e3^^83^^a1^^e3^^83^^83^^e3^^82^^bb^^e3^^83^^bc^^e3^^82^^b8^^e3^^81^^ab^^e7^^bd^^ae^^e3^^81^^8d^^e6^^8f^^9b^^e3^^81^^88^^e3^^82^^8b^^e3^^80^^82
  \AtBeginDocument{\message{pdftexja: tate mode}}%
}
\DeclareOption{oneside}{\@twosidefalse}
\DeclareOption{twoside}{\@twosidetrue}
\DeclareOption{onecolumn}{\@twocolumnfalse}
\DeclareOption{twocolumn}{\@twocolumntrue}
\DeclareOption{titlepage}{\@titlepagetrue}
\DeclareOption{notitlepage}{\@titlepagefalse}
\DeclareOption{leqno}{\input{leqno.clo}}
\DeclareOption{fleqn}{\input{fleqn.clo}}
\DeclareOption{openbib}{%
  \AtEndOfPackage{%
   \renewcommand\@openbib@code{%
      \advance\leftmargin\bibindent
      \itemindent -\bibindent
      \listparindent \itemindent
      \parsep \z@
      }%
   \renewcommand\newblock{\par}}}
\if@compatibility
  \@mathrmmctrue
\else
  \DeclareOption{mathrmmc}{\@mathrmmctrue}
\fi
\DeclareOption{draft}{\setlength\overfullrule{5pt}}
\DeclareOption{final}{\setlength\overfullrule{0pt}}
\newif\ifptexmin
\DeclareOption{ptexmin}{\ptexmintrue}%
\DeclareOption{disablejfam}{\pdfj@disablejfamtrue}
\ExecuteOptions{a4paper,10pt,oneside,onecolumn,final,tate}
\DeclareOption*{\pdfjclass@classoption{\CurrentOption}}
\ProcessOptions\relax
\ifptexmin
  \def\pdfj@jfm{pdftexja-jfm-ptexmin}%
\else
  \def\pdfj@jfm{pdftexja-jfm-ujis}%
\fi
\ifpdfj@disablejfam
  \pdfjclass@addextra{math=false}%
  \pdfjclass@addextra{math-capture=false}%
\fi
\pdfjclass@classsetup{0.962216}{\pdfj@jfm}%
  {\ifpdfj@tate tate\else yoko\fi}{false}{}
\input{pdfjtsize1\@ptsize.clo}
\pdfjclass@postload{0pt plus .4pt minus .5pt}%
  {2.40554pt plus 1pt minus 1pt}
\def\Cjascale{0.962216}
\if@stysize
  \setlength\columnsep{3\Cwd}
\else
  \setlength\columnsep{10\p@}
\fi
\setlength\columnseprule{0\p@}
\pdfjclass@crop@apply
\setlength\lineskip{1\p@}
\setlength\normallineskip{1\p@}
\renewcommand{\baselinestretch}{}
\setlength\parskip{0\p@ \@plus \p@}
\setlength\parindent{1\Cwd}
\@lowpenalty   51
\@medpenalty  151
\@highpenalty 301
\setcounter{topnumber}{2}
\setcounter{bottomnumber}{1}
\setcounter{totalnumber}{3}
\setcounter{dbltopnumber}{2}
\renewcommand{\topfraction}{.7}
\renewcommand{\bottomfraction}{.3}
\renewcommand{\textfraction}{.2}
\renewcommand{\floatpagefraction}{.5}
\renewcommand{\dbltopfraction}{.7}
\renewcommand{\dblfloatpagefraction}{.5}
\def\pltx@cleartorightpage{\clearpage\if@twoside
  \pdftexjaIfDirectionTF{tate}{\@tempcnta\@ne}{\@tempcnta\z@}%
  \unless\ifodd\numexpr\c@page+\@tempcnta\relax
    \hbox{}\thispagestyle{empty}\newpage
    \if@twocolumn\hbox{}\newpage\fi
  \fi\fi}
\def\pltx@cleartoleftpage{\clearpage\if@twoside
  \pdftexjaIfDirectionTF{tate}{\@tempcnta\@ne}{\@tempcnta\z@}%
  \ifodd\numexpr\c@page+\@tempcnta\relax
    \hbox{}\thispagestyle{empty}\newpage
    \if@twocolumn\hbox{}\newpage\fi
  \fi\fi}
\def\pltx@cleartooddpage{\clearpage\if@twoside
  \ifodd\c@page\else
    \hbox{}\thispagestyle{empty}\newpage
    \if@twocolumn\hbox{}\newpage\fi
  \fi\fi}
\def\pltx@cleartoevenpage{\clearpage\if@twoside
  \ifodd\c@page
    \hbox{}\thispagestyle{empty}\newpage
    \if@twocolumn\hbox{}\newpage\fi
  \fi\fi}
\def\ps@plain{\let\@mkboth\@gobbletwo
   \let\ps@jpl@in\ps@plain
   \let\@oddhead\@empty
   \def\@oddfoot{\reset@font\hfil\thepage\hfil}%
   \let\@evenhead\@empty
   \let\@evenfoot\@oddfoot}
\let\ps@jpl@in\ps@plain
\def\ps@headnombre{\let\@mkboth\@gobbletwo
    \let\ps@jpl@in\ps@headnombre
  \def\@evenhead{\hfil\thepage}%
  \def\@oddhead{\thepage\hfil}%
  \let\@oddfoot\@empty\let\@evenfoot\@empty}
\def\ps@footnombre{\let\@mkboth\@gobbletwo
    \let\ps@jpl@in\ps@footnombre
  \def\@evenfoot{\hfil\thepage}%
  \def\@oddfoot{\thepage\hfil}%
  \let\@oddhead\@empty\let\@evenhead\@empty}
\if@twoside
  \def\ps@headings{\let\ps@jpl@in\ps@headnombre
    \let\@oddfoot\@empty\let\@evenfoot\@empty
    \def\@evenhead{{\leftmark}\hfil\thepage}%
    \def\@oddhead{\thepage\hfil\rightmark}%
    \let\@mkboth\markboth
    \def\sectionmark##1{\markboth{%
       \ifnum \c@secnumdepth >\z@ \thesection.\hskip1\zw\fi
       ##1}{}}%
    \def\subsectionmark##1{\markright{%
       \ifnum \c@secnumdepth >\@ne \thesubsection.\hskip1\zw\fi
       ##1}}%
  }
\else % if not twoside
  \def\ps@headings{\let\ps@jpl@in\ps@headnombre
    \let\@oddfoot\@empty
    \def\@oddhead{\thepage\hfil\rightmark}%
    \let\@mkboth\markboth
  \def\sectionmark##1{\markright{%
     \ifnum \c@secnumdepth >\m@ne \thesection.\hskip1\zw\fi
     ##1}}%
  }
\fi
\if@twoside
  \def\ps@bothstyle{\let\ps@jpl@in\ps@footnombre
    \def\@evenhead{\hfil\leftmark}% right page
    \def\@evenfoot{\hfil\thepage}% right page
    \def\@oddhead{\rightmark\hfil}% left page
    \def\@oddfoot{\thepage\hfil}% left page
  \let\@mkboth\markboth
  \def\sectionmark##1{\markboth{%
     \ifnum \c@secnumdepth >\z@ \thesection.\hskip1\zw\fi
     ##1}{}}%
  \def\subsectionmark##1{\markright{%
     \ifnum \c@secnumdepth >\@ne \thesubsection.\hskip1\zw\fi
     ##1}}%
  }
\else % if one column
  \def\ps@bothstyle{\let\ps@jpl@in\ps@footnombre
    \def\@oddhead{\rightmark\hfil}%
    \def\@oddfoot{\thepage\hfil}%
    \let\@mkboth\markboth
  \def\sectionmark##1{\markright{%
     \ifnum \c@secnumdepth >\m@ne \thesection.\hskip1\zw\fi
     ##1}}%
  }
\fi
\def\ps@myheadings{\let\ps@jpl@in\ps@plain%
  \let\@oddfoot\@empty\let\@evenfoot\@empty
  \def\@evenhead{{\leftmark}\hfil\thepage}%
  \def\@oddhead{\thepage\hfil\rightmark}%
  \let\@mkboth\@gobbletwo
  \let\sectionmark\@gobble
  \let\subsectionmark\@gobble
}
\if@compatibility
\newenvironment{titlepage}
    {%
     \if@twocolumn\@restonecoltrue\onecolumn
     \else\@restonecolfalse\newpage\fi
     \thispagestyle{empty}%
     \setcounter{page}\z@
    }%
    {\if@restonecol\twocolumn\else\newpage\fi
    }
\else
\newenvironment{titlepage}
    {%
      \if@twocolumn
        \@restonecoltrue\onecolumn
      \else
        \@restonecolfalse\newpage
      \fi
      \thispagestyle{empty}%
      \ifodd\c@page\setcounter{page}\@ne\else\setcounter{page}\z@\fi %% 2017/02/15
    }%
    {\if@restonecol\twocolumn \else \newpage \fi
     \if@twoside\else
        \setcounter{page}\@ne
     \fi
    }
\fi
\def\p@thanks#1{\footnotemark
  \protected@xdef\@thanks{\@thanks
    \protect{\noindent\hbox{\protect\pdftexjaBox{yoko}{$\m@th^\thefootnote$}}#1\protect\par}}}
\if@titlepage
  \newcommand{\maketitle}{\begin{titlepage}%
  \let\footnotesize\small
  \let\footnoterule\relax
  \let\thanks\p@thanks
  \let\footnote\thanks
  \vbox to\textheight\bgroup\tate\hsize\textwidth
  \null\vfil
  \vskip 60\p@
  \begin{center}%
    {\LARGE \@title \par}%
    \vskip 3em%
    {\Large
     \lineskip .75em%
      \begin{tabular}[t]{c}%
        \@author
      \end{tabular}\par}%
      \vskip 1.5em%
    {\large \@date \par}%       % Set date in \large size.
  \end{center}\par
  \vfil{\centering\@thanks}\vfil\null
  \egroup
  \end{titlepage}%
  \setcounter{footnote}{0}%
  \global\let\thanks\relax
  \global\let\maketitle\relax
  \global\let\p@thanks\relax
  \global\let\@thanks\@empty
  \global\let\@author\@empty
  \global\let\@date\@empty
  \global\let\@title\@empty
  \global\let\title\relax
  \global\let\author\relax
  \global\let\date\relax
  \global\let\and\relax
  }%
\else
  \newcommand{\maketitle}{\par
  \begingroup
    \renewcommand{\thefootnote}{\fnsymbol{footnote}}%
    \def\@makefnmark{\hbox{%
      \pdftexjaIfDirectionTF{tate}%
        {\pdftexjaBox{yoko}{$\m@th^{\@thefnmark}$}}%
        {$\m@th^{\@thefnmark}$}}}%
    \long\def\@makefntext##1{\parindent 1\zw\noindent
       \hb@xt@ 2\zw{\hss\@makefnmark}##1}%
    \if@twocolumn
      \ifnum \col@number=\@ne \@maketitle
      \else \twocolumn[\@maketitle]%
      \fi
    \else
      \newpage
      \global\@topnum\z@   % Prevents figures from going at top of page.
      \@maketitle
    \fi
     \thispagestyle{jpl@in}\@thanks
  \endgroup
  \setcounter{footnote}{0}%
  \global\let\thanks\relax
  \global\let\maketitle\relax
  \global\let\@maketitle\relax
  \global\let\p@thanks\relax
  \global\let\@thanks\@empty
  \global\let\@author\@empty
  \global\let\@date\@empty
  \global\let\@title\@empty
  \global\let\title\relax
  \global\let\author\relax
  \global\let\date\relax
  \global\let\and\relax
  }
  \def\@maketitle{%
  \newpage\null
  \vskip 2em%
  \begin{center}%
  \let\footnote\p@thanks
    {\LARGE \@title \par}%
    \vskip 1.5em%
    {\large
      \lineskip .5em%
      \begin{tabular}[t]{c}%
        \@author
      \end{tabular}\par}%
    \vskip 1em%
    {\large \@date}%
  \end{center}%
  \par\vskip 1.5em}
\fi
\if@titlepage
  \newenvironment{abstract}{%
      \titlepage
      \null\vfil
      \@beginparpenalty\@lowpenalty
      \begin{center}%
        {\bfseries\abstractname}%
        \@endparpenalty\@M
      \end{center}}%
      {\par\vfil\null\endtitlepage}
\else
  \newenvironment{abstract}{%
    \if@twocolumn
      \section*{\abstractname}%
    \else
      \small
      \begin{center}%
        {\bfseries\abstractname\vspace{-.5em}\vspace{\z@}}%
      \end{center}%
      \quotation
    \fi}{\if@twocolumn\else\endquotation\fi}
\fi
\setcounter{secnumdepth}{3}
\newcounter{part}
\newcounter{section}
\newcounter{subsection}[section]
\newcounter{subsubsection}[subsection]
\newcounter{paragraph}[subsubsection]
\newcounter{subparagraph}[paragraph]
\renewcommand{\thepart}{\rensuji{\@Roman\c@part}}
\renewcommand{\thesection}{\rensuji{\@arabic\c@section}}
\renewcommand{\thesubsection}{\thesection^^e3^^83^^bb\rensuji{\@arabic\c@subsection}}
\renewcommand{\thesubsubsection}{%
   \thesubsection^^e3^^83^^bb\rensuji{\@arabic\c@subsubsection}}
\renewcommand{\theparagraph}{%
   \thesubsubsection^^e3^^83^^bb\rensuji{\@arabic\c@paragraph}}
\renewcommand{\thesubparagraph}{%
   \theparagraph^^e3^^83^^bb\rensuji{\@arabic\c@subparagraph}}
\newcommand{\part}{%
  \if@noskipsec \leavevmode \fi
  \par\addvspace{4ex}%
  \@afterindenttrue
  \secdef\@part\@spart}
\def\@part[#1]#2{%
  \ifnum \c@secnumdepth >\m@ne
    \refstepcounter{part}%
    \addcontentsline{toc}{part}{%
       \prepartname\thepart\postpartname\hspace{1\zw}#1}%
  \else
    \addcontentsline{toc}{part}{#1}%
  \fi
  \markboth{}{}%
  {\parindent\z@\raggedright
   \interlinepenalty\@M\normalfont
   \ifnum \c@secnumdepth >\m@ne
     \Large\bfseries\prepartname\thepart\postpartname
     \par\nobreak
   \fi
   \huge\bfseries#2\par}%
  \nobreak\vskip3ex\@afterheading}
\def\@spart#1{{%
  \parindent\z@\raggedright
  \interlinepenalty\@M\normalfont
  \huge\bfseries#1\par}%
  \nobreak\vskip3ex\@afterheading}
\newcommand{\section}{\@startsection{section}{1}{\z@}%
   {1.5\Cvs \@plus.5\Cvs \@minus.2\Cvs}%
   {.5\Cvs \@plus.3\Cvs}%
   {\normalfont\Large\bfseries}}
\newcommand{\subsection}{\@startsection{subsection}{2}{\z@}%
   {1.5\Cvs \@plus.5\Cvs \@minus.2\Cvs}%
   {.5\Cvs \@plus.3\Cvs}%
   {\normalfont\large\bfseries}}
\newcommand{\subsubsection}{\@startsection{subsubsection}{3}{\z@}%
   {1.5\Cvs \@plus.5\Cvs \@minus.2\Cvs}%
   {.5\Cvs \@plus.3\Cvs}%
   {\normalfont\normalsize\bfseries}}
\newcommand{\paragraph}{\@startsection{paragraph}{4}{\z@}%
   {3.25ex \@plus 1ex \@minus .2ex}%
   {-1em}%
   {\normalfont\normalsize\bfseries}}
\newcommand{\subparagraph}{\@startsection{subparagraph}{5}{\z@}%
   {3.25ex \@plus 1ex \@minus .2ex}%
   {-1em}%
   {\normalfont\normalsize\bfseries}}
\newcommand{\appendix}{\par
  \setcounter{section}{0}%
  \setcounter{subsection}{0}%
  \renewcommand{\thesection}{\rensuji{\@Alph\c@section}}}
\if@twocolumn
  \setlength\leftmargini {2em}
\else
  \setlength\leftmargini {2.5em}
\fi
\setlength\leftmarginii  {2.2em}
\setlength\leftmarginiii {1.87em}
\setlength\leftmarginiv  {1.7em}
\if@twocolumn
  \setlength\leftmarginv {.5em}
  \setlength\leftmarginvi{.5em}
\else
  \setlength\leftmarginv {1em}
  \setlength\leftmarginvi{1em}
\fi
\setlength  \labelsep  {.5em}
\setlength  \labelwidth{\leftmargini}
\addtolength\labelwidth{-\labelsep}
\@beginparpenalty -\@lowpenalty
\@endparpenalty   -\@lowpenalty
\@itempenalty     -\@lowpenalty
\renewcommand{\theenumi}{\rensuji{\@arabic\c@enumi}}
\renewcommand{\theenumii}{\rensuji{(\@alph\c@enumii)}}
\renewcommand{\theenumiii}{\rensuji{\@roman\c@enumiii}}
\renewcommand{\theenumiv}{\rensuji{\@Alph\c@enumiv}}
\newcommand{\labelenumi}{\theenumi}
\newcommand{\labelenumii}{\theenumii}
\newcommand{\labelenumiii}{\theenumiii}
\newcommand{\labelenumiv}{\theenumiv}
\renewcommand{\p@enumii}{\theenumi}
\renewcommand{\p@enumiii}{\theenumi(\theenumii)}
\renewcommand{\p@enumiv}{\p@enumiii\theenumiii}
\renewenvironment{enumerate}
  {\ifnum \@enumdepth >\thr@@\@toodeep\else
   \advance\@enumdepth\@ne
   \edef\@enumctr{enum\romannumeral\the\@enumdepth}%
   \expandafter \list \csname label\@enumctr\endcsname{%
      \pdftexjaIfDirectionTF{tate}{%
         \ifnum \@listdepth=\@ne \topsep.5\normalbaselineskip
           \else\topsep\z@\fi
         \parskip\z@ \itemsep\z@ \parsep\z@
         \labelwidth1\zw \labelsep.3\zw
         \ifnum \@enumdepth=\@ne \leftmargin1\zw\relax
           \else\leftmargin\leftskip\fi
         \advance\leftmargin 1\zw
      }{}%
         \usecounter{\@enumctr}%
         \def\makelabel##1{\hss\llap{##1}}}%
   \fi}{\endlist}
\newcommand{\labelitemi}{\labelitemfont \textbullet}
\newcommand{\labelitemii}{%
  \pdftexjaIfDirectionTF{tate}%
     {\labelitemfont \textcircled{~}}%
     {\labelitemfont \bfseries\textendash}%
}
\newcommand{\labelitemiii}{\labelitemfont \textasteriskcentered}
\newcommand{\labelitemiv}{\labelitemfont \textperiodcentered}
\newcommand\labelitemfont{\normalfont}
\renewenvironment{itemize}
  {\ifnum \@itemdepth >\thr@@\@toodeep\else
   \advance\@itemdepth\@ne
   \edef\@itemitem{labelitem\romannumeral\the\@itemdepth}%
   \expandafter \list \csname \@itemitem\endcsname{%
      \pdftexjaIfDirectionTF{tate}{%
         \ifnum \@listdepth=\@ne \topsep.5\normalbaselineskip
           \else\topsep\z@\fi
         \parskip\z@ \itemsep\z@ \parsep\z@
         \labelwidth1\zw \labelsep.3\zw
         \ifnum \@itemdepth =\@ne \leftmargin1\zw\relax
           \else\leftmargin\leftskip\fi
         \advance\leftmargin 1\zw
      }{}%
         \def\makelabel##1{\hss\llap{##1}}}%
   \fi}{\endlist}
\newenvironment{description}
  {\list{}{\labelwidth\z@ \itemindent-\leftmargin
   \pdftexjaIfDirectionTF{tate}{%
     \leftmargin\leftskip \advance\leftmargin3\Cwd
     \rightmargin\rightskip
     \labelsep=1\zw \itemsep\z@
     \listparindent\z@ \topskip\z@ \parskip\z@ \partopsep\z@
   }{}%
           \let\makelabel\descriptionlabel}}{\endlist}
\newcommand{\descriptionlabel}[1]{%
   \hspace\labelsep\normalfont\bfseries #1}
\newenvironment{verse}
  {\let\\\@centercr
   \list{}{\itemsep\z@ \itemindent -1.5em%
           \listparindent\itemindent
           \rightmargin\leftmargin \advance\leftmargin 1.5em}%
           \item\relax}{\endlist}
\newenvironment{quotation}
  {\list{}{\listparindent 1.5em%
           \itemindent\listparindent
           \rightmargin\leftmargin
           \parsep\z@ \@plus\p@}%
           \item\relax}{\endlist}
\newenvironment{quote}
  {\list{}{\rightmargin\leftmargin}%
           \item\relax}{\endlist}
\newcounter{figure}
\renewcommand{\thefigure}{\rensuji{\@arabic\c@figure}}
\def\fps@figure{tbp}
\def\ftype@figure{1}
\def\ext@figure{lof}
\def\fnum@figure{\figurename\thefigure}
\newenvironment{figure}
               {\@float{figure}}
               {\end@float}
\newenvironment{figure*}
               {\@dblfloat{figure}}
               {\end@dblfloat}
\newcounter{table}
\renewcommand{\thetable}{\rensuji{\@arabic\c@table}}
\def\fps@table{tbp}
\def\ftype@table{2}
\def\ext@table{lot}
\def\fnum@table{\tablename\thetable}
\newenvironment{table}
               {\@float{table}}
               {\end@float}
\newenvironment{table*}
               {\@dblfloat{table}}
               {\end@dblfloat}
\newlength\abovecaptionskip
\newlength\belowcaptionskip
\setlength\abovecaptionskip{10\p@}
\setlength\belowcaptionskip{0\p@}
\long\def\@makecaption#1#2{%
  \vskip\abovecaptionskip
  \pdftexjaIfDirectionTF{tate}{%
    \sbox\@tempboxa{#1\hskip1\zw#2}%
  }{%
    \sbox\@tempboxa{#1: #2}%
  }%
  \ifdim \wd\@tempboxa >\hsize
    \pdftexjaIfDirectionTF{tate}{%
      #1\hskip1\zw#2\relax\par
    }{%
      #1: #2\relax\par
    }%
  \else
    \global \@minipagefalse
    \hb@xt@\hsize{\hfil\box\@tempboxa\hfil}%
  \fi
  \vskip\belowcaptionskip}
\setlength\arraycolsep{5\p@}
\setlength\tabcolsep{6\p@}
\setlength\arrayrulewidth{.4\p@}
\setlength\doublerulesep{2\p@}
\setlength\tabbingsep{\labelsep}
\skip\@mpfootins = \skip\footins
\setlength\fboxsep{3\p@}
\setlength\fboxrule{.4\p@}
\renewcommand{\theequation}{\@arabic\c@equation}
\unless\ifpdfj@disablejfam
\if@mathrmmc
  \pdftexjaDeclareJapaneseMathAlphabet{\mathrm}{mc}%
  \pdftexjaDeclareJapaneseMathAlphabet{\mathbf}{gt}%
\fi
\fi
\DeclareOldFontCommand{\mc}{\normalfont\mcfamily}{\mathmc}
\DeclareOldFontCommand{\gt}{\normalfont\gtfamily}{\mathgt}
\DeclareOldFontCommand{\rm}{\normalfont\rmfamily}{\mathrm}
\DeclareOldFontCommand{\sf}{\normalfont\sffamily}{\mathsf}
\DeclareOldFontCommand{\tt}{\normalfont\ttfamily}{\mathtt}
\DeclareOldFontCommand{\bf}{\normalfont\bfseries}{\mathbf}
\DeclareOldFontCommand{\it}{\normalfont\itshape}{\mathit}
\DeclareOldFontCommand{\sl}{\normalfont\slshape}{\@nomath\sl}
\DeclareOldFontCommand{\sc}{\normalfont\scshape}{\@nomath\sc}
\DeclareRobustCommand*{\cal}{\@fontswitch\relax\mathcal}
\DeclareRobustCommand*{\mit}{\@fontswitch\relax\mathnormal}
\setcounter{tocdepth}{3}
\newcommand{\@pnumwidth}{1.55em}
\newcommand{\@tocrmarg}{2.55em}
\newcommand{\@dotsep}{4.5}
\newdimen\toclineskip
\setlength\toclineskip{2\p@}
\newdimen\@lnumwidth
\def\numberline#1{\hb@xt@\@lnumwidth{#1\hfil}}
\def\@dottedtocline#1#2#3#4#5{%
  \ifnum #1>\c@tocdepth \else
    \vskip\toclineskip \@plus.2\p@
    {\leftskip #2\relax \rightskip \@tocrmarg \parfillskip -\rightskip
     \parindent #2\relax\@afterindenttrue
     \interlinepenalty\@M
     \leavevmode
     \@lnumwidth #3\relax
     \advance\leftskip \@lnumwidth \null\nobreak\hskip -\leftskip
     {#4}\nobreak
     \leaders\hbox{$\m@th \mkern \@dotsep mu.\mkern \@dotsep mu$}%
     \hfill\nobreak
     \hb@xt@\@pnumwidth{\hss\normalfont \normalcolor\rensuji{#5}}%
     \par}%
  \fi}
\newcommand{\tableofcontents}{%
  \section*{\contentsname
    \@mkboth{\contentsname}{\contentsname}%
  }\@starttoc{toc}%
}
\newcommand*{\l@part}[2]{%
  \ifnum \c@tocdepth >-2\relax
    \addpenalty{\@secpenalty}%
    \addvspace{2.25em \@plus\p@}%
    \begingroup
    \parindent\z@\rightskip\@pnumwidth
    \parfillskip-\@pnumwidth
    {\leavevmode\large\bfseries
     \setlength\@lnumwidth{4\zw}%
     #1\hfil\nobreak
     \hb@xt@\@pnumwidth{\hss\rensuji{#2}}}\par
    \nobreak
    \if@compatibility
    \global\@nobreaktrue
    \everypar{\global\@nobreakfalse\everypar{}}%
    \fi
     \endgroup
  \fi}
\newcommand*{\l@section}[2]{%
  \ifnum \c@tocdepth >\z@
    \addpenalty{\@secpenalty}%
    \addvspace{1.0em \@plus\p@}%
    \begingroup
      \parindent\z@ \rightskip\@pnumwidth \parfillskip-\rightskip
      \leavevmode\bfseries
      \setlength\@lnumwidth{1.5em}%
      \advance\leftskip\@lnumwidth \hskip-\leftskip
      #1\nobreak\hfil\nobreak\hb@xt@\@pnumwidth{\hss\rensuji{#2}}\par
    \endgroup
  \fi}
\newcommand*{\l@subsection}   {\@dottedtocline{2}{1\zw}{4\zw}}
\newcommand*{\l@subsubsection}{\@dottedtocline{3}{2\zw}{6\zw}}
\newcommand*{\l@paragraph}    {\@dottedtocline{4}{3\zw}{8\zw}}
\newcommand*{\l@subparagraph} {\@dottedtocline{5}{4\zw}{9\zw}}
\newcommand{\listoffigures}{%
    \section*{\listfigurename}%
  \@mkboth{\listfigurename}{\listfigurename}%
  \@starttoc{lof}%
}
\newcommand*{\l@figure}{\@dottedtocline{1}{1\zw}{4\zw}}
\newcommand{\listoftables}{%
    \section*{\listtablename}%
  \@mkboth{\listtablename}{\listtablename}%
  \@starttoc{lot}%
}
\let\l@table\l@figure
\newdimen\bibindent
\setlength\bibindent{1.5em}
\newcommand{\newblock}{\hskip .11em\@plus.33em\@minus.07em}
\newenvironment{thebibliography}[1]
{\section*{\refname}\@mkboth{\refname}{\refname}%
   \list{\@biblabel{\@arabic\c@enumiv}}%
        {\settowidth\labelwidth{\@biblabel{#1}}%
         \leftmargin\labelwidth
         \advance\leftmargin\labelsep
         \@openbib@code
         \usecounter{enumiv}%
         \let\p@enumiv\@empty
         \renewcommand\theenumiv{\@arabic\c@enumiv}}%
   \sloppy
   \clubpenalty4000
   \@clubpenalty\clubpenalty
   \widowpenalty4000%
   \sfcode`\.\@m}
  {\def\@noitemerr
    {\@latex@warning{Empty `thebibliography' environment}}%
   \endlist}
\let\@openbib@code\@empty
\newenvironment{theindex}
  {\if@twocolumn\@restonecolfalse\else\@restonecoltrue\fi
   \twocolumn[\section*{\indexname}]%
   \@mkboth{\indexname}{\indexname}%
   \thispagestyle{jpl@in}\parindent\z@
   \parskip\z@ \@plus .3\p@\relax
   \columnseprule\z@ \columnsep 35\p@
   \let\item\@idxitem}
  {\if@restonecol\onecolumn\else\clearpage\fi}
\newcommand{\@idxitem}{\par\hangindent 40\p@}
\newcommand{\subitem}{\@idxitem \hspace*{20\p@}}
\newcommand{\subsubitem}{\@idxitem \hspace*{30\p@}}
\newcommand{\indexspace}{\par \vskip 10\p@ \@plus5\p@ \@minus3\p@\relax}
\renewcommand{\footnoterule}{%
  \kern-3\p@
  \hrule\@width.4\columnwidth
  \kern2.6\p@}
\newcommand\@makefntext[1]{\parindent 1\zw
  \noindent\hb@xt@ 2\zw{\hss\@makefnmark}#1}
\let\pdfj@today@year\pdfjclass@today@year
\newcommand{\prepartname}{^^e7^^ac^^ac}
\newcommand{\postpartname}{^^e9^^83^^a8}
\newcommand{\contentsname}{^^e7^^9b^^ae ^^e6^^ac^^a1}
\newcommand{\listfigurename}{^^e5^^9b^^b3 ^^e7^^9b^^ae ^^e6^^ac^^a1}
\newcommand{\listtablename}{^^e8^^a1^^a8 ^^e7^^9b^^ae ^^e6^^ac^^a1}
\newcommand{\refname}{^^e5^^8f^^82^^e8^^80^^83^^e6^^96^^87^^e7^^8c^^ae}
\newcommand{\indexname}{^^e7^^b4^^a2 ^^e5^^bc^^95}
\newcommand{\figurename}{^^e5^^9b^^b3}
\newcommand{\tablename}{^^e8^^a1^^a8}
\newcommand{\appendixname}{^^e4^^bb^^98 ^^e9^^8c^^b2}
\newcommand{\abstractname}{^^e6^^a6^^82 ^^e8^^a6^^81}
\pagestyle{plain}
\pagenumbering{arabic}
\raggedbottom
\@ifl@t@r\fmtversion{2025-06-01}{%
  \AssignSocketPlug{build/column/outputbox}{pdftexja-floats-footnotes}
}{%
  \fnfixbottomtrue % 2017-02-19
  \IfFileExists{stfloats.sty}{\RequirePackage{stfloats}\fnbelowfloat}{}
}
\if@twocolumn
  \twocolumn
  \sloppy
\else
  \onecolumn
\fi
\normalmarginpar
\@mparswitchfalse
\AddToHook{package/ftnright/before}{\let\pdfj@orig@@makefntext=\@makefntext}
\AddToHook{package/ftnright/after}{\let\@makefntext=\pdfj@orig@@makefntext}
\endinput
%%
%% End of file `pdfjtarticle.cls'.

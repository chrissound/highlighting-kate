{- |
   Module      : Text.Highlighting.Kate.Format
   Copyright   : Copyright (C) 2008 John MacFarlane
   License     : GNU GPL, version 2 or above

   Maintainer  : John MacFarlane <jgm@berkeley.edu>
   Stability   : alpha
   Portability : portable

Formatters that convert a list of annotated source lines to various output formats.
-}

module Text.Highlighting.Kate.Format ( formatAsHtml, formatAsLaTeX, FormatOption (..),
                                       highlightingCss, pygments, kate, espresso, tango,
                                       defaultHighlightingCss, defaultLaTeXMacros ) where
import Text.Highlighting.Kate.Definitions
import Text.Blaze
import Text.Printf
import qualified Text.Blaze.Html5 as H
import qualified Text.Blaze.Html5.Attributes as A
import Data.Monoid
import Data.List (intersperse)

-- | Options for formatters.
data FormatOption = OptNumberLines     -- ^ Number lines
                  | OptNumberFrom Int  -- ^ Number of first line
                  | OptLineAnchors     -- ^ Anchors on each line number
                  | OptTitleAttributes -- ^ Include title attributes
                  | OptInline          -- ^ Format as span-level, not block-level element
                  deriving (Eq, Show, Read)


--
-- LaTeX
--

-- | Format a list of highlighted @SourceLine@s as LaTeX.
formatAsLaTeX :: [FormatOption]  -- ^ Options
              -> String          -- ^ Language (not used, but here for parallelism with formatasHtml)
              -> [SourceLine]    -- ^ Source lines to format
              -> String
formatAsLaTeX opts _ lines =
  let startNum = getStartNum opts
      code = unlines $ map sourceLineToLaTeX lines
      commandchars = "commandchars=\\\\\\{\\}"
  in  if OptInline `elem` opts
         then "\\Verb[" ++ commandchars ++ "]{" ++ code ++ "}"
         else "\\begin{Verbatim}[" ++
              (if OptNumberLines `elem` opts
                  then "numbers=left," ++
                       (if startNum == 1
                           then ""
                           else ",firstnumber=" ++ show startNum) ++ ","
                  else ""
              ) ++ commandchars ++ "]\n" ++ code ++ "\\end{Verbatim}"

tokenToLaTeX :: Token -> String
tokenToLaTeX (NormalTok, txt) = escapeLaTeX txt
tokenToLaTeX (toktype, txt)   = '\\':(show toktype ++ "{" ++ escapeLaTeX txt ++ "}")

escapeLaTeX :: String -> String
escapeLaTeX = concatMap escapeLaTeXChar
  where escapeLaTeXChar '\\' = "\\textbackslash{}"
        escapeLaTeXChar '{'  = "\\{"
        escapeLaTeXChar '}'  = "\\}"
        escapeLaTeXChar x    = [x]

sourceLineToLaTeX :: SourceLine -> String
sourceLineToLaTeX contents = concatMap tokenToLaTeX contents


--
-- HTML
--

-- | Format a list of highlighted @SourceLine@s as Html.
formatAsHtml :: [FormatOption]  -- ^ Options
              -> String          -- ^ Language
              -> [SourceLine]    -- ^ Source lines to format
              -> Html
formatAsHtml opts lang lines =
  let startNum = getStartNum opts
      numberOfLines = length lines
      code = H.code ! A.class_ (toValue $ unwords ["sourceCode", lang])
                    $ mconcat $ intersperse (toHtml "\n") $ map (sourceLineToHtml opts) lines
  in  if OptInline `elem` opts
         then code
         else if OptNumberLines `elem` opts
                 then let lnTitle = A.title (toValue "Click to toggle line numbers")
                          lnOnClick = A.onclick $ toValue
                                                $ "with (this.firstChild.style) { display = (display == '') ? 'none' : '' }"
                          nums = H.td ! A.class_ (toValue "lineNumbers") ! lnTitle ! lnOnClick
                                      $ H.pre
                                      $ mapM_ lineNum [startNum..(startNum + numberOfLines - 1)]
                          lineNum n = if OptLineAnchors `elem` opts
                                         then (H.a ! A.id (toValue $ show n) $ toHtml $ show n)
                                               >> toHtml "\n"
                                         else toHtml $ show n ++ "\n"
                          sourceCode = H.td ! A.class_ (toValue "sourceCode")
                                            $ H.pre ! A.class_ (toValue "sourceCode") $ code
                      in  H.table ! A.class_ (toValue "sourceCode") $ H.tr ! A.class_ (toValue "sourceCode") $ nums >> sourceCode
                 else H.pre ! A.class_ (toValue "sourceCode") $ code

tokenToHtml :: [FormatOption] -> Token -> Html
tokenToHtml _ (NormalTok, txt)    = toHtml txt
tokenToHtml opts (toktype, txt)  =
  titleize $ H.span ! A.class_ (toValue $ short toktype) $ toHtml txt
    where titleize x = if OptTitleAttributes `elem` opts
                          then x ! A.title (toValue $ show toktype)
                          else x

short :: TokenType -> String
short KeywordTok        = "kw"
short DataTypeTok       = "dt"
short DecValTok         = "dv"
short BaseNTok          = "bn"
short FloatTok          = "fl"
short CharTok           = "ch"
short StringTok         = "st"
short CommentTok        = "co"
short OtherTok          = "ot"
short AlertTok          = "al"
short FunctionTok       = "fu"
short RegionMarkerTok   = "re"
short ErrorTok          = "er"
short NormalTok         = ""

sourceLineToHtml :: [FormatOption] -> SourceLine -> Html
sourceLineToHtml opts contents = mapM_ (tokenToHtml opts) contents

getStartNum :: [FormatOption] -> Int
getStartNum [] = 1
getStartNum (OptNumberFrom n : _) = n
getStartNum (_:xs) = getStartNum xs


defaultHighlightingCss :: String
defaultHighlightingCss = highlightingCss pygments
-- TODO
--  "table.sourceCode, tr.sourceCode, td.lineNumbers, td.sourceCode, table.sourceCode pre \n\
--  \   { margin: 0; padding: 0; border: 0; vertical-align: baseline; border: none; }\n\
--  \td.lineNumbers { border-right: 1px solid #AAAAAA; text-align: right; color: #AAAAAA; padding-right: 5px; padding-left: 5px; }\n\
--  \td.sourceCode { padding-left: 5px; }\n\

--
-- FORMATS
--

-- | Format loosely based on pygments's default colors
pygments :: Format
pygments = Format{
    backgroundColor = Nothing
  , defaultColor = Nothing
  , tokenFormats =
    [ (KeywordTok, format{ tokenColor = toColor "#007020", tokenBold = True })
    , (DataTypeTok, format{ tokenColor = toColor "#902000" })
    , (DecValTok, format{ tokenColor = toColor "#40a070" })
    , (BaseNTok, format{ tokenColor = toColor "#40a070" })
    , (FloatTok, format{ tokenColor = toColor "#40a070" })
    , (CharTok, format{ tokenColor = toColor "#4070a0" })
    , (StringTok, format{ tokenColor = toColor "#4070a0" })
    , (CommentTok, format{ tokenColor = toColor "#60a0b0", tokenItalic = True })
    , (OtherTok, format{ tokenColor = toColor "#007020" })
    , (AlertTok, format{ tokenColor = toColor "#ff0000", tokenBold = True })
    , (FunctionTok, format{ tokenColor = toColor "#06287e" })
    , (ErrorTok, format{ tokenColor = toColor "#ff0000", tokenBold = True })
    ]
  }

-- | Format loosely based on kate's default colors
kate :: Format
kate = Format{
    backgroundColor = Nothing
  , defaultColor = Nothing
  , tokenFormats =
    [ (KeywordTok, format{ tokenBold = True })
    , (DataTypeTok, format{ tokenColor = toColor "#800000" })
    , (DecValTok, format{ tokenColor = toColor "#0000FF" })
    , (BaseNTok, format{ tokenColor = toColor "#0000FF" })
    , (FloatTok, format{ tokenColor = toColor "#800080" })
    , (CharTok, format{ tokenColor = toColor "#FF00FF" })
    , (StringTok, format{ tokenColor = toColor "#DD0000" })
    , (CommentTok, format{ tokenColor = toColor "#808080", tokenItalic = True })
    , (AlertTok, format{ tokenColor = toColor "#00ff00", tokenBold = True })
    , (FunctionTok, format{ tokenColor = toColor "#000080" })
    , (ErrorTok, format{ tokenColor = toColor "#ff0000", tokenBold = True })
    ]
  }

-- | Format loosely based on pygments's tango colors
tango :: Format
tango = Format{
    backgroundColor = toColor "#f8f8f8"
  , defaultColor = Nothing
  , tokenFormats =
    [ (KeywordTok, format{ tokenColor = toColor "#204a87", tokenBold = True })
    , (DataTypeTok, format{ tokenColor = toColor "#204a87" })
    , (DecValTok, format{ tokenColor = toColor "#0000cf" })
    , (BaseNTok, format{ tokenColor = toColor "#0000cf" })
    , (FloatTok, format{ tokenColor = toColor "#0000cf" })
    , (CharTok, format{ tokenColor = toColor "#4e9a06" })
    , (StringTok, format{ tokenColor = toColor "#4e9a06" })
    , (CommentTok, format{ tokenColor = toColor "#8f5902", tokenItalic = True })
    , (OtherTok, format{ tokenColor = toColor "#8f5902" })
    , (AlertTok, format{ tokenColor = toColor "#ef2929" })
    , (FunctionTok, format{ tokenColor = toColor "#000000" })
    , (ErrorTok, format{ tokenColor = toColor "a40000", tokenBold = True })
    ]
  }

-- | Format loosely based on ultraviolet's espresso_libre.css
espresso :: Format
espresso = Format{
    backgroundColor = toColor "#2A211C"
  , defaultColor = toColor "#BDAE9D"
  , tokenFormats =
    [ (KeywordTok, format{ tokenColor = toColor "#43A8ED", tokenBold = True })
    , (DataTypeTok, format{ tokenUnderline = True })
    , (DecValTok, format{ tokenColor = toColor "#44AA43" })
    , (BaseNTok, format{ tokenColor = toColor "#44AA43" })
    , (FloatTok, format{ tokenColor = toColor "#44AA43" })
    , (CharTok, format{ tokenColor = toColor "#049B0A" })
    , (StringTok, format{ tokenColor = toColor "#049B0A" })
    , (CommentTok, format{ tokenColor = toColor "#0066FF", tokenItalic = True })
    , (AlertTok, format{ tokenColor = toColor "#ffff00" })
    , (FunctionTok, format{ tokenColor = toColor "#FF9358", tokenBold = True })
    , (ErrorTok, format{ tokenColor = toColor "ffff00", tokenBold = True })
    ]
  }

highlightingCss :: Format -> String
highlightingCss f = unlines $ colorspec ++ map toCss (tokenFormats f)
  where colorspec = case (defaultColor f, backgroundColor f) of
                         (Nothing, Nothing) -> []
                         (Just c, Nothing)  -> ["pre > code { color: " ++ fromColor c ++ "; }"]
                         (Nothing, Just c)  -> ["pre > code { background-color: " ++ fromColor c ++ "; }"]
                         (Just c1, Just c2) -> ["pre > code { color: " ++ fromColor c1 ++ "; background-color: " ++
                                                 fromColor c2 ++ "; }"]

toCss :: (TokenType, TokenFormat) -> String
toCss (t,tf) = "code > span." ++ short t ++ " { "
                ++ colorspec ++ backgroundspec ++ weightspec ++ stylespec
                ++ decorationspec ++ "}"
  where colorspec = maybe "" (\col -> "color: " ++ fromColor col ++ "; ") $ tokenColor tf
        backgroundspec = maybe "" (\col -> "background-color: " ++ fromColor col ++ "; ") $ tokenBackground tf
        weightspec = if tokenBold tf then "font-weight: bold; " else ""
        stylespec  = if tokenItalic tf then "font-style: italic; " else ""
        decorationspec = if tokenUnderline tf then "font-decoration: underline; " else ""

-- TODO
highlightingLaTeXMacros :: Format -> String
highlightingLaTeXMacros f = unlines $
  [ "\\usepackage{color}"
  , "\\usepackage{framed}"
  , "\\usepackage{fancyvrb}"
  ] ++
  (case backgroundColor f of
        Nothing          -> []
        Just (RGB r g b) -> [printf "\\definecolor{shadecolor}{RGB}{%d,%d,%d}" r g b]) ++
  map macrodef (tokenFormats f)

macrodef :: (TokenType, TokenFormat) -> String
macrodef (tokt, tokf) = "\\newcommand{\\" ++ show tokt ++
                     "}[1]{" ++ (ul . bf . it . bg . co $ "{#1}") ++ "}"
  where ul x = if tokenUnderline tokf
                  then "\\underline{" ++ x ++ "}"
                  else x
        it x = if tokenItalic tokf
                  then "\\textit{" ++ x ++ "}"
                  else x
        bf x = if tokenBold tokf
                  then "\\textbf{" ++ x ++ "}"
                  else x
        bcol = fromColor `fmap` tokenBackground tokf :: Maybe (Double, Double, Double)
        bg x = case bcol of
                    Nothing          -> x
                    Just (r, g, b) -> printf "\\colorbox[rgb]{%0.2f,%0.2f,%0.2f}{%s}" r g b x
        col  = fromColor `fmap` tokenColor tokf :: Maybe (Double, Double, Double)
        co x = case col of
                    Nothing          -> x
                    Just (r, g, b) -> printf "\\textcolor[rgb]{%0.2f,%0.2f,%0.2f}{%s}" r g b x

defaultLaTeXMacros :: String
defaultLaTeXMacros = highlightingLaTeXMacros pygments

-- see test.tex
{-
\documentclass{article}
\usepackage{framed}
\usepackage{color}
\usepackage{fancyvrb}
\newcommand{\kw}[1]{\textcolor[rgb]{0,0.44,0.12}{#1}}
\newcommand{\dt}[1]{\textcolor[rgb]{0.56,0.12,0}{#1}}
\newcommand{\dv}[1]{\textcolor[rgb]{0.25,0.63,0.44}{#1}}
\newcommand{\bn}[1]{\textcolor[rgb]{0.25,0.63,0.44}{#1}}
\newcommand{\fl}[1]{\textcolor[rgb]{0.25,0.63,0.44}{#1}}
\newcommand{\ch}[1]{\textcolor[rgb]{0.25,0.44,0.63}{#1}}
\newcommand{\st}[1]{\textcolor[rgb]{0.25,0.44,0.63}{#1}}
\newcommand{\co}[1]{\textcolor[rgb]{96,0.63,0.69}{\textit{#1}}}
\newcommand{\ot}[1]{\textcolor[rgb]{0,0.44,0.12}{#1}}
\newcommand{\al}[1]{\textcolor[rgb]{1,0,0}{\textbf{#1}}}
\newcommand{\fu}[1]{\textcolor[rgb]{0.02,0.16,0.49}{#1}}
\newcommand{\re}[1]{#1}
\newcommand{\er}[1]{\textcolor[rgb]{1,0,0}{\textbf{#1}}}
\definecolor{shadecolor}{RGB}{222,167,130}
%\setlength{\FrameSep}{0pt}

\begin{document}

Hi:
\begin{snugshade}
\begin{Verbatim}[numbers=left,,commandchars=\\\{\}]
main  \fu{=} \fu{interact} (\fu{reverse})
\end{Verbatim}
\end{snugshade}
ok then.
\end{document}
-}

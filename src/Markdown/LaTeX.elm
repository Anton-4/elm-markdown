module Markdown.LaTeX exposing (export)

{-| For simple applications, the function xxx will be enough.
The other functions are mostly for building apps, e.g., editors,
in which the source text changes a lot. The best guide to
using the code are the examples. See the folder `examples`
and `editors`.


## Types

@docs MarkdownMsg

@docs fromAST


## Utility

-}

import BlockType exposing (BalancedType(..), BlockType(..), Language(..), Level, MarkdownType(..))
import Dict
import Html exposing (Html)
import Html.Attributes as HA exposing (style)
import HtmlEntity
import MDInline exposing (MDInline(..))
import Markdown.LaTeXPostProcess as LaTeXPostProcess
import Markdown.Option exposing (MarkdownOption(..), OutputOption(..))
import Markdown.Parse as Parse
    exposing
        ( BlockContent(..)
        , Id
        , MDBlock(..)
        , MDBlockWithId(..)
        , projectedStringOfBlockContent
        , stringFromId
        )
import SvgParser
import Tree exposing (Tree)


{-| Render source test given an a Markdown flavor
-}
export : String -> String
export str =
    str
        |> Parse.toMDBlockTree 0 ExtendedMath
        |> fromAST ( 0, 0 )


{-| Render to Html from a parse tree
-}
fromAST : Id -> Tree MDBlockWithId -> String
fromAST selectedId blockTreeWithId =
    blockTreeWithId
        |> Tree.children
        |> List.map (mmBlockTreeToLaTeX selectedId)
        |> String.join "\n\n"
        |> LaTeXPostProcess.fixItemLists


masterId =
    HA.id "__RENDERED_TEXT__"


{-| Use `String` so that user clicks on elements in the rendered text can be detected.
-}
type MarkdownMsg
    = IDClicked String


typeOfMDBlock : MDBlock -> BlockType
typeOfMDBlock (MDBlock bt _ _) =
    bt


isHeading : MDBlock -> Bool
isHeading block =
    case typeOfMDBlock block of
        MarkdownBlock (Heading _) ->
            True

        _ ->
            False


typeOfMDBlockWithId : MDBlockWithId -> BlockType
typeOfMDBlockWithId (MDBlockWithId _ bt _ _) =
    bt


isHeadingWithId : MDBlockWithId -> Bool
isHeadingWithId block =
    case typeOfMDBlockWithId block of
        MarkdownBlock (Heading _) ->
            True

        _ ->
            False


isMathWithId : MDBlockWithId -> Bool
isMathWithId block =
    case typeOfMDBlockWithId block of
        BalancedBlock DisplayMath ->
            True

        _ ->
            False


id0 =
    ( -1, -1 )


highlightColor =
    "#d7d6ff"


{-| DOC sync: if targetId == currentId, then return highlighted style
-}
selectedStyle_ : Id -> Id -> Html.Attribute MarkdownMsg
selectedStyle_ targetId currentId =
    case targetId == currentId of
        True ->
            HA.style "background-color" highlightColor

        False ->
            HA.style "background-color" "#fff"


{-| DOC sync: if targetId == currentId, then return highlighted style
-}
selectedStyle : Id -> Id -> List (Html.Attribute MarkdownMsg)
selectedStyle targetId currentId =
    case targetId == currentId of
        True ->
            [ HA.style "background-color" highlightColor ]

        False ->
            [ HA.style "background-color" "#fff" ]


mmBlockTreeToLaTeX : Id -> Tree MDBlockWithId -> String
mmBlockTreeToLaTeX selectedId tree =
    if Tree.children tree == [] then
        -- Render leaf blocks
        let
            (MDBlockWithId id bt lev content) =
                Tree.label tree
        in
        case bt of
            BalancedBlock DisplayMath ->
                renderBlock selectedId id (MDBlock bt lev content)

            _ ->
                renderBlock selectedId id (MDBlock bt lev content)

    else
        case Tree.label tree of
            MDBlockWithId id (MarkdownBlock TableRow) _ _ ->
                List.map (mmBlockTreeToLaTeX selectedId) (Tree.children tree) |> String.join " & "

            MDBlockWithId id (MarkdownBlock Table) _ _ ->
                env "tabular"
                    ((List.map (mmBlockTreeToLaTeX selectedId) (Tree.children tree) |> String.join " \\\\\n")
                        |> String.trim
                    )

            MDBlockWithId id (MarkdownBlock Plain) _ _ ->
                List.map (mmBlockTreeToLaTeX selectedId) (Tree.children tree) |> String.join "\n"

            MDBlockWithId id (MarkdownBlock _) _ _ ->
                List.map (mmBlockTreeToLaTeX selectedId) (Tree.children tree) |> String.join "\n"

            MDBlockWithId id (BalancedBlock DisplayMath) level content ->
                displayMathText (projectedStringOfBlockContent content)

            MDBlockWithId id (BalancedBlock Verbatim) _ _ ->
                "OUF: Verbatim!"

            MDBlockWithId id (BalancedBlock (DisplayCode lang)) _ _ ->
                "OUF: Code!"


idAttr : Id -> Html.Attribute MarkdownMsg
idAttr id =
    HA.id (stringFromId id)


idAttrWithLabel : Id -> String -> Html.Attribute MarkdownMsg
idAttrWithLabel id label =
    HA.id (stringFromId id ++ label)


renderBlock : Id -> Id -> MDBlock -> String
renderBlock selectedId id block =
    case block of
        MDBlock (MarkdownBlock Root) _ _ ->
            "ROOT"

        MDBlock (MarkdownBlock Plain) level blockContent ->
            renderBlockContent selectedId id level blockContent

        MDBlock (MarkdownBlock Blank) level blockContent ->
            renderBlockContent selectedId id level blockContent

        MDBlock (MarkdownBlock (Heading k)) level blockContent ->
            renderHeading selectedId id k level blockContent

        MDBlock (MarkdownBlock Quotation) level blockContent ->
            renderQuotation selectedId id level blockContent

        MDBlock (MarkdownBlock Poetry) level blockContent ->
            renderPoetry selectedId id level blockContent

        MDBlock (MarkdownBlock UListItem) level blockContent ->
            renderUListItem selectedId id level blockContent

        MDBlock (MarkdownBlock (OListItem index)) level blockContent ->
            renderOListItem selectedId id index level blockContent

        MDBlock (MarkdownBlock HorizontalRule) level blockContent ->
            "\\hrule"

        MDBlock (MarkdownBlock BlockType.Image) level blockContent ->
            renderBlockContent selectedId id level blockContent

        MDBlock (BalancedBlock DisplayMath) level blockContent ->
            case blockContent of
                T str ->
                    displayMathText str

                _ ->
                    displayMathText ""

        MDBlock (BalancedBlock Verbatim) level blockContent ->
            case blockContent of
                T str ->
                    env "verbatim" str

                _ ->
                    displayMathText ""

        MDBlock (BalancedBlock (DisplayCode lang)) level blockContent ->
            case blockContent of
                T str ->
                    str

                _ ->
                    displayMathText ""

        MDBlock (MarkdownBlock TableCell) level blockContent ->
            " " ++ renderBlockContent selectedId id level blockContent

        MDBlock (MarkdownBlock TableRow) level blockContent ->
            renderBlockContent selectedId id level blockContent

        MDBlock (MarkdownBlock Table) level blockContent ->
            renderBlockContent selectedId id level blockContent

        MDBlock (MarkdownBlock (ExtensionBlock info)) level blockContent ->
            case String.trim info of
                "svg" ->
                    "SVG: not implemented"

                "invisible" ->
                    ""

                _ ->
                    renderAsVerbatim info selectedId id level blockContent


renderAsVerbatim : String -> Id -> Id -> Int -> BlockContent -> String
renderAsVerbatim info selectedId id level blockContent =
    case blockContent of
        M (OrdinaryText str) ->
            env "verbatim" str

        _ ->
            ""


renderSvg selectedId id level blockContent =
    case blockContent of
        M (OrdinaryText svgText) ->
            renderSvg_ svgText

        _ ->
            Html.span [ HA.class "X5" ] []


renderSvg_ : String -> Html msg
renderSvg_ svgText =
    case SvgParser.parse svgText of
        Ok data ->
            data

        Err _ ->
            Html.span [ HA.class "X6" ] []


renderOrdinary : String -> Id -> Id -> Level -> BlockContent -> String
renderOrdinary info selectedId id level blockContent =
    renderBlockContent selectedId id level blockContent


marginOfLevel level =
    HA.style "margin-left" (String.fromInt (0 * level) ++ "px")


blockLevelClass k =
    HA.class <| "mm-block-" ++ String.fromInt k


unWrapParagraph : MDInline -> List MDInline
unWrapParagraph mmInline =
    case mmInline of
        Paragraph element ->
            element

        _ ->
            []


renderOListItem : Id -> Id -> Int -> Level -> BlockContent -> String
renderOListItem selectedId id index level blockContent =
    "\\item " ++ renderBlockContent selectedId id level blockContent


renderUListItem : Id -> Id -> Level -> BlockContent -> String
renderUListItem selectedId id level blockContent =
    "\\item " ++ renderBlockContent selectedId id level blockContent


prependToParagraph : MDInline -> BlockContent -> BlockContent
prependToParagraph head tail =
    case tail of
        T _ ->
            tail

        M mmInLine ->
            case mmInLine of
                Paragraph lst ->
                    M (Paragraph (head :: lst))

                _ ->
                    tail


renderHeading : Id -> Id -> Int -> Level -> BlockContent -> String
renderHeading selectedId id k level blockContent =
    let
        name =
            nameFromBlockContent blockContent
    in
    case k of
        1 ->
            macro "section" (renderBlockContent selectedId id level blockContent)

        2 ->
            macro "subsection" (renderBlockContent selectedId id level blockContent)

        3 ->
            macro "subsubsection" (renderBlockContent selectedId id level blockContent)

        4 ->
            macro "subsubsubsection" (renderBlockContent selectedId id level blockContent)

        _ ->
            macro "subheading" (renderBlockContent selectedId id level blockContent)


renderTOCHeading : Id -> Id -> Int -> Level -> BlockContent -> String
renderTOCHeading selectedId id k level blockContent =
    let
        name =
            nameFromBlockContent blockContent
    in
    "TOC heading: " ++ name


renderQuotation : Id -> Id -> Level -> BlockContent -> String
renderQuotation selectedId id level blockContent =
    env "quotation" (renderBlockContent selectedId id level blockContent)


renderPoetry : Id -> Id -> Level -> BlockContent -> String
renderPoetry selectedId id level blockContent =
    env "poetry" (renderBlockContent selectedId id level blockContent)


renderBlockContent : Id -> Id -> Level -> BlockContent -> String
renderBlockContent selectedId id level blockContent =
    case blockContent of
        M mmInline ->
            renderToLaTeX selectedId id level mmInline

        T str ->
            str


nameFromBlockContent : BlockContent -> String
nameFromBlockContent blockContent =
    case blockContent of
        M (Paragraph [ Line [ OrdinaryText str ] ]) ->
            String.trim str

        _ ->
            ""


renderToLaTeX : Id -> Id -> Level -> MDInline -> String
renderToLaTeX selectedId id level mmInline =
    case mmInline of
        OrdinaryText str ->
            str

        ItalicText str ->
            macro "italic" str

        BoldText str ->
            macro "strong" str

        Code str ->
            macro "code" str

        InlineMath str ->
            inlineMathText id str

        StrikeThroughText str ->
            macro "strike" str

        HtmlEntity str ->
            "htmlEntity:" ++ str

        HtmlEntities list ->
            -- (List.map htmlEntity list |> String.join "") ++ " "
            "htmlEntity: not implemented"

        BracketedText str ->
            "[" ++ str ++ "]"

        Link url label ->
            macro2 "href" url label

        ExtensionInline op arg ->
            macro op arg

        MDInline.Image label_ url ->
            macro3 "image" url label_ ""

        Line arg ->
            let
                joined =
                    joinLine selectedId id level arg
                        |> String.join "\n"
            in
            joined

        Paragraph arg ->
            let
                mapper : MDInline -> String
                mapper =
                    \m -> renderToLaTeX selectedId id level m
            in
            List.map mapper arg
                |> String.join "\n"

        Stanza arg ->
            renderStanza id arg

        Error arg ->
            "Error"


renderStanza : Id -> String -> String
renderStanza id arg =
    env "poetry" arg


joinLine : Id -> Id -> Level -> List MDInline -> List String
joinLine selectedId id level items =
    let
        folder : MDInline -> ( List String, List String ) -> ( List String, List String )
        folder item ( accString, accElement ) =
            case item of
                OrdinaryText str ->
                    case isPunctuation (String.left 1 str) of
                        True ->
                            ( str :: accString, accElement )

                        False ->
                            ( (" " ++ str) :: accString, accElement )

                _ ->
                    if accString /= [] then
                        let
                            content =
                                String.join "" accString

                            span =
                                content
                        in
                        ( [], renderToLaTeX selectedId id level item :: span :: accElement )

                    else
                        ( [], renderToLaTeX selectedId id level item :: accElement )

        flush : ( List String, List String ) -> List String
        flush ( accString, accElement ) =
            if accString /= [] then
                let
                    content =
                        String.join "" accString

                    span =
                        content
                in
                span :: accElement

            else
                accElement
    in
    List.foldl folder ( [], [] ) items
        |> flush
        |> List.reverse


isPunctuation : String -> Bool
isPunctuation str =
    List.member str [ ".", ",", ";", ":", "?", "!" ]


strikethrough : String -> String
strikethrough str =
    macro "strike" str



-- HELPERS


htmlEntity : String -> String
htmlEntity str =
    Maybe.withDefault ("(" ++ str ++ ")") <| Dict.get str HtmlEntity.dict


env : String -> String -> String
env name body =
    "\\begin{" ++ name ++ "}\n" ++ body ++ "\n\\end{" ++ name ++ "}"


macro : String -> String -> String
macro name arg =
    "\\" ++ name ++ "{" ++ arg ++ "}"


macro2 : String -> String -> String -> String
macro2 name arg1 arg2 =
    "\\" ++ name ++ "{" ++ arg1 ++ "}" ++ "{" ++ arg2 ++ "}"


macro3 : String -> String -> String -> String -> String
macro3 name arg1 arg2 arg3 =
    "\\" ++ name ++ "{" ++ arg1 ++ "}" ++ "{" ++ arg2 ++ "}" ++ "{" ++ arg3 ++ "}"



-- MATH --


inlineMathText : Id -> String -> String
inlineMathText id str =
    "$ " ++ String.trim str ++ " $ "


displayMathText : String -> String
displayMathText str =
    let
        str2 =
            String.trim str
    in
    "$$\n" ++ str2 ++ "\n$$"
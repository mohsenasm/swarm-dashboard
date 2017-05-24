module Components.Networks exposing (Connections, buildConnections, connections, header)

import Array exposing (Array)
import Html as H
import Html.Attributes as A
import Svg exposing (..)
import Svg.Attributes exposing (..)
import Docker.Types exposing (..)
import Components.NetworkConnections as NetworkConnections exposing (..)
import Util exposing (..)


type alias Connections =
    NetworkConnections


type alias Color =
    String


networkColors : Array Color
networkColors =
    Array.fromList
        [ "rgb(215, 74, 136)"
        , "rgb(243, 154, 155)"
        , "rgb(169, 65, 144)"
        , "rgb(249, 199, 160)"
        , "rgb(263, 110, 141)"
        ]


networkColor : Int -> Color
networkColor i =
    Maybe.withDefault "white" (Array.get (i % Array.length networkColors) networkColors)



-- Geometry


widthStep : Float
widthStep =
    16


totalWidth : List a -> Float
totalWidth aList =
    (toFloat (List.length aList)) * widthStep


columnCenter : Int -> Float
columnCenter i =
    ((toFloat i) * widthStep + widthStep / 2)


columnStart : Int -> Float
columnStart i =
    ((toFloat i) * widthStep)



-- SVG shorthand


svgLine : ( Float, Float ) -> ( Float, Float ) -> Float -> String -> Svg msg
svgLine ( ox, oy ) ( dx, dy ) width colour =
    line
        [ x1 (toString ox)
        , y1 (toString oy)
        , x2 (toString dx)
        , y2 (toString dy)
        , strokeWidth (toString width)
        , stroke colour
        ]
        []


svgCircle : ( Float, Float ) -> Float -> String -> Svg msg
svgCircle ( cenx, ceny ) rad colour =
    circle
        [ cx (toString cenx)
        , cy (toString ceny)
        , r (toString rad)
        , fill colour
        ]
        []



-- Symbol pieces


topLine : Int -> Color -> Svg msg
topLine i color =
    svgLine ( columnCenter i, 0 ) ( columnCenter i, 31 ) 2 color


bottomLine : Int -> Color -> Svg msg
bottomLine i color =
    svgLine ( columnCenter i, 31 ) ( columnCenter i, 62 ) 2 color


dot : Int -> Color -> Svg msg
dot i color =
    svgCircle ( columnCenter i, 31 ) (widthStep / 3) color


fullLine : Int -> Color -> Svg msg
fullLine i color =
    svgLine ( columnCenter i, 0 ) ( columnCenter i, 1 ) 2 color


tcap : Int -> Color -> List (Svg msg)
tcap i color =
    [ (svgLine ( (columnStart i) + widthStep / 6, 0 ) ( (columnStart i) + widthStep * 5 / 6, 0 ) 4 color)
    , svgLine ( columnCenter i, 0 ) ( columnCenter i, widthStep ) 2 color
    ]



-- Components


head : List Network -> Svg msg
head networks =
    let
        cap i network =
            if network.ingress then
                tcap i "white"
            else
                []
    in
        svg
            [ width (toString (totalWidth networks))
            , height (toString widthStep)
            , viewBox ("0 0 " ++ toString (totalWidth networks) ++ " " ++ toString widthStep)
            ]
            (networks |> List.indexedMap cap >> List.concat)


attachments : List Connection -> Array Color -> Svg msg
attachments connections colors =
    let
        symbol : Int -> Connection -> List (Svg msg)
        symbol i connection =
            let
                color =
                    Maybe.withDefault "white" (Array.get i colors)
            in
                case connection of
                    Through ->
                        [ topLine i color, bottomLine i color ]

                    Start ->
                        [ dot i color, bottomLine i color ]

                    Middle ->
                        [ topLine i color, dot i color, bottomLine i color ]

                    End ->
                        [ topLine i color, dot i color ]

                    Only ->
                        [ dot i color ]

                    None ->
                        []
    in
        svg
            [ width (toString (totalWidth connections)), height "62", viewBox ("0 0 " ++ toString (totalWidth connections) ++ " 62") ]
            (connections |> List.indexedMap symbol >> List.concat)


tails : List Connection -> Array Color -> Svg msg
tails connections colors =
    let
        symbol i connection =
            let
                color =
                    Maybe.withDefault "white" (Array.get i colors)
            in
                if List.member connection [ Start, Middle, Through ] then
                    [ fullLine i color ]
                else
                    []
    in
        svg
            [ width (toString (totalWidth connections))
            , height "100%"
            , viewBox ("0 0 " ++ toString (totalWidth connections) ++ " 1")
            , preserveAspectRatio "none"
            ]
            (connections |> List.indexedMap symbol >> List.concat)



-- Exposed compopnents


buildConnections : List Service -> List Network -> Connections
buildConnections =
    NetworkConnections.build


header : List Network -> H.Html msg
header networks =
    H.th [ class "networks", A.style [ ( "width", (toString (totalWidth networks)) ++ "px" ) ] ] [ head networks ]


connections : Service -> Connections -> H.Html msg
connections service networkConnections =
    let
        connections =
            NetworkConnections.serviceConnections service networkConnections

        colors =
            networkConnections.networks |> Array.fromList << List.indexedMap (\i n -> iff n.ingress "white" (networkColor i))
    in
        H.td [ class "networks" ]
            [ attachments connections colors
            , H.div [] [ tails connections colors ]
            ]

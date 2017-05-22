module Components.Networks exposing (Connections, buildConnections, connections, header)

import Html as H
import Html.Attributes as A
import Svg exposing (..)
import Svg.Attributes exposing (..)
import Docker.Types exposing (..)
import Components.NetworkConnections as NetworkConnections exposing (..)


type alias Connections =
    NetworkConnections



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


topLine : Int -> Svg msg
topLine i =
    svgLine ( columnCenter i, 0 ) ( columnCenter i, 31 ) 2 "white"


bottomLine : Int -> Svg msg
bottomLine i =
    svgLine ( columnCenter i, 31 ) ( columnCenter i, 62 ) 2 "white"


dot : Int -> Svg msg
dot i =
    svgCircle ( columnCenter i, 31 ) (widthStep / 3) "white"


fullLine : Int -> Svg msg
fullLine i =
    svgLine ( columnCenter i, 0 ) ( columnCenter i, 1 ) 2 "white"


tcap : Int -> List (Svg msg)
tcap i =
    [ (svgLine ( (columnStart i) + widthStep / 6, 0 ) ( (columnStart i) + widthStep * 5 / 6, 0 ) 4 "white")
    , svgLine ( columnCenter i, 0 ) ( columnCenter i, widthStep ) 2 "white"
    ]



-- Components


head : List Network -> Svg msg
head networks =
    let
        cap i network =
            if network.ingress then
                tcap i
            else
                []
    in
        svg
            [ width (toString (totalWidth networks))
            , height (toString widthStep)
            , viewBox ("0 0 " ++ toString (totalWidth networks) ++ " " ++ toString widthStep)
            ]
            (networks |> List.indexedMap cap >> List.concat)


attachments : List Connection -> Svg msg
attachments connections =
    let
        symbol : Int -> Connection -> List (Svg msg)
        symbol i connection =
            case connection of
                Through ->
                    [ topLine i, bottomLine i ]

                Start ->
                    [ dot i, bottomLine i ]

                Middle ->
                    [ topLine i, dot i, bottomLine i ]

                End ->
                    [ topLine i, dot i ]

                Only ->
                    [ dot i ]

                None ->
                    []
    in
        svg
            [ width (toString (totalWidth connections)), height "62", viewBox ("0 0 " ++ toString (totalWidth connections) ++ " 62") ]
            (connections |> List.indexedMap symbol >> List.concat)


tails : List Connection -> Svg msg
tails connections =
    let
        symbol i connection =
            if List.member connection [ Start, Middle, Through ] then
                [ fullLine i ]
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
    in
        H.td [ class "networks" ]
            [ attachments connections
            , H.div [] [ tails connections ]
            ]

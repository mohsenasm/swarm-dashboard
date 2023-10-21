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


svgLine : ( Float, Float ) -> ( Float, Float ) -> Float -> String -> String -> Svg msg
svgLine ( ox, oy ) ( dx, dy ) width colour name =
    line
        [ x1 (toString ox)
        , y1 (toString oy)
        , x2 (toString dx)
        , y2 (toString dy)
        , strokeWidth (toString width)
        , stroke colour
        ]
        [
          Svg.title [] [ text name ]
        ]


svgCircle : ( Float, Float ) -> Float -> String -> String -> Svg msg
svgCircle ( cenx, ceny ) rad colour name =
    circle
        [ cx (toString cenx)
        , cy (toString ceny)
        , r (toString rad)
        , fill colour
        ]
        [
          Svg.title [] [ text name ]
        ]



-- Symbol pieces


topLine : Int -> Color -> String -> Svg msg
topLine i color name =
    svgLine ( columnCenter i, 0 ) ( columnCenter i, 31 ) 2 color name


bottomLine : Int -> Color -> String -> Svg msg
bottomLine i color name =
    svgLine ( columnCenter i, 31 ) ( columnCenter i, 62 ) 2 color name


dot : Int -> Color -> String -> Svg msg
dot i color name =
    svgCircle ( columnCenter i, 31 ) (widthStep / 3) color name


fullLine : Int -> Color -> String -> Svg msg
fullLine i color name =
    svgLine ( columnCenter i, 0 ) ( columnCenter i, 1 ) 2 color name


tcap : Int -> Color -> String -> List (Svg msg)
tcap i color name =
    [ (svgLine ( (columnStart i) + widthStep / 6, 0 ) ( (columnStart i) + widthStep * 5 / 6, 0 ) 4 color name)
    , svgLine ( columnCenter i, 0 ) ( columnCenter i, widthStep ) 2 color name
    ]



-- Components


head : List Network -> Svg msg
head networks =
    let
        cap i network =
            if network.ingress then
                tcap i "white" network.name
            else
                []
    in
        svg
            [ width (toString (totalWidth networks))
            , height (toString widthStep)
            , viewBox ("0 0 " ++ toString (totalWidth networks) ++ " " ++ toString widthStep)
            ]
            (networks |> List.indexedMap cap >> List.concat)


attachments : List Connection -> Array Color -> Array String -> Svg msg
attachments connections colors names =
    let
        symbol : Int -> Connection -> List (Svg msg)
        symbol i connection =
            let
                color =
                    Maybe.withDefault "white" (Array.get i colors)
                
                name =
                    Maybe.withDefault "" (Array.get i names)
            in
                case connection of
                    Through ->
                        [ topLine i color name, bottomLine i color name ]

                    Start ->
                        [ dot i color name, bottomLine i color name ]

                    Middle ->
                        [ topLine i color name, dot i color name, bottomLine i color name ]

                    End ->
                        [ topLine i color name, dot i color name ]

                    Only ->
                        [ dot i color name ]

                    None ->
                        []
    in
        svg
            [ width (toString (totalWidth connections)), height "62", viewBox ("0 0 " ++ toString (totalWidth connections) ++ " 62") ]
            (connections |> List.indexedMap symbol >> List.concat)


tails : List Connection -> Array Color -> Array String -> Svg msg
tails connections colors names =
    let
        symbol i connection =
            let
                color =
                    Maybe.withDefault "white" (Array.get i colors)
                
                name =
                    Maybe.withDefault "" (Array.get i names)
            in
                if List.member connection [ Start, Middle, Through ] then
                    [ fullLine i color name ]
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
        
        names =
            networkConnections.networks |> Array.fromList << List.indexedMap (\i n -> n.name)
    in
        H.td [ class "networks" ]
            [ attachments connections colors names
            , H.div [] [ tails connections colors names ]
            ]

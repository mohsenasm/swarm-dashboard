module Components.Networks exposing (..)

import Dict exposing (Dict)
import Html as H
import Html.Attributes as A
import Svg exposing (..)
import Svg.Attributes exposing (..)
import Docker.Types exposing (..)


type Connection
    = None
    | Through
    | Start
    | Middle
    | End
    | Only


type alias NetworkConnections =
    Dict ( ServiceId, NetworkId ) Connection


type alias NetworkAttachments =
    Dict ( ServiceId, NetworkId ) Bool


widthStep : Int
widthStep =
    16


header : List Network -> Svg msg
header networks =
    let
        totalWidth =
            (List.length networks) * widthStep

        tcap : Int -> List (Svg msg)
        tcap i =
            [ line
                [ x1 (toString (toFloat (i * widthStep) + ((toFloat widthStep) / 6.0)))
                , y1 "0"
                , x2 (toString (toFloat (i * widthStep) + (toFloat widthStep) * (5 / 6)))
                , y2 "0"
                , strokeWidth "4"
                , stroke "white"
                ]
                []
            , line
                [ x1 (toString (i * widthStep + widthStep // 2))
                , y1 "0"
                , x2 (toString (i * widthStep + widthStep // 2))
                , y2 (toString widthStep)
                , strokeWidth "2"
                , stroke "white"
                ]
                []
            ]
    in
        svg
            [ width (toString totalWidth)
            , height (toString widthStep)
            , viewBox ("0 0 " ++ toString totalWidth ++ " " ++ toString widthStep)
            , preserveAspectRatio "none"
            ]
            (networks
                |> (List.indexedMap
                        (\i network ->
                            if network.ingress then
                                tcap i
                            else
                                []
                        )
                   )
                >> List.concat
            )


attachments : List Connection -> Svg msg
attachments connections =
    let
        totalWidth =
            (List.length connections) * widthStep

        topLine : Int -> Svg msg
        topLine i =
            line
                [ x1 (toString (i * widthStep + widthStep // 2))
                , y1 "0"
                , x2 (toString (i * widthStep + widthStep // 2))
                , y2 "31"
                , strokeWidth "2"
                , stroke "white"
                ]
                []

        bottomLine : Int -> Svg msg
        bottomLine i =
            line
                [ x1 (toString (i * widthStep + widthStep // 2))
                , y1 "31"
                , x2 (toString (i * widthStep + widthStep // 2))
                , y2 "62"
                , strokeWidth "2"
                , stroke "white"
                ]
                []

        dot : Int -> Svg msg
        dot i =
            circle
                [ cx (toString (i * widthStep + widthStep // 2))
                , cy "31"
                , r (toString (widthStep // 3))
                , fill "white"
                ]
                []
    in
        svg
            [ width (toString totalWidth), height "62", viewBox ("0 0 " ++ toString totalWidth ++ " 62") ]
            (connections
                |> (List.indexedMap
                        (\i connection ->
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
                        )
                        >> List.concat
                   )
            )


tails : List Connection -> Svg msg
tails connections =
    let
        totalWidth =
            (List.length connections) * widthStep

        fullLine : Int -> Svg msg
        fullLine i =
            line
                [ x1 (toString (i * widthStep + widthStep // 2))
                , y1 "0"
                , x2 (toString (i * widthStep + widthStep // 2))
                , y2 "1"
                , strokeWidth "2"
                , stroke "white"
                ]
                []
    in
        svg
            [ width (toString totalWidth)
            , height "100%"
            , viewBox ("0 0 " ++ toString totalWidth ++ " 1")
            , preserveAspectRatio "none"
            ]
            (connections
                |> (List.indexedMap
                        (\i connection ->
                            if List.member connection [ Start, Middle, Through ] then
                                [ fullLine i ]
                            else
                                []
                        )
                   )
                >> List.concat
            )


networksHeader : List Network -> H.Html msg
networksHeader networks =
    let
        networksWidth =
            toString (List.length networks * widthStep) ++ "px"
    in
        H.th [ class "networks", A.style [ ( "width", networksWidth ) ] ] [ header networks ]


connections : Service -> List Network -> NetworkConnections -> H.Html msg
connections service allNetworks networkConnections =
    let
        connectionType network =
            Maybe.withDefault None (Dict.get ( service.id, network.id ) networkConnections)

        connections =
            List.map connectionType allNetworks
    in
        H.td [ class "networks" ]
            [ attachments connections
            , H.div []
                [ tails connections ]
            ]

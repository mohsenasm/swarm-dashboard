module Components exposing (..)

import Dict exposing (Dict)
import Html exposing (..)
import Html.Attributes exposing (..)
import Util exposing (..)
import Docker.Types exposing (..)
import Components.Networks as Networks


statusString : String -> String -> String
statusString state desiredState =
    if state == desiredState then
        state
    else
        state ++ " → " ++ desiredState


task : Service -> AssignedTask -> Html msg
task service { status, desiredState, containerSpec, slot, info } =
    let
        classes =
            [ ( status.state, True )
            , ( "desired-" ++ desiredState, True )
            , ( "running-old", status.state == "running" && service.containerSpec.image /= containerSpec.image )
            ]

        slotLabel slot =
            case slot of
                Just s ->
                    "." ++ toString s

                Nothing ->
                    ""
        
        cpuInfo =
            case info.cpu of
                Just s ->
                    [
                        div [ class "tag left" ] [ text s ]
                    ]

                Nothing ->
                    []

        memoryInfo =
            case info.memory of
                Just s ->
                    [
                        div [ class "tag right" ] [ text s ]
                    ]

                Nothing ->
                    []

        timestateInfo =
            case status.timestateInfo of
                Just s ->
                    [
                        br [] []
                        , small [] [ text s ]
                    ]

                Nothing ->
                    []
    in
        li [ classList classes ]
            (List.concat [
                cpuInfo
                , (List.concat [
                    memoryInfo
                    , (List.concat [
                        [ text (service.name ++ slotLabel slot)
                        , br [] []
                        , text (statusString status.state desiredState) ]
                        , timestateInfo
                    ])
                ])
            ])
            


serviceNode : Service -> TaskIndex -> Node -> Html msg
serviceNode service taskAllocations node =
    let
        tasks =
            Maybe.withDefault [] (Dict.get ( node.id, service.id ) taskAllocations)
        forThisService (n, s) = 
            s == service.id
        tasksOfThisService = List.filter forThisService (Dict.keys taskAllocations)
        noTaskNowhere = List.length tasksOfThisService == 0
    in
        if noTaskNowhere then
            td [ class "empty-service" ] []
        else
            td []
                [ ul [] (List.map (task service) tasks) ]


serviceRow : List Node -> TaskIndex -> Networks.Connections -> Service -> Html msg
serviceRow nodes taskAllocations networkConnections service =
    tr []
        (th [] [ text service.name ] :: (Networks.connections service networkConnections) :: (List.map (serviceNode service taskAllocations) nodes))


node : Node -> Html msg
node node =
    let
        leader =
            Maybe.withDefault False (Maybe.map .leader node.managerStatus)

        classes =
            [ ( "down", node.status.state == "down" )
            , ( "manager", node.role == "manager" )
            , ( "leader", leader )
            ]

        nodeRole =
            String.join " " [ node.role, iff leader "(leader)" "" ]

        info =
            case node.info of
                Just s ->
                    [
                        br [] []
                        , text (s)
                    ]

                Nothing ->
                    []
    in
        th [ classList classes ]
            (List.concat [
                [ 
                    strong [] [ text node.name ]
                    , br [] []
                    , text nodeRole
                    , br [] []
                    , text node.status.address
                ]
                , info
            ])


swarmHeader : List Node -> List Network -> String -> Html msg
swarmHeader nodes networks refreshTime =
    tr [] ((th [] [ img [ src "docker_logo.svg" ] []
                    , div [ class "refresh-time" ] [ text refreshTime ]
                  ]
           ) :: Networks.header networks :: (nodes |> List.map node))


swarmGrid : List Service -> List Node -> List Network -> TaskIndex -> String -> Html msg
swarmGrid services nodes networks taskAllocations refreshTime =
    let
        networkConnections =
            Networks.buildConnections services networks
    in
        table []
            [ thead [] [ swarmHeader nodes networks refreshTime ]
            , tbody [] (List.map (serviceRow nodes taskAllocations networkConnections) services)
            ]

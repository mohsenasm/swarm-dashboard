module Components exposing (..)

import Dict exposing (Dict)
import Html exposing (..)
import Html.Attributes exposing (..)
import Docker.Types exposing (..)
import Components.Networks exposing (..)


attachments : List Service -> NetworkAttachments
attachments services =
    let
        networkReducer : ServiceId -> Network -> NetworkAttachments -> NetworkAttachments
        networkReducer serviceId network attachments =
            Dict.update ( serviceId, network.id ) (always (Just True)) attachments

        serviceReducer : Service -> NetworkAttachments -> NetworkAttachments
        serviceReducer service attachments =
            service.networks |> List.foldl (networkReducer service.id) attachments
    in
        List.foldl serviceReducer Dict.empty services


networkConnections : List Service -> List Network -> NetworkConnections
networkConnections services networks =
    let
        networkAttachments =
            attachments services

        attached sid nid =
            Maybe.withDefault False (Dict.get ( sid, nid ) networkAttachments)

        serviceReducer : Network -> ( Int, Int ) -> Service -> ( Int, NetworkConnections ) -> ( Int, NetworkConnections )
        serviceReducer network ( first, last ) service ( idx, connections ) =
            if idx < first || idx > last then
                ( idx + 1, Dict.update ( service.id, network.id ) (always (Just None)) connections )
            else if idx == first && idx == last then
                ( idx + 1, Dict.update ( service.id, network.id ) (always (Just Only)) connections )
            else if idx == first then
                ( idx + 1, Dict.update ( service.id, network.id ) (always (Just Start)) connections )
            else if idx == last then
                ( idx + 1, Dict.update ( service.id, network.id ) (always (Just End)) connections )
            else if attached service.id network.id then
                ( idx + 1, Dict.update ( service.id, network.id ) (always (Just Middle)) connections )
            else
                ( idx + 1, Dict.update ( service.id, network.id ) (always (Just Through)) connections )
    in
        networks
            |> (List.foldl
                    (\network connections ->
                        let
                            nid =
                                network.id

                            ( _, bounds ) =
                                services
                                    |> (List.foldl
                                            (\service ( idx, ( first, last ) ) ->
                                                if attached service.id nid then
                                                    if first > -1 || network.ingress then
                                                        ( idx + 1, ( first, idx ) )
                                                    else
                                                        ( idx + 1, ( idx, idx ) )
                                                else
                                                    ( idx + 1, ( first, last ) )
                                            )
                                            ( 0, ( -1, -1 ) )
                                       )
                        in
                            services
                                |> (List.foldl (serviceReducer network bounds) ( 0, connections ))
                                |> Tuple.second
                    )
                    Dict.empty
               )


statusString : String -> String -> String
statusString state desiredState =
    if state == desiredState then
        state
    else
        state ++ " → " ++ desiredState


task : Service -> AssignedTask -> Html msg
task service { status, desiredState, containerSpec, slot } =
    let
        classes =
            [ ( status.state, True )
            , ( "desired-" ++ desiredState, True )
            , ( "running-old", status.state == "running" && service.containerSpec.image /= containerSpec.image )
            ]
    in
        li [ classList classes ]
            [ text (service.name ++ "." ++ toString slot)
            , br [] []
            , text (statusString status.state desiredState)
            ]


serviceNode : Service -> TaskIndex -> Node -> Html msg
serviceNode service taskAllocations node =
    let
        tasks =
            Maybe.withDefault [] (Dict.get ( node.id, service.id ) taskAllocations)
    in
        td []
            [ ul [] (List.map (task service) tasks) ]


serviceRow : List Node -> TaskIndex -> List Network -> NetworkConnections -> Service -> Html msg
serviceRow nodes taskAllocations allNetworks networkConnections service =
    tr []
        (th [] [ text service.name ] :: (connections service allNetworks networkConnections) :: (List.map (serviceNode service taskAllocations) nodes))


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
            String.join " "
                [ node.role
                , (if leader then
                    "(leader)"
                   else
                    ""
                  )
                ]
    in
        th [ classList classes ]
            [ strong [] [ text node.name ]
            , br [] []
            , text nodeRole
            , br [] []
            , text node.status.address
            ]


swarmHeader : List Node -> List Network -> Html msg
swarmHeader nodes networks =
    tr [] ((th [] [ img [ src "docker_logo.svg" ] [] ]) :: networksHeader networks :: (nodes |> List.map node))


swarmGrid : List Service -> List Node -> List Network -> TaskIndex -> Html msg
swarmGrid services nodes networks taskAllocations =
    table []
        [ thead [] [ swarmHeader nodes networks ]
        , tbody [] (List.map (serviceRow nodes taskAllocations networks (networkConnections services networks)) services)
        ]

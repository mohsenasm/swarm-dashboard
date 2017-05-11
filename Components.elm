module Components exposing (..)

import Dict exposing (Dict)
import Html exposing (..)
import Html.Attributes exposing (..)
import Docker.Types exposing (..)


statusString : String -> String -> String
statusString state desiredState =
    if state == desiredState then
        state
    else
        state ++ " -> " ++ desiredState


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
serviceNode service tasksByNodeService node =
    let
        tasks =
            Maybe.withDefault [] (Dict.get ( node.id, service.id ) tasksByNodeService)
    in
        td []
            [ ul [] (List.map (task service) tasks) ]


service : List Node -> TaskIndex -> Service -> Html msg
service nodes tasksByNodeService ({ name } as service) =
    tr []
        (th [] [ text name ] :: (List.map (serviceNode service tasksByNodeService) nodes))


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
            , text node.status.address
            , br [] []
            , text nodeRole
            ]


swarmHeader : List Node -> Html msg
swarmHeader nodes =
    tr [] (th [] [ img [ src "docker_logo.svg" ] [] ] :: (nodes |> List.map node))


swarmGrid : List Service -> List Node -> TaskIndex -> Html msg
swarmGrid services nodes tasksByNodeService =
    table []
        [ thead [] [ swarmHeader nodes ]
        , tbody [] (List.map (service nodes tasksByNodeService) services)
        ]

module Components exposing (..)

import Dict exposing (Dict)
import Html exposing (..)
import Html.Attributes exposing (..)
import Docker.Types exposing (..)


task : Service -> Task -> Html msg
task service task =
    li [ class task.state ]
        [ text (service.name ++ "." ++ toString task.slot)
        , br [] []
        , text task.state
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


swarmHeader : List Node -> Html msg
swarmHeader nodes =
    tr [] (th [] [ img [ src "docker_logo.svg" ] [] ] :: (nodes |> List.map (\node -> th [] [ text node.name ])))


swarmGrid : List Service -> List Node -> TaskIndex -> Html msg
swarmGrid services nodes tasksByNodeService =
    table []
        [ thead [] [ swarmHeader nodes ]
        , tbody [] (List.map (service nodes tasksByNodeService) services)
        ]

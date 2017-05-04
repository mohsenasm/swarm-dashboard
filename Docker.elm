module Docker exposing (..)

import Dict exposing (Dict)
import Docker.Types exposing (..)
import Docker.Json exposing (parse)


indexTasks : List Task -> TaskIndex
indexTasks tasks =
    let
        reducer task result =
            let
                key =
                    ( task.nodeId, task.serviceId )

                value =
                    (task :: (Maybe.withDefault [] (Dict.get key result)))
            in
                Dict.insert key value result
    in
        List.foldl reducer Dict.empty tasks


empty : Docker
empty =
    Docker [] [] []


sort : Docker -> Docker
sort { nodes, services, tasks } =
    let
        sortedNodes =
            List.sortBy (.name) nodes

        sortedServices =
            List.sortBy (.name) services
    in
        Docker sortedNodes sortedServices tasks


fromJson : String -> Result String Docker
fromJson =
    parse >> Result.map sort

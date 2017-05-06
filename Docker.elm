module Docker exposing (..)

import Dict exposing (Dict)
import Docker.Types exposing (..)
import Docker.Json exposing (parse)


indexTasks : List Task -> TaskIndex
indexTasks tasks =
    let
        reducer task result =
            case task.nodeId of
                Just nodeId ->
                    let
                        key =
                            ( nodeId, task.serviceId )

                        value =
                            (task :: (Maybe.withDefault [] (Dict.get key result)))
                    in
                        Dict.insert key value result

                Nothing ->
                    result
    in
        List.foldl reducer Dict.empty tasks


empty : Docker
empty =
    Docker [] [] []


complement : (a -> Bool) -> a -> Bool
complement fn =
    \x -> not (fn x)


isCompleted : Task -> Bool
isCompleted { state } =
    (state == "rejected") || (state == "shutdown")


preProcess : Docker -> Docker
preProcess { nodes, services, tasks } =
    -- TODO split tasks into placed and not placed (based on NodeID)
    let
        sortedNodes =
            List.sortBy (.name) nodes

        sortedServices =
            List.sortBy (.name) services

        filteredTasks =
            List.filter (complement isCompleted) tasks
    in
        Docker sortedNodes sortedServices filteredTasks


fromJson : String -> Result String Docker
fromJson =
    parse >> Result.map preProcess

module Docker exposing (..)

import Dict exposing (Dict)
import Date exposing (Date)
import Docker.Types exposing (..)
import Docker.Json exposing (parse)
import Util exposing (..)


isFailed : TaskStatus -> Bool
isFailed { state } =
    (state == "failed")


isCompleted : TaskStatus -> Bool
isCompleted { state } =
    (state == "rejected") || (state == "shutdown")


withoutFailedTaskHistory : List AssignedTask -> List AssignedTask
withoutFailedTaskHistory =
    let
        key { serviceId, slot } =
            ( serviceId, slot )

        latestRunning =
            List.sortBy (.status >> .timestamp >> Date.toTime)
                >> List.filter (\t -> t.status.state /= "failed")
                >> List.reverse
                >> List.head

        latest =
            List.sortBy (.status >> .timestamp >> Date.toTime)
                >> List.reverse
                >> (List.take 1)

        failedOlderThan running task =
            isFailed task.status && Date.toTime task.status.timestamp < Date.toTime running.status.timestamp

        filterPreviouslyFailed tasks =
            case latestRunning tasks of
                -- remove older failed tasks
                Just runningTask ->
                    List.filter (complement (failedOlderThan runningTask)) tasks

                -- Keep only the latest failed task
                Nothing ->
                    latest tasks
    in
        (groupBy key) >> (Dict.map (\_ -> filterPreviouslyFailed)) >> Dict.values >> List.concat


process : DockerApiData -> Docker
process { nodes, services, tasks } =
    let
        sortedNodes =
            List.sortBy .name nodes

        sortedServices =
            List.sortBy .name services

        ( assignedTasks, plannedTasks ) =
            tasks
                |> (List.partition (.nodeId >> isJust))
                >> (Tuple.mapFirst (List.map assignedTask))
                >> (Tuple.mapSecond (List.map plannedTask))

        selectNotCompleted =
            List.filter (.status >> complement isCompleted)

        processedTasks =
            assignedTasks |> selectNotCompleted >> withoutFailedTaskHistory
    in
        Docker sortedNodes sortedServices plannedTasks processedTasks


empty : Docker
empty =
    Docker [] [] [] []


fromJson : String -> Result String Docker
fromJson =
    parse >> Result.map process

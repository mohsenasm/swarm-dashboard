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
process { nodes, networks, services, tasks } =
    let
        emptyNetwork =
            { id = "", ingress = False, name = "" }

        networkIndex =
            indexBy (.id) networks

        resolveNetworks : List NetworkId -> List Network
        resolveNetworks networks =
            networks |> List.map (\id -> Maybe.withDefault emptyNetwork (Dict.get id networkIndex))

        linkNetworks : List RawService -> List Service
        linkNetworks =
            List.map (\service -> { service | networks = resolveNetworks service.networks })

        allNetworks : List RawService -> List Network
        allNetworks =
            List.concatMap .networks
                >> unique
                >> resolveNetworks
                >> (List.sortBy .name)
                >> (List.sortBy
                        (.ingress
                            >> (\is ->
                                    if is then
                                        0
                                    else
                                        1
                               )
                        )
                   )

        ( assignedTasks, plannedTasks ) =
            tasks
                |> (List.partition (.nodeId >> isJust))
                >> (Tuple.mapFirst (List.map assignedTask))
                >> (Tuple.mapSecond (List.map plannedTask))

        notCompleted =
            List.filter (.status >> complement isCompleted)

        filterTasks =
            notCompleted >> withoutFailedTaskHistory
    in
        { nodes = (List.sortBy .name nodes)
        , networks = (allNetworks services)
        , services = (List.sortBy .name (linkNetworks services))
        , plannedTasks = plannedTasks
        , assignedTasks = (filterTasks assignedTasks)
        }


empty : Docker
empty =
    Docker [] [] [] [] []


fromJson : String -> Result String Docker
fromJson =
    parse >> Result.map process

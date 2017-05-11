module Docker.Json exposing (parse)

import Date exposing (Date)
import Json.Decode as Json
import Docker.Types exposing (..)


containerSpec : Json.Decoder ContainerSpec
containerSpec =
    Json.map ContainerSpec
        (Json.at [ "Image" ] Json.string)


nodeStatus : Json.Decoder NodeStatus
nodeStatus =
    Json.map2 NodeStatus
        (Json.at [ "State" ] Json.string)
        (Json.at [ "Addr" ] Json.string)


managerStatus : Json.Decoder ManagerStatus
managerStatus =
    Json.map2 ManagerStatus
        (Json.at [ "Leader" ] Json.bool)
        (Json.at [ "Reachability" ] Json.string)


node : Json.Decoder Node
node =
    Json.map5 Node
        (Json.at [ "ID" ] Json.string)
        (Json.at [ "Description", "Hostname" ] Json.string)
        (Json.at [ "Spec", "Role" ] Json.string)
        (Json.at [ "Status" ] nodeStatus)
        (Json.maybe (Json.at [ "ManagerStatus" ] managerStatus))


service : Json.Decoder Service
service =
    Json.map3 Service
        (Json.at [ "ID" ] Json.string)
        (Json.at [ "Spec", "Name" ] Json.string)
        (Json.at [ "Spec", "TaskTemplate", "ContainerSpec" ] containerSpec)


date : Json.Decoder Date
date =
    let
        safeFromString =
            Date.fromString >> (Result.withDefault (Date.fromTime 0.0))
    in
        Json.string |> Json.map safeFromString


taskStatus : Json.Decoder TaskStatus
taskStatus =
    Json.map2 TaskStatus
        (Json.at [ "Timestamp" ] date)
        (Json.at [ "State" ] Json.string)


task : Json.Decoder Task
task =
    Json.map7 Task
        (Json.at [ "ID" ] Json.string)
        (Json.at [ "ServiceID" ] Json.string)
        (Json.maybe (Json.at [ "NodeID" ] Json.string))
        (Json.at [ "Slot" ] Json.int)
        (Json.at [ "Status" ] taskStatus)
        (Json.at [ "DesiredState" ] Json.string)
        (Json.at [ "Spec", "ContainerSpec" ] containerSpec)


dockerApi : Json.Decoder DockerApiData
dockerApi =
    Json.map3 DockerApiData
        (Json.at [ "nodes" ] (Json.list node))
        (Json.at [ "services" ] (Json.list service))
        (Json.at [ "tasks" ] (Json.list task))


parse : String -> Result String DockerApiData
parse =
    Json.decodeString dockerApi

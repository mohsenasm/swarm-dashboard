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
    Json.map6 Node
        (Json.at [ "ID" ] Json.string)
        (Json.at [ "Description", "Hostname" ] Json.string)
        (Json.at [ "Spec", "Role" ] Json.string)
        (Json.at [ "Status" ] nodeStatus)
        (Json.maybe (Json.at [ "ManagerStatus" ] managerStatus))
        (Json.maybe (Json.at [ "info" ] Json.string))


network : Json.Decoder Network
network =
    Json.map3 Network
        (Json.at [ "Id" ] Json.string)
        (Json.at [ "Name" ] Json.string)
        (Json.at [ "Ingress" ] Json.bool)


filterEmptyNetworks : Maybe (List NetworkId) -> Json.Decoder (List NetworkId)
filterEmptyNetworks networks =
    Json.succeed (Maybe.withDefault [] networks)


service : Json.Decoder RawService
service =
    Json.map4 RawService
        (Json.at [ "ID" ] Json.string)
        (Json.at [ "Spec", "Name" ] Json.string)
        (Json.at [ "Spec", "TaskTemplate", "ContainerSpec" ] containerSpec)
        ((Json.maybe (Json.at [ "Endpoint", "VirtualIPs" ] (Json.list (Json.at [ "NetworkID" ] Json.string)))) |> Json.andThen filterEmptyNetworks)


date : Json.Decoder Date
date =
    let
        safeFromString =
            Date.fromString >> (Result.withDefault (Date.fromTime 0.0))
    in
        Json.string |> Json.map safeFromString


taskStatus : Json.Decoder TaskStatus
taskStatus =
    Json.map3 TaskStatus
        (Json.at [ "Timestamp" ] date)
        (Json.maybe (Json.at [ "timestateInfo" ] Json.string))
        (Json.at [ "State" ] Json.string)


taskInfo : Json.Decoder TaskInfo
taskInfo =
    Json.map2 TaskInfo
        (Json.maybe (Json.at [ "cpu" ] Json.string))
        (Json.maybe (Json.at [ "memory" ] Json.string))


task : Json.Decoder Task
task =
    Json.map8 Task
        (Json.at [ "ID" ] Json.string)
        (Json.at [ "ServiceID" ] Json.string)
        (Json.maybe (Json.at [ "NodeID" ] Json.string))
        (Json.maybe (Json.at [ "Slot" ] Json.int))
        (Json.at [ "Status" ] taskStatus)
        (Json.at [ "DesiredState" ] Json.string)
        (Json.at [ "Spec", "ContainerSpec" ] containerSpec)
        (Json.at [ "info" ] taskInfo)


dockerApi : Json.Decoder DockerApiData
dockerApi =
    Json.map5 DockerApiData
        (Json.at [ "nodes" ] (Json.list node))
        (Json.at [ "networks" ] (Json.list network))
        (Json.at [ "services" ] (Json.list service))
        (Json.at [ "tasks" ] (Json.list task))
        (Json.at [ "refreshTime" ] Json.string)


parse : String -> Result String DockerApiData
parse =
    Json.decodeString dockerApi

module Docker.Json exposing (parse)

import Docker.Types exposing (..)
import Json.Decode as Json


containerSpec : Json.Decoder ContainerSpec
containerSpec =
    Json.map ContainerSpec
        (Json.at [ "Image" ] Json.string)


node : Json.Decoder Node
node =
    Json.map4 Node
        (Json.at [ "ID" ] Json.string)
        (Json.at [ "Description", "Hostname" ] Json.string)
        (Json.at [ "Spec", "Role" ] Json.string)
        (Json.at [ "Spec", "Availability" ] Json.string)


service : Json.Decoder Service
service =
    Json.map3 Service
        (Json.at [ "ID" ] Json.string)
        (Json.at [ "Spec", "Name" ] Json.string)
        (Json.at [ "Spec", "TaskTemplate", "ContainerSpec" ] containerSpec)


task : Json.Decoder Task
task =
    Json.map7 Task
        (Json.at [ "ID" ] Json.string)
        (Json.at [ "ServiceID" ] Json.string)
        (Json.maybe (Json.at [ "NodeID" ] Json.string))
        (Json.at [ "Slot" ] Json.int)
        -- https://github.com/docker/swarmkit/blob/master/design/task_model.md#task-lifecycle
        (Json.at [ "Status", "State" ] Json.string)
        (Json.at [ "DesiredState" ] Json.string)
        (Json.at [ "Spec", "ContainerSpec" ] containerSpec)


dockerApi : Json.Decoder Docker
dockerApi =
    Json.map3 Docker
        (Json.at [ "nodes" ] (Json.list node))
        (Json.at [ "services" ] (Json.list service))
        (Json.at [ "tasks" ] (Json.list task))


parse : String -> Result String Docker
parse =
    Json.decodeString dockerApi

module Docker.Json exposing (parse)

import Docker.Types exposing (..)
import Json.Decode as Json


node : Json.Decoder Node
node =
    Json.map4 Node
        (Json.at [ "ID" ] Json.string)
        (Json.at [ "Description", "Hostname" ] Json.string)
        (Json.at [ "Spec", "Role" ] Json.string)
        (Json.at [ "Spec", "Availability" ] Json.string)


service : Json.Decoder Service
service =
    Json.map2 Service
        (Json.at [ "ID" ] Json.string)
        (Json.at [ "Spec", "Name" ] Json.string)


task : Json.Decoder Task
task =
    Json.map5 Task
        (Json.at [ "ID" ] Json.string)
        (Json.at [ "ServiceID" ] Json.string)
        (Json.at [ "NodeID" ] Json.string)
        (Json.at [ "Slot" ] Json.int)
        -- https://github.com/docker/swarmkit/blob/master/design/task_model.md#task-lifecycle
        (Json.at [ "Status", "State" ] Json.string)


dockerApi : Json.Decoder Docker
dockerApi =
    Json.map3 Docker
        (Json.at [ "nodes" ] (Json.list node))
        (Json.at [ "services" ] (Json.list service))
        (Json.at [ "tasks" ] (Json.list task))


parse : String -> Result String Docker
parse =
    Json.decodeString dockerApi

module Docker.Types exposing (..)

import Dict exposing (Dict)
import Date exposing (Date)


type alias NodeId =
    String


type alias ServiceId =
    String


type alias ContainerSpec =
    { image : String }


type alias Node =
    { id : NodeId
    , name : String
    , role : String
    , state : String
    }


type alias Service =
    { id : ServiceId
    , name : String
    , containerSpec : ContainerSpec
    }


type alias TaskStatus =
    { timestamp : Date
    , state : String
    }


type alias Task =
    { id : String
    , serviceId : String
    , nodeId : Maybe String
    , slot : Int
    , status : TaskStatus
    , desiredState : String
    , containerSpec : ContainerSpec
    }


type alias PlannedTask =
    { id : String
    , serviceId : String
    , slot : Int
    , status : TaskStatus
    , desiredState : String
    , containerSpec : ContainerSpec
    }


plannedTask : Task -> PlannedTask
plannedTask { id, serviceId, slot, status, desiredState, containerSpec } =
    PlannedTask id serviceId slot status desiredState containerSpec


type alias AssignedTask =
    { id : String
    , serviceId : String
    , nodeId : String
    , slot : Int
    , status : TaskStatus
    , desiredState : String
    , containerSpec : ContainerSpec
    }


assignedTask : Task -> AssignedTask
assignedTask { id, serviceId, nodeId, slot, status, desiredState, containerSpec } =
    AssignedTask id serviceId (Maybe.withDefault "" nodeId) slot status desiredState containerSpec


type alias Docker =
    { nodes : List Node
    , services : List Service
    , plannedTask : List PlannedTask
    , assignedTasks : List AssignedTask
    }


type alias DockerApiData =
    { nodes : List Node
    , services : List Service
    , tasks : List Task
    }


type alias TaskIndexKey =
    ( NodeId, ServiceId )


type alias TaskIndex =
    Dict TaskIndexKey (List AssignedTask)


taskIndexKey : AssignedTask -> TaskIndexKey
taskIndexKey { nodeId, serviceId } =
    ( nodeId, serviceId )

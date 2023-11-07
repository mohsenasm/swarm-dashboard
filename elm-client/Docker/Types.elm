module Docker.Types exposing (..)

import Dict exposing (Dict)
import Date exposing (Date)


type alias NodeId =
    String


type alias ServiceId =
    String


type alias NetworkId =
    String


type alias ContainerSpec =
    { image : String }


type alias NodeStatus =
    { state : String
    , address : String
    }


type alias ManagerStatus =
    { leader : Bool
    , reachability : String
    }


type alias Node =
    { id : NodeId
    , name : String
    , role : String
    , status : NodeStatus
    , managerStatus : Maybe ManagerStatus
    , info : Maybe String
    }


type alias Network =
    { id : NetworkId
    , name : String
    , ingress : Bool
    }


type alias RawService =
    { id : ServiceId
    , name : String
    , containerSpec : ContainerSpec
    , networks : List NetworkId
    }


type alias Service =
    { id : ServiceId
    , name : String
    , containerSpec : ContainerSpec
    , networks : List Network
    }


type alias TaskStatus =
    { timestamp : Date
    , timestateInfo : Maybe String
    , state : String
    }


type alias TaskInfo =
    { cpu : Maybe String
    , memory : Maybe String
    }


type alias Task =
    { id : String
    , serviceId : String
    , nodeId : Maybe String
    , slot : Maybe Int
    , status : TaskStatus
    , desiredState : String
    , containerSpec : ContainerSpec
    , info : TaskInfo
    }


type alias PlannedTask =
    { id : String
    , serviceId : String
    , slot : Maybe Int
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
    , slot : Maybe Int
    , status : TaskStatus
    , desiredState : String
    , containerSpec : ContainerSpec
    , info : TaskInfo
    }


assignedTask : Task -> AssignedTask
assignedTask { id, serviceId, nodeId, slot, status, desiredState, containerSpec, info } =
    AssignedTask id serviceId (Maybe.withDefault "" nodeId) slot status desiredState containerSpec info


type alias Docker =
    { nodes : List Node
    , networks : List Network
    , services : List Service
    , plannedTasks : List PlannedTask
    , assignedTasks : List AssignedTask
    , refreshTime : String
    }


type alias DockerApiData =
    { nodes : List Node
    , networks : List Network
    , services : List RawService
    , tasks : List Task
    , refreshTime : String
    }


type alias TaskIndexKey =
    ( NodeId, ServiceId )


type alias TaskIndex =
    Dict TaskIndexKey (List AssignedTask)


taskIndexKey : AssignedTask -> TaskIndexKey
taskIndexKey { nodeId, serviceId } =
    ( nodeId, serviceId )

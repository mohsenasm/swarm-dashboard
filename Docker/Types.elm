module Docker.Types exposing (..)

import Dict exposing (Dict)


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


type alias Task =
    { id : String
    , serviceId : String
    , nodeId : Maybe String
    , slot : Int
    , state : String
    , desiredState : String
    , containerSpec : ContainerSpec
    }


type alias Docker =
    { nodes : List Node
    , services : List Service
    , tasks : List Task
    }


type alias TaskIndexKey =
    ( NodeId, ServiceId )


type alias TaskIndex =
    Dict TaskIndexKey (List Task)

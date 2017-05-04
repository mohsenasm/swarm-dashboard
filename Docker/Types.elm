module Docker.Types exposing (..)

import Dict exposing (Dict)


type alias NodeId =
    String


type alias ServiceId =
    String


type alias Node =
    { id : NodeId
    , name : String
    , role : String
    , state : String
    }


type alias Service =
    { id : ServiceId
    , name : String
    }


type alias Task =
    { id : String
    , serviceId : String
    , nodeId : String
    , slot : Int
    , state : String
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

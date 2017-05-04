module Main exposing (..)

import Dict exposing (Dict)
import Json.Decode as Json
import Html exposing (..)
import Html.Attributes exposing (..)
import Navigation
import WebSocket


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


node : Json.Decoder Node
node =
    Json.map4 Node
        (Json.at [ "ID" ] Json.string)
        (Json.at [ "Description", "Hostname" ] Json.string)
        (Json.at [ "Spec", "Role" ] Json.string)
        (Json.at [ "Spec", "Availability" ] Json.string)


type alias Service =
    { id : ServiceId
    , name : String
    }


service : Json.Decoder Service
service =
    Json.map2 Service
        (Json.at [ "ID" ] Json.string)
        (Json.at [ "Spec", "Name" ] Json.string)


type alias Task =
    { id : String
    , serviceId : String
    , nodeId : String
    , slot : Int
    , state : String
    }


task : Json.Decoder Task
task =
    Json.map5 Task
        (Json.at [ "ID" ] Json.string)
        (Json.at [ "ServiceID" ] Json.string)
        (Json.at [ "NodeID" ] Json.string)
        (Json.at [ "Slot" ] Json.int)
        -- https://github.com/docker/swarmkit/blob/master/design/task_model.md#task-lifecycle
        (Json.at [ "Status", "State" ] Json.string)


type alias ServerData =
    { nodes : List Node
    , services : List Service
    , tasks : List Task
    }


swarmInfoDecoder : Json.Decoder ServerData
swarmInfoDecoder =
    Json.map3 ServerData
        (Json.at [ "nodes" ] (Json.list node))
        (Json.at [ "services" ] (Json.list service))
        (Json.at [ "tasks" ] (Json.list task))


parse : String -> Result String ServerData
parse =
    Json.decodeString swarmInfoDecoder


type alias TaskIndexKey =
    ( NodeId, ServiceId )


type alias TaskIndex =
    Dict TaskIndexKey (List Task)


indexTasks : List Task -> TaskIndex
indexTasks tasks =
    let
        reducer task result =
            let
                key =
                    ( task.nodeId, task.serviceId )

                value =
                    (task :: (Maybe.withDefault [] (Dict.get key result)))
            in
                Dict.insert key value result
    in
        List.foldl reducer Dict.empty tasks


localWebsocket : Navigation.Location -> String
localWebsocket location =
    "ws://" ++ location.host ++ "/stream"


type alias Model =
    { webSocketUrl : String
    , serverJson : String
    , swarmInfo : ServerData
    , tasks : Dict ( NodeId, ServiceId ) (List Task)
    }


type Msg
    = UrlChange Navigation.Location
    | Data String


init : Navigation.Location -> ( Model, Cmd Msg )
init location =
    ( { webSocketUrl = localWebsocket location
      , serverJson = localWebsocket location
      , swarmInfo = ServerData [] [] []
      , tasks = Dict.empty
      }
    , Cmd.none
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Data serverJson ->
            case parse serverJson of
                Ok serverData ->
                    ( { model | serverJson = serverJson, swarmInfo = serverData, tasks = indexTasks serverData.tasks }, Cmd.none )

                Err error ->
                    ( { model | serverJson = serverJson, tasks = Dict.empty }, Cmd.none )

        UrlChange location ->
            ( model, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions model =
    WebSocket.listen model.webSocketUrl Data


taskCmp : Service -> Task -> Html Msg
taskCmp service task =
    li [ class task.state ]
        [ text (service.name ++ "." ++ toString task.slot)
        , br [] []
        , text task.state
        ]


serviceNodeCmp : Service -> TaskIndex -> Node -> Html Msg
serviceNodeCmp service tasksByNodeService node =
    let
        tasks =
            Maybe.withDefault [] (Dict.get ( node.id, service.id ) tasksByNodeService)
    in
        td []
            [ ul [] (List.map (taskCmp service) tasks) ]


serviceCmp : List Node -> TaskIndex -> Service -> Html Msg
serviceCmp nodes tasksByNodeService ({ name } as service) =
    tr []
        ([ th [] [ text name ] ] ++ (List.map (serviceNodeCmp service tasksByNodeService) nodes))


swarmHeader : List Node -> Html Msg
swarmHeader nodes =
    tr [] ([ th [] [] ] ++ (nodes |> List.map (\node -> th [] [ text node.name ])))


swarmGrid : List Service -> List Node -> TaskIndex -> Html Msg
swarmGrid services nodes tasksByNodeService =
    table []
        [ thead [] [ swarmHeader nodes ]
        , tbody [] (List.map (serviceCmp nodes tasksByNodeService) services)
        ]


view : Model -> Html Msg
view { swarmInfo, tasks, serverJson } =
    let
        { services, nodes } =
            swarmInfo
    in
        div []
            [ h1 [] [ text "Swarm" ]
            , swarmGrid services nodes tasks
            , h2 [] [ text "Full API response" ]
            , pre [] [ text serverJson ]
            ]


main : Program Never Model Msg
main =
    Navigation.program UrlChange
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }

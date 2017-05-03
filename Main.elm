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


indexTasks : List Task -> Dict ( NodeId, ServiceId ) (List Task)
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


view : Model -> Html Msg
view model =
    div []
        [ h1 [] [ text "Swarm" ]
        , table []
            [ thead []
                [ tr []
                    ([ th [] [] ] ++ (model.swarmInfo.nodes |> List.map (\node -> th [] [ text node.name ])))
                ]
            , tbody []
                (model.swarmInfo.services
                    |> List.map
                        (\service ->
                            tr []
                                ([ th [] [ text service.name ]
                                 ]
                                    ++ (model.swarmInfo.nodes
                                            |> List.map
                                                (\node ->
                                                    td []
                                                        (case model.tasks |> Dict.get ( node.id, service.id ) of
                                                            Just tasks ->
                                                                [ ul []
                                                                    (List.map
                                                                        (\t ->
                                                                            li [ class t.state ]
                                                                                [ text (service.name ++ "." ++ toString t.slot)
                                                                                , br [] []
                                                                                , text t.id
                                                                                ]
                                                                        )
                                                                        tasks
                                                                    )
                                                                ]

                                                            Nothing ->
                                                                []
                                                        )
                                                )
                                       )
                                )
                        )
                )
            ]
        , h2 [] [ text "Full API response" ]
        , pre [] [ text model.serverJson ]
        ]


main : Program Never Model Msg
main =
    Navigation.program UrlChange
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }

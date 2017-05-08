module Main exposing (..)

import Navigation
import Html exposing (..)
import Dict exposing (Dict)
import WebSocket
import Docker exposing (fromJson, indexTasks)
import Docker.Types exposing (..)
import Components as UI


localWebsocket : Navigation.Location -> String
localWebsocket location =
    if location.protocol == "https:" then
        "wss://" ++ location.host ++ "/stream"
    else
        "ws://" ++ location.host ++ "/stream"


type alias Model =
    { webSocketUrl : String
    , swarm : Docker
    , tasks : TaskIndex
    , errors : List String
    }


type Msg
    = UrlChange Navigation.Location
    | Receive String


init : Navigation.Location -> ( Model, Cmd Msg )
init location =
    ( { webSocketUrl = localWebsocket location
      , swarm = Docker.empty
      , tasks = Dict.empty
      , errors = []
      }
    , Cmd.none
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Receive serverJson ->
            case fromJson serverJson of
                Ok serverData ->
                    ( { model | swarm = serverData, tasks = indexTasks serverData.tasks }, Cmd.none )

                Err error ->
                    ( { model | errors = error :: model.errors }, Cmd.none )

        UrlChange location ->
            ( model, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions model =
    WebSocket.listen model.webSocketUrl Receive


view : Model -> Html Msg
view { swarm, tasks, errors } =
    let
        { services, nodes } =
            swarm
    in
        div []
            [ UI.swarmGrid services nodes tasks
            , ul [] (List.map (\e -> li [] [ text e ]) errors)
            ]


main : Program Never Model Msg
main =
    Navigation.program UrlChange
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }

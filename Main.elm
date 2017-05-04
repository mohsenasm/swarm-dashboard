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
    "ws://" ++ location.host ++ "/stream"


type alias Model =
    { webSocketUrl : String
    , swarm : Docker
    , tasks : TaskIndex
    }


type Msg
    = UrlChange Navigation.Location
    | Receive String


init : Navigation.Location -> ( Model, Cmd Msg )
init location =
    ( { webSocketUrl = localWebsocket location
      , swarm = Docker.empty
      , tasks = Dict.empty
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
                    ( model, Cmd.none )

        UrlChange location ->
            ( model, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions model =
    WebSocket.listen model.webSocketUrl Receive


view : Model -> Html Msg
view { swarm, tasks } =
    let
        { services, nodes } =
            swarm
    in
        div []
            [ h1 [] [ text "Swarm" ]
            , UI.swarmGrid services nodes tasks
            ]


main : Program Never Model Msg
main =
    Navigation.program UrlChange
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }

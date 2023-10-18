module Main exposing (..)

import Navigation
import Html exposing (..)
import Dict exposing (Dict)
import Util exposing (..)
import WebSocket
import Docker.Types exposing (..)
import Docker exposing (fromJson)
import Components as UI
import Http

localWebsocket : Navigation.Location -> String
localWebsocket location =
    if location.protocol == "https:" then
        "wss://" ++ location.host ++ "/stream"
    else
        "ws://" ++ location.host ++ "/stream"


type alias Model =
    { webSocketUrl : String
    , authToken : String
    , swarm : Docker
    , tasks : TaskIndex
    , errors : List String
    }


type Msg
    = GetAuthToken
    | AuthTokenReceived (Result Http.Error String)
    | UrlChange Navigation.Location
    | Receive String

authTokenGetter : Cmd Msg
authTokenGetter =
    Http.send AuthTokenReceived (Http.getString "/auth_token")

init : Navigation.Location -> ( Model, Cmd Msg )
init location =
    ( { webSocketUrl = localWebsocket location
      , authToken = ""
      , swarm = Docker.empty
      , tasks = Dict.empty
      , errors = []
      }
    , authTokenGetter
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GetAuthToken ->
            ( model, authTokenGetter )
        
        AuthTokenReceived result ->
            case result of
                Ok authToken ->
                    ( { model | authToken = authToken }, Cmd.none )

                Err httpError ->
                    ( { model | errors = (toString httpError) :: model.errors }, Cmd.none )  

        Receive serverJson ->
            case fromJson serverJson of
                Ok serverData ->
                    ( { model | swarm = serverData, tasks = groupBy taskIndexKey serverData.assignedTasks }, Cmd.none )

                Err error ->
                    if String.contains "WrongAuthToken" error then
                        ( { model | errors = error :: model.errors }, authTokenGetter )
                    else
                        ( { model | errors = error :: model.errors }, Cmd.none )

        UrlChange location ->
            ( model, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions model =
    if String.isEmpty model.authToken then
        Sub.none
    else
        WebSocket.listen (model.webSocketUrl ++ "?authToken=" ++ model.authToken) Receive


view : Model -> Html Msg
view { swarm, tasks, errors } =
    let
        { services, nodes, networks } =
            swarm
    in
        div []
            [ UI.swarmGrid services nodes networks tasks
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
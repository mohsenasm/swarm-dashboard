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
        "wss://" ++ location.host ++ location.pathname ++ "stream"
    else
        "ws://" ++ location.host ++ location.pathname ++ "stream"


type alias Model =
    { pathname : String
    , webSocketUrl : String
    , authToken : String
    , swarm : Docker
    , tasks : TaskIndex
    , errors : List String
    }


type Msg
    = AuthTokenReceived (Result Http.Error String)
    | UrlChange Navigation.Location
    | Receive String

authTokenGetter : String -> Cmd Msg
authTokenGetter pathname =
    Http.send AuthTokenReceived ( Http.getString ( pathname ++ "auth_token" ) )

init : Navigation.Location -> ( Model, Cmd Msg )
init location =
    ( { pathname = location.pathname
      , webSocketUrl = localWebsocket location
      , authToken = ""
      , swarm = Docker.empty
      , tasks = Dict.empty
      , errors = []
      }
    , authTokenGetter location.pathname
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of        
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
                    if String.contains "WrongAuthToken" error then -- caused by a reconnection
                        ( model, ( authTokenGetter model.pathname ) )
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
        { services, nodes, networks, refreshTime } =
            swarm
    in
        div []
            [ UI.swarmGrid services nodes networks tasks refreshTime
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

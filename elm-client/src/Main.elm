port module Main exposing (..)

import Browser
import Browser.Navigation as Nav
import Url
import Html exposing (..)
import Dict exposing (Dict)
import Util exposing (..)
import Docker.Types exposing (..)
import Docker exposing (fromJson)
import Components as UI
import Http


localWebsocket : Url.Url -> String
localWebsocket location =
    let
        hostWithPort =
            case location.port_ of
                Just p ->
                    location.host ++ ":" ++ String.fromInt p

                Nothing ->
                    location.host
    in
    if location.protocol == Url.Https then
        "wss://" ++ hostWithPort ++ location.path ++ "stream"
    else
        "ws://" ++ hostWithPort ++ location.path ++ "stream"


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
    | UrlChange Url.Url
    | UrlRequested Browser.UrlRequest
    | Receive String


authTokenGetter : String -> Cmd Msg
authTokenGetter pathname =
    Http.get { url = pathname ++ "auth_token", expect = Http.expectString AuthTokenReceived }


port incoming : (String -> msg) -> Sub msg


port connect : String -> Cmd msg


httpErrorToString : Http.Error -> String
httpErrorToString err =
    case err of
        Http.BadUrl urlStr ->
            "BadUrl " ++ urlStr

        Http.Timeout ->
            "Timeout"

        Http.NetworkError ->
            "NetworkError"

        Http.BadStatus statusCode ->
            "BadStatus " ++ String.fromInt statusCode

        Http.BadBody message ->
            "BadBody " ++ message


init : () -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init _ location _ =
    ( { pathname = location.path
      , webSocketUrl = localWebsocket location
      , authToken = ""
      , swarm = Docker.empty
      , tasks = Dict.empty
      , errors = []
      }
    , authTokenGetter location.path
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of        
        AuthTokenReceived result ->
            case result of
                Ok authToken ->
                    let
                        url =
                            model.webSocketUrl ++ "?authToken=" ++ authToken
                    in
                    ( { model | authToken = authToken }, connect url )

                Err httpError ->
                    ( { model | errors = (httpErrorToString httpError) :: model.errors }, Cmd.none )  

        Receive serverJson ->
            case fromJson serverJson of
                Ok serverData ->
                    ( { model | swarm = serverData, tasks = groupBy taskIndexKey serverData.assignedTasks }, Cmd.none )

                Err error ->
                    if String.contains "WrongAuthToken" error then -- caused by a reconnection
                        ( model, ( authTokenGetter model.pathname ) )
                    else
                        ( { model | errors = error :: model.errors }, Cmd.none )

        UrlChange _ ->
            ( model, Cmd.none )

        UrlRequested _ ->
            ( model, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions model =
    if String.isEmpty model.authToken then
        Sub.none
    else
        incoming Receive


view : Model -> Browser.Document Msg
view { swarm, tasks, errors } =
    let
        { services, nodes, networks, refreshTime } =
            swarm
    in
        { title = "Swarm Dashboard"
        , body =
            [ div []
                [ UI.swarmGrid services nodes networks tasks refreshTime
                , ul [] (List.map (\e -> li [] [ text e ]) errors)
                ]
            ]
        }


main : Program () Model Msg
main =
    Browser.application
        { init = init
        , onUrlChange = UrlChange
        , onUrlRequest = UrlRequested
        , subscriptions = subscriptions
        , update = update
        , view = view
        }

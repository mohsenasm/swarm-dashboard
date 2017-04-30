module Main exposing (..)

import Html exposing (..)
import WebSocket


webSocketUrl : String
webSocketUrl =
    "ws://192.168.99.100:8081/stream"


type alias Model =
    String


init : ( Model, Cmd Msg )
init =
    ( "Hello World!", Cmd.none )


type Msg
    = Data String


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Data data ->
            ( data, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions model =
    WebSocket.listen webSocketUrl Data


view : Model -> Html Msg
view model =
    div []
        [ h1 [] [ text "Hello World!" ]
        , p [] [ text model ]
        ]


main : Program Never Model Msg
main =
    program
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }

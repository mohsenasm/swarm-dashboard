module Main exposing (..)

import Html exposing (..)
import Navigation
import WebSocket


localWebsocket : Navigation.Location -> String
localWebsocket location =
    "ws://" ++ location.host ++ "/stream"


type alias Model =
    { webSocketUrl : String
    , data : String
    }


init : Navigation.Location -> ( Model, Cmd Msg )
init location =
    ( { webSocketUrl = localWebsocket location, data = localWebsocket location }, Cmd.none )


type Msg
    = UrlChange Navigation.Location
    | Data String


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Data data ->
            ( { model | data = data }, Cmd.none )

        UrlChange location ->
            ( model, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions model =
    WebSocket.listen model.webSocketUrl Data


view : Model -> Html Msg
view model =
    div []
        [ h1 [] [ text "Hello World!" ]
        , p [] [ text model.data ]
        ]


main : Program Never Model Msg
main =
    Navigation.program UrlChange
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }

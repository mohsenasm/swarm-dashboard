module Main exposing (..)

import Html exposing (..)


type alias Model =
    String


init : ( Model, Cmd Msg )
init =
    ( "Hello World!", Cmd.none )


type Msg
    = Nothing


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Nothing ->
            ( model, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none


view : Model -> Html Msg
view model =
    h1 [] [ text "Hello World!" ]


main : Program Never Model Msg
main =
    program
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }

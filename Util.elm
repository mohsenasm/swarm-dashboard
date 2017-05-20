module Util exposing (..)

import Dict exposing (Dict)
import Set exposing (Set)


complement : (a -> Bool) -> a -> Bool
complement fn =
    \x -> not (fn x)


isJust : Maybe a -> Bool
isJust x =
    Maybe.withDefault False (Maybe.map (\x -> True) x)


groupBy : (a -> comparable) -> List a -> Dict comparable (List a)
groupBy key =
    let
        cons new =
            Maybe.withDefault []
                >> (::) new
                >> Just

        reducer item =
            Dict.update (key item) (cons item)
    in
        List.foldl reducer Dict.empty


indexBy : (a -> comparable) -> List a -> Dict comparable a
indexBy key =
    let
        cons new =
            Maybe.withDefault new
                >> Just

        reducer item =
            Dict.update (key item) (cons item)
    in
        List.foldl reducer Dict.empty


unique : List comparable -> List comparable
unique =
    Set.fromList >> Set.toList

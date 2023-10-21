module Util exposing (..)

import Dict exposing (Dict)
import Set exposing (Set)


complement : (a -> Bool) -> a -> Bool
complement fn =
    \x -> not (fn x)


isJust : Maybe a -> Bool
isJust x =
    Maybe.withDefault False (Maybe.map (\x -> True) x)


iff : Bool -> a -> a -> a
iff condition true false =
    if condition then
        true
    else
        false


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


indexedFoldl : (Int -> a -> b -> b) -> b -> List a -> b
indexedFoldl indexedReducer init list =
    let
        reducer item ( idx, accumulator ) =
            ( idx + 1, indexedReducer idx item accumulator )
    in
        list |> (List.foldl reducer ( 0, init ) >> Tuple.second)

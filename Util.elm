module Util exposing (..)

import Dict exposing (Dict)


complement : (a -> Bool) -> a -> Bool
complement fn =
    \x -> not (fn x)


isJust : Maybe a -> Bool
isJust x =
    Maybe.withDefault False (Maybe.map (\x -> True) x)


groupBy : (a -> comparable) -> List a -> Dict comparable (List a)
groupBy key =
    let
        push new =
            Maybe.withDefault [] >> (::) new >> Just

        reducer item =
            Dict.update (key item) (push item)
    in
        List.foldl reducer Dict.empty

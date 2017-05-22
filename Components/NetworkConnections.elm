module Components.NetworkConnections exposing (Connection(..), NetworkConnections, build, get)

import Dict exposing (Dict)
import Docker.Types exposing (..)
import Util exposing (..)


type alias Bounds =
    ( Int, Int )


type Connection
    = None
    | Through
    | Start
    | Middle
    | End
    | Only


type alias NetworkConnections =
    Dict ( ServiceId, NetworkId ) Connection


type alias NetworkAttachments =
    Dict ( ServiceId, NetworkId ) Bool


attachments : List Service -> NetworkAttachments
attachments services =
    let
        networkReducer : ServiceId -> Network -> NetworkAttachments -> NetworkAttachments
        networkReducer serviceId network attachments =
            Dict.update ( serviceId, network.id ) (always (Just True)) attachments

        serviceReducer : Service -> NetworkAttachments -> NetworkAttachments
        serviceReducer service attachments =
            service.networks |> List.foldl (networkReducer service.id) attachments
    in
        List.foldl serviceReducer Dict.empty services


connectionType : Service -> Network -> Bool -> Int -> Bounds -> Connection
connectionType service network connected idx ( first, last ) =
    if idx < first || idx > last then
        None
    else if idx == first && idx == last then
        Only
    else if idx == first then
        Start
    else if idx == last then
        End
    else if connected then
        Middle
    else
        Through


empty : NetworkConnections
empty =
    Dict.empty


get : ( ServiceId, NetworkId ) -> NetworkConnections -> Connection
get key connections =
    Maybe.withDefault None (Dict.get key connections)


update : ServiceId -> NetworkId -> Connection -> NetworkConnections -> NetworkConnections
update sid nid connection connections =
    Dict.update ( sid, nid ) (always (Just connection)) connections


build : List Service -> List Network -> NetworkConnections
build services networks =
    let
        networkAttachments =
            attachments services

        attached sid nid =
            Maybe.withDefault False (Dict.get ( sid, nid ) networkAttachments)

        updateBounds : Int -> Bool -> Bool -> Bounds -> Bounds
        updateBounds current connected ingress ( first, last ) =
            let
                hasLowerBound =
                    not ingress && first < 0
            in
                ( (iff (connected && hasLowerBound) current first), (iff connected current last) )

        firstAndLastConnection : Network -> Bounds
        firstAndLastConnection n =
            services
                |> Util.indexedFoldl
                    (\idx s bounds -> updateBounds idx (attached s.id n.id) n.ingress bounds)
                    ( -1, -1 )

        updateConnections : Network -> Bounds -> NetworkConnections -> NetworkConnections
        updateConnections n bounds connections =
            services
                |> Util.indexedFoldl
                    (\nidx s connections -> update s.id n.id (connectionType s n (attached s.id n.id) nidx bounds) connections)
                    connections
    in
        networks
            |> List.foldl
                (\network connections -> updateConnections network (firstAndLastConnection network) connections)
                empty

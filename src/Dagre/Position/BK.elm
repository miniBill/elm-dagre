module Dagre.Position.BK exposing (NodePointDict, positionX)

import Dagre.Utils as DU
import Dict exposing (Dict)
import Graph as G
import List.Extra as LE



{-
   This module provides coordinate assignment based on Brandes and Köpf, "Fast
   and Simple Horizontal Coordinate Assignment."
-}
{-
   The following type maps a Node Id to one of the coordinates either x or y
-}


type alias NodePointDict =
    Dict G.NodeId Float


type alias NodeDict =
    Dict G.NodeId G.NodeId


type VertDir
    = Up
    | Down


type HorizDir
    = Left
    | Right


nodeWidth =
    0



{-
   This function is exposed to other modules and runs the Brandes Kopf, Algorithm 4
   TODO: Need to add balance subroutine
-}


positionX : G.Graph n e -> ( List DU.Layer, List DU.Edge ) -> NodePointDict
positionX g ( rankList, edges ) =
    let
        edgesWithType =
            DU.markEdgesWithEdgeType g edges

        ( type1Conflicts, _ ) =
            preprocessing ( rankList, edgesWithType )

        conflicts =
            type1Conflicts

        vhDir =
            List.map (\v -> List.map (\h -> ( v, h )) [ Left, Right ]) [ Up, Down ]
                |> List.concat

        xss =
            List.map (\d -> ( d, positionXHelper g ( rankList, edges ) conflicts d )) vhDir

        smallestWidthAlign =
            findSmallestWidthAlignment (List.map Tuple.second xss) nodeWidth

        alignedXss =
            alignCoordinates xss smallestWidthAlign

        -- xs =
        --     positionXHelper g ( rankList, edges ) conflicts ( Down, Right )
    in
    balance alignedXss



{-
   This is the implementation of Algorithm 1 from Brandes and kopf
   The following function implements the preprocessing step. The algorithm marks
   all the type1 conflicts and type2(to be implemented) conflicts.
   TODO: Type2 Conflicts marking

-}


preprocessing : ( List DU.Layer, List DU.EdgeWithType ) -> ( List DU.Edge, List DU.Edge )
preprocessing ( rankList, edges ) =
    let
        allType1Conflicts =
            findType1Conflicts ( rankList, edges )
    in
    ( allType1Conflicts, [] )



{-
   This function finds the horizontal coordinates for a given Vertical
   and Horizontal direction

-}


positionXHelper : G.Graph n e -> ( List DU.Layer, List DU.Edge ) -> List DU.Edge -> ( VertDir, HorizDir ) -> NodePointDict
positionXHelper g ( rankList, edges ) conflicts ( vDir, hDir ) =
    let
        ( intAdjustedRankList, neighbourFn ) =
            case vDir of
                Up ->
                    ( rankList, DU.alongIncomingEdges edges )

                Down ->
                    ( List.reverse rankList, DU.alongOutgoingEdges edges )

        finalAdjustedRankList =
            case hDir of
                Left ->
                    intAdjustedRankList

                Right ->
                    List.map List.reverse intAdjustedRankList

        ( root, align ) =
            verticalAlignment finalAdjustedRankList conflicts neighbourFn

        xs =
            horizontalCompaction finalAdjustedRankList (sep 50 10 g) root align
    in
    case hDir of
        Left ->
            xs

        Right ->
            Dict.map (\_ c -> -c) xs



{-
   This is the implementation of algorithm 2 of Brandes-Kopf
   This function groups the nodes into blocks and returns two circular
   linked lists, root and align, which is used for the actual horizontal
   Coordinate assignment.
-}


verticalAlignment : List DU.Layer -> List DU.Edge -> DU.NeighbourFn -> ( NodeDict, NodeDict )
verticalAlignment rankList conflicts neighbourFn =
    let
        root =
            Dict.fromList <| List.map (\n -> ( n, n )) (List.concat rankList)

        align =
            Dict.fromList <| List.map (\n -> ( n, n )) (List.concat rankList)

        pos =
            getPosDict rankList

        ( finalRoot, finalAlign ) =
            List.foldl (verticalAlignmentVisitLayer pos conflicts neighbourFn) ( root, align ) rankList
    in
    ( finalRoot, finalAlign )



{-
   This is the implementation of algorithm 3 of Brandes-Kopf
   This function performs the horizontal compaction and Coordinate assignment.
-}


horizontalCompaction : List DU.Layer -> (G.NodeId -> G.NodeId -> Float) -> NodeDict -> NodeDict -> NodePointDict
horizontalCompaction rankList sepFn root align =
    let
        sink =
            Dict.fromList <| List.map (\n -> ( n, n )) (List.concat rankList)

        shift =
            Dict.fromList <| List.map (\n -> ( n, DU.infinity )) (List.concat rankList)

        pred =
            getPredDict rankList

        xs =
            Dict.empty

        roots =
            List.filter (\v -> Just v == Dict.get v root) (List.concat rankList)

        ( updShift, updSink, updXs ) =
            List.foldl (placeBlock pred sepFn root align) ( shift, sink, xs ) roots

        finXs =
            List.foldl (\l xs_ -> List.foldl (assignAbsoluteX root updShift updSink) xs_ l) updXs rankList
    in
    finXs


placeBlock : NodeDict -> (G.NodeId -> G.NodeId -> Float) -> NodeDict -> NodeDict -> G.NodeId -> ( NodePointDict, NodeDict, NodePointDict ) -> ( NodePointDict, NodeDict, NodePointDict )
placeBlock pred sepFn root align v ( shift, sink, xs ) =
    case Dict.get v xs of
        Nothing ->
            let
                xsV =
                    Dict.insert v 0 xs
            in
            placeBlockHelper pred sepFn root align v v ( shift, sink, xsV )

        Just _ ->
            ( shift, sink, xs )



{-
   assigns the absolute x coordinates
   This line differs from the source paper. See
   http://www.inf.uni-konstanz.de/~brandes/publications/ for details.
-}


assignAbsoluteX : NodeDict -> NodePointDict -> NodeDict -> G.NodeId -> NodePointDict -> NodePointDict
assignAbsoluteX root shift sink v xs =
    let
        root_v =
            getNode v root

        xs_v =
            case Dict.get root_v xs of
                Nothing ->
                    Dict.insert v 0 xs

                Just xsRootV ->
                    Dict.insert v xsRootV xs

        shift_sink_root_v =
            case Dict.get root_v sink of
                Nothing ->
                    DU.infinity

                Just sink_root_v ->
                    case Dict.get sink_root_v shift of
                        Nothing ->
                            DU.infinity

                        Just shiftVal ->
                            shiftVal

        xs_v_shifted =
            if v == root_v && shift_sink_root_v < DU.infinity then
                Dict.update v (Maybe.map (\n -> n + shift_sink_root_v)) xs_v

            else
                xs_v
    in
    xs_v_shifted


sep : Float -> Float -> G.Graph n e -> G.NodeId -> G.NodeId -> Float
sep nodeSep edgeSep g v u =
    let
        initDummyId =
            case G.nodeIdRange g of
                Nothing ->
                    0

                Just ( _, maxNodeId ) ->
                    maxNodeId + 1

        getSep =
            \nId ->
                if DU.isDummyNode initDummyId nId then
                    edgeSep

                else
                    nodeSep
    in
    (getSep u + getSep v) / 2 + nodeWidth



{-
   Returns the alignment with the smallest width
-}


findSmallestWidthAlignment : List NodePointDict -> Float -> NodePointDict
findSmallestWidthAlignment xss w =
    let
        minW =
            \xs -> Dict.map (\k v -> v - (w / 2)) xs |> Dict.values |> List.minimum |> Maybe.withDefault 0

        maxW =
            \xs -> Dict.map (\k v -> v + (w / 2)) xs |> Dict.values |> List.maximum |> Maybe.withDefault 0

        xss_ =
            List.map (\xs -> ( xs, maxW xs - minW xs )) xss

        defXs_ =
            Maybe.withDefault ( Dict.empty, 0 ) (LE.getAt 0 xss_)
    in
    LE.minimumBy Tuple.second xss_
        |> Maybe.withDefault defXs_
        |> Tuple.first



{-
   Align the coordinates of each of the layout alignments such that
   left-biased alignments have their minimum coordinate at the same point as
   the minimum coordinate of the smallest width alignment and right-biased
   alignments have their maximum coordinate at the same point as the maximum
   coordinate of the smallest width alignment.
-}


alignCoordinates : List ( ( VertDir, HorizDir ), NodePointDict ) -> NodePointDict -> List NodePointDict
alignCoordinates xss alignTo =
    let
        minX =
            \xs -> Dict.values xs |> List.minimum |> Maybe.withDefault 0

        maxX =
            \xs -> Dict.values xs |> List.maximum |> Maybe.withDefault 0

        alignToMin =
            minX alignTo

        alignToMax =
            maxX alignTo

        delta =
            \hDir xs ->
                case hDir of
                    Left ->
                        alignToMin - minX xs

                    Right ->
                        alignToMax - maxX xs

        deltas =
            List.map (\( ( _, hDir ), xs ) -> delta hDir xs) xss

        xss_ =
            List.map2 (\( ( _, _ ), xs ) del -> Dict.map (\_ x -> x + del) xs) xss deltas
    in
    xss_



{-
   Balances the layout by taking the Average Median of coordinates based on
   different biases.
-}


balance : List NodePointDict -> NodePointDict
balance xss =
    let
        helper =
            \n x xsC ->
                if Dict.member n xsC then
                    Dict.update n (Maybe.map (\xCoords -> x :: xCoords)) xsC

                else
                    Dict.insert n [ x ] xsC

        appendXs =
            \xs xsC -> Dict.foldl helper xsC xs

        multiXs =
            List.foldl appendXs Dict.empty xss

        sortedMultiXs =
            Dict.map (\_ x -> List.sort x) multiXs

        finalX =
            \l ->
                case l of
                    [ _, x1, x2, _ ] ->
                        (x1 + x2) / 2

                    [ _, x, _ ] ->
                        x

                    [ x0, x1 ] ->
                        (x0 + x1) / 2

                    [ x ] ->
                        x

                    [] ->
                        0

                    x :: _ ->
                        x
    in
    Dict.map (\_ xList -> finalX xList) sortedMultiXs



{-
   Following are helper functions for Preprocessing Step (Algorithm 1 from BK)

-}


findType1Conflicts : ( List DU.Layer, List DU.EdgeWithType ) -> List DU.Edge
findType1Conflicts ( rankList, edges ) =
    let
        adjacentLayers =
            DU.getAdjacentLayerPairs rankList
    in
    List.concat <| List.map (type1VisitLayer edges) adjacentLayers


type1VisitLayer : List DU.EdgeWithType -> ( DU.Layer, DU.Layer ) -> List DU.Edge
type1VisitLayer edges ( l1, l2 ) =
    let
        reqEdges =
            DU.getEdgesWithTypeDirectedFromLayers ( l1, l2 ) edges
                |> List.map (DU.mapEdgeWithTypeToOrder ( l1, l2 ))

        prevLayerLength =
            List.length l1

        layerLength =
            List.length l2

        rawType1Conflicts =
            List.foldl (findInnerSegmentAndMarkConflicts ( prevLayerLength, layerLength ) reqEdges) ( ( 0, 0 ), [] ) (List.range 0 (layerLength - 1))
                |> Tuple.second

        type1Conflicts =
            List.map (DU.mapEdgeOrderToNode ( l1, l2 )) rawType1Conflicts
    in
    type1Conflicts


findInnerSegmentAndMarkConflicts : ( Int, Int ) -> List DU.EdgeWithType -> Int -> ( ( Int, Int ), List DU.Edge ) -> ( ( Int, Int ), List DU.Edge )
findInnerSegmentAndMarkConflicts ( prevLayerLength, layerLength ) edges l1 ( ( k0, scanPos ), type1Conflicts ) =
    let
        w =
            findOtherInnerSegmentNode edges l1
    in
    case ( w, l1 == layerLength - 1 ) of
        ( Nothing, False ) ->
            ( ( k0, scanPos ), type1Conflicts )

        ( Just k1, _ ) ->
            let
                subLayer =
                    List.range scanPos l1

                newConflictsList =
                    List.map (markType1Conflicts edges ( k0, k1 )) subLayer

                newConflicts =
                    List.concat newConflictsList
            in
            ( ( k1, l1 + 1 ), List.append type1Conflicts newConflicts )

        ( Nothing, True ) ->
            let
                k1 =
                    prevLayerLength - 1

                subLayer =
                    List.range scanPos l1

                newConflictsList =
                    List.map (markType1Conflicts edges ( k0, k1 )) subLayer

                newConflicts =
                    List.concat newConflictsList
            in
            ( ( k1, l1 + 1 ), List.append type1Conflicts newConflicts )


findOtherInnerSegmentNode : List DU.EdgeWithType -> Int -> Maybe Int
findOtherInnerSegmentNode edges nodeId =
    let
        innerEdges =
            DU.getInEdges nodeId edges |> DU.filterEdgesByType DU.Inner

        upperNodeOfInnerSegments =
            List.map Tuple.first innerEdges
    in
    List.minimum upperNodeOfInnerSegments


markType1Conflicts : List DU.EdgeWithType -> ( Int, Int ) -> Int -> List DU.Edge
markType1Conflicts edges ( k0, k1 ) l =
    let
        nonInnerEdges =
            DU.getInEdges l edges |> DU.filterEdgesByType DU.NonInner

        conflictingNonInnerEdges =
            List.filter (\( f, t ) -> checkType1Conflict ( k0, k1 ) f) nonInnerEdges
    in
    conflictingNonInnerEdges


checkType1Conflict : ( Int, Int ) -> Int -> Bool
checkType1Conflict ( k0, k1 ) k =
    if k < k0 || k > k1 then
        True

    else
        False



{-
   The functions that start from here are helper function for
   Vertical Alignment Function
   based on Algorithm-2 of Brandes and Kopf
-}


getPosDict : List DU.Layer -> Dict G.NodeId Int
getPosDict rankList =
    let
        dictList =
            List.map (\l -> List.map (\n -> ( n, DU.getOrder l n )) l) rankList
                |> List.concat
    in
    Dict.fromList dictList


getPos : Dict G.NodeId Int -> G.NodeId -> Int
getPos pos node =
    case Dict.get node pos of
        Just idx ->
            idx

        Nothing ->
            -1


getNode : G.NodeId -> NodeDict -> G.NodeId
getNode node dict =
    case Dict.get node dict of
        Just x ->
            x

        Nothing ->
            DU.intMin


hasConflict : List DU.Edge -> ( G.NodeId, G.NodeId ) -> Bool
hasConflict conflicts ( u, v ) =
    if List.member ( u, v ) conflicts || List.member ( v, u ) conflicts then
        True

    else
        False


alignVertexHelper : List DU.Edge -> G.NodeId -> ( G.NodeId, Int ) -> ( ( NodeDict, NodeDict ), Int ) -> ( ( NodeDict, NodeDict ), Int )
alignVertexHelper conflicts v ( w, pos_w ) ( ( root, align ), prevIdx ) =
    if getNode v align == v && prevIdx < pos_w && (hasConflict conflicts ( w, v ) |> not) then
        let
            updatedAlignW =
                Dict.update w (Maybe.map (\_ -> v)) align

            updatedRootV =
                Dict.update v (Maybe.map (\_ -> getNode w root)) root

            updatedAlignV =
                Dict.update v (Maybe.map (\_ -> getNode v updatedRootV)) updatedAlignW

            newPrevIdx =
                pos_w
        in
        ( ( updatedRootV, updatedAlignV ), newPrevIdx )

    else
        ( ( root, align ), prevIdx )


alignVertex : Dict G.NodeId Int -> List DU.Edge -> DU.NeighbourFn -> G.NodeId -> ( ( NodeDict, NodeDict ), Int ) -> ( ( NodeDict, NodeDict ), Int )
alignVertex pos conflicts neighbourFn v ( ( root, align ), prevIdx ) =
    let
        ws =
            neighbourFn v |> List.sortBy (getPos pos)

        mp =
            (toFloat (List.length ws) - 1) / 2

        w_mp =
            List.range (floor mp) (ceiling mp)
                |> List.map
                    (\i ->
                        case LE.getAt i ws of
                            Just w ->
                                w

                            Nothing ->
                                DU.intMin
                    )
                |> List.filter (\w -> w /= DU.intMin)
                |> List.map (\w -> ( w, getPos pos w ))

        updatedValues =
            List.foldl (alignVertexHelper conflicts v) ( ( root, align ), prevIdx ) w_mp
    in
    updatedValues


verticalAlignmentVisitLayer : Dict G.NodeId Int -> List DU.Edge -> DU.NeighbourFn -> DU.Layer -> ( NodeDict, NodeDict ) -> ( NodeDict, NodeDict )
verticalAlignmentVisitLayer pos conflicts neighbourFn layer ( root, align ) =
    let
        ( ( finalRoot, finalAlign ), _ ) =
            List.foldl (alignVertex pos conflicts neighbourFn) ( ( root, align ), -1 ) layer
    in
    ( finalRoot, finalAlign )



{-
   The following functions are Helper Functions for Algorithm 3 of Brandes-Kopf
-}


getPredDictHelper : DU.Layer -> NodeDict -> NodeDict
getPredDictHelper layer pred =
    let
        predecessors =
            List.take (List.length layer - 1) layer

        nodes =
            List.drop 1 layer

        nodesWithPreds =
            List.map2 Tuple.pair nodes predecessors

        finalDict =
            List.foldl (\( n, p ) predDict -> Dict.insert n p predDict) pred nodesWithPreds
    in
    finalDict


getPredDict : List DU.Layer -> NodeDict
getPredDict rankList =
    let
        initDict =
            Dict.empty

        pred =
            List.foldl getPredDictHelper initDict rankList
    in
    pred


updateShiftOrXS : Float -> NodeDict -> G.NodeId -> G.NodeId -> ( NodePointDict, NodePointDict ) -> ( NodePointDict, NodePointDict )
updateShiftOrXS delta sink u v ( shift, xs ) =
    if Dict.get v sink /= Dict.get u sink then
        let
            sink_u_ =
                Dict.get u sink

            xs_v_ =
                Dict.get v xs

            xs_u_ =
                Dict.get u xs

            shift_sink_u_ =
                Maybe.andThen (\sink_u -> Dict.get sink_u shift) sink_u_

            updateValue =
                case ( shift_sink_u_, xs_v_, xs_u_ ) of
                    ( Just ss_u, Just xs_v, Just xs_u ) ->
                        Just (min ss_u (xs_v - xs_u - delta))

                    _ ->
                        Nothing

            updatedShift =
                case sink_u_ of
                    Just sink_u ->
                        Dict.update sink_u (\_ -> updateValue) shift

                    _ ->
                        shift
        in
        ( updatedShift, xs )

    else
        let
            xs_v_ =
                Dict.get v xs

            xs_u_ =
                Dict.get u xs

            updateValue =
                case ( xs_v_, xs_u_ ) of
                    ( Just xs_v, Just xs_u ) ->
                        Just (max xs_v (xs_u + delta))

                    _ ->
                        Nothing

            updatedXS =
                Dict.update v (\_ -> updateValue) xs
        in
        ( shift, updatedXS )


placePredecessor : G.NodeId -> NodeDict -> (G.NodeId -> G.NodeId -> Float) -> NodeDict -> NodeDict -> G.NodeId -> G.NodeId -> ( NodePointDict, NodeDict, NodePointDict ) -> ( NodePointDict, NodeDict, NodePointDict )
placePredecessor p pred sepFn root align v w ( shift, sink, xs ) =
    let
        root_p_ =
            Dict.get p root

        ( pred_shift, pred_sink, pred_xs ) =
            case root_p_ of
                Nothing ->
                    ( shift, sink, xs )

                Just u ->
                    placeBlock pred sepFn root align u ( shift, sink, xs )

        updatedSink =
            if Dict.get v pred_sink == Just v then
                Dict.update v (\_ -> Dict.get (getNode p root) pred_sink) pred_sink

            else
                pred_sink

        delta =
            sepFn w p

        ( updatedShift, updatedXS ) =
            case root_p_ of
                Nothing ->
                    ( pred_shift, pred_xs )

                Just u ->
                    updateShiftOrXS delta updatedSink u v ( pred_shift, pred_xs )
    in
    ( updatedShift, updatedSink, updatedXS )


placeBlockHelper : NodeDict -> (G.NodeId -> G.NodeId -> Float) -> NodeDict -> NodeDict -> G.NodeId -> G.NodeId -> ( NodePointDict, NodeDict, NodePointDict ) -> ( NodePointDict, NodeDict, NodePointDict )
placeBlockHelper pred sepFn root align v w ( shift, sink, xs ) =
    let
        ( final_shift, final_sink, final_xs ) =
            case Dict.get w pred of
                Nothing ->
                    ( shift, sink, xs )

                Just p ->
                    placePredecessor p pred sepFn root align v w ( shift, sink, xs )

        w_new_ =
            Dict.get w align
    in
    if w_new_ == Just v then
        ( final_shift, final_sink, final_xs )

    else
        case w_new_ of
            Nothing ->
                ( final_shift, final_sink, final_xs )

            Just w_new ->
                placeBlockHelper pred sepFn root align v w_new ( final_shift, final_sink, final_xs )


getWidth : Dict G.NodeId Float -> Float -> G.NodeId -> Float
getWidth widthDict defaultWidth nodeId =
    Dict.get nodeId widthDict
        |> Maybe.withDefault defaultWidth
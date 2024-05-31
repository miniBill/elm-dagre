module Simple exposing (..)

import Graph as G
import Html
import Render as R
import Dagre.Attributes as DA


simpleGraph : G.Graph Int ()
simpleGraph =
    G.fromNodeLabelsAndEdgePairs
        (List.range 0 22)
        [ ( 0, 3 )
        , ( 0, 4 )
        , ( 0, 5 )
        , ( 0, 6 )
        , ( 0, 7 )
        , ( 0, 8 )
        , ( 0, 9 )
        , ( 1, 6 )
        , ( 1, 18 )
        , ( 5, 20 )
        , ( 5, 21 )
        , ( 5, 22 )
        , ( 6, 11 )
        , ( 9, 12 )
        , ( 9, 13 )
        , ( 9, 14 )
        , ( 9, 15 )
        , ( 10, 12 )
        , ( 13, 16 )
        , ( 13, 17 )
        , ( 13, 18 )
        , ( 13, 19 )
        ]


simpleGraph2 : G.Graph Int ()
simpleGraph2 =
    G.fromNodeLabelsAndEdgePairs
        (List.range 1 23)
        -- [ ( 1, 3 )
        -- , ( 1, 4 )
        -- , ( 1, 13 )
        -- , ( 1, 21 )
        -- , ( 2, 3 )
        -- , ( 2, 20 )
        -- , ( 3, 4 )
        -- , ( 3, 5 )
        -- , ( 3, 23 )
        -- , ( 4, 6 )
        -- , ( 5, 7 )
        -- , ( 6, 8 )
        -- , ( 6, 16 )
        -- , ( 6, 23 )
        -- , ( 7, 9 )
        -- , ( 8, 10 )
        -- , ( 8, 11 )
        -- , ( 9, 12 )
        -- , ( 10, 13 )
        -- , ( 10, 14 )
        -- , ( 10, 15 )
        -- , ( 11, 15 )
        -- , ( 11, 16 )
        -- , ( 12, 20 )
        -- , ( 13, 17 )
        -- , ( 14, 17 )
        -- , ( 14, 18 )
        -- , ( 16, 18 )
        -- , ( 16, 19 )
        -- , ( 16, 20 )
        -- , ( 18, 21 )
        -- , ( 19, 22 )
        -- , ( 21, 23 )
        -- , ( 22, 23 )


        -- ]
        [(0, 2), (0, 3), (0, 12), (0, 20), (1, 2), (1, 19), (2, 3), (2, 4), (2, 22), (3, 5), (4, 6), (5, 7), (5, 15), (5, 22), (6, 8), (7, 9), (7, 10), (8, 11), (9, 12), (9, 13), (9, 14), (10, 14), (10, 15), (11, 19), (12, 16), (13, 16), (13, 17), (15, 17), (15, 18), (15, 19), (17, 20), (18, 21), (20, 22), (21, 22)]


main : Html.Html msg
main =
    R.draw
        [ DA.rankDir DA.TB
        , DA.nodeSep 10
        ]
        [ R.style "height: 100vh;"
        ]
        simpleGraph
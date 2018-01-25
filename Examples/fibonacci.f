
: NEXT-FIBONACCI ( limit n1 n2 -- limit n2 n1+n2 )
    SWAP    ( limit n2 n1 )
    DUP     ( limit n2 n1 n1 )
    .       ( limit n2 n1 )
    OVER    ( limit n2 n1 n2 )
    +       ( limit n2 n1+n2 )
    DUP     ( limit n2 n1+n2 n1+n2 )
    3 PICK  ( limit n2 n1+n2 n1+n2 limit )
    < IF    ( limit n2 n1+n2 )
        RECURSE
    THEN
    EXIT    ( limit n2 n1+n2 )
;

: FIBONACCI ( limit -- )
    1 1                     ( limit 1 1 )
    NEXT-FIBONACCI          ( limit x y )
    DROP DROP DROP
    CR
;

1134903171 FIBONACCI

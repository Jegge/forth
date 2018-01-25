

: FIBONACCI ( n1 n2 -- n2 n1+n2 )
    SWAP ( n2 n1 )
    DUP  ( n2 n1 n1 )
    .    ( n2 n1 )
    OVER ( n2 n1 n2 )
    +    ( n2 n1+n2 )
;




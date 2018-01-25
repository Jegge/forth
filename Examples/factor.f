
: FACTOR ( limit -- result )
    DUP 1 = IF  ( 1 -- 1 )
        EXIT
    THEN
    DUP         ( limit limit )
    1-          ( limit limit-1 )
    RECURSE     ( limit limit-1 limit-2 limit-3 ... 1 )
    *
;

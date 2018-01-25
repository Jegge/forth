
\ https://projecteuler.net/problem=1

: IS-MULTIPLE   ( n1 n2 -- 0/1 if n1 is multiple of n2 )
    MOD
    NOT
;

: PEULER-001 ( limit -- result )
    0 SWAP 1            ( sum limit index )
    DO
        I 3 IS-MULTIPLE ( sum r1 )
        I 5 IS-MULTIPLE ( sum r1 r2 )
        OR IF           ( sum r1&r2)
            I +         ( sum+i)
        THEN
    LOOP
;

\-------------------------------------------------------------------------------------------

\ https://projecteuler.net/problem=2

: IS-EVEN       ( n1 -- 0/1 )
    2 MOD NOT
;

: FIBONACCI ( n1 n2 -- n2 n1+n2 n1 )
    2DUP    ( n1 n2 n1 n2 )
    +       ( n1 n2 n1+n2 )
    ROT     ( n2 n1+n2 n1 )
;

: PEULER-002
    0                   ( sum )
    1 1                 ( sum n1 n2 )
    BEGIN
        FIBONACCI       ( sum n1 n2 res )
        DUP IS-EVEN IF
            2SWAP       ( n2 res sum n1 )
            -ROT        ( n2 n1 res sum )
            +           ( n2 n1 sum )
            ROT         ( sum n2 n1 )
            SWAP        ( sum n1 n2 )
        THEN
        DUP 100 >
    UNTIL
;




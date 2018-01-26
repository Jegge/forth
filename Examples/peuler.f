
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
        OR IF           ( sum r1|r2 )
            I +         ( sum )
        THEN
    LOOP
;

\-------------------------------------------------------------------------------------------

\ https://projecteuler.net/problem=2

: IS-EVEN       ( n1 -- 0/1 )
    2 MOD NOT
;

: FIBONACCI ( n1 n2 -- n2 n1+n2 )
    TUCK    ( n2 n1 n2 )
    +       ( n2 n1+n2 )
;

: PEULER-002    ( limit -- result )
    0 1 1               ( limit sum n1 n2 )
    BEGIN
        DUP 4 PICK <    \ while n2 < limit
    WHILE               ( limit sum n1 n2 )
        FIBONACCI       ( limit sum n1 n2 )
        OVER IS-EVEN IF \ if n1 is even...
            OVER        ( limit sum n1 n2 n1 )
            2SWAP       ( limit n2 n1 sum n1 )
            +           ( limit n2 n1 sum )
            -ROT        ( limit sum n2 n1 )
            SWAP        ( limit sum n1 n2 )
        THEN
    REPEAT
    2DROP               ( limit sum )
    NIP                 ( sum )
;




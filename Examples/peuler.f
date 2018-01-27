\-------------------------------------------------------------------------------------------
\
\ https://projecteuler.net/problem=1
\

: IS-MULTIPLE   ( n1 n2 -- 0/1 if n1 is multiple of n2 )
    MOD NOT
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
\
\ https://projecteuler.net/problem=2
\

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

\-------------------------------------------------------------------------------------------
\
\ https://projecteuler.net/problem=3
\

: IS-EVEN       ( n1 -- 0/1 )
    2 MOD NOT
;

: IS-MULTIPLE   ( n1 n2 -- 0/1 ) \ n1 is a multiple of n2
    MOD NOT
;

: IS-PRIME     ( n -- 0/1 )
    DUP 2 = IF
        DROP                    (   )
        TRUE                    ( result )
        EXIT
    THEN
    DUP IS-EVEN IF
        DROP                    (   )
        FALSE                   ( result )
        EXIT
    THEN                        ( n )
    3                           ( n index )
    BEGIN
        2DUP                    ( n index n index )
        SWAP                    ( n index index n )
        2 /                     ( n index index limit )
        <                       \ while index < limit
    WHILE                       ( n index )
        2DUP IS-MULTIPLE IF     \ if n is a multiple of index
            2DROP               (   )
            FALSE               ( result )
            EXIT
        THEN
        1+ 1+                   ( n index )
    REPEAT
    2DROP                       (   )
    TRUE                        ( result )
;

: NEXT-PRIME-FACTOR ( n, factor -- n, factor )
    BEGIN
        2DUP                    ( n factor n factor )
        SWAP                    ( n factor factor n )
        2 /                     ( n factor factor limit )
        <                       \ while factor < limit
    WHILE                       ( n factor )
        2DUP IS-MULTIPLE IF     \ if n is a multiple of factor
            DUP IS-PRIME IF     \ if factor is a prime
                TUCK            ( factor n factor )
                /               ( factor n )
                SWAP            ( n factor )
                EXIT
            THEN
        THEN
        1+
    REPEAT                      ( factor n )
    1-
;

: PEULER-003 ( n -- factor )
    2                           ( n factor )
    BEGIN
        OVER IS-PRIME NOT       \ while n is not prime
    WHILE
        NEXT-PRIME-FACTOR       ( n factor )
        2DUP . . CR
    REPEAT
    DROP                        ( n )
;

\-------------------------------------------------------------------------------------------
\
\ https://projecteuler.net/problem=4
\





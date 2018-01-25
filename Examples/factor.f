

: FACTOR ( n1 -- result )
    DUP     ( n1 n1 index )
    0       ( n1 n1 index )
    DO      ( n1 )
        I   ( n1 I )
        1+  ( n1 I+1 )
        *   ( n1*I+1 )
    LOOP
;



: FACTOR ( n1 -- result )
DUP 0   ( n1 n1 0 )
DO
I . CR
LOOP
;



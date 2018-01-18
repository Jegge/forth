\ bootstrap code - see http://git.annexia.org/?p=jonesforth.git;a=blob;f=jonesforth.f;h=5c1309574ae1165195a43250c19c822ab8681671;hb=HEAD

\ Define some character constants
: '\n' 10 ;
: BL   32 ; \ BL (BLank) is a standard FORTH word for space.

\ CR prints a carriage return
: CR '\n' EMIT ;

\ SPACE prints a space
: SPACE BL EMIT ;

\ NEGATE leaves the negative of a number on the stack.
: NEGATE 0 SWAP - ;

\ Standard words for booleans.
: TRUE  1 ;
: FALSE 0 ;
: NOT   0= ;

\ LITERAL takes whatever is on the stack and compiles LIT <foo>
: LITERAL IMMEDIATE ' LIT , , ;
: ':' [ CHAR : ] LITERAL ;
: ';' [ CHAR ; ] LITERAL ;
: '(' [ CHAR ( ] LITERAL ;
: ')' [ CHAR ) ] LITERAL ;
: '"' [ CHAR " ] LITERAL ;
: 'A' [ CHAR A ] LITERAL ;
: '0' [ CHAR 0 ] LITERAL ;
: '-' [ CHAR - ] LITERAL ;
: '.' [ CHAR . ] LITERAL ;

\ While compiling, '[COMPILE] word' compiles 'word' if it would otherwise be IMMEDIATE.
: [COMPILE] IMMEDIATE WORD FIND , ;

\ RECURSE makes a recursive call to the current word that is being compiled.
: RECURSE IMMEDIATE LATEST , ;


\ condition IF true-part THEN rest              --> compiles to:  condition 0BRANCH OFFSET true-part rest
\ condition IF true-part ELSE false-part THEN   --> compiles to:  condition 0BRANCH OFFSET true-part BRANCH OFFSET2 false-part rest

: IF IMMEDIATE
    ' 0BRANCH , \ compile 0BRANCH
    IP@         \ get current instruction address on stack
    0 ,         \ insert dummy offset
;

: THEN IMMEDIATE
    DUP         \ on stack: two times address of previous 0BRANCH
    IP@ SWAP -  \ on stack: previous address, offset to previous address
    SWAP IP!    \ write offset to previous address
;

: ELSE IMMEDIATE
    ' BRANCH ,  \ compile BRANCH
    IP@         \ get current instruction address on stack
    0 ,         \ insert dummy offset
    SWAP
    DUP
    IP@ SWAP -
    SWAP IP!    \ write offset to previous address
;

\ BEGIN loop-part condition UNTIL   --> compiles to: loop-part condition 0BRANCH OFFSET

: BEGIN IMMEDIATE
    IP@                 \ store current instruction address on stack
;

: UNTIL IMMEDIATE
    ' 0BRANCH ,         \ compile 0BRANCH
    IP@ - 1-            \ get offset from current instruction address from the one on stack (also omit the 0branch itself)
    ,                   \ compile offset
;

\ BEGIN loop-part AGAIN     --> compiles to: loop-part BRANCH OFFSET

: AGAIN IMMEDIATE
    ' BRANCH ,         \ compile BRANCH
    IP@ - 1-            \ get offset from current instruction address from the one on stack (also omit the 0branch itself)
    ,                   \ compile offset
;


\ BEGIN condition WHILE loop-part REPEAT    --> compiles to: condition 0BRANCH OFFSET2 loop-part BRANCH OFFSET
\       where OFFSET points back to condition (the beginning) and OFFSET2 points to after the whole piece of code

: WHILE IMMEDIATE
    ' 0BRANCH , \ compile 0BRANCH
    IP@         \ get current instruction address on stack
    0 ,         \ insert dummy offset
;

: REPEAT IMMEDIATE
    ' BRANCH ,      \ compile BRANCH
    SWAP            \ get the original offset (from BEGIN)
    IP@ - 1- ,      \ and compile it after BRANCH (and take BRANCH into account)
    DUP
    IP@ SWAP -      \ calculate the offset2
    SWAP IP!        \ and back-fill it in the original location
;


\ UNLESS is a reversed IF
: UNLESS IMMEDIATE
    ' NOT ,         \ compile NOT (to reverse the test)
    [COMPILE] IF    \ continue by calling the normal IF
;

\ multiline comments
: ( IMMEDIATE
    1
    BEGIN
        KEY
        DUP '(' = IF
            DROP
            1+
        ELSE
            ')' = IF
                1-
            THEN
        THEN
    DUP 0= UNTIL
    DROP
;

\ some stack operations
: NIP ( x y -- y ) SWAP DROP ;
: TUCK ( x y -- y x y ) SWAP OVER ;

\ write spaces to stdout
: SPACES        ( n -- )
    BEGIN
        DUP 0>          ( while n > 0 )
    WHILE
        SPACE           ( print a space )
        1-              ( until we count down to 0 )
    REPEAT
    DROP
;

\ setting the base
: DECIMAL ( -- ) 10 BASE ! ;
: HEX ( -- ) 16 BASE ! ;

\ number formatting: unsigned numbers
: U.                ( u -- )
    BASE @ /MOD     ( width rem quot )
    ?DUP IF         ( if quotient <> 0 then )
        RECURSE     ( print the quotient )
    THEN
    ( print the remainder )
    DUP 10 < IF
        '0'             ( decimal digits 0..9 )
    ELSE
        10 -            ( hex and beyond digits A..Z )
        'A'
    THEN
    +
    EMIT
;

(  prints the contents of the stack.  It doesn't alter the stack. )
: .S ( -- )
    DSP@
    BEGIN
        DUP 0>
    WHILE
        DUP PICK U.
        SPACE
        1-
    REPEAT
    DROP
;


( This word returns the width (in characters) of an unsigned number in the current base )
: UWIDTH             ( u -- width )
    BASE @ /        ( rem quot )
    ?DUP IF         ( if quotient <> 0 then )
        RECURSE 1+  ( return 1+recursive call )
    ELSE
        1               ( return 1 )
    THEN
;

: U.R           ( u width -- )
    SWAP            ( width u )
    DUP             ( width u u )
    UWIDTH          ( width u uwidth )
    ROT             ( u uwidth width )
    SWAP -          ( u width-uwidth )
    SPACES
    U.
;

( .R prints a signed number, padded to a certain width. )
: .R            ( n width -- )
    SWAP            ( width n )
    DUP 0< IF
        NEGATE      ( width u )
        1           ( save a flag to remember that it was negative | width n 1 )
        SWAP        ( width 1 u )
        ROT         ( 1 u width )
        1-          ( 1 u width-1 )
    ELSE
        0           ( width u 0 )
        SWAP        ( width 0 u )
        ROT         ( 0 u width )
    THEN
    SWAP            ( flag width u )
    DUP             ( flag width u u )
    UWIDTH          ( flag width u uwidth )
    ROT             ( flag u uwidth width )
    SWAP -          ( flag u width-uwidth )
    SPACES          ( flag u )
    SWAP            ( u flag )
    IF              ( was it negative? print the - character )
        '-' EMIT
    THEN
    U.
;

: . 0 .R SPACE ;
: U. U. SPACE ;

( ? fetches the integer at an address and prints it. )
: ? ( addr -- ) @ . ;

( WORDS prints all the words defined in the dictionary, starting with the word defined most recently. However it doesn't print hidden words. )
: WORDS
    LATEST                  ( latest )
    BEGIN
        DUP 0>
    WHILE
        DUP ?HIDDEN NOT IF  ( ignore hidden words )
            DUP ID.         ( but if not hidden, print the word )
            SPACE
        THEN
        1-               
    REPEAT
    CR
;


\: TEST 65 BEGIN DUP 70 < WHILE DUP EMIT 1+ REPEAT ;
\ LATEST SEE
\ 1 TRACE !




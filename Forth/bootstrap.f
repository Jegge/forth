\ 
\ HOUSEKEEPING ----------------------------------------------------------------------
\ 

\ LITERAL takes whatever <foo> is on the stack and compiles LIT <foo>
: LITERAL IMMEDIATE
    ' LIT , \ compile LIT
    ,       \ compile the literal itself (from the stack)
;

\ While compiling, '[COMPILE] word' compiles 'word' if it would otherwise be IMMEDIATE.
: [COMPILE] IMMEDIATE
    WORD        \ get the next word
    FIND        \ find it in the dictionary
    >CFA        \ get its codeword
    ,           \ and compile that
;


\ RECURSE makes a recursive call to the current word that is being compiled.
: RECURSE IMMEDIATE  \ ( -- )
    LATEST @
    >CFA
    ,
;

\ 
\ CHARACTER constants ----------------------------------------------------------------------
\ 

: '\n' 10 ;         \ ( -- 10 )   Newline
: BL   32 ;         \ ( -- 32 )   Blank

: ':' [ CHAR : ] LITERAL ;
: ';' [ CHAR ; ] LITERAL ;
: '(' [ CHAR ( ] LITERAL ;
: ')' [ CHAR ) ] LITERAL ;
: '"' [ CHAR " ] LITERAL ;
: 'A' [ CHAR A ] LITERAL ;
: '0' [ CHAR 0 ] LITERAL ;
: '-' [ CHAR - ] LITERAL ;
: '.' [ CHAR . ] LITERAL ;
: '[' [ CHAR [ ] LITERAL ;

: CR '\n' EMIT ;    \ ( -- )
: ESC 27 EMIT ;     \ ( -- )
: SPACE BL EMIT ;   \ ( -- )


\ BOOLEAN values
: TRUE  1 ;         \ ( -- 1 )
: FALSE 0 ;         \ ( -- 0 )
: NOT   0= ;        \ ( n -- !n )

\ NUMBER Formatting
: . 0 .R SPACE ;    \ ( n -- )
: U. 0 U.R SPACE ;  \ ( u -- )
: ? @ . ;           \ ( addr -- )

\ 
\ STATE manipulation ----------------------------------------------------------------------
\ 

: DECIMAL 10 BASE ! ;   \ ( -- )
: HEX 16 BASE ! ;       \ ( -- )
: OCTAL 8 BASE ! ;      \ ( -- )
: BINARY 2 BASE ! ;     \ ( -- )

: DEBUG 255 TRACE ! ;   \ ( -- )
: RELEASE 0 TRACE ! ;   \ ( -- )

\ 
\ CONDITIONAL EXECUTION ----------------------------------------------------------------------
\ 

\ <condition> IF <true-part> THEN
: IF IMMEDIATE      \ ( n -- )
    ' 0BRANCH ,
    HERE @
    0 ,
;

: THEN IMMEDIATE
    DUP
    HERE @ SWAP -
    SWAP !
;

\ <condition> IF <true-part> ELSE <false-part> THEN
: ELSE IMMEDIATE
    ' BRANCH ,
    HERE @
    0 ,
    SWAP
    DUP
    HERE @ SWAP -
    SWAP !
;

\ 
\ LOOPING ----------------------------------------------------------------------
\ 

\ limit index DO <loop-part> LOOP
: DO IMMEDIATE      \ ( limit index -- )
    HERE @
    ' >R ,
    ' >R ,
;

: LOOP IMMEDIATE    \ ( -- )
    ' R> ,
    ' R> ,
    ' LIT , 1 ,     \ ( limit index 1 )
    ' + ,           \ ( limit index+1 )
    ' 2DUP ,        \ ( limit index+1 limit index+1 )
    ' <= ,           \ ( limit index+1 0/1 )
    ' 0BRANCH ,
    HERE @ -
    ,
;

\ limit index DO <loop-part> increment +LOOP
: +LOOP IMMEDIATE   \ ( n -- )
    ' R> ,
    ' R> ,          \ ( increment limit index )
    ' ROT ,         \ ( limit index increment )
    ' + ,           \ ( limit index+1 )
    ' 2DUP ,        \ ( limit index+1 limit index+1 )
    ' <= ,           \ ( limit index+1 0/1 )
    ' 0BRANCH ,
    HERE @ -
    ,
;

: I RSP@ C+ C+ @ ;         \ ( -- n )
: J RSP@ C+ C+ C+ C+ @ ;   \ ( -- n )

\ BEGIN <loop-part> <condition> UNTIL
: BEGIN IMMEDIATE   \ ( -- )
    HERE @
;

: UNTIL IMMEDIATE   \ ( n -- )
    ' 0BRANCH ,
    HERE @ -
    ,
;

\ BEGIN <condition> WHILE <loop-part> REPEAT
: WHILE IMMEDIATE   \ ( n -- )
    ' 0BRANCH ,
    HERE @
    0 ,
;

\ BEGIN loop-part AGAIN
: AGAIN IMMEDIATE   \ ( -- )
    ' BRANCH ,
    HERE @ -
    ,
;

: REPEAT IMMEDIATE
    ' BRANCH ,      \ compile BRANCH
    SWAP            \ get the original offset (from BEGIN)
    HERE @ - ,      \ and compile it after BRANCH
    DUP
    HERE @ SWAP -   \ calculate the offset2
    SWAP !          \ and back-fill it in the original location
;

\ UNLESS is the same as IF but the test is reversed.
: UNLESS IMMEDIATE
    ' NOT ,         \ compile NOT (to reverse the test)
    [COMPILE] IF    \ continue by calling the normal IF
;

\ 
\ COMMENTS ----------------------------------------------------------------------
\ 
: ( IMMEDIATE
    1        \ allowed nested parens by keeping track of depth
    BEGIN
        KEY             \ read next character
        DUP '(' = IF    \ open paren?
            DROP        \ drop the open paren
            1+          \ depth increases
        ELSE
            ')' = IF    \ close paren?
                1-      \ depth decreases
            THEN
        THEN
    DUP 0= UNTIL        \ continue until we reach matching close paren, depth 0
    DROP                \ drop the depth counter
;

( From now on we can use ( ... ) for comments. )

( Some more complicated stack examples, showing the stack notation. )
: NIP ( x y -- y ) SWAP DROP ;
: TUCK ( x y -- y x y ) SWAP OVER ;
: PICK  ( x_u ... x_1 x_0 u -- x_u ... x_1 x_0 x_u ) 1+ 4 * DSP@ + @ ;

( With the looping constructs, we can now write SPACES, which writes n spaces to stdout. )
: SPACES    ( n -- )
    BEGIN
        DUP 0>    ( while n > 0 )
    WHILE
        SPACE     ( print a space )
        1-        ( until we count down to 0 )
    REPEAT
    DROP
;

( FORTH word .S prints the contents of the stack.  It doesn't alter the stack. Very useful for debugging. )
: .S        ( -- )
    S0 @            ( get current stack pointer )
    C-
    BEGIN
        DUP DSP@ C+ >
    WHILE
        DUP @ .    ( print the stack element )
        C-          ( move down )
    REPEAT
    DROP
    CR
;


( c a b WITHIN returns true if a <= c and c < b )
(  or define without ifs: OVER - >R - R>  U<  )
: WITHIN
    -ROT                ( b c a )
    OVER                ( b c a c )
    <= IF
        > IF            ( b c -- )
            TRUE
        ELSE
            FALSE
        THEN
    ELSE
        2DROP           ( b c -- )
        FALSE
    THEN
;

( ALIGNED takes an address and rounds it up (aligns it) to the next 4 byte boundary. )
: ALIGNED    ( addr -- addr )
    3 + 3 INVERT AND    ( (addr+3) & ~3 )
;

( ALIGN aligns the HERE pointer, so the next word appended will be aligned properly. )
: ALIGN HERE @ ALIGNED HERE ! ;

( C, appends a byte to the current compiled word. )
: C,
    HERE @ C!    ( store the character in the compiled image )
    1 HERE +!    ( increment HERE pointer by 1 byte )
;

: S" IMMEDIATE        ( -- addr len )
    STATE @ IF          ( compiling? )
        ' LITSTRING ,       ( compile LITSTRING )
        HERE @              ( save the address of the length word on the stack )
        0 ,                 ( dummy length - we don't know what it is yet )
        BEGIN
            KEY             ( get next character of the string )
            DUP '"' <>
        WHILE
            C,              ( copy character )
        REPEAT
        DROP                ( drop the double quote character at the end )
        DUP                 ( get the saved address of the length word )
        HERE @ SWAP -       ( calculate the length )
        C-                  ( subtract 4 (because we measured from the start of the length word) )
        SWAP !              ( and back-fill the length location )
        ALIGN               ( round up to next multiple of 4 bytes for the remaining code )
    ELSE                ( immediate mode )
        HERE @              ( get the start address of the temporary space )
        BEGIN
            KEY
            DUP '"' <>
        WHILE
            OVER C!         ( save next character )
            1+              ( increment address )
        REPEAT
        DROP                ( drop the final " character )
        HERE @ -            ( calculate the length )
        HERE @              ( push the start address )
        SWAP                ( addr len )
    THEN
;

( ." is the print string operator in FORTH.  Example: ." Something to print" )
: ." IMMEDIATE        ( -- )
    STATE @ IF          ( compiling? )
        [COMPILE] S"        ( read the string, and compile LITSTRING, etc. )
        ' TELL ,            ( compile the final TELL )
    ELSE                ( In immediate mode, just read characters and print them until we get to the ending double quote. )
        BEGIN
            KEY
            DUP '"' = IF
                DROP    ( drop the double quote character )
                EXIT    ( return from this function )
            THEN
            EMIT
        AGAIN
    THEN
;

( In FORTH, global constants  are defined like this: 10 CONSTANT TEN
  When TEN is executed, it leaves the integer 10 on the stack. )
: CONSTANT
    WORD        ( get the name (the name follows CONSTANT) )
    CREATE      ( make the dictionary entry )
    DOCOL ,     ( append DOCOL (the codeword field of this word) )
    ' LIT ,     ( append the codeword LIT )
    ,           ( append the value on the top of the stack )
    ' EXIT ,    ( append the codeword EXIT )
    MARKER ,       ( REMOVE LATER ON )
;

( In FORTH, global variables are defined like this: VARIABLE VAR
  When VAR is executed, it leaves the address of VAR on the stack
    VAR @           leaves the value of VAR on the stack
    VAR @ . CR      prints the value of VAR
    VAR ? CR        same as above, since ? is the same as @ .
    20 VAR !        sets VAR to 20 )

: ALLOT        ( n -- )
    HERE +!        ( adds n to HERE )
;

: VARIABLE
    WORD CREATE
    DOCOL ,
    ' LIT ,
    HERE @ 3 CELLS +  ( make pointer after MARKER )
    ,                 ( append the pointer to the new memory )
    ' EXIT ,
    MARKER ,
    1 CELLS ALLOT
;


( VALUEs are like VARIABLEs but with a simpler syntax.

  20 VALUE VAL      creates VAL with initial value 20
  VAL               pushes the value (20) directly on the stack
  30 TO VAL         updates VAL, setting it to 30
  VAL               pushes the value (30) directly on the stack )

: VALUE        ( n -- )
    WORD CREATE    ( make the dictionary entry (the name follows VALUE) )
    DOCOL ,        ( append DOCOL )
    ' LIT ,        ( append the codeword LIT )
    ,              ( append the initial value )
    ' EXIT ,       ( append the codeword EXIT )
    MARKER ,
;

: TO IMMEDIATE    ( n -- )
    WORD            ( get the name of the value )
    FIND            ( look it up in the dictionary )
    >DFA            ( get a pointer to the first data field (the 'LIT') )
    C+              ( increment to point at the value )
    STATE @ IF   ( compiling? )
        ' LIT ,     ( compile LIT )
        ,           ( compile the address of the value )
        ' ! ,       ( compile ! )
    ELSE        ( immediate mode )
        !           ( update it straightaway )
    THEN
;

( x +TO VAL adds x to VAL )
: +TO IMMEDIATE
    WORD        ( get the name of the value )
    FIND        ( look it up in the dictionary )
    >DFA        ( get a pointer to the first data field (the 'LIT') )
    C+          ( increment to point at the value )
    STATE @ IF  ( compiling? )
        ' LIT ,     ( compile LIT )
        ,           ( compile the address of the value )
        ' +! ,      ( compile +! )
    ELSE        ( immediate mode )
        +!          ( update it straightaway )
    THEN
;

\
\ ARRAYS
\

\ Fills n bytes of memory, beginning at addr, with value b
: FILL ( addr, n, b -- )
    -ROT    ( b, addr, n)
    OVER    ( b, addr, n, addr )
    +       ( b, addr, addr+n )
    SWAP    ( b, addr+n, addr )
    DO
        I       ( b addr )
        OVER    ( b addr b )
        -ROT    ( b b addr )
        C!
    LOOP
;

\ Fills n bytes of memory, beginning at addr, with 0
: ERASE ( addr, n -- )
    0 FILL
;




(
'WORD word FIND ?HIDDEN' returns true if 'word' is flagged as hidden.
'WORD word FIND ?IMMEDIATE' returns true if 'word' is flagged as immediate.
)
: ?HIDDEN
    C+        ( skip over the link pointer )
    C@        ( get the flags/length byte )
    F_HIDDEN AND    ( mask the F_HIDDEN flag and return it (as a truth value) )
;

: ?IMMEDIATE
    C+        ( skip over the link pointer )
    C@        ( get the flags/length byte )
    F_IMMED AND    ( mask the F_IMMED flag and return it (as a truth value) )
;

: ?DIRTY
    C+              ( skip over the link pointer )
    C@              ( get the flags/length byte )
    F_DIRTY AND     ( mask the F_DIRTY flag and return it (as a truth value) )
;

: CASE IMMEDIATE
    0        ( push 0 to mark the bottom of the stack )
;

: OF IMMEDIATE
    ' OVER ,        ( compile OVER )
    ' = ,           ( compile = )
    [COMPILE] IF    ( compile IF )
    ' DROP ,        ( compile DROP )
;

: ENDOF IMMEDIATE
    [COMPILE] ELSE      ( ENDOF is the same as ELSE )
;

: ENDCASE IMMEDIATE
    ' DROP ,            ( compile DROP )
    BEGIN               ( keep compiling THEN until we get to our zero marker )
        ?DUP
    WHILE
        [COMPILE] THEN
    REPEAT
;

: :NONAME
    0 0 CREATE    ( create a word with no name - we need a dictionary header because ; expects it )
    HERE @        ( current HERE value is the address of the codeword, ie. the xt )
    DOCOL ,        ( compile DOCOL (the codeword) )
    ]        ( go into compile mode )
;

: ['] IMMEDIATE
    ' LIT ,        ( compile LIT )
;

: BYE
    0
    SYS-EXIT
;

\ 
\ MATH ----------------------------------------------------------------------
\ 

: ABS ( n - |n|)
  DUP
  0< IF
    -1 *
  THEN
;

: MIN ( n1 n2 -- min )
    2DUP
    > IF
        SWAP
    THEN
    DROP
;

: MAX ( n1 n2 -- max )
    2DUP
    < IF
        SWAP
    THEN
    DROP
;

: NEGATE    ( n -- n*-1 )
    0
    SWAP -
;

: /         ( a b -- a/b )
    /MOD
    SWAP
    DROP
;

: MOD       ( a b -- a%b )
    /MOD
    DROP
;

\ 
\ SCREEN CONTROL ----------------------------------------------------------------------
\ 

: SCREEN-HOME ( -- ) ESC '[' EMIT  '0' EMIT ';' EMIT '0' EMIT 72 EMIT ;     \ prints ansi control sequence \033[0;0H to move cursor to 0,0
: SCREEN-CLEAR ( -- ) ESC '[' EMIT '0' 2 + EMIT 74 EMIT ;                   \ prints ansi control sequence \033[2J to clear the terminal
: PAGE ( -- ) SCREEN-CLEAR SCREEN-HOME ;

\ 
\ WELOME  ----------------------------------------------------------------------
\ 

: WELCOME ( -- )
    PAGE
    ." Jegge's fifth Forth v" VERSION .
    ." - " UNUSED . ." cells free." CR
    ." BYE or ^D to quit, ^C to interrupt execution." CR
    CR
;

WELCOME
HIDE WELCOME


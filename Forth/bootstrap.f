\ bootstrap code - see http://git.annexia.org/?p=jonesforth.git;a=blob;f=jonesforth.f;h=5c1309574ae1165195a43250c19c822ab8681671;hb=HEAD

\ The primitive word /MOD (DIVMOD) leaves both the quotient and the remainder on the stack.  (On
\ i386, the idivl instruction gives both anyway).  Now we can define the / and MOD in terms of /MOD
\ and a few other primitives.
: / /MOD SWAP DROP ;
: MOD /MOD DROP ;

\ Define some character constants
: '\n' 10 ;
: BL   32 ; \ BL (BLank) is a standard FORTH word for space.

\ CR prints a carriage return
: CR '\n' EMIT ;

: ESC 27 EMIT ;


\ SPACE prints a space
: SPACE BL EMIT ;

\ NEGATE leaves the negative of a number on the stack.
: NEGATE 0 SWAP - ;

\ Standard words for booleans.
: TRUE  1 ;
: FALSE 0 ;
: NOT   0= ;

\ LITERAL takes whatever is on the stack and compiles LIT <foo>
: LITERAL IMMEDIATE
    ' LIT , \ compile LIT
    ,       \ compile the literal itself (from the stack)
;

\ Now we can use [ and ] to insert literals which are calculated at compile time.  (Recall that
\ [ and ] are the FORTH words which switch into and out of immediate mode.)
\ Within definitions, use [ ... ] LITERAL anywhere that '...' is a constant expression which you
\ would rather only compute once (at compile time, rather than calculating it each time your word runs).
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

\ While compiling, '[COMPILE] word' compiles 'word' if it would otherwise be IMMEDIATE.
: [COMPILE] IMMEDIATE
    WORD        \ get the next word
    FIND        \ find it in the dictionary
    >CFA        \ get its codeword
    ,           \ and compile that
;

\ RECURSE makes a recursive call to the current word that is being compiled.
\
\ Normally while a word is being compiled, it is marked HIDDEN so that references to the
\ same word within are calls to the previous definition of the word.  However we still have
\ access to the word which we are currently compiling through the LATEST pointer so we
\ can use that to compile a recursive call.
: RECURSE IMMEDIATE
    LATEST @    \ LATEST points to the word being compiled at the moment
    >CFA        \ get the codeword
    ,           \ compile it
;

: IF IMMEDIATE
    ' 0BRANCH ,     \ compile 0BRANCH
    HERE @          \ save location of the offset on the stack
    0 ,             \ compile a dummy offset
;

: THEN IMMEDIATE
    DUP
    HERE @ SWAP -   \ calculate the offset from the address saved on the stack
    SWAP !          \ store the offset in the back-filled location
;

: ELSE IMMEDIATE
    ' BRANCH ,      \ definite branch to just over the false-part
    HERE @          \ save location of the offset on the stack
    0 ,             \ compile a dummy offset
    SWAP            \ now back-fill the original (IF) offset
    DUP             \ same as for THEN word above
    HERE @ SWAP -
    SWAP !
;

\ BEGIN loop-part condition UNTIL
\    -- compiles to: --> loop-part condition 0BRANCH OFFSET
\    where OFFSET points back to the loop-part
\ This is like do { loop-part } while (condition) in the C language
: BEGIN IMMEDIATE
    HERE @          \ save location on the stack
;

: UNTIL IMMEDIATE
    ' 0BRANCH ,     \ compile 0BRANCH
    HERE @ -        \ calculate the offset from the address saved on the stack
    ,               \ compile the offset here
;

\ BEGIN loop-part AGAIN
\    -- compiles to: --> loop-part BRANCH OFFSET
\    where OFFSET points back to the loop-part
\ In other words, an infinite loop which can only be returned from with EXIT
: AGAIN IMMEDIATE
    ' BRANCH ,      \ compile BRANCH
    HERE @ -        \ calculate the offset back
    ,               \ compile the offset here
;

\ BEGIN condition WHILE loop-part REPEAT
\    -- compiles to: --> condition 0BRANCH OFFSET2 loop-part BRANCH OFFSET
\    where OFFSET points back to condition (the beginning) and OFFSET2 points to after the whole piece of code
\ So this is like a while (condition) { loop-part } loop in the C language
: WHILE IMMEDIATE
    ' 0BRANCH ,     \ compile 0BRANCH
    HERE @          \ save location of the offset2 on the stack
    0 ,             \ compile a dummy offset2
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
\
\ Note the use of [COMPILE]: Since IF is IMMEDIATE we don't want it to be executed while UNLESS
\ is compiling, but while UNLESS is running (which happens to be when whatever word using UNLESS is
\ being compiled -- whew!).  So we use [COMPILE] to reverse the effect of marking IF as immediate.
\ This trick is generally used when we want to write our own control words without having to
\ implement them all in terms of the primitives 0BRANCH and BRANCH, but instead reusing simpler
\ control words like (in this instance) IF.
: UNLESS IMMEDIATE
    ' NOT ,         \ compile NOT (to reverse the test)
    [COMPILE] IF    \ continue by calling the normal IF
;

\    COMMENTS ----------------------------------------------------------------------
\
\ FORTH allows ( ... ) as comments within function definitions.  This works by having an IMMEDIATE
\ word called ( which just drops input characters until it hits the corresponding ).
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

: PICK  ( x_u ... x_1 x_0 u -- x_u ... x_1 x_0 x_u )
    1+          ( add one because of 'u' on the stack )
    4 *         ( multiply by the word size )
    DSP@ +      ( add to the stack pointer )
    @           ( and fetch )
;

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

( Standard words for manipulating BASE. )
: DECIMAL ( -- ) 10 BASE ! ;
: HEX ( -- ) 16 BASE ! ;

( FORTH word .S prints the contents of the stack.  It doesn't alter the stack. Very useful for debugging. )
: .S        ( -- )
    DSP@            ( get current stack pointer )
    BEGIN
        DUP S0 @ <
    WHILE
        DUP @ .    ( print the stack element )
        C+          ( move up )
    REPEAT
    DROP
    CR
;

( ? fetches the integer at an address and prints it. )
: ? ( addr -- ) @ . ;

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

: ALLOT        ( n -- addr )
    HERE @ SWAP    ( here n )
    HERE +!        ( adds n to HERE, after this the old value of HERE is still on the stack )
;

: VARIABLE
    1 CELLS ALLOT   ( allocate 1 cell of memory, push the pointer to this memory )
    WORD CREATE     ( make the dictionary entry (the name follows VARIABLE) )
    DOCOL ,         ( append DOCOL (the codeword field of this word) )
    ' LIT ,         ( append the codeword LIT )
    ,               ( append the pointer to the new memory )
    ' EXIT ,        ( append the codeword EXIT )
    MARKER ,       ( REMOVE LATER ON )
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
    MARKER ,       ( REMOVE LATER ON )
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
(

: DO IMMEDIATE ( limit index -- )
    HERE @          \ save location on the stack
    ' 2DUP
    ' <
    [COMPILE] WHILE
;

: LOOP IMMEDIATE ( index -- index + 1 )
    1+
    [COMPILE] REPEAT
;
)

: SCREEN-HOME ( -- ) ESC '[' EMIT  '0' EMIT ';' EMIT '0' EMIT 72 EMIT ;  ( prints ansi control sequence to move cursor to 0,0 )
: SCREEN-CLEAR ( -- ) ESC '[' EMIT '0' 2 + EMIT 74 EMIT ; ( prints ansi control sequence to clear the terminal \033[2J )
: PAGE ( -- ) SCREEN-CLEAR SCREEN-HOME ;

( show banner )
: WELCOME
    ." Jegge's fifth Forth v" VERSION .
    ." - " UNUSED . ." cells free." CR
    ." ^D or BYE to quit." CR
    CR
;

WELCOME
HIDE WELCOME


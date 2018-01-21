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

\    CONTROL STRUCTURES ----------------------------------------------------------------------
\
\ So far we have defined only very simple definitions.  Before we can go further, we really need to
\ make some control structures, like IF ... THEN and loops.  Luckily we can define arbitrary control
\ structures directly in FORTH.
\
\ Please note that the control structures as I have defined them here will only work inside compiled
\ words.  If you try to type in expressions using IF, etc. in immediate mode, then they won't work.
\ Making these work in immediate mode is left as an exercise for the reader.

\ condition IF true-part THEN rest
\    -- compiles to: --> condition 0BRANCH OFFSET true-part rest
\    where OFFSET is the offset of 'rest'
\ condition IF true-part ELSE false-part THEN
\     -- compiles to: --> condition 0BRANCH OFFSET true-part BRANCH OFFSET2 false-part rest
\    where OFFSET if the offset of false-part and OFFSET2 is the offset of rest

\ IF is an IMMEDIATE word which compiles 0BRANCH followed by a dummy offset, and places
\ the address of the 0BRANCH on the stack.  Later when we see THEN, we pop that address
\ off the stack, calculate the offset, and back-fill the offset.
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

(
    From now on we can use ( ... ) for comments.

    STACK NOTATION ----------------------------------------------------------------------

    In FORTH style we can also use ( ... -- ... ) to show the effects that a word has on the
    parameter stack.  For example:

    ( n -- )    means that the word consumes an integer (n) from the parameter stack.
    ( b a -- c )    means that the word uses two integers (a and b, where a is at the top of stack)
    and returns a single integer (c).
    ( -- )        means the word has no effect on the stack
)

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


(
PRINTING NUMBERS ----------------------------------------------------------------------

The standard FORTH word . (DOT) is very important.  It takes the number at the top
of the stack and prints it out.  However first I'm going to implement some lower-level
FORTH words:

U.R    ( u width -- )    which prints an unsigned number, padded to a certain width
U.    ( u -- )    which prints an unsigned number
.R    ( n width -- )    which prints a signed number, padded to a certain width.

For example:
-123 6 .R
will print out these characters:
<space> <space> - 1 2 3

In other words, the number padded left to a certain number of characters.

The full number is printed even if it is wider than width, and this is what allows us to
define the ordinary functions U. and . (we just set width to zero knowing that the full
number will be printed anyway).

Another wrinkle of . and friends is that they obey the current base in the variable BASE.
BASE can be anything in the range 2 to 36.

While we're defining . &c we can also define .S which is a useful debugging tool.  This
word prints the current stack (non-destructively) from top to bottom.
)

( This is the underlying recursive definition of U. )
: U.        ( u -- )
    BASE @ /MOD         ( width rem quot )
    ?DUP IF             ( if quotient <> 0 then )
        RECURSE         ( print the quotient )
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

(
FORTH word .S prints the contents of the stack.  It doesn't alter the stack.
Very useful for debugging.
)
: .S        ( -- )
    DSP@            ( get current stack pointer )
    BEGIN
        DUP S0 @ <
    WHILE
        DUP @ U.    ( print the stack element )
        SPACE
        C+          ( move up )
    REPEAT
    DROP
;

( This word returns the width (in characters) of an unsigned number in the current base )
: UWIDTH    ( u -- width )
    BASE @ /        ( rem quot )
    ?DUP IF         ( if quotient <> 0 then )
        RECURSE 1+  ( return 1+recursive call )
    ELSE
        1           ( return 1 )
    THEN
;

: U.R        ( u width -- )
    SWAP            ( width u )
    DUP             ( width u u )
    UWIDTH          ( width u uwidth )
    ROT             ( u uwidth width )
    SWAP -          ( u width-uwidth )
    ( At this point if the requested width is narrower, we'll have a negative number on the stack.
      Otherwise the number on the stack is the number of spaces to print.  But SPACES won't print
      a negative number of spaces anyway, so it's now safe to call SPACES ... )
    SPACES
    ( ... and then call the underlying implementation of U. )
    U.
;

(
.R prints a signed number, padded to a certain width.  We can't just print the sign
and call U.R because we want the sign to be next to the number ('-123' instead of '-  123').
)
: .R        ( n width -- )
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

( Finally we can define word . in terms of .R, with a trailing space. )
: . 0 .R SPACE ;

( The real U., note the trailing space. )
: U. U. SPACE ;

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

( DEPTH returns the depth of the stack. )
: DEPTH        ( -- n )
    S0 @ DSP@ -
    C-              ( adjust because S0 was on the stack when we pushed DSP )
;

(
STRINGS ----------------------------------------------------------------------

S" string" is used in FORTH to define strings.  It leaves the address of the string and
its length on the stack, (length at the top of stack).  The space following S" is the normal
space between FORTH words and is not a part of the string.

This is tricky to define because it has to do different things depending on whether
we are compiling or in immediate mode.  (Thus the word is marked IMMEDIATE so it can
detect this and do different things).

In compile mode we append
LITSTRING <string length> <string rounded up 4 bytes>
to the current word.  The primitive LITSTRING does the right thing when the current
word is executed.

In immediate mode there isn't a particularly good place to put the string, but in this
case we put the string at HERE (but we _don't_ change HERE).  This is meant as a temporary
location, likely to be overwritten soon after.
)

(
ALIGNED takes an address and rounds it up (aligns it) to the next 4 byte boundary.
)
: ALIGNED    ( addr -- addr )
3 + 3 INVERT AND    ( (addr+3) & ~3 )
;

(
ALIGN aligns the HERE pointer, so the next word appended will be aligned properly.
)
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

(
." is the print string operator in FORTH.  Example: ." Something to print"
The space after the operator is the ordinary space required between words and is not
a part of what is printed.

In immediate mode we just keep reading characters and printing them until we get to
the next double quote.

In compile mode we use S" to store the string, then add TELL afterwards:
LITSTRING <string length> <string rounded up to 4 bytes> TELL

It may be interesting to note the use of [COMPILE] to turn the call to the immediate
word S" into compilation of that word.  It compiles it into the definition of .",
not into the definition of the word being compiled when this is running (complicated
enough for you?)
)
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

(
CONSTANTS AND VARIABLES ----------------------------------------------------------------------

In FORTH, global constants and variables are defined like this:

10 CONSTANT TEN        when TEN is executed, it leaves the integer 10 on the stack
VARIABLE VAR        when VAR is executed, it leaves the address of VAR on the stack

Constants can be read but not written, eg:

TEN . CR        prints 10

You can read a variable (in this example called VAR) by doing:

VAR @            leaves the value of VAR on the stack
VAR @ . CR        prints the value of VAR
VAR ? CR        same as above, since ? is the same as @ .

and update the variable by doing:

20 VAR !        sets VAR to 20

Note that variables are uninitialised (but see VALUE later on which provides initialised
variables with a slightly simpler syntax).

How can we define the words CONSTANT and VARIABLE?

The trick is to define a new word for the variable itself (eg. if the variable was called
'VAR' then we would define a new word called VAR).  This is easy to do because we exposed
dictionary entry creation through the CREATE word (part of the definition of : above).
A call to WORD [TEN] CREATE (where [TEN] means that "TEN" is the next word in the input)
leaves the dictionary entry:
)
: CONSTANT
    WORD        ( get the name (the name follows CONSTANT) )
    CREATE      ( make the dictionary entry )
    DOCOL ,     ( append DOCOL (the codeword field of this word) )
    ' LIT ,     ( append the codeword LIT )
    ,           ( append the value on the top of the stack )
    ' EXIT ,    ( append the codeword EXIT )
    MARKER ,       ( REMOVE LATER ON )
;

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

(
VALUES ----------------------------------------------------------------------

VALUEs are like VARIABLEs but with a simpler syntax.  You would generally use them when you
want a variable which is read often, and written infrequently.

20 VALUE VAL     creates VAL with initial value 20
VAL        pushes the value (20) directly on the stack
30 TO VAL    updates VAL, setting it to 30
VAL        pushes the value (30) directly on the stack

Notice that 'VAL' on its own doesn't return the address of the value, but the value itself,
making values simpler and more obvious to use than variables (no indirection through '@').
The price is a more complicated implementation, although despite the complexity there is no
performance penalty at runtime.

A naive implementation of 'TO' would be quite slow, involving a dictionary search each time.
But because this is FORTH we have complete control of the compiler so we can compile TO more
efficiently, turning:
TO VAL
into:
LIT <addr> !
and calculating <addr> (the address of the value) at compile time.
)

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
PRINTING THE DICTIONARY ----------------------------------------------------------------------

ID. takes an address of a dictionary entry and prints the word's name.

For example: LATEST @ ID. would print the name of the last word that was defined.
)
: ID.
    C+        ( skip over the link pointer )
    DUP C@          ( get the flags/length byte )
    F_LENMASK AND   ( mask out the flags - just want the length )
    BEGIN
        DUP 0>      ( length > 0? )
    WHILE
        SWAP 1+     ( addr len -- len addr+1 )
        DUP C@      ( len addr -- len addr char | get the next character)
        EMIT        ( len addr char -- len addr | and print it)
        SWAP 1-     ( len addr -- addr len-1    | subtract one from length )
    REPEAT
    2DROP        ( len addr -- )
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

(
CASE ----------------------------------------------------------------------

CASE...ENDCASE is how we do switch statements in FORTH.  There is no generally
agreed syntax for this, so I've gone for the syntax mandated by the ISO standard
FORTH (ANS-FORTH).

( some value on the stack )
CASE
test1 OF ... ENDOF
test2 OF ... ENDOF
testn OF ... ENDOF
... ( default case )
ENDCASE

The CASE statement tests the value on the stack by comparing it for equality with
test1, test2, ..., testn and executes the matching piece of code within OF ... ENDOF.
If none of the test values match then the default case is executed.  Inside the ... of
the default case, the value is still at the top of stack (it is implicitly DROP-ed
by ENDCASE).  When ENDOF is executed it jumps after ENDCASE (ie. there is no "fall-through"
and no need for a break statement like in C).

The default case may be omitted.  In fact the tests may also be omitted so that you
just have a default case, although this is probably not very useful.

An example (assuming that 'q', etc. are words which push the ASCII value of the letter
on the stack):

0 VALUE QUIT
0 VALUE SLEEP
KEY CASE
'q' OF 1 TO QUIT ENDOF
's' OF 1 TO SLEEP ENDOF
( default case: )
." Sorry, I didn't understand key <" DUP EMIT ." >, try again." CR
ENDCASE

(In some versions of FORTH, more advanced tests are supported, such as ranges, etc.
Other versions of FORTH need you to write OTHERWISE to indicate the default case.
As I said above, this FORTH tries to follow the ANS FORTH standard).

The implementation of CASE...ENDCASE is somewhat non-trivial.  I'm following the
implementations from here:
http://www.uni-giessen.de/faq/archiv/forthfaq.case_endcase/msg00000.html

The general plan is to compile the code as a series of IF statements:

CASE                (push 0 on the immediate-mode parameter stack)
test1 OF ... ENDOF        test1 OVER = IF DROP ... ELSE
test2 OF ... ENDOF        test2 OVER = IF DROP ... ELSE
testn OF ... ENDOF        testn OVER = IF DROP ... ELSE
... ( default case )        ...
ENDCASE                DROP THEN [THEN [THEN ...]]

The CASE statement pushes 0 on the immediate-mode parameter stack, and that number
is used to count how many THEN statements we need when we get to ENDCASE so that each
IF has a matching THEN.  The counting is done implicitly.  If you recall from the
implementation above of IF, each IF pushes a code address on the immediate-mode stack,
and these addresses are non-zero, so by the time we get to ENDCASE the stack contains
some number of non-zeroes, followed by a zero.  The number of non-zeroes is how many
times IF has been called, so how many times we need to match it with THEN.

This code uses [COMPILE] so that we compile calls to IF, ELSE, THEN instead of
actually calling them while we're compiling the words below.

As is the case with all of our control structures, they only work within word
definitions, not in immediate mode.
)
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


: EXCEPTION-MARKER
    RDROP            ( drop the original parameter stack pointer )
    0            ( there was no exception, this is the normal return path )
;

: CATCH        ( xt -- exn? )
    DSP@ C+ >R        ( save parameter stack pointer (+4 because of xt) on the return stack )
    ' EXCEPTION-MARKER C+    ( push the address of the RDROP inside EXCEPTION-MARKER ... )
    >R            ( ... on to the return stack so it acts like a return address )
    EXECUTE            ( execute the nested function )
;

: THROW        ( n -- )
    ?DUP IF            ( only act if the exception code <> 0 )
        RSP@             ( get return stack pointer )
        BEGIN
            DUP R0 C- <        ( RSP < R0 )
        WHILE
            DUP @            ( get the return stack entry )
            ' EXCEPTION-MARKER C+ = IF    ( found the EXCEPTION-MARKER on the return stack )
                C+            ( skip the EXCEPTION-MARKER on the return stack )
                RSP!            ( restore the return stack pointer )

                ( Restore the parameter stack. )
                DUP DUP DUP        ( reserve some working space so the stack for this word
                                 doesn't coincide with the part of the stack being restored )
                R>            ( get the saved parameter stack pointer | n dsp )
                C-            ( reserve space on the stack to store n )
                SWAP OVER        ( dsp n dsp )
                !            ( write n on the stack )
                DSP! EXIT        ( restore the parameter stack pointer, immediately exit )
            THEN
            C+
        REPEAT

        ( No matching catch - print a message and restart the INTERPRETer. )
        DROP

        CASE
        0 1- OF    ( ABORT )
            ." ABORTED" CR
        ENDOF
        ( default case )
        ." UNCAUGHT THROW "
            DUP . CR
        ENDCASE
        QUIT
    THEN
;

: ABORT        ( -- )
    0 1- THROW
;

( Print a stack trace by walking up the return stack. )
: PRINT-STACK-TRACE
    RSP@                ( start at caller of this function )
    BEGIN
        DUP R0 C- <        ( RSP < R0 )
    WHILE
        DUP @            ( get the return stack entry )
        CASE
        ' EXCEPTION-MARKER C+ OF    ( is it the exception stack frame? )
            ." CATCH ( DSP="
            C+ DUP @ U.        ( print saved stack pointer )
            ." ) "
        ENDOF
        ( default case )
            DUP
            CFA>            ( look up the codeword to get the dictionary entry )
            ?DUP IF            ( and print it )
                2DUP            ( dea addr dea )
                ID.            ( print word from dictionary entry )
                [ CHAR + ] LITERAL EMIT
                SWAP >DFA C+ - .    ( print offset )
            THEN
        ENDCASE
        C+            ( move up the stack )
    REPEAT
    DROP
    CR
;

: BYE
    0
    SYS-EXIT
;

( show banner )
: WELCOME
    ." Jegge's fifth Forth v" VERSION . CR
    ." ^D to quit." CR
    CR
;





WELCOME
HIDE WELCOME



\ TODO: FORGET
\ LATEST @ SEE

\ : DOUBLE DUP + ;
\ : SLOW WORD FIND >CFA EXECUTE ;
\ 5 SLOW DOUBLE . CR    \ prints 10
\ 5 WORD DOUBLE FIND >CFA EXECUTE . CR

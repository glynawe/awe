# Awe Algol W

[TOC]

## About Awe

This file documents Awe's implementation of ALGOL W, the run-time
behaviour of Awe-compiled programs, and how to interface ALGOL with C.
See the 'awe(1)' and 'awe.mk(7)' man pages for specifics of how to run
the Awe compiler.

You will need a copy of the 'ALGOL W Language Description' by your
elbow:

A LaTeX-formatted PDF:

<https://github.com/glynawe/awe/blob/main/algolw.pdf>
        
A scanned original can be found here:

<http://www.fh-jena.de/~kleine/history/history.html>

*The Michigan Terminal System, Volume 16: ALGOL W in MTS* contains a
good, textbook guide to ALGOL W (but stop reading at page 188, where
it begins to describe an extensive MTS-dependant I/O system that Awe
does not implement).

<http://www.bitsavers.org/pdf/univOfMichigan/mts/volumes/>


## Awe's Dialect

Awe's dialect of ALGOL W is the language described by the *ALGOL W
Language Description, June 1972*, with these exceptions:

Language:

- identifiers are case-insensitive;
- procedure formal parameters must be fully specified;
- LOGICAL values may be compared;
- modern handing of ambiguous IF/ELSE statements;
- arrays may have dimensions of zero width;
- compiler directives block comments.

Standard Library:

- floating-point arithmetic is done according to IEEE-754 rules;
- a few of the standard functions have been extended or omitted.

Operating System Interface:

- the I/O System is reconfigurable, initially set for stream-based I/O;
- the I/O System has a second printer, directed to stderr;
- the character set is ISO 8859-1, with EBCDIC 1047 ordering;
- external reference procedures must be written in C;
- Awe source files can be run though the C preprocessor.

These differences should only affect the validity of programs that
declare procedure formal parameters or rely on an exact representation
of System/360 floating-point math. The differences exist for the sake
of compatibility with Linux and GCC and backwards-compatibility with
undocumented features of previous compilers.

▸ This documentation describes Awe's dialect in the form of edits to
the ALGOL W Language Description in order to borrow its unambiguous
formal language. The edits are NOT proposed changes to that document.


### Source files

Awe allows an ALGOL W source program to span multiple source files.
This can be used to create a primitive module system and the ALGOL
equivalent of C header files.  Several of the Awe example programs
demonstrate this.


### Identifiers

Awe is case-insensitive.

▸ In 2.1, Basic Symbols, add:

> A letter may be substituted with its lowercase form in any
> syntactic entity other than 〈string constant〉.


### Arithmetic

Integer arithmetic is performed on 32-bit two's-complement numbers, 
the same as System/360, except that overflows will not be detected.

Floating point arithmetic is performed to IEEE-754 double-precision 
rules, not the System/360 processor's rules. The domains of the 
functions of analysis will have changed. C's `double` type, 
used to represent both `REAL` and `LONG REAL`, can have a three
digit exponent.

▸ In section 8.2 Standard Functions of Analysis, remove the "domain:"
  parts from the procedure comments.

▸ In section 8.4 Predeclared Variables, remove the "initialized to"
  parts from the procedure comments for `EPSILON`, `LONGEPSILON` and
  `MAXREAL`.

▸ In section 8.1, Standard Transfer Functions, replace `BASE10` and
  `LONGBASE10` with these:

>     STRING(12) PROCEDURE BASE10 (LONG REAL VALUE X);
>     COMMENT If the exponent part of X is 3 digits long,
>             X in the format ±EEE±DDDDDDD,
>             otherwise X in the format ⊔±EE±DDDDDDD ;
>
>     STRING(20) PROCEDURE LONGBASE10 (LONG REAL VALUE X);
>     COMMENT If the exponent part of X is 3 digits long,
>             X in the format ±EEE±DDDDDDDDDDDDDDD,
>             otherwise X in the format ⊔±EE±DDDDDDDDDDDDDDD ;

There are two additional functions `GAMMA` and `LONGGAMMA`.

▸ In section 8.2 Standard Functions of Analysis, add:

>     REAL PROCEDURE GAMMA (REAL VALUE X);
>     COMMENT Returns the gamma function of X;
>
>     LONG REAL PROCEDURE LONGGAMMA (LONG REAL VALUE X);
>     COMMENT Returns the gamma function of X;

Functions and conditions too dependent on System/360 to be
reliably reimplemented have been omitted.

▸ In section 8.5 Exceptional Conditions, remove all mention of `UNFL`,
  `OVFL` and `INTOVFL`.

▸ In section 8.1, Standard Transfer Functions, remove all metion of `BASE16` and
  `LONGBASE16`.

`ROUNDTOREAL` rounds a `REAL` number number down the precision of C's `float`.

▸ In section 8.1, Standard Transfer Functions, replace ROUNDTOREAL with:

>     REAL PROCEDURE ROUNDTOREAL(LONG REAL VALUE X);
>     COMMENT Returns the properly rounded real (short precision) value of the
>             long precision value X;

(Awe uses C `double` for both `REAL` and `LONG REAL`, but nevertheless this
is the correct behaviour according to Nicolas Brouard.)

### TIME Function

The `TIME` function has additional control codes to allow finer
measurements.

▸ To the table in section 8.2, Time Function, add:

| code  | result                 | units       |
| ----- | ---------------------- | ----------- |
| 10000 | elapsed execution time | clock ticks |
| 10001 | clock ticks per second |             |

▸ Add the paragraph:

>  The clock tick unit is defined in the 21.3.1 CPU Time Inquiry
>  section of the GNU glibc manual.


### Formal procedure parameters

Awe requires require complete specification of formal procedure
parameters.

Awe will not accept this correct program:

```
BEGIN
    PROCEDURE TRI (INTEGER VALUE I);
      (I * I + I) DIV 2;
    PROCEDURE SHOW ( INTEGER PROCEDURE F );
      FOR I := 1 UNTIL 5 DO
          WRITE(I, F(I));
    SHOW(TRI)
END.
```

But it will accept this modified program:

```
BEGIN
    PROCEDURE TRI (INTEGER VALUE I);
      (I * I + I) DIV 2;
    PROCEDURE SHOW ( INTEGER PROCEDURE F (INTEGER VALUE X) );
      FOR I := 1 UNTIL 5 DO
          WRITE(I, F(I));
    SHOW(TRI)
END.
```

▸ In section 5.3.1, Procedure Declarations Syntax, replace the 〈formal
  parameter segment〉 and 〈formal type〉 rules with these:

>     〈formal parameter segment〉 ::=
>             〈formal type〉 〈identifier list〉
>           | 〈formal array parameter〉
>           | 〈formal procedure parameter〉
>
>     〈formal type〉 ::=
>             〈simple type〉
>           | 〈simple type〉 VALUE
>           | 〈simple type〉 RESULT
>           | 〈simple type〉 VALUE RESULT
>
>     〈formal procedure parameter〉 ::=
>           | PROCEDURE 〈identifier list〉
>           | PROCEDURE 〈identifier list〉 '(' 〈formal parameter list〉 ')'
>           | 〈simple type〉 PROCEDURE 〈identifier list〉
>           | 〈simple type〉 PROCEDURE 〈identifier list〉 '(' 〈formal parameter list〉 ')'

▸ Add this section:

>  5.3.2.5, Equivalence of formal parameter lists
>
>  Two formal parameter lists are equivalent if their parameters can be
>  paired, and each pair has: the same formal type; the same
>  dimensions (if any); equivalent formal parameter lists (if any).

▸ To section 7.3.2.2 Actual formal correspondence, add:

>  If the formal parameter has a formal parameter list then the
>  actual parameter must designate a procedure with an equivalent
>  formal parameter list.

(Many previous Algol compilers have required complete specification of
formal procedure parameters. Without it, the "thunk" parameter passing
method would have to be used for all types of parameter, and it is
quite inefficient for VALUE parameters. And, in Awe's case, thunks are
difficult to define as C functions, due to C's strong typing.)


### If Statements and the Dangling Else

Awe follows ISO Pascal's rule for resolving the "dangling else"
ambiguity (which is also the rule used by C).

▸ In section 7.5.1, If Statements, Syntax, replace the rule for 
  〈if statement〉 with this:

>     〈if statement〉 ::= 〈if clause〉 〈statement〉
>                     | 〈if clause〉 〈statement〉 〈else part〉
>
>     〈else part〉    ::= ELSE 〈statement〉

And add the paragraph:

>   An 〈if statement〉 without an 〈else part〉 shall not be immediately
>   followed by the reserved word ELSE.

This does not affect the validity of strictly correct programs.

(This change is for the sake of backwards compatibility. And it is a
Yacc parser's default behaviour.  The *ALGOL W Language Description*
restricts the THEN branch of an IF statement to non-structured
statements, but Hendrik Boom's A68H code breaks that rule so
frequently that it is clear that the compiler he was using did not
enforce it.)


### Empty arrays

Awe allows "empty arrays" to be declared.

▸ Replace the last sentence of 5.2.2. Array Declarations, Semantics with this:

> In order to be valid, for every bound pair, the value of the upper
> bound may be no lower than one less than the upper bound. If a
> valid array has any bound pair where the upper bound is one less
> than the lower bound then it denotes an empty array.

▸ Replace the second sentence of 6.1.2. Variables, Semantics with this:

> An array designator is invalid if its array identifier denotes an
> empty array or if any of its subscripts lie outside the declared
> bounds for that subscript's position.

This does not affect the validity of strictly correct programs.

(Hendrik Boom says that this was an undocumented feature of OS/360
ALGOLW, and that using it makes some algorithms considerably clearer.)


### Comparison of LOGICAL values

Awe allows LOGICAL values to be compared. 

▸ In section 6.4.1, Logical Expressions, Syntax, add:

>     〈relation〉 ::= 〈logical expression 5〉 〈equality operator〉 〈logical expression 5〉
>                |  〈logical expression 5〉 〈inequality operator〉 〈logical expression 5〉

▸ In section 6.4.2, Logical Expressions, Semantics, add:

> When logical values are compared TRUE is greater than FALSE.

(Tony Marsland says this was an undocumented feature of MTS ALGOL W. 
His Awit chess program uses "¬=" as an exclusive-or operator.)


### Compiler directive cards

The ALGOLW compiler allowed "compiler directive cards" for setting
compiler options and controlling the format of program listings. A
compiler directive card is an line with an `@` sign in the first
column, the rest of the line being some compiler-specific command.

Linemarker directive cards are a special case that begin with the
character `#`. They allow Awe to be used with the C preprocessor.
See [C preprocessor compatibility](#c-preprocessor-compatibility) 
below.

Awe silently ignores all compiler directives but its own.


#### Block comment directive cards

Awe recogises two compiler directives: the `@awe_text` card causes
Awe to ignore all subsequent lines until it sees an `@awe_code`
directive. These can be used to create block comments that can contain
semicolons. Use these to comment out code.


### C preprocessor compatibility

Linemarker directives make a compiler change the source file name it
uses for error messages and sets the compiler's line counter to a 
new value. The C preprocessor places linemarkers in its output so 
that a compiler can point you to where errors actually originate.

Awe recognises linemarker directives in this format:

    ‘#’ 〈space〉 〈integer〉 〈space〉 〈string〉

where the hash must be in the first column of the line, the integer
stands for the next line number and the double-quoted string is the
new source file name. The rest of the line is ignored.

The Gnu cpp preprocessor can be made to output Awe-compatible code
when called like this:

    cpp -ffreestanding -traditional-cpp program.alw.pp > program.alw

Those flags prevent C compiler specific output.
See https://gcc.gnu.org/onlinedocs/cpp/ for more about cpp.

Note that cpp recognises and removes C style comments, not Algol ones,
so it will be confused if the characters `/*` appear in an Algol-style
comment.



### Minor syntactic additions


#### Alternative symbols.

▸ To section 2.1, Basic Symbols, add:

>     '~' | NOT | '~=' | '//'

and:

> The symbol '¬' may be substituted with the symbols '~' or NOT.
> The symbol '¬=' may be substituted with the symbol '~='.
> The symbol '|' may be substituted with the symbol '//'.



#### MTS ALGOL W "brief comments"

Brief comments, as described in *The Michigan Terminal System, Volume
16: ALGOL W in MTS*:

> "Comments may be written in a brief form by using the percent sign,
>  %, to indicate both the start and the end of a comment. Comments
>  which start with percent may also be ended with a semicolon."

The Awe compiler gives a warning when the '% 〈comment〉 ;' form is
used, because it can lead to unexpected results. Consider carefully
what this attempt at commenting out a line actually does:

```
% commented_out; %
next_procedure;
```

The `@awe_text` and `@awe_code` compiler directives can be used to
reliably comment out lines of code.



### Block identifiers

Algol W allows an identifier to follow the END keyword of a block.
The identifer has no effect, but is usually used to mark the end of a
procedure.

If the identifier at the end of the main block of a procedure is not
the same as the procedure's identifier then Awe will give a warning.



## Character Set

Programs compiled with Awe will use the ISO 8859-1 (Latin1) character
set internally and for I/O. This is for the sake of compatibility with
the GNU C library and modern operating systems. For most ALGOL W programs the
change in character representation will be completely invisible.

The ALGOL W Language Description explicitly requires EBCDIC numeric
encodings to be used for string comparison and the CODE and DECODE
procedures. The Awe run-time library uses character transliteration
tables to obtain EBCDIC 1047 encodings, EBCDIC 1047 is a superset of
System/360 EBCDIC that has a 1-to-1 mapping to ISO 8859-1.

In Awe's dialect of ALGOL W, string values and string constants are
separate concepts. (Not every string value can be represented by a
string constant.)

▸ Replace paragraph 4.4.2, Strings, Semantics with:

>  Strings consist of any sequence of (at least one and at most 256)
>  ISO 8859-1 characters. The number of characters in a string is
>  said to be the length of the string. The ISO 8859-1 characters and
>  the ordering relation on strings are defined in Appendix A.
>
>  String constants consist of any sequence of (at least one and at
>  most 256) printable ISO 8859-1 characters enclosed by ", the
>  string quote; if the string quote appears in that sequence of
>  characters it must be immediately followed by a second string
>  quote which is then ignored. The enclosed sequence of characters
>  represents a string.

▸ Replace Appendix A, Character Encodings, with:

>  The following table presents the correspondence between string
>  characters, which belong in the ISO 8859-1 character set, to their
>  EBCDIC 1047 integer encodings. This encoding establishes the
>  ordering relation on characters and thus on strings. (Also see
>  CODE and DECODE, in Section 8.1.)
>
>       +    0  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15
> 
>       0   00 01 02 03 9C 09 86 7F 97 8D 8E 0B 0C 0D 0E 0F 
>      16   10 11 12 13 9D 85 08 87 18 19 92 8F 1C 1D 1E 1F 
>      32   80 81 82 83 84 0A 17 1B 88 89 8A 8B 8C 05 06 07 
>      48   90 91 16 93 94 95 96 04 98 99 9A 9B 14 15 9E 1A 
>      64      A0 â  ä  à  á  ã  å  ç  ñ  ¢  .  <  (  +  |
>      80   &  é  ê  ë  è  í  î  ï  ì  ß  !  $  *  )  ;  ^ 
>      96   -  /  Â  Ä  À  Á  Ã  Å  Ç  Ñ  ¦  ,  %     >  ? 
>     112   ø  É  Ê  Ë  È  Í  Î  Ï  Ì  `  :  #  @  '  =  " 
>     128   Ø  a  b  c  d  e  f  g  h  i  «  »  ð  ý  þ  ± 
>     144   °  j  k  l  m  n  o  p  q  r  ª  º  æ  ¸  Æ  ¤ 
>     160   µ  ~  s  t  u  v  w  x  y  z  ¡  ¿  Ð  [  Þ  ® 
>     176   ¬  £  ¥  ·  ©  §  ¶  ¼  ½  ¾  Ý  ¨  ¯  ]  ´  × 
>     192   {  A  B  C  D  E  F  G  H  I  AD ô  ö  ò  ó  õ 
>     208   }  J  K  L  M  N  O  P  Q  R  ¹  û  ü  ù  ú  ÿ 
>     224   \  ÷  S  T  U  V  W  X  Y  Z  ²  Ô  Ö  Ò  Ó  Õ 
>     240   0  1  2  3  4  5  6  7  8  9  ³  Û  Ü  Ù  Ú  FF 
>
>  The hexadecimal numbers in the table represent non-printing 
>  ISO 8859-1 characters.


### Strings as arrays of bytes

It has been common practice to treat STRING variables as arrays of
bytes, using CODE and DECODE to access the elements:

    BYTE := DECODE(ARRAY_STRING(INDEX|1));
    ARRAY_STRING(INDEX|1) := CODE(BYTE);

That will still work for most programs, because Awe's character
transliteration tables are inverse functions. The exceptions are
programs that use strings to pass byte arrays to external procedures,
in those cases CODE and DECODE can be replaced by non-transliterating
function procedures.  

In the ALGOL W program source, add:

```
INTEGER PROCEDURE CODE (STRING(1) VALUE S); ALGOL "byte2int";
STRING(1) PROCEDURE DECODE (INTEGER VALUE X); ALGOL "int2byte";
```

Link the program to these C functions:

```
int byte2int (unsigned char s) { return s; }
unsigned char int2byte (int x) { return x % 256; }
```

(See the [C Interface](#c-interface) section below.)


## Compiler Errors

Awe's compiler error messages are printed on the standard error stream
in GCC's "brief format". An example:

    test/file.alw:12:20: expected an INTEGER here, this is a REAL.

The expression which caused the error is at column 20 of line 12 of
the source file 'test/file.alw'. Lines are counted from one. Columns
are counted from zero.

Type errors should result in very descriptive error messages.

Syntax error messages will not be so descriptive, but will be located
correctly. Because ALGOL W is an "expression language", the source of
a syntax error will sometimes be further away than you'd expect.

Awe will test the assignment compatibility of reference values and
validity of field designators at compile-time whenever possible.
This does not affect the execution of correct programs.


### Name Parameters

The Awe compiler will note the places where "Call by Name" parameters
are declared, very frequently a VALUE parameter is what was desired.

The Awe compiler gives a warning wherever an expression is used as a
Call by Name actual parameter. Those often lead to undefined
behaviour, see [Invalid Name Parameters](#invalid-name-parameters) 
below.


## Run-Time Behaviour

This section describes behaviour of programs compiled by Awe. 
This behaviour is mostly determined by the Awe run-time library
`libawe.a`.


### Name Parameters

Awe programs execute valid Call By Name procedure parameters correctly.
Awe passes Knuth's "Man or Boy" test for Algol compilers.

#### Invalid Name Parameters 

When an expression is used as a Name actual parameter, and the
procedure assigns to the corresponding formal parameter, the execution
of the procedure is undefined, because there will be an expression on
both the left and right hand side of an assignment sign (examine
section 6.7 of the Language Description). An Awe-compiled program's
behaviour in this situation is to evaluate both expressions and
continue executing.


### Run-Time Error Messages

Programs compiled by Awe should be able to produce ALGOL W specific
error messages for most run-time errors.

Run-time error messages are printed on the standard error stream in
GCC's "brief format". An example:

    test/file.alw:12:20: Floating-point division by zero.

The expression which caused the error is at column 20 of line 12 of
the source file 'test/file.alw'. Lines are counted from one. Columns
are counted from zero. The file path is the one that was given to the
compiler.

C assertion errors always indicate bugs in the Awe run-time library.
Segmentation faults should only occur in the case of excessively deep
recursion. (However, if you link to C code you are back on your own.)


#### The default Exceptional Condition error messages

- `Floating-point division by zero.`
- `Integer division by zero.`
- `Negative argument for SQRT or LONGSQRT.`
- `Argument of EXP or LONGEXP out of domain.`
- `Argument of LN, LOG, LONGLN or LONGLOG out of domain.`
- `Argument of SIN, COS, LONGSIN or LONGCOS out of domain.`
- `Unexpected end of input.`

(The ALGOL W runtime's response to Exceptional Condition errors 
can be customised. See section 8.5 of the *ALGOL W Language 
Description*.)


#### Miscellaneous errors:

- `assertion failure`   (Raised by ASSERT statements.)
- `FOR step of 0`
- `CASE range error: selector is 〈i〉`
- `Exponent operator division by zero: 0 ** -〈exponent〉`


#### Reference errors:

- `Could not allocate record 〈number〉: Out of memory!`
- `tried to find field 〈identifier〉 of a NULL reference`
- `tried to find field 〈identifier〉 of an uninitialized reference`
- `tried to find field 〈identifier〉 of a REFERENCE(〈class list〉)`
- `a REFERENCE(〈class list〉) cannot be made to refer to a '〈class〉' record.`


#### Array errors

- `bound 〈n〉 of '〈array〉' is (〈min〉::〈max〉) here` (Raised when an array is declared, if 〈min〉 is more than 1 greater than 〈max〉.)
- `subscript 〈n〉  = 〈i〉, outside the range (〈min〉::〈max〉)` (Arrays are "empty" if 〈min〉 is 1 greater than 〈max〉.)

See [Empty arrays](#empty-arrays) above.

#### String errors

- `Invalid substring (〈index〉|〈length〉).`  (Raised if 〈index〉 < 0.)
- `Substring (〈index〉|〈length〉) of a string of length 〈length〉` (Raised if the substring does not lie within the string.)


#### I/O System errors
 
- `Expected to read 〈type〉 on line 〈n〉 of 〈file〉; found 〈type〉.`
- `Integer too low on line 〈n〉 of 〈file〉`
- `Integer too high on line 〈n〉 of 〈file〉`
- `Bits constant too high on line 〈n〉 of 〈file〉`
- `String too long on line 〈n〉 of 〈file〉`
- `Real number out of range on line 〈n〉 of 〈file〉` (Real number underflow/overflow are range errors.)
- `A WRITE field was too wide for the page here. The page width is 〈n〉 but the field width was 〈n〉.`
- `The page estimate, 〈n〉 pages, has been reached.`
- `The page estimate is 0 pages, nothing should be written.`
- `IOCONTROL code 〈n〉 is undefined.`
- `R_FORMAT = "〈character〉", this is not a valid format code.`
- `Expected an integer between 〈min〉 and 〈max〉 in system variable 〈name〉.`
- `Expected a true or false value in system variable 〈name〉.`
- `Unexpected end of input.`

See the table in the [I/O System](#io-system) section.

`Unexpected end of input` is an 
[Exceptional Condition](#the-default-exceptional-condition-error-messages)
which can be customised so that will set a flag rather than halt the program.


### Record Allocation

The Awe run-time dynamically allocates records during the execution of
reference expressions (cf. 6.7 of the Language Description). It does
not use dynamic allocation for any other purpose.

The Awe run-time library uses the Boehm GC function `GC_ALLOC` to
allocate records, and allows Boehm GC to garbage collect a record when
no references to it remain. Awe programs should be linked to `libgc`.



### Allocation numbers

"Allocation numbers" are assigned to records from a counter that is
incremented every time a record is allocated. These are used when
writing RECORD values, see the [WRITE](#write) section. EXCEPTION records
have negative allocation numbers.

(Hendrik Boom says this was a undocumented feature of the OS/360
implementation of ALGOL W, and very useful when debugging a program.)



## Input/Output System

The Awe Input/Output System is the one described in section 7.9 of the
*June 1972 ALGOL W Language Description*, with minor modifications to
allow it to deal with Posix stream I/O.

An Awe-compiled program uses the Posix standard output stream
(`stdout`) as its printer. Lines from standard input (`stdin`)
represent card reader input records. At the default I/O System
settings, record lengths are flexible. The character set is ISO-8859-1
(Latin1), rather than EBCDIC.

There is a second "printer" for sending messages to the standard error
stream (`stderr`). Output can be directed there using an extended
IOCONTROL code.

Run-time error messages are printed on the standard error stream.

▸ In section 7.9.1, The Input/Output System, replace the first two
  paragraphs with:

>  ALGOL W provides a single input stream and a two legible output
>  streams. These streams are conceived as sequences of records, each
>  record consisting of an ISO 8859-1 character sequence, excluding
>  the operating system's standard newline and formfeed characters.
>
>  The input stream has the logical properties of a sequence of lines
>  in a text file. The output stream has the logical properties of a
>  sequence of lines on a line printer, and the records may be
>  grouped into logical pages. Each page consists of not less than
>  one line.


### IOCONTROL

IOCONTROL has an extended set of control codes, mostly to modify the
Input/ Output System configuration. The configuration can also be set
by operating system environment variables.

The initial configuration handles line length, whitespace and page
breaks in a relaxed way that better suits stream I/O. The Input/Output
System can be returned to strict ALGOL W Language Description
behaviour by setting Unix environment variables, or by this statement:
`IOCONTROL(4, 40009, 40011)`

The control codes:


| code  | meaning                   | default | environment variable     |
| ----  | ------------------------- | ------- | ------------------------ |
| 4     | hard page breaks = ON     | off     | `AWE_HARD_PAGE_BREAKS`   |
| 5     | hard page breaks = OFF    |         |                          |
| 1dddd | output page width         | 132     | `AWE_PAGE_WIDTH`         |
| 2dddd | output page height        | 60      | `AWE_PAGE_HEIGHT`        |
| 3dddd | output page estimate      | 9999    | `AWE_PAGE_ESTIMATE`      |
| 40001 | reset page and line count |         |                          |
| 40002 | unconditional line break  |         |                          |
| 40004 | pretty page breaks = OFF  | OFF     | `AWE_PRETTY_PAGE BREAKS` |
| 40005 | pretty page breaks = ON   |         |                          |
| 40006 | strict line breaks = OFF  | OFF     | `AWE_STRICT_LINE_BREAKS` |
| 40007 | strict line breaks = ON   |         |                          |
| 40008 | trim lines = OFF          | ON      | `AWE_TRIM_LINES`         |
| 40009 | trim lines = ON           |         |                          |
| 40010 | eject last page = OFF     | OFF     | `AWE_EJECT_LAST_PAGE`    |
| 40011 | eject last page = ON      |         |                          |
| 50000 | redirect output to stdout | stdout  |                          |
| 50001 | redirect output to stderr |         |                          |


**dddd** 
  stands for the digits of a numeric setting, where 9999 means *unlimited*.

**Output page estimate** 
  is the number of pages the program may output, 0 means no
  output is allowed.

**Hard page breaks**
  means replace the last line feed of a page with a form feed or
  write a "pretty page break." 

(The correct ALGOL W Language Description default is ON, but OFF
  suits stream output better.)

**Unconditional line break**
  means write a line break immediately, even if nothing has been
  written to the current line.

**Pretty page breaks**
  means rule across the page with "~" signs at the end of a page,
  rather than issue a form feed code.

**Strict line breaks**
  means raise a run-time error if a WRITE field is wider than the
  output page width.

**Trim lines**
  means do not print spaces at the end of a line. 
  (The correct ALGOL W Language Description behaviour is to print
  spaces at the ends of lines, but that can be confusing when
  displayed in a environment that wraps lines.)

**Eject last page**
 means perform a page break at the end of the program. If this is
  off a line break is performed instead. 
  (The correct ALGOL W Language Description behaviour is to eject
  the last page, but a mere line break suits stream output better.)

**Redirect output to stderr**
  By default the "printer" outputs to `stdout`, which will most likely
  be piped into a file by the program's user. Awe allows the
  program's output to be temporarily redirected to `strerr` to print
  error messages where they can be seen.


### READ

READ pays no attention to the length of input records; it reads lines
rather than punch cards.

READ allows `e` to be used in place of `'` (single quote) in REAL
constants.


### READCARD

READCARD reads input records that are the length of its STRING actual
parameters; it is not limited to 80 character records. If the record
contains more characters than the parameter can hold, the excess
characters will be ignored. If the record is shorter than the
parameter, the parameter will be padded with spaces.


### WRITE

By default WRITE does not print spaces at the ends of lines, nor does
it eject the last page. See the "trim lines" and "eject last page"
IOCONTROL control codes above.

Negative numbers in the I_W or R_W editing variables cause output
fields to be left-justified.

#### Writing Reference Values

WRITE can write REFERENCE values. REFERENCE values are written with
this syntax:

    ‘null’ | 〈class identifier〉 ‘.’ 〈integer〉

〈class identifier〉 is the referenced record's class and 〈integer〉
is the "record's allocation number" (see the [Records](#records) section above.)
The variable I_W controls reference fields' width.


### WRITECARD

This additional standard procedure is used in several places in Tony
Marsland's computer chess program Awit. 

WRITECARD's description in The Michigan Terminal System, Volume 16:
ALGOL W in MTS:

>    Writecard designates a procedure which writes the whole of the
>    supplied string argument on a single output record. Each Writecard
>    argument starts a new output record and any subsequent output by
>    any output procedure will also start a new record.
>
>    If a string expression output by Writecard is longer than the
>    maximum length of an output record for the basic output stream
>    then it is truncated on the right.
>
>    Note that all expressions in the Writecard parameter list must be
>    of simple type string. They may be entire strings or substring
>    designators.

No other features of MTS ALGOL W's I/O system have been implemented.



## C Interface

Procedure declarations with "external references" describe the
interfaces of separately compiled procedures. An example:

```
INTEGER PROCEDURE UNPACK (BITS VALUE W; INTEGER RESULT LO, HI); 
    ALGOL "unpack16";
```
Awe translates these procedure declarations into equivalent C function
prototypes, and writes those to the standard output while it is
compiling.  You will need to provide a separately compiled C function
for each of those prototypes.

An example output:

```
/* INTEGER PROCEDURE unpack (BITS VALUE w; INTEGER RESULT lo, hi); 
   ALGOL "unpack16"; */
void unpack16 (unsigned int w, int *lo, int *hi);
```

The string element of an external reference becomes the identifier of
the C function; the function return type and formal parameters are
translated according to Awe's calling conventions (described below);
the ALGOL or FORTRAN keyword is ignored.

Avoid using function identifiers starting with underscores, they may
conflict with temporary variables inside the main function of the
ALGOL W program.

(The external reference procedures I've seen in ALGOL W programs have
been small FORTRAN procedures to make operating system calls.  Those
would have to rewritten in any case, so the requirement to rewrite
them in C is not an unnecessary burden. In theory, I could provide an
interface to GCC's Fortran front-end, but there has been no call for
it yet.)


### An example program

This program uses an external reference procedure to fetch the time,
and that procedure is defined by a separately compiled C function.

The ALGOL W program, `when.alw`:

```
BEGIN
    PROCEDURE LOCAL_TIME (INTEGER ARRAY HMS(*); LOGICAL RESULT DST);
      ALGOL "localtime_wrapper";
      
    INTEGER ARRAY A (1 :: 3);
    LOGICAL D;
    
    LOCAL_TIME(A, D);
    
    FOR I := 1 UNTIL 3 DO WRITEON(A(I));
    WRITE(IF D THEN "Summer! :-)" ELSE "Winter. :-(")
END.
```

The Makefile:

```
PROGRAM        = when
ALGOLW_SOURCES = when.alw
C_SOURCES      = timelib.c
include awe.mk
```

The include file does all the real work, see the `awe.mk(7)` man page.

The C library, `timelib.c`:

```
#include <awe.h>
#include <time.h>
#include "when.awe.h"
#define HMS(i) *_awe_array_SUB(_awe_HERE, int, hms, i)
void localtime_wrapper (_awe_array *hms, int *dst)
{
    time_t t = time(NULL);
    struct tm *T = localtime(&t);
    HMS(1) = T->tm_hour;
    HMS(2) = T->tm_min;
    HMS(3) = T->tm_sec;
    *dst = T->tm_isdst;
}
```

The `when.awe.h` header file is automatically generated by `awe.mk`,
it contains prototypes for all the externally referenced procedures in
`when.alw`.

See the [Arrays](#arrays) section below for an explnation of how the 
`HMS` array argument is handled. 


### awe.h

`awe.h` is the header file for Awe's run-time library. It should
included into separately compiled function source files.  Not every
definition in it will be useful to you, but some, like the ALGOL W
string handling functions, certainly will be.


### Errors

Errors can raised from within C functions by calling the `_awe_error` 
function. Its first argument should always be `_awe_HERE`, which 
points to the error's location in the C file. Its remaining 
arguments are the same as C's `printf`.


### Simple types

These are the ALGOL W simple types (cf. section 4 of the Language
Description) and the C types that represent them. ALGOL W function
procedures return values of these types, and they are the basis for
all formal parameters. All ALGOL W record fields have simple types.

| simple type       | C type            |
| ----------------- | ----------------- |
| `INTEGER`         | `int`             |
| `REAL`            | `double`          |
| `LONG REAL`       | `double`          |
| `COMPLEX`         | `_Complex double` |
| `LONG COMPLEX`    | `_Complex double` |
| `LOGICAL`         | `int`             |
| `BITS`            | `unsigned int`    |
| `STRING (1)`      | `unsigned char`   |
| `STRING (n)`      | `_awe_str`        |
| `REFERENCE (any)` | `void *`          |

`LOGICAL`.
The FALSE value is 0, all other values are TRUE.

`INTEGER`, `BITS`.
 GCC's `int` and `unsigned int` are always 32 bits wide, which is
  what we want.

`STRING(1)`
  is a single character, represented by a C `unsigned char`
  value. ISO 8859-1 character codes range from 0 to 255.

`STRING(n)`.
  String types where n > 1 are represented by `_awe_str`, a pointer
  to a unique array of n `unsigned char` elements. ALGOL W strings
  are not compatible with C strings: they are of a fixed length,
  padded with spaces and are never zero-terminated.  `awe.h`
  contains prototypes for Awe's string handling functions.

`REFERENCE`. All reference types are translated to `void*` pointers, but they
  remain strongly typed in the ALGOL W side of the program. There
  are caveats to manipulating ALGOL W records, see the [Records](#records)
  section below.

`COMPLEX`.
`_Complex double` is GNU C's raw syntax for the complex type.



### Function procedure return values

An external C function should return the C equivalent of its ALGOL W
procedure's simple type.

```
/* INTEGER PROCEDURE TRI (INTEGER VALUE X); ALGOL "tri"; */

int tri (int x)
{
    return (x*x + x) / 2;
}
```

When a string is returned from a function procedure, its array of
characters must be copied into a special buffer. Use the function
`_awe_str_cast` to do this, it will also handle ALGOL W's string
padding for you.

```
/* STRING(8) PROCEDURE HEX (INTEGER VALUE X); ALGOL "hex"; */

#include <awe.h>  /* for _awe_str_cast's prototype */

_awe_str hex (int index)
{
    unsigned char str[9];
    int len;
    len = sprintf("%X", str, x);
    return _awe_str_cast(str, len, 8);
}
```

### Formal parameters to procedures

These are C equivalents of ALGOL W formal parameters:

| ALGOL W formal parameter   | C function argument           |
| -------------------------- | ----------------------------- |
| `T VALUE x`                | `t x`                         |
| `T RESULT x`               | `t* x`                        |
| `T VALUE RESULT x`         | `t* x`                        |
| `T x` (i.e. Call by Name)  | `t* (*x)()`                   |
| `PROCEDURE x`              | `void (*x)()`                 |
| `T PROCEDURE x`            | `t (*x)()`                    |
| `T ARRAY x (*)`            | `_awe_array_t *x`             |
| `T ARRAY x (*,*)`          | `_awe_array_t *x`             | 

where `T` is an ALGOL W simple type, `t` is its C equivalent 
and `t*` is a C pointer to its equivalent.

For STRING(n) typed formal parameters, where n > 1, both `t` 
and `t*` are equivalent to `_awe_str`.

**VALUE** parameters are represented by ordinary C arguments. An `_awe_str`
argument will point to a copy of the actual parameter's character
array.

**RESULT** and **VALUE RESULT** parameters are represented by pointers to copies
of parameter variables.  Those copies will be assigned back to their
variables after the function has returned.

**Call by Name** parameters are represented by pointers to functions that
return pointers to variables. In an ALGOL W program these functions
are called every time their variables are accessed, but you are not
obliged to do this in your C code. Note that Name parameters can have
side-effects.

**PROCEDURE** parameters are represented by functions that return values,
or void functions. If a PROCEDURE parameter has parameters of its own
then those are included in its function prototype, recursively,
following the same formal parameter rules. For example:

```
PROCEDURE x (INTEGER PROCEDURE y (BITS VALUE z));
```

Becomes:

```
void x (int (*y)(unsigned int z));
```

**ARRAY** parameters are represented by pointers to `_awe_array_t`, the Awe
runtime's stack-based multidimensional array type.


### Arrays

`_awe_array_t` structures contain useful information about arrays,
for example their number of dimensions and upper and lower bounds
of those dimensions. Read awe.h for details.

A pointer to an element of an `_awe_array` can be obtained using the
`_awe_array_SUB` macro:

```
_awe_array_SUB(loc, type, array, subscripts...)
```

Where:

- `loc`            is a source location (use the `_awe_HERE` macro)
- `type`           is the C type of the array's elements
- `array`          is pointer to the array
- `subscripts...`  all further arguments are integer subscripts

For example, this accesses element `x(2,j+1)` of the two-dimensional
integer array x:

``` 
*_awe_array_SUB(_awe_HERE, int, x, 2, j+1)
```

Macros can be used to make array access less cumbersome:

```
#define X(i,j) *_awe_array_SUB(_awe_HERE, int, x, (i), (j))
```

### Records

A record's `struct` declaration is only visible inside the ALGOL W
program's `main` function, so it needs to be duplicated for separately
compiled functions.

This is the C structure corresponding to an ALGOL W record:

```
struct record {
    const char *_class;
    int _number;
    〈type 1〉 〈id 1〉;
    〈type 2〉 〈id 2〉;
    ...
    〈type n〉 〈id n〉;
}
```

where, for each field of the record in order, 〈type i〉 is the C
simple type of the field, and 〈id i〉 is its field identifier.

`_class` 
   is a pointer to the name of a record's class, which also
   serves as a class discriminator tag;

`_number` 
    is a unique "allocation number" for the Standard I/O WRITE
    procedure. See the [Writing Reference Values](#writing-reference-values) section above.

An externally referenced procedure cannot allocate new ALGOL W records
and should never alter a record's `_class` or `_number` fields.

An ALGOL W reference parameter is only valid if it designates NULL or
a pointer to a record allocated by an ALGOL W reference expression, so
a record should not normally be freed.

The Awe run-time initializes all reference variables to the value
`_alw_uninitialized_reference`, to allow field designators to give
run-time errors on that condition.


### Representing Pointers

It has been common practise to return pointers from externally
referenced procedures as INTEGER or BITS values. That will not work on
64-bit systems, where pointers are larger than 32-bits. There are two
ways out of this problem:

(1) return handles (indexes into arrays of pointers);

(2) return pointers as references to dummy record classes:

```
RECORD file (INTEGER dummy_field);

REFERENCE(file) fopen (STRING(255) VALUE path; 
                       STRING(2) VALUE mode);
            ALGOL "fopen_wrapper";
```

These references point to C structures rather than valid ALGOL W records, so:
* dummy record class must be the sole member of a reference class identifier list;
* a dummy record class's dummy fields should never be accessed or assigned to;
* ALGOL W code should never allocate new dummy class records.

---
Glyn Webster, 2024

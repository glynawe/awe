/* parser.mly -- Ocamlyacc parser for Algol W    -*-indented-text-*-

  This is a LALR grammar based on the BNF affix grammar used in the Language Description.
  The Language Description grammar uses type information to direct the parsing, this
  grammar does not, subsequently some grammatical errors have to be detected as type
  errors by the 'Compiler.expression' function.

  This is an expression grammar: statements are simply expressions
  that return no values. There is no explicit parsing rule for empty 
  statements, they are dealt with as special cases of the structured 
  expressions that they can appear in.

  *

  Awe is free software: you can redistribute it and/or modify it
  under the terms of the GNU General Public License as published
  by the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  Awe is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public
  License along with Awe.  If not, see <http://www.gnu.org/licenses/>.
*/

%{
  let pos i               = Location.of_position (Parsing.rhs_start_pos i)
  let rhs_end_pos i       = Location.of_position (Parsing.rhs_end_pos i)
  let symbol_start_pos () = Location.of_position (Parsing.symbol_start_pos ())

  type 'a seq = Snoc of 'a seq * 'a | Empty   (* backward list for doing lots of appends *)
  let (++) xs x = Snoc (xs, x)
  let lone x = Snoc (Empty, x)
  let lst q = 
    let rec rev_append sq ls =
      match sq with
      | Empty -> ls
      | Snoc (front, last) -> rev_append front (last :: ls)
    in
    rev_append q []
%}

%start program
%start separate_procedure
%start test_declaration
%start test_expression

%type <Tree.t> program
%type <Tree.t> separate_procedure

%type <Tree.t> test_declaration
%type <Tree.t> test_expression

%type <Tree.t> block
%type <Tree.t seq * Tree.t seq> block_body 
%type <Tree.t seq> block_head
%type <Table.Id.t> block_end

%type <Tree.t> expression
%type <Tree.t seq> expression_list 

%type <Tree.t> if_expr
%type <Tree.t> while_expr
%type <Tree.t> for_expr
%type <Tree.t> do_branch
%type <Tree.t> case_expr
%type <Tree.t seq> case_branch_list

%type <Tree.t> designator
%type <Tree.t> actual_parameter 
%type <Tree.t seq> actual_parameter_list 

%type <Tree.t> declaration
%type <Tree.t> simple_declarations
%type <Tree.t> array_declarations
%type <Tree.t> procedure_declaration
%type <Tree.t seq> formal_list formal_parameter_list
%type <Tree.t> record_declaration
%type <Tree.t seq> simple_declarations_list 

%type <Tree.t> simple_type
%type <Table.Id.t seq> identifier_list
%type <Tree.t * Tree.t> dimension
%type <Tree.t seq> formal_parameter_list
%type <Tree.t> formal_parameter_segment
%type <(Tree.t * Tree.t) seq> dimension_list 
%type <int> stars

%token <Table.Id.t>    Identifier
%token <string>  String
%token <string * string>  Real      
%token <string * string>  Imaginary 
%token <string * string>  LongReal      
%token <string * string>  LongImaginary 
%token <string> Bits
%token <string> Integer

%token FULLSTOP EOF
%token TRUE FALSE NULL
%token IF THEN ELSE
%token CASE OF
%token WHILE DO
%token ASSERT GOTO
%token FOR UNTIL STEP
%token AND OR SHL SHR PLUS MINUS STAR SLASH DIV REM STARSTAR EQ NE GT LT GE LE IS 
%token ASSIGN
%token BEGIN COLON SEMICOLON END
%token BRA COMMA BAR KET
%token INTEGER REAL COMPLEX LONG_REAL LONG_COMPLEX LOGICAL BITS STRING REFERENCE
%token LONG SHORT ABS NOT
%token ARRAY COLONCOLON 
%token PROCEDURE VALUE RESULT RECORD 
%token ALGOL FORTRAN

%right THEN DO ELSE
%left ASSERT
%right ASSIGN
%left OR
%left AND
%left NOT
%left EQ NE GT LT GE LE IS
%left PLUS MINUS
%left STAR SLASH DIV REM
%left STARSTAR SHL SHR 
%left LONG SHORT ABS

%%

program
: expression EOF          { $1 }
| expression FULLSTOP EOF { $1 }
;

separate_procedure
: procedure_declaration FULLSTOP EOF { $1 }
; 

/* These are only needed when testing the parsing */
test_declaration
: declaration EOF { $1 }
;
test_expression
: expression EOF { $1 }
;


expression 
: Integer                        { Tree.Integer       (pos 1, $1) }
| Real                           { Tree.Real          (pos 1, fst $1, snd $1) }
| Imaginary                      { Tree.Imaginary     (pos 1, fst $1, snd $1) }
| LongReal                       { Tree.LongReal      (pos 1, fst $1, snd $1) }
| LongImaginary                  { Tree.LongImaginary (pos 1, fst $1, snd $1) }
| String                         { Tree.String        (pos 1, $1) }
| Bits                           { Tree.Bits          (pos 1, $1) }
| TRUE                           { Tree.TRUE          (pos 1) }
| FALSE                          { Tree.FALSE         (pos 1) }
| NULL                           { Tree.NULL          (pos 1) }

| block                          { $1 }
| case_expr                      { $1 }
| if_expr                        { $1 }
| while_expr                     { $1 }
| for_expr                       { $1 }
| GOTO Identifier                { Tree.GOTO (pos 1, $2) }
| ASSERT expression              { Tree.ASSERT (pos 1, $2) }

| designator                     { $1 }
| designator ASSIGN expression   { Tree.Assignment (pos 1, $1, $3) }
| BRA expression KET             { $2 }

| PLUS  expression               { Tree.Unary (pos 1, Tree.IDENTITY, $2) }
| MINUS expression               { Tree.Unary (pos 1, Tree.NEG, $2) }
| NOT   expression               { Tree.Unary (pos 1, Tree.NOT, $2) }
| LONG  expression               { Tree.Unary (pos 1, Tree.LONG, $2) }
| SHORT expression               { Tree.Unary (pos 1, Tree.SHORT, $2) }
| ABS   expression               { Tree.Unary (pos 1, Tree.ABS, $2) }

| expression AND expression      { Tree.Binary (pos 2, $1, Tree.AND,  $3) }
| expression OR expression       { Tree.Binary (pos 2, $1, Tree.OR,   $3) }
| expression SHL expression      { Tree.Binary (pos 2, $1, Tree.SHL,  $3) }
| expression SHR expression      { Tree.Binary (pos 2, $1, Tree.SHR,  $3) }
| expression PLUS expression     { Tree.Binary (pos 2, $1, Tree.ADD,  $3) }
| expression MINUS expression    { Tree.Binary (pos 2, $1, Tree.SUB,  $3) }
| expression STAR expression     { Tree.Binary (pos 2, $1, Tree.MUL,  $3) }
| expression SLASH expression    { Tree.Binary (pos 2, $1, Tree.RDIV, $3) }
| expression DIV expression      { Tree.Binary (pos 2, $1, Tree.IDIV, $3) }
| expression REM expression      { Tree.Binary (pos 2, $1, Tree.REM,  $3) }
| expression STARSTAR expression { Tree.Binary (pos 2, $1, Tree.PWR,  $3) }
| expression EQ expression       { Tree.Binary (pos 2, $1, Tree.EQ,   $3) }
| expression NE expression       { Tree.Binary (pos 2, $1, Tree.NE,   $3) }
| expression GT expression       { Tree.Binary (pos 2, $1, Tree.GT,   $3) }
| expression LT expression       { Tree.Binary (pos 2, $1, Tree.LT,   $3) }
| expression GE expression       { Tree.Binary (pos 2, $1, Tree.GE,   $3) }
| expression LE expression       { Tree.Binary (pos 2, $1, Tree.LE,   $3) }
| expression IS expression       { Tree.Binary (pos 2, $1, Tree.IS,   $3) }
;

expression_list 
: expression                        { lone $1 }
| expression_list COMMA expression  { $1 ++ $3 }
;

/* Blocks */

/* The bodies of blocks contain a mixture of expressions and labels. */
block
: block_body expression block_end       { Tree.BEGIN (pos 1, lst (fst $1), lst (snd $1 ++ $2), $3) }
| block_body block_end                  { Tree.BEGIN (pos 1, lst (fst $1), lst (snd $1 ++ Tree.Empty (pos 2)), $2) }
;

block_end
: END            { Table.Id.dummy }
| END Identifier { $2 }
;

block_body
: block_head                       { ($1,     Empty) }
| block_body SEMICOLON             { (fst $1, snd $1 ++ (Tree.Empty (rhs_end_pos 2))) }
| block_body expression SEMICOLON  { (fst $1, snd $1 ++ $2) }
| block_body Identifier COLON      { (fst $1, snd $1 ++ (Tree.Label (pos 2, $2))) }
;

block_head
: BEGIN                             { Empty }
| block_head declaration SEMICOLON  { $1 ++ $2 }
;


/* Conditional expressions */

if_expr 
: IF expression THEN                             { Tree.IF (pos 1, $2, Tree.Empty (rhs_end_pos 3)) }
| IF expression THEN expression                  { Tree.IF (pos 1, $2, $4) }
| IF expression THEN expression ELSE expression  { Tree.IF_else (pos 1, $2, $4, $6) }
| IF expression THEN ELSE expression             { Tree.IF_else (pos 1, $2, Tree.Empty (rhs_end_pos 3), $5) }
| IF expression THEN expression ELSE             { Tree.IF_else (pos 1, $2, $4, Tree.Empty (rhs_end_pos 5)) }
;

case_expr
: CASE expression OF BRA expression_list KET           { Tree.CASE_expr (pos 1, $2, lst $5) }
| CASE expression OF BEGIN case_branch_list block_end  { Tree.CASE (pos 1, $2, lst $5) }
;

/* Empty statement branches are allowed. */
case_branch_list
: case_branch_list SEMICOLON expression { $1 ++ $3 }
| case_branch_list SEMICOLON            { $1 ++ Tree.Empty (pos 2) }
| expression                            { lone $1 }
|                                       { lone (Tree.Empty (symbol_start_pos ())) }
;

/* Looping Statements */

while_expr
: WHILE expression do_branch  { Tree.WHILE (pos 1, $2, $3) }
;

for_expr 
: FOR Identifier ASSIGN expression UNTIL expression do_branch                 { Tree.FOR (pos 1, $2, $4, $6, $7) }
| FOR Identifier ASSIGN expression STEP expression UNTIL expression do_branch { Tree.FOR_step (pos 1,$2,$4,$6,$8,$9) }
| FOR Identifier ASSIGN expression_list do_branch                             { Tree.FOR_list (pos 1, $2, lst $4, $5) }
;

do_branch 
: DO expression  { $2 }
| DO             { Tree.Empty (rhs_end_pos 1) }
;


/* These might be control identifiers, designators or procedures calls. */

designator 
: Identifier  
    { Tree.Identifier (pos 1, $1) }
| Identifier BRA actual_parameter_list KET    
    { Tree.Parametrized (pos 1, $1, lst $3) }
| Identifier BRA expression BAR Integer KET   
    { Tree.Substring  (pos 1, Tree.Identifier (pos 1, $1), $3, (int_of_string $5)) }
| Identifier BRA actual_parameter_list KET BRA expression BAR Integer KET   
    { Tree.Substring  (pos 1, Tree.Parametrized (pos 1, $1, lst $3), $6, (int_of_string $8)) }
;

actual_parameter_list 
: actual_parameter                              { lone $1 }
| actual_parameter_list COMMA actual_parameter  { $1 ++ $3 }
;

actual_parameter 
: STAR       { Tree.STAR (pos 1) }
| expression { $1 }
|            { Tree.Empty (symbol_start_pos ()) }
;


/* Declarations */

declaration 
: simple_declarations   { $1 }
| array_declarations    { $1 }
| record_declaration    { $1 }
| procedure_declaration { $1 }
;

simple_declarations 
: simple_type identifier_list  { Tree.Simple (pos 1, $1, lst $2) }
;

array_declarations 
: simple_type ARRAY identifier_list BRA dimension_list KET  { Tree.ARRAY (pos 1, $1, lst $3, lst $5) }
;

dimension_list 
: dimension                       { lone $1 }
| dimension_list COMMA dimension  { $1 ++ $3 }
;

dimension 
: expression COLONCOLON expression  { ($1, $3) }
;

record_declaration 
: RECORD Identifier BRA simple_declarations_list KET  { Tree.RECORD (pos 1, $2, lst $4) }
;

simple_declarations_list 
: simple_declarations                                    { lone $1 }
| simple_declarations_list SEMICOLON simple_declarations { $1 ++ $3 }
;

simple_type
: INTEGER                            { Tree.INTEGER }
| REAL                               { Tree.REAL }
| COMPLEX                            { Tree.COMPLEX }
| LONG_REAL                          { Tree.LONG_REAL }
| LONG_COMPLEX                       { Tree.LONG_COMPLEX }
| LOGICAL                            { Tree.LOGICAL }
| BITS                               { Tree.BITS }
| BITS BRA Integer KET               { Tree.BITS }
| STRING                             { Tree.STRING None }
| STRING BRA Integer KET             { Tree.STRING (Some (int_of_string $3)) }
| REFERENCE BRA identifier_list KET  { Tree.REFERENCE (pos 1, lst $3) }
;

identifier_list 
: Identifier                       { lone $1 }
| identifier_list COMMA Identifier { $1 ++ $3 }
;


/* Procedures */

procedure_declaration 
: simple_type PROCEDURE Identifier formal_list SEMICOLON procedure_body { Tree.PROCEDURE (pos 1, Some $1, $3, lst $4, $6) }
| PROCEDURE Identifier formal_list SEMICOLON procedure_body    { Tree.PROCEDURE (pos 1, None, $2, lst $3, $5) }
;

procedure_body 
: expression        { $1 }
| ALGOL String      { Tree.External (pos 1, $2) }
| FORTRAN String    { Tree.External (pos 1, $2) }
|                   { Tree.Empty (symbol_start_pos ()) }
;

formal_list
: BRA formal_parameter_list KET { $2 }
|                               { Empty }
;

formal_parameter_list 
: formal_parameter_segment                                 { lone $1 }
| formal_parameter_list SEMICOLON formal_parameter_segment { $1 ++ $3 }
;

formal_parameter_segment 
: simple_type identifier_list                       { Tree.Name_formal (pos 1, $1, lst $2) }
| simple_type VALUE identifier_list                 { Tree.VALUE_formal (pos 1, $1, lst  $3) }
| simple_type RESULT identifier_list                { Tree.RESULT_formal (pos 1, $1, lst  $3) }
| simple_type VALUE RESULT identifier_list          { Tree.VALUE_RESULT_formal (pos 1 , $1, lst $4) }
| simple_type PROCEDURE identifier_list formal_list { Tree.PROCEDURE_formal (pos 1, Some  $1, lst $3, lst $4) }
| PROCEDURE identifier_list formal_list             { Tree.PROCEDURE_formal (pos 1, None, lst $2, lst $3)  }
| simple_type ARRAY identifier_list BRA stars KET   { Tree.ARRAY_formal (pos 1, $1, lst $3, $5)  }
; 

stars 
: STAR             { 1 }
| stars COMMA STAR { $1 + 1 }
;

/* end */

(* lexer.mll -- Algol W lexical analyser 

--

This file is part of Awe. Copyright 2012 Glyn Webster.

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

*)

{
  open Parser
  open Lexing

  exception Error of Location.t * string
  let error message pos = raise (Error (Location.of_position pos, message))

  let give_warnings = ref true  (* warnings can be turned off to test lexing rules *)


  (* 'warning loc "message" arg1 arg2 ...' is a printf-like function for warnings *)

  let warning loc = 
    let warn message =
      let s = Location.to_string loc ^ " Warning: " ^ message ^ "\n" in
      output_string stderr s ;
      flush stderr
    in
    Printf.ksprintf warn


  (* The start position of tokens with there own lexing rules. *)

  let start_pos = ref dummy_pos  


  (* the start position of the current line. *)

  let start_of_line = ref 0


  (* Increment the line position for error messages. *)

  let new_line lexbuf =
    start_of_line := lexbuf.lex_curr_p.pos_cnum ;
    lexbuf.lex_curr_p <- { lexbuf.lex_curr_p with 
                           pos_bol = lexbuf.lex_curr_p.pos_cnum ; 
                           pos_lnum = lexbuf.lex_curr_p.pos_lnum + 1 } 



  (* Make real numbers from lexed real, exponent, imaginary modifier and LONG modifier substrings.
     All substrings except the 'real' one are optional. *)

  let make_real r e i l =
    let r = if (r.[0] = '.') then ("0" ^ r) else r in
    let r = if (r.[String.length r - 1] = '.') then (r ^ "0") else r in
    let x = match e with None -> "" | Some s -> s in
    match i, l with
    | None, None     -> Real (r, x)
    | Some _, None   -> Imaginary (r, x)
    | None, Some _   -> LongReal (r, x)
    | Some _, Some _ -> LongImaginary (r, x)


  (* Buffer for the contents of string constants. *)

  let string_buffer = Buffer.create 80
  let string_add s = Buffer.add_string string_buffer s


  (* Reserved words. *)

  let tokens_of_reserved_words : Parser.token Table.IdMap.t = 
    List.fold_left
      (fun m (s, t) -> Table.IdMap.add (Table.Id.create s) t m)
      Table.IdMap.empty
      [ ("abs",       ABS);
        ("algol",     ALGOL);
        ("and",       AND);
        ("array",     ARRAY);
        ("assert",    ASSERT);
        ("begin",     BEGIN);
        ("bits",      BITS);
        ("boolean",   LOGICAL);
        ("case",      CASE);
        ("complex",   COMPLEX);
        ("div",       DIV);
        ("do",        DO);
        ("else",      ELSE);
        ("end",       END);
        ("false",     FALSE);
        ("fortran",   FORTRAN);
        ("for",       FOR);
        ("goto",      GOTO);
        ("if",        IF);
        ("integer",   INTEGER);
        ("is",        IS);
        ("logical",   LOGICAL);
        ("long",      LONG);
        ("not",       NOT);
        ("null",      NULL);
        ("of",        OF);
        ("or",        OR);
        ("procedure", PROCEDURE);
        ("real",      REAL);
        ("record",    RECORD);
        ("reference", REFERENCE);
        ("rem",       REM);
        ("result",    RESULT);
        ("shl",       SHL);
        ("short",     SHORT);
        ("shr",       SHR);
        ("step",      STEP);
        ("string",    STRING);
        ("then",      THEN);
        ("true",      TRUE);
        ("until",     UNTIL);
        ("value",     VALUE);
        ("while",     WHILE) ]
      
  let token_to_string = 
    function
      | Identifier x -> Table.Id.to_string x
      | Integer x ->  x
      | Real (r,"") -> r
      | Real (r,e) -> Printf.sprintf "%s'%s" r e
      | Imaginary (r,"") -> Printf.sprintf "%sI" r
      | Imaginary (r,e) -> Printf.sprintf "%s'%sI" r e
      | LongReal (r,"") -> Printf.sprintf "%sL" r
      | LongReal (r,e) -> Printf.sprintf "%s'%sL" r e
      | LongImaginary (r,"") -> Printf.sprintf "%sIL" r
      | LongImaginary (r,e) -> Printf.sprintf "%s'%sIL" r e
      | String x -> Printf.sprintf "%S" x
      | Bits x -> Printf.sprintf "#%s" x
      | EOF -> "{eof}"
      | STARSTAR -> "**"
      | STAR -> "*"
      | SLASH -> "/"
      | PLUS -> "+"
      | MINUS -> "-"
      | NOT -> "~"
      | NE -> "~="
      | EQ -> "="
      | LT -> "<"
      | LE -> "<="
      | GT -> ">"
      | GE -> ">="
      | BRA -> "("
      | KET -> ")"
      | COMMA -> ","
      | COLONCOLON -> "::"
      | COLON -> ":"
      | SEMICOLON -> ";"
      | BAR -> "|"
      | ASSIGN -> ":="
      | FULLSTOP -> "."
      | ABS -> "ABS"
      | ALGOL -> "ALGOL"
      | AND -> "AND"
      | ARRAY -> "ARRAY"
      | ASSERT -> "ASSERT"
      | BEGIN -> "BEGIN"
      | BITS -> "BITS"
      | CASE -> "CASE"
      | COMPLEX -> "COMPLEX"
      | DIV -> "DIV"
      | DO -> "DO"
      | ELSE -> "ELSE"
      | END -> "END"
      | FALSE -> "FALSE"
      | FOR -> "FOR"
      | FORTRAN -> "FORTRAN"
      | GOTO -> "GOTO"
      | IF -> "IF"
      | INTEGER -> "INTEGER"
      | IS -> "IS"
      | LOGICAL -> "LOGICAL"
      | LONG -> "LONG"
      | LONG_COMPLEX -> "LONG COMPLEX"
      | LONG_REAL -> "LONG REAL"
      | NULL -> "NULL"
      | OF -> "OF"
      | OR -> "OR"
      | PROCEDURE -> "PROCEDURE"
      | REAL -> "REAL"
      | RECORD -> "RECORD"
      | REFERENCE -> "REFERENCE"
      | REM -> "REM"
      | RESULT -> "RESULT"
      | SHL -> "SHL"
      | SHORT -> "SHORT"
      | SHR -> "SHR"
      | STEP -> "STEP"
      | STRING -> "STRING"
      | THEN -> "THEN"
      | TRUE -> "TRUE"
      | UNTIL -> "UNTIL"
      | VALUE -> "VALUE"
      | WHILE -> "WHILE"


  (* A hook to allow lexer debugging code to be inserted, if necessary. *)
  let return_token t = t
}

let integer_number = ['0'-'9']+
let unscaled_real = integer_number '.' integer_number | '.' integer_number | integer_number '.'
let exponent = ['+' '-']? integer_number
let tenpower = '\''
let space = [' ' '\t']

let nl = '\n' | "\r\n" | "\n\r" | '\r'

(* The not sign can be '~', '¬', or the keyword "NOT" *)
let not_sign = '~' | '\172' | "\194\172" | ['N' 'n']['O' 'o']['T' 't']

rule token = parse

(* Whitespace *)
| space+ { token lexbuf }
| nl   { new_line lexbuf ; token lexbuf }

(* AWE test code section marks. The program ends when one of these is encountered. *)
| "----flags"
| "----stdin"
| "----compile"
| "----messages"
| "----stdout"
| "----stderr"
| "----exitcode"
| "----end"
      { return_token EOF }

(* C preprocessor linemarkers (non-standard) *)
| space*
  '#' space+
  (['0'-'9']+ as line_digits) space+
  '"' ([^ '\r' '\n' '"']+  as file_name) '"'
  [^ '\r' '\n']*
    { if file_name.[0] <> '<' || file_name = "<stdin>" then
        begin
          let line_number = int_of_string line_digits - 1 in
          Location.set_source file_name;
          lexbuf.lex_curr_p <- { lexbuf.lex_curr_p with pos_lnum = line_number }
        end;
      token lexbuf }
    
(* Symbols *)

| ':' space* '=' { return_token ASSIGN }
| ':' space* ':' { return_token COLONCOLON }
| '*' space* '*' { return_token STARSTAR }
| not_sign space* '=' { return_token NE }   
| '<' space* '=' { return_token LE }
| '>' space* '=' { return_token GE }
| not_sign { return_token NOT }
| ')'     { return_token KET }
| '('     { return_token BRA }
| '+'     { return_token PLUS }
| '*'     { return_token STAR }
| '-'     { return_token MINUS }
| ','     { return_token COMMA }
| '/'     { return_token SLASH }
| '<'     { return_token LT }
| '='     { return_token EQ }
| ';'     { return_token SEMICOLON }
| ':'     { return_token COLON }
| '|'     { return_token BAR }
| "//"    { return_token BAR }
| '>'     { return_token GT }

(* Numeric constant. *)    

| (unscaled_real as r) (tenpower (exponent as e))? (['I' 'i'] as i)? (['L' 'l'] as l)?
    { return_token (make_real r e i l) }

| tenpower (exponent as e) (['I' 'i'] as i)? (['L' 'l'] as l)?
    { return_token (make_real "1.0" (Some e) i l) }

| (integer_number as r) (tenpower (exponent as e)) (['I' 'i'] as i)? (['L' 'l'] as l)?
    { return_token (make_real (r ^ ".0") (Some e) i l) }

| (integer_number as r) ['I' 'i'] (['L' 'l'] as l)?
    { return_token (make_real (r ^ ".0") None (Some "I") l) }

| (integer_number as r) ['L' 'l']
    { return_token (make_real (r ^ ".0") None None (Some "L")) }

| integer_number as s
    { return_token (Integer s) }

(* Hexadecimal BITS constant. *)    
| '#' (['0'-'9' 'A'-'F' 'a'-'f']+ as s)
    { return_token (Bits (String.uppercase_ascii s)) }

(* The start of a string constant. *)    
| '"'  
    { start_pos := lexbuf.lex_start_p ;
      Buffer.clear string_buffer ; 
      string_constant lexbuf 
    }

(* The start of a comment. *)
| ['C' 'c']['O' 'o']['M' 'm']['M' 'm']['E' 'e']['N' 'n']['T' 't']  
    { start_pos := lexbuf.lex_start_p ;
      algolw_comment false lexbuf 
    }

| '%'
    { start_pos := lexbuf.lex_start_p ;
      algolw_comment true lexbuf 
    }

(* Reserved words with embedded whitespace. *)
| ['G' 'g']['O' 'o']
  [' ' '\t']*
  ['T' 't']['O' 'o']
    { return_token GOTO }
| ['L' 'l']['O' 'o']['N' 'n']['G' 'g']
  [' ' '\t']+
  ['R' 'r']['E' 'e']['A' 'a']['L' 'l']
      { return_token LONG_REAL }
| ['L' 'l']['O' 'o']['N' 'n']['G' 'g']
  [' ' '\t']+
  ['C' 'c']['O' 'o']['M' 'm']['P' 'p']['L' 'l']['E' 'e']['X' 'x']
    { return_token LONG_COMPLEX }

(* Reserved words and identifiers. *)
| ['A'-'Z' 'a'-'z'] ['A'-'Z' '_' 'a'-'z' '0'-'9']* as word
    { let id = Table.Id.create word in
      try
        return_token (Table.IdMap.find id tokens_of_reserved_words)
      with Not_found ->
        return_token (Identifier id)
    }

(* End-of-file. A fullstop marks the end of the program: anything after it is ignored. *)
| eof { return_token EOF }
| '.' { return_token FULLSTOP }

(* Compiler directive for a long comment, for commenting out sections of code. (An AWE extension.) *)
| '@' ['A' 'a']['W' 'w']['E' 'e'] '_'
      ['T' 't']['E' 'e']['X' 'x']['T' 't'] 
      [' ' '\t']* nl
    { if lexbuf.lex_start_p.pos_cnum = !start_of_line then
        ( start_pos := lexbuf.lex_start_p ;
          new_line lexbuf ; 
          algolw_long_comment lexbuf  )
      else
        let s = lexeme lexbuf in
        let directive = String.sub s 0 (String.length s - 1) in
        error (Printf.sprintf "Misplaced directive \"%s\"" directive) lexbuf.lex_start_p
    }

(* Other compiler directives.  AWE ignores these. *)
| '@' [^ '\r' '\n']* nl
    { if lexbuf.lex_start_p.pos_cnum = !start_of_line then
        ( new_line lexbuf ; token lexbuf ) (* ignore *)
      else
        let s = lexeme lexbuf in
        let directive = String.sub s 0 (String.length s - 1) in
        error (Printf.sprintf "Misplaced directive \"%s\"" directive) lexbuf.lex_start_p
    }

| _ as c  { error (Printf.sprintf "Unexpected character %C" c) lexbuf.lex_start_p }


(* Comment.  Returns nothing, behaves like whitespace. Short comments may end on a '%' *)
and algolw_comment short = parse
| ';'   { if short && !give_warnings then
            warning (Location.of_position lexbuf.lex_curr_p) "Did you mean this comment to end on a \";\"? " ;
          lexbuf.lex_start_p <- !start_pos ; 
          token lexbuf }
| '%'   { if short then (lexbuf.lex_start_p <- !start_pos ; token lexbuf) else algolw_comment short lexbuf }
| nl    { new_line lexbuf ; algolw_comment short lexbuf }
| eof   { error "This comment is not closed with a semicolon" !start_pos }
| _     { algolw_comment short lexbuf }


(* Long comment.  Returns nothing, behaves like whitespace. *)
and algolw_long_comment = parse
| '@' ['A' 'a']['W' 'w']['E' 'e'] '_'
      ['C' 'c']['O' 'o']['D' 'd']['E' 'e'] 
      [' ' '\t']* nl
    { if lexbuf.lex_start_p.pos_cnum = !start_of_line then
        (new_line lexbuf ; lexbuf.lex_start_p <- !start_pos ; token lexbuf)  (* return *)
      else
        (new_line lexbuf ; algolw_long_comment lexbuf) }  (* ignore *)
| '@' ['A' 'a']['W' 'w']['E' 'e'] '_'
      ['T' 't']['E' 'e']['X' 'x']['T' 't'] 
      [' ' '\t']* nl
    { if lexbuf.lex_start_p.pos_cnum = !start_of_line then
        error "This @AWE_TEXT directive is not closed with an @AWE_CODE directive" !start_pos
      else
        (new_line lexbuf ; algolw_long_comment lexbuf) }  (* ignore *)
| eof   
    { error "This @AWE_TEXT directive is not closed with an @AWE_CODE directive" !start_pos }
| nl    
    { new_line lexbuf ; algolw_long_comment lexbuf }
| _
    { algolw_long_comment lexbuf }


(* String constant. Returns the contents of the string. *)
and string_constant = parse
| "\"\"" { string_add "\"" ; string_constant lexbuf }  (* A doubled quote is an escape for a quote. *)
| "\""   { return_token (String (Buffer.contents string_buffer)) }
| eof    { error "This string is not closed with a double quote" !start_pos }
| nl     { error "This string is not closed with a double quote" !start_pos }
| _      { let s = lexeme lexbuf in
           let c = s.[0] in
           if c >= ' ' && c <= '~' || c >= '\xA1' && c <= '\xFF' then (* Latin-1 printable *)
             ( string_add s ; string_constant lexbuf )
           else
             error "This string contains a non-printing or non ISO 8859-1 character code" !start_pos
}

(* end *)

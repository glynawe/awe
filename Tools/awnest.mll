(* awnest.mll -- Algol W block nesting annotater

(Note this "awnest.mll" source is the complete program, 
"awnest.ml" is just a temporary output file.)


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
License along with Awe.  If not, see <http://www.gnu.org/licenses/>. *)

{
  open Lexing
  open Printf

  let line = Buffer.create 80
  let add s = Buffer.add_string line s
  let addc c = Buffer.add_char line c

  let level = ref 0
  let previous_level = ref 0
  let on_begin_token () = incr level
  let on_end_token () = decr level

  let start_of_line = ref 0

  let update_line_position lexbuf =
    start_of_line := lexbuf.lex_curr_p.pos_cnum ;
    let p = lexbuf.lex_curr_p in
    lexbuf.lex_curr_p <- {p with pos_lnum = p.pos_lnum + 1 ; pos_bol = p.pos_cnum}

  let finish_line lexbuf =                     (* Edit "finish_line" to alter the output format. *)
    let linenum = lexbuf.lex_curr_p.pos_lnum in
    printf "%05i " linenum ;
    if !level > !previous_level then
      if !level < 10 then printf "%i- " !level else printf "%i-" !level
    else if !level < !previous_level then
      printf "-%-2i" !previous_level
    else
      printf "-- " ;
    printf " %s\n" (Buffer.contents line) ;
    Buffer.clear line ;
    previous_level := !level ;
    update_line_position lexbuf

  let error lexbuf =
    let p = lexbuf.lex_curr_p in
    fprintf stderr "Lexical error at %i:%i\n"  (p.pos_lnum + 1) (p.pos_cnum -  p.pos_bol + 1) ;
    exit 1
}


let integer_number = ['0'-'9']+
let unscaled_real = integer_number '.' integer_number | '.' integer_number | integer_number '.'
let exponent = ['+' '-']? integer_number
let tenpower = '\''
let space = [' ' '\t']
let newline = "\r\n" | "\n\r" | '\r' | '\n'
let not_sign =  '~' | '\172' | "\194\172" ['N' 'n']['O' 'o']['T' 't']


rule token = parse

| newline { finish_line lexbuf ; token lexbuf }

| space+ as s { add s ; token lexbuf }

(* Symbols *)
| ':' space* '='
| ':' space* ':'
| '*' space* '*'
| '<' space* '='
| '>' space* '='
| not_sign space* '='
| ')'    | '('    | '+'    | '*'    | '-'    | ','    | '/'
| '<'    | '='    | ';'    | ':'    | '|'    | '>'
| not_sign
      as s { add s ; token lexbuf }

(* Numeric constants. *)

| unscaled_real tenpower exponent? ['I' 'i']? ['L' 'l']?
| tenpower exponent ['I' 'i']? ['L' 'l']?
| integer_number tenpower exponent ['I' 'i']? ['L' 'l']?
| integer_number ['I' 'i']? ['L' 'l']?
| integer_number
| '#' ['0'-'9' 'A'-'F' 'a'-'f']+
    as s { add s ; token lexbuf }

(* The start of a string constant. *)
| '"'  as s { addc s ; string_constant lexbuf }

(* The start of a comment. *)
| ['C' 'c']['O' 'o']['M' 'm']['M' 'm']['E' 'e']['N' 'n']['T' 't']
    as s { add s ; algolw_comment false lexbuf }
| '%' as s { addc s ; algolw_comment true lexbuf }

(* Reserved words with embedded whitespace. *)
| ['G' 'g']['O' 'o'] space* ['T' 't']['O' 'o']
| ['L' 'l']['O' 'o']['N' 'n']['G' 'g'] space+ ['R' 'r']['E' 'e']['A' 'a']['L' 'l']
| ['L' 'l']['O' 'o']['N' 'n']['G' 'g'] space+ ['C' 'c']['O' 'o']['M' 'm']['P' 'p']['L' 'l']['E' 'e']['X' 'x']
    as s { add s ; token lexbuf }

(* Reserved words and identifiers. *)
| ['A'-'Z' 'a'-'z'] ['A'-'Z' '_' 'a'-'z' '0'-'9']* as s
    { match String.lowercase_ascii s with
      | "begin" -> on_begin_token () ; add s ; token lexbuf
      | "end"   -> on_end_token () ; add s ; token lexbuf
      | _       -> add s ; token lexbuf
    }

(* End-of-file. A fullstop marks the end of the program: anything after it is ignored. *)
| '.' as s { addc s ; token lexbuf }

(* Compiler directives.  "AWE_TEXT" starts a long comment, but otherwise Awe ignores these. *)
| ('@' ['A' 'a']['W' 'w'] ['E' 'e'] '_'
      ['T' 't']['E' 'e']['X' 'x']['T' 't'] 
      [' ' '\t']*  as s) space* newline
    { add s ; finish_line lexbuf ; algolw_long_comment lexbuf }
| '@' [^ '\r' '\n']* as s { add s; token lexbuf }

| eof { finish_line lexbuf }   (* end of the source file, exit lexer here *)

| _ { error lexbuf }

(* Comment.  Returns nothing, behaves like whitespace. Short comments may end on a '%' *)
and algolw_comment short = parse
| ';'  as s { addc s ; token lexbuf }
| '%'  as s { addc s ; token lexbuf }
| newline   { finish_line lexbuf ; algolw_comment short lexbuf }
| eof       { error lexbuf }
| _    as s { addc s ; algolw_comment short lexbuf }


(* Long comment.  Returns nothing, behaves like whitespace. *)
and algolw_long_comment = parse
| ('@' ['A' 'a']['W' 'w'] ['E' 'e'] '_'
      ['C' 'c']['O' 'o']['D' 'd']['E' 'e'] 
      [' ' '\t']* as s) space* newline
    { if lexbuf.lex_start_p.pos_cnum = !start_of_line then
        (add s ; finish_line lexbuf ; token lexbuf)  (* return *)
      else
        (add s ; finish_line lexbuf ; algolw_long_comment lexbuf)  (* ignore *) }
| ('@' ['A' 'a']['W' 'w'] ['E' 'e'] '_'
      ['T' 't']['E' 'e']['X' 'x']['T' 't'] 
      [' ' '\t']*  as s) space* newline      
    { if lexbuf.lex_start_p.pos_cnum = !start_of_line then
        error lexbuf  (* previous "AWE_TEXT" was not closed *)
      else
        (add s ; finish_line lexbuf ; algolw_long_comment lexbuf) (* ignore *) }
| eof   
    { error lexbuf }
| newline
    { finish_line lexbuf ; algolw_long_comment lexbuf }
| _ as c
    { addc c ; algolw_long_comment lexbuf }


(* String constant. *)
and string_constant = parse
| "\"\""  as s { add s ; string_constant lexbuf }  (* A doubled quote is an escape for a quote. *)
| "\""    as s { addc s ; token lexbuf }
| eof     { error lexbuf }
| newline { error lexbuf }
| _       as s { addc s ; string_constant lexbuf }

{
  token (Lexing.from_channel stdin)
}

(* end *)

(* testparsing.mll -- test parser.mly and lexer.mll on one-line examples 

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

{ open Printf
  open Lexing

  let rstrip s =
    let rec loop = function
      | -1 -> ""
      | i when s.[i] = ' ' -> loop (i - 1)
      | i -> (String.sub s 0 (i + 1))
    in
    loop (String.length s - 1)

  let error_count = ref 0 
}

let spaces = [' ' '\t']+
let line = [^'$' '\n'][^ '\n']* 
let comment = '$' [^ '\n']*

rule test entry_point error_count file_name line_number = 
  parse
  | eof
      { error_count }
  | spaces? comment? '\n'
      { test entry_point error_count file_name (line_number + 1) lexbuf }
  | comment '\n'
      { test entry_point error_count file_name (line_number + 1) lexbuf }
  | (line as first) '\n' (line as second)
      { let input_string = rstrip first in 
        let expected_string = rstrip second in 
        let output_string = 
          let lexbuf = Lexing.from_string input_string in
          let error loc msg = sprintf "%*s^%s" (Location.column loc) "" msg in
          try
            entry_point lexbuf
          with
          | Lexer.Error (loc, msg) -> error loc msg 
          | Parsing.Parse_error -> 
              error (Location.of_position (Lexing.lexeme_start_p lexbuf)) "Syntax Error" 
        in
        if output_string = expected_string then 
          test entry_point error_count file_name (line_number + 1) lexbuf
        else 
          ( fprintf stderr "File %S, line %i:\n   input %S\n  output %S\nexpected %S\n" 
              file_name line_number input_string output_string expected_string ;
            test entry_point (error_count + 1)  file_name (line_number + 1) lexbuf
          )
      }
  | _ 
      { fprintf stderr "File %S, line %i:\ntest file syntax error\n" file_name line_number ;
        (error_count + 1) }
      

{ 
  let usage = "Usage:\n test-parsing --test (declarations|expressions) <test-file-name> ...\n"

  let action = ref ""
  let file_names = ref []
  let add_file name = file_names := !file_names @ [name]
      
  let () =
    Arg.parse (Arg.align ["--test", Arg.Set_string action, ""]) add_file usage ;
    Lexer.give_warnings := false ;
    let entry_point =
      match !action with
      | "expressions"  -> (fun lexbuf -> Tree.str (Parser.test_expression  Lexer.token lexbuf))
      | "declarations" -> (fun lexbuf -> Tree.str (Parser.test_declaration Lexer.token lexbuf))
      | _ -> failwith "--test is not declaration, program or environment"
    in
    let error_count = List.fold_left 
      ( fun error_count file_name ->
          Location.set_source file_name;
          let chan = open_in file_name in
          let lexbuf = Lexing.from_channel chan in
          let error_count' = test entry_point error_count file_name 1 lexbuf in
          close_in chan ;
          error_count' )
      0 
      !file_names
    in
    if error_count > 0 then 
      ( fprintf stderr "*** %i incorrectly parsed productions ***\n" error_count ;
        exit 1 )
}

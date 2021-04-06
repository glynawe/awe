(* awe.ml -- command line of the Algol W compiler

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
License along with Awe.  If not, see <http://www.gnu.orglicenses/>.

*)

open Lexing ;;
open Printf ;;


let usage : string = "\nUsage: awe [source.alw...] [-o executable | -c output.c | -p output.c]\n"

let error (loc : Location.t) (message : string) : 'a =
  fprintf stderr "%s %s\n" (Location.to_string loc) message ;
  exit 1


(* This returns a lexbuf that takes its input from a list of source files.
   If the list is empty, the input is from stdin instead. *)

let multi_file_lexbuf (sources : string list) : Lexing.lexbuf =
    match sources with
    | [] ->
        let lexbuf = Lexing.from_channel stdin in
        lexbuf.lex_curr_p <- {pos_fname = "<stdin>"; pos_lnum = 0; pos_bol = 0; pos_cnum = 0} ;
        Location.set_source "<stdin>";
        lexbuf
    | first :: rest ->
        let lexbuf = ref (Lexing.from_string "") in  (* dummy *)
        let open_source path =
          !lexbuf.lex_curr_p <- {pos_fname = path; pos_lnum = 0; pos_bol = 0; pos_cnum = 0} ;
          Location.set_source path;
          try
            open_in path
          with Sys_error _ ->
            (fprintf stderr "Awe cannot open source file '%s'\n" path ; exit 1)
        in
        let channel = ref (open_source first) in
        let remaining = ref rest in
        let rec lexbuf_reader buffer n_requested =
          let n = input !channel buffer 0 n_requested in
          if n > 0 then 
            n 
          else  (* end of current file *)
            match !remaining with
            | [] -> 0   (* end of last file *)
            | f :: fs ->
                channel := open_source f ;
                remaining := fs ;
                lexbuf_reader buffer n_requested
        in
        lexbuf := Lexing.from_function lexbuf_reader ;
        !lexbuf


(* This runs a program and returns its exit code. *)

(*
let run (argv : string array) : int =
  match Unix.fork() with
  | 0   -> (try Unix.execvp argv.(0) argv with _ -> exit 127)
  | pid -> 
      match snd (Unix.waitpid [] pid) with
      | Unix.WEXITED exitcode -> exitcode
      | Unix.WSIGNALED signal
      | Unix.WSTOPPED signal  -> assert (signal <> 0) ; signal
*)

type operation_t = Compile | Intermediate | Procedure


let compile (sources : string list) (operation : operation_t) (target : string) : unit =

  let code =
    let lexbuf = multi_file_lexbuf sources in
    let lexloc () = Location.of_position (Lexing.lexeme_start_p lexbuf) in
    try
      match operation with
      | Procedure -> Compiler.separate_procedure (Parser.separate_procedure Lexer.token lexbuf)
      | _ -> Compiler.program (Parser.program Lexer.token lexbuf)
    with
    | Lexer.Error (loc, message)    -> error loc message
    | Parsing.Parse_error           -> error (lexloc()) "Syntax error"
    | Compiler.Error (loc, message) -> error loc message
    | Failure message               -> error (lexloc()) ("Bug in the Awe compiler: " ^ message)
  in

  let output_code path code = 
    try 
      let f = open_out path in
      Code.output_code f code;
      close_out f
    with Sys_error message ->
      fprintf stderr "awe: cannot open %S for output: %s\n" path message ;
      exit 1
  in
  
  match operation with 
  | Intermediate | Procedure ->
      output_code target code
  | Compile ->
      let target_c = target ^ ".awe.c" in
      output_code target_c code ;
      let libs = "-lawe -lm -lgc"  in
      let run_gcc = sprintf "gcc %s %s -o %s" (Filename.quote target_c) libs (Filename.quote target) in
      let exitcode = Sys.command run_gcc in
      if exitcode = 0 then
        Sys.remove target_c
      else
        (fprintf stderr "awe: GCC compilation failed: %s" run_gcc ; exit 1)
;;


let command_line () : string list * operation_t * string =

  let operation = ref Compile in
  let target_filename = ref "" in
  let target_set = ref false in
  let source_files = ref [] in

  let target op filename = 
    if !target_set then 
      raise (Arg.Bad "More than one option flag")
    else 
      ( target_set := true ; 
        operation := op ; 
        target_filename := filename )
  in

  let addfile f = source_files := !source_files @ [f] in

  let rec executable_filename filenames = 
    let lastname = List.hd (List.rev filenames) in
    try 
      Filename.chop_extension lastname
    with 
      Invalid_argument _ -> raise (Arg.Bad (lastname ^ " has no file extension"))
  in

  let options = 
    [ ("-o", Arg.String (target Compile),       " executable Compile to an executable.");
      ("-c", Arg.String (target Intermediate),  " object.c   Compile to a C intermediate file.");
      ("-p", Arg.String (target Procedure),     " object.c   Separately compile a single Algol procedure.");
      ("-i", Arg.Set Options.initialize_all,    " Initialize all variables.");
      ("-t", Arg.Set Options.add_tracing_hooks, " Add tracing hooks.") ] 
  in

  try 
    Arg.parse options addfile usage ;
    if !source_files = [] then raise (Arg.Bad "No source files") ;
    if not !target_set then target_filename := executable_filename !source_files ;
    (!source_files, !operation, !target_filename)
  with Arg.Bad message ->
    Arg.usage options (message ^ usage) ; exit 1
;;


let sources, operation, target = command_line () in
compile sources operation target 
;;


(* end *)  

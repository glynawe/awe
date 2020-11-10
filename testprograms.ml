(* testprograms.ml -- script to run the many little programs in AWE test suite. 

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

open Printf ;;

exception Syntax_error of int ;;

let nfails = ref 0 ;;
let halt_on_error = ref false ;;

let strip_right s =
  let rec loop i = 
    if i = -1 then ""
    else if String.contains " \t\n\r" s.[i] then loop (i - 1)
    else String.sub s 0 (i + 1)
  in
  loop (String.length s - 1)
;;

let strip_left s =
  let n = String.length s in
  let rec loop i = 
    if i = n then s
    else if String.contains " \t\n\r" s.[i] then loop (i + 1)
    else String.sub s i (n - i)
  in
  loop 0
;;

let strip s = strip_right (strip_left s) ;;

let starts_with this s =
  let ns = String.length s in
  let nt = String.length this in
  nt <= ns && String.sub s 0 nt = this
;;  


let read_whole_file filename =
  if Sys.file_exists filename then
    let chan = open_in filename in
    let lines = ref [] in 
    ( try
        while true do
          lines := (strip_right (input_line chan) ^ "\n") :: !lines
        done
      with End_of_file ->
        close_in chan 
    );
    let s = String.concat "" (List.rev !lines) in
    if s <> "" && s.[String.length s - 1] <> '\n' then
      s ^ "\n"
    else
      s
  else 
    ""
;;

let write_whole_file filename contents =
  let chan = open_out filename in
  output_string chan contents;
  close_out chan
;;

let input_test chan =
  let awe_flags = ref "" in
  let awe_compile = ref "" in
  let awe_messages = ref "" in
  let awe_stdout = ref "" in
  let awe_stdin = ref "" in
  let awe_stderr = ref "" in
  let awe_exitcode = ref 0 in
  let line = ref "" in
  let linenum = ref 0 in
  let text = Buffer.create 1024 in
  let eatlines eof_okay =
    Buffer.clear text;
    try 
      line := strip_right (input_line chan);
      incr linenum;
      while not (starts_with "----" !line) do
        Buffer.add_string text !line ;
        Buffer.add_char text '\n' ;
        line := strip_right (input_line chan) ;
        incr linenum;
      done;
      Buffer.contents text
    with End_of_file ->
      if eof_okay then
        Buffer.contents text
      else
        raise (Syntax_error !linenum)
  in
  let eatcode () =
    try
      Scanf.sscanf (eatlines false) " %i " (fun i -> i);
    with Failure _->
      raise (Syntax_error !linenum)
  in
  ignore (eatlines true);
  if starts_with "----" !line then
    begin
      if starts_with "----flags" !line then awe_flags := strip (eatlines false);
      if starts_with "----stdin" !line then awe_stdin := eatlines false;
      if starts_with "----compile" !line then awe_compile := eatlines false;
      if starts_with "----messages" !line then awe_messages := eatlines false;
      if starts_with "----stdout" !line then awe_stdout := eatlines false;
      if starts_with "----stderr" !line then awe_stderr := eatlines false;
      if starts_with "----exitcode" !line then awe_exitcode := eatcode () ;
      if not (starts_with "----end" !line) then raise (Syntax_error !linenum);
    end;
  (!awe_flags, !awe_compile, !awe_messages, !awe_stdin, !awe_stdout, !awe_stderr, !awe_exitcode)
;;  

let run_commands cs =
  let rec loop =
    function
    | [] -> 0
    | c :: cs' ->
        let exitcode = Sys.command c in
        if exitcode = 0 then
          loop cs'
        else
          exitcode
  in loop cs
;;

let run_test filename awe_flags awe_compile awe_messages awe_stdin awe_stdout awe_stderr awe_exitcode =
  print_endline filename;
  let s = String.sub filename 0 (String.index filename '.') in
  let compilation_exitcode = 
    run_commands
      [ "rm -f testme testme-compile testme-messages testme-stderr testme-stdin testme-stdout";
        sprintf "./awe %s %s.alw -c %s.awe.c 1>testme-messages 2>testme-compile" awe_flags s s;
        sprintf "gcc -I. -L. '%s.awe.c' -lawe -lgc -lm -o testme 2>>testme-compile" s ]
  in
  let () = write_whole_file "testme-stdin" awe_stdin in
  let awe_exitcode' = 
    if compilation_exitcode = 0 then
      Sys.command "./testme <testme-stdin >testme-stdout 2>testme-stderr"
    else
      0  (* i.e. try to ignore it *)
  in
  let awe_compile' = read_whole_file "testme-compile" in
  let awe_messages' = read_whole_file "testme-messages" in
  let awe_stderr'  = read_whole_file "testme-stderr"  in
  let awe_stdout'  = read_whole_file "testme-stdout"  in
  if awe_compile' <> awe_compile || 
    awe_stderr'   <> awe_stderr  || 
    awe_messages' <> awe_messages  || 
    awe_stdout'   <> awe_stdout  ||
    awe_exitcode' <> awe_exitcode 
  then
    begin
      if awe_compile' <> awe_compile then
        printf "*** Got this compiler error:\n%s\nExpected:\n%s\n" awe_compile' awe_compile ;
      if awe_messages' <> awe_messages then
        printf "*** Got these compiler messages:\n%s\nExpected:\n%s\n" awe_messages' awe_messages ;
      if awe_stdout' <> awe_stdout then
        printf "*** Got this output on stdout:\n%s\nExpected:\n%s\n" awe_stdout' awe_stdout ;
      if awe_stderr' <> awe_stderr then
        printf "*** Got this output on stderr:\n%s\nExpected:\n%s\n" awe_stderr' awe_stderr ;
      if awe_exitcode' <> awe_exitcode then
        printf "*** Got exit code %i, expected %i\n" awe_exitcode' awe_exitcode ;
      incr nfails ;
      if !halt_on_error then exit 1
    end
;;

let test_file filename =
  let chan = open_in filename in
  let flags, compile, messages, stdin, stdout, stderr, exitcode = 
    try 
      input_test chan
    with Syntax_error linenum ->
      begin
        close_in chan ;
        fprintf stderr "File %S, line %i: test file syntax error\n" filename linenum ;
        exit 1 
      end
  in
  close_in chan ;
  run_test filename flags compile messages stdin stdout stderr exitcode
;;

let _ =
  for i = 1 to Array.length Sys.argv - 1 do
    if Sys.argv.(i) = "-h" then
      halt_on_error := true
    else
      test_file Sys.argv.(i)
  done ;
  if !nfails = 0 then
    printf "testprograms: All test suite programs passed!\n"
  else
    begin
      printf "testprograms: %i test suite programs failed.\n" !nfails ;
      exit 1
    end
;;

(* end *)

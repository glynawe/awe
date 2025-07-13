(* location.ml 

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

type source_t = { file_name           : string;
                  file_number         : int } 
      
type t = { source : source_t;
           line   : int;
           column : int }

let filename loc     = loc.source.file_name
let file_number loc  = loc.source.file_number
let line loc         = loc.line
let column loc       = loc.column
    
let to_string loc = 
  Printf.sprintf "%s:%i:%i:" (filename loc) (line loc) (column loc + 1)


let sources : (string, source_t) Hashtbl.t = Hashtbl.create 20

let source_list : source_t list ref = ref []

  
let source_files () = List.map (function source -> source.file_name) !source_list

                                          
let create_source file_name  =
  try
    Hashtbl.find sources file_name
  with Not_found ->
    let file_number = List.length !source_list in
    let source = {file_name; file_number} in
    source_list := !source_list @ [source] ;
    Hashtbl.add sources file_name source ;
    source
                          

let current_source : source_t ref =
  let stdin_source = create_source "<stdin>" in
  ref stdin_source
  

let set_source filename =
  let source = create_source filename in
  current_source := source
                          

let create filename line column =
  let source = create_source filename in
  {source; line; column}
  
  
let of_position (position : Lexing.position) : t =
  let source = !current_source in
  let line   = position.Lexing.pos_lnum in
  let column = position.Lexing.pos_cnum - position.Lexing.pos_bol in
  {source; line; column}

(* end *)

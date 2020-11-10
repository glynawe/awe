(* code.ml 

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

(* The idea here is to leave all the work until the code is output.
   We particularly don't want to concatenate tens of thousands of
   increasing large strings as we go. *)

type t =
  | Empty
  | Id of Table.Id.t
  | String of string
  | Add of t * t
  | Add_comma of t *  t  (* separate with commas when no-empty *)
  | Concat of string * t list
  | Template of string * t list


let empty = Empty

let string s = String s

let id i = Id i

let add a b = Add (a, b)

let add_with_comma a b = Add_comma (a, b)

let separate separator code_list = 
  Concat (separator, code_list)

let concat code_list = 
  Concat ("", code_list)

let template template code_list = 
  Template (template, code_list)


let emit_code (emit_string : string -> unit)  
              (emit_char   : char -> unit) 
              (code        : t) 
              : unit =
  let rec emit_node  =
   function
   | Empty    -> ()
   | String s -> emit_string s
   | Id id    -> emit_string (Table.Id.to_C_id_string id)
   | Add (a, b)           -> emit_node a ; emit_node b
   | Add_comma (a, Empty) -> emit_node a
   | Add_comma (Empty, b) -> emit_node b
   | Add_comma (a, b)     -> emit_node a ; emit_string ", " ; emit_node b
   | Concat (seperator, code_list) -> 
       let rec loop =
         function
         | []      -> ()
         | [c]     -> emit_node c
         | c :: cs -> emit_node c ; emit_string seperator ; loop cs
       in
       loop code_list
   | Template (template, code_list) ->
       let rec loop i cs =
         if i < String.length template then 
           if template.[i] = '$' then
             match cs with
             | [] -> failwith ("Code.emit_code: no arguments for '" ^ template ^ "\"")
             | c :: cs' -> ( emit_node c ; loop (i + 1) cs' )
           else
             ( emit_char template.[i] ; loop (i + 1) cs )
         else
           match cs with
           | [] -> ()
           | _ -> failwith ("Code.emit_code: to many arguments for '" ^ template ^ "\"")
       in
       loop 0 code_list
  in emit_node code


let output_code (ch : out_channel) (code : t) : unit = 
  emit_code (output_string ch) (output_char ch) code 


let to_string (code : t) : string = 
  let buf = Buffer.create 100 in
  emit_code (Buffer.add_string buf) (Buffer.add_char buf) code ;
  Buffer.contents buf 


let rec is_empty =
  function
  | Empty -> true
  | String "" -> true
  | Add (x, y) -> is_empty x && is_empty y
  | Concat (_, xs) -> List.for_all is_empty xs
  | Template ("", _) -> true
  | _ -> false


(* end *)

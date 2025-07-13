(* table.ml 

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


let gnuc_keywords : (string, unit) Hashtbl.t =  Hashtbl.create 50 ;;

List.iter (fun s -> Hashtbl.add gnuc_keywords s ())
  [ "__asm__"; "__const__"; "__extension__"; "__inline__"; "__signed__"; "__typeof__";
    "__volatile__"; "asm"; "auto"; "break"; "case"; "char";
    "const"; "continue"; "default"; "do"; "double"; "else";
    "enum"; "extern"; "float"; "for"; "goto"; "if";
    "inline"; "int"; "long"; "register"; "return"; "short";
    "signed"; "sizeof"; "static"; "struct"; "switch"; "typedef";
    "typeof"; "union"; "unsigned"; "void"; "volatile"; "while" ;
    "_Complex";
    (* these get renamed to prevent the Awe runtime and C standard library names clashing: *)
    "time"; "round"; "odd"; "argc"; "argv"; "truncate";
    (* GCC thinks that all functions named "main" should return an int, not 
       just the outermost one, so let's rename that too to keep GCC happy: *)
    "main"
  ];;


module Id = struct
  type t = int

  let id2string : string DynArray.t = DynArray.create ""

  let string2id : (string, int) Hashtbl.t = Hashtbl.create 83

  let create (str : string) : t =
    let str = String.lowercase_ascii str in
    let str = if (Hashtbl.mem gnuc_keywords str) then (str ^ "_") else str in
    try
      Hashtbl.find string2id str
    with Not_found ->
      let id = DynArray.length id2string in
      DynArray.add id2string str ;
      Hashtbl.add string2id str id ;
      id

  let to_C_id_string (id : t) : string =  (* do not remove trailing '_' *)
    DynArray.get id2string id

  let to_string (id : t) : string =    (* remove trailing '_', if any *)
    let s = DynArray.get id2string id in
    if s.[String.length s - 1] = '_' then
      String.sub s 0 (String.length s - 1)
    else
      s

  let hash (id : t) : int = id

  let compare (id1 : t) (id2 : t) : int = id1 - id2

  let eq (id1 : t) (id2 : t) : bool = (id1 = id2)

  let dummy = -1
end


(* Maps of identifiers to any type. Used in 'Scope'. *)
module IdMap = Map.Make(Id) ;;


(* end *)

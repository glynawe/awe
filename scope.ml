(* scope.ml 

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


exception Undefined of Table.Id.t

exception Redefined of Table.Id.t * Type.definition_t


module Local = 
struct
  type t = Type.definition_t Table.IdMap.t

  let empty = Table.IdMap.empty

  let get block id = 
    try 
      Some (Table.IdMap.find id block)
    with 
      Not_found -> None

  let set block id defn = 
    try 
      let existing_defn = Table.IdMap.find id block in
      raise (Redefined (id, existing_defn))
    with Not_found -> 
      Table.IdMap.add id defn block

  let redefine block id defn = 
    Table.IdMap.add id defn (Table.IdMap.remove id block)

  let fold = Table.IdMap.fold
end
 

type t = Local.t list
    

let empty = [Local.empty]


let push scope = Local.empty :: scope


let pop  = 
  function
  | [] -> failwith "Scope.pop: this popped the global scope."
  | _ :: outer_scope -> outer_scope


let rec get scope id =
  match scope with
  | [] -> raise (Undefined id)
  | local_block :: global_scope ->
      match Local.get local_block id with
      | Some defn -> defn
      | None -> get global_scope id


let set scope id defn =
  match scope with
  | [] -> failwith "This should never happen."
  | local_block :: global_scope -> 
      Local.set local_block id defn :: global_scope

let redefine scope id defn =
  match scope with
  | [] -> failwith "This should never happen."
  | local_block :: global_scope -> 
      Local.redefine local_block id defn :: global_scope

(* end*)

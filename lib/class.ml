(* class.mli -- record class identifiers 

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

(* Record classes are identified by their index in a global class
   array. Awe must give record classes unique C identifiers because C
   structure definitions are always global.  *)

type t = int

let compare a b = a - b

let exception_class = (Table.Id.create "_awe_class_0_exception", "exception")

let global_class_array = DynArray.create (Table.Id.dummy, "")

let create loc id = 
  let name = Table.Id.to_string id in
  let number = DynArray.length global_class_array in
  let global_id = Table.Id.create (Printf.sprintf "_awe_class_%i_%s" number name) in
  DynArray.add global_class_array (global_id, name) ; 
  number

let to_id c     = fst (DynArray.get global_class_array c)

let to_string c = snd (DynArray.get global_class_array c)

let contents () = DynArray.to_list global_class_array

      

(* end *)

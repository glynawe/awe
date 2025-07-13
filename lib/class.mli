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


(* Record classes need unique global C identifiers. This module generates them. *)

type t

val compare : t -> t -> int

val create : Location.t -> Table.Id.t -> t

val to_id : t -> Table.Id.t

val to_string : t -> string  (* the C identifier for the class *)

val contents : unit -> (Table.Id.t * string) list

(* end *)

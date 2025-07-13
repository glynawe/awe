(* dynArray.mli -- An array that grows when elements are added to the end. 

A newly created DynArray.t has no elements.

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

type 'a t

val create : 'a -> 'a t  (* the parameter is a dummy *)
val get : 'a t -> int -> 'a
val add : 'a t -> 'a -> unit
val length : 'a t -> int
val to_list : 'a t -> 'a list

(* end *)


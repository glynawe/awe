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

(* Rapidly concatenatable scraps of C code text. *)

(* A scrap of C code. *)
type t 

val empty : t

(* 'string s' converts the  string 's' to a scrap. *)
val string : string -> t

val id : Table.Id.t -> t

val to_string : t -> string


(* 'separate seperator scrap_list' concatenates a list of C code scraps,
    using the string 'separator' as a separator. *)
val separate : string -> t list -> t


val concat : t list -> t
val add : t -> t -> t

(* Adds two code scraps with a comma between them. 
   But if either of the scraps is empty the separator is not used. *)

val add_with_comma : t -> t -> t

(* 'template template scrap_list' makes a C code scrap, replacing '$'
    signs in 'template' with C code scraps from 'scrap_list'. *)
val template : string -> t list -> t

(* 'output_code channel scrap' outputs 'scrap' to 'channel' as a string. *)
val output_code : out_channel -> t -> unit

(* 'is_empty scrap' returns true if 'scrap' represents an empty string. *)
val is_empty : t -> bool

(* end *)

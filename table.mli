(* table.mli 

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

(* The global symbol table. *)

(* Algol W identifiers. These are case insensitive, but they are always output in lowercase.  
   This interface is compatible with 'Set.OrderedType' and 'Hashtbl.HashableType'. 
*)
module Id : sig

  (* An identifier in an Algol W program. *)
  type t

  (* 'create string' creates a new identifier from an identifier string *)
  val create    : string -> t
    
  (* 'to_string identifier' returns the string representation of an identifier.
      Returns the identifier as a lowercase string *)
  val to_string : t -> string

  (* Returns the string representation of an identifier, with a "_" appended 
     if it would clash with GNU C's reserved words or global identifiers. *)
  val to_C_id_string : t -> string
    
  val hash      : t -> int
  val compare   : t -> t -> int
  val eq        : t -> t -> bool

  val dummy : t  (* an identifer that is never used *)
end


(* Maps of identifiers to any type. Used in Scope module. *)
module IdMap : Map.S with type key = Id.t


(* end *)

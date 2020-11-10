(* scope.mli 

   Declaration scopes for blocks, PROCEDURE formal parameter lists and FOR statements. 

   (The control identifier of a FOR statement is local to its body.) 

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


(* Local scopes: a map of identifiers to definitions. No identifier may be defined twice in a local scope. *)
module Local : 
sig 
  type t
  val empty : t
  val get : t -> Table.Id.t -> Type.definition_t option  (* None if the id is not defined *)
  val set : t -> Table.Id.t -> Type.definition_t -> t    (* Can raise Redefined *)
end


(* Global scopes: a stack of nested local scopes, the top of the stack
   is the innermost scope.  New definitions are placed in the
   innermost scope only, but all scopes are searched in order when
   looking up a definition. The innermost scope is searched first. *)

type t = Local.t list
  

(* Raised by 'get' if an identifier is not defined anywhere in the a global scope. *)

exception Undefined of Table.Id.t


(* 'Redefined (identifier, definition)' is raised by 'set' if it was
   about to be redefine 'identifier' in the local scope. 
   'definition' is the existing definition for 'identifier' *)

exception Redefined of Table.Id.t * Type.definition_t


(* A empty global scope. *)

val empty : t


(* 'push scope' returns the scope with a new, empty local scope added. *)

val push : t -> t
    

(* 'pop scope' returns the scope with the innermost local scope removed.
   Fails if it is applied to the global scope (always a bug.) *)

val pop : t -> t
    

(* 'get identifier scope' returns the  definition of 'identifier' in 'scope'. 
    Raises Undefined if 'identifier' not in 'scope'. *)

val get : t -> Table.Id.t -> Type.definition_t        


(* 'set scope identifier definition' gives 'identifier' a 'definition' of in the local scope.  
    Returns the modified scope.
    Raises Redefined if 'identifier' is already defined in the local scope *)

val set : t -> Table.Id.t -> Type.definition_t -> t


(* 'redefine scope identifier definition' redefines 'identifier' with 'definition' of in the local scope.  
    Returns the modified scope. *)

val redefine : t -> Table.Id.t -> Type.definition_t -> t

(* end *)

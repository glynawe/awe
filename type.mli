(* type.mli -- Algol W data types and identifier definitions

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
License along with Awe.  If not, see <http://www.gnu.org/licenses/>. *)


(* The "See section xxx" comments refer to 'Algol W Language Description, June 1972'. *)


module ClassSet : Set.S with type elt = Class.t   (* For references. See section 5.1  *)

(* Definitions for identifiers in the scope: *)

type definition_t =
  | Variable of simple_t                   (* Simple-type variables, VALUE parameter variables. *)
  | Array of simple_t * int                (* ARRAY variables. *)
  | Name of simple_t                       (* Name parameter variables. *)
  | Result of simple_t                     (* RESULT or VALUE RESULT parameter variables. *)
  | Control                                (* FOR statement control variables. *)
  | Procedure of procedure_t               (* Procedures, PROCEDURE parameter variables. *)
  | Standard of standard                   (* The Standard I/O procedures. See section 7.9. These are variadic. *)
  | Analysis of simple_t                   (* The Standard Functions of Analysis. See section 8.2. These need runtime checks. *)
  | Field of simple_t * Class.t            (* RECORD field selectors. *)
  | Record of Class.t * simple_t list      (* RECORD classes, and their fields. *)
  | Label                                  (* GOTO labels. *)

and procedure_t = simple_t * formal_t list (* a PROCEDURE has a return type and a list of formal parameters *)

and formal_t =
  | By_name         of simple_t
  | By_value        of simple_t
  | By_result       of simple_t
  | By_value_result of simple_t
  | By_procedure    of procedure_t
  | By_array        of simple_t * int  (* int is the number dimensions *)

and simple_t =
  | Number of precision * domain
  | Logical
  | Bits of int              (* int is the word width *)
  | String of int            (* int is the length *)
  | Reference of ClassSet.t
  | Null                     (* NULL has a special record class compatible with all others. See section 4.5 *)
  | Statement                (* FOR and WHILE loops and calls to procedures without return types are "statements".
                                A statement cannot be used in an assignment. Analogous to C's "void" type. *)
and  domain =
  | Integer
  | Real
  | Complex

and precision =
  | Short
  | Long

and standard =
  | Write
  | Writeon
  | Writecard
  | Read
  | Readon
  | Readcard
  | Iocontrol


val integer : simple_t  (* equal to Number(Short, Integer) *)


(* 'assignment_compatible dest src' returns true if a value of simple type
    'src' can assigned to a designator of simple type 'dest'. *)

val assignment_compatible : simple_t -> simple_t -> bool


(* 'equal_simple_types t0 t1' returns 'true' are the same simple type. 
    (note: all references have the same simple type in the eyes of Algol W 
    until runtime, but references with no classes in common will never
    be compatible, so Awe disallows those at compile time. *)

val equal_simple_types : simple_t -> simple_t -> bool


(* 'equal_procedure_types p0 p1' returns 'true' if two procedures have
    the type. Their return types and formal parameter types must match
    up according to the 'equal_simple_types' rules. *)

val equal_procedure_types : procedure_t -> procedure_t -> bool


(* 'triplet_rule t1 t2' returns the simple type general enough to hold values of both type 't1' and 't2'.  
    E.g. INTEGER and REAL have the mutually compatible type REAL because INTEGERs can be cast to REAL.
    see Section 6 of the Algol W Description.
    Raises Incompatible if there is no such type. *)

val triplet_rule : simple_t -> simple_t -> simple_t

exception Incompatible


(* These pretty print type information for error messages: *)

val describe_definition : definition_t -> string

val describe_simple : simple_t -> string

val describe_procedure : procedure_t -> string

val string_of_simple : simple_t -> string

val describe_formal : formal_t -> string

val describe_standard : standard -> string


(* end *)

(* tree.mli -- Algol W parse tree. 

The Parser module generates one of these, and the Compiler module translates it into C code.

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

type id = Table.Id.t
type loc = Location.t  (* the tree is heavily annotated with source code locations, to be used when reporting type errors *)

type t = 
  (* Constants *)
  | Integer        of loc * string
  | Bits           of loc * string
  | String         of loc * string
  | Real           of loc * string * string  (* Stored as decimal and exponent strings, to avoid rounding errors. *)
  | Imaginary      of loc * string * string  
  | LongReal       of loc * string * string
  | LongImaginary  of loc * string * string  
  | TRUE           of loc
  | FALSE          of loc
  | NULL           of loc

  (* statements *)
  | IF_else    of loc * t * t * t   (* test expression,  THEN branch, ELSE branch *)
  | IF         of loc * t * t
  | CASE       of loc * t * t list  (* test expression, branches *)
  | CASE_expr  of loc * t * t list
  | WHILE      of loc * t * t               (* test, body *)
  | FOR        of loc * id * t * t * t      (* control id, initial and final expressions, body *)
  | FOR_step   of loc * id * t * t * t * t  (* control id, initial, step and final expressions, body *)
  | FOR_list   of loc * id * t list * t
  | GOTO       of loc * id
  | ASSERT     of loc * t
  | Empty      of loc
  | BEGIN      of loc * t list * t list * id  (* declarations, statements, labels, closing id *)

  | Label     of loc * id  (* Labels in the bodies of blocks. *)

  | Assignment   of loc * t * t
  | Identifier   of loc * id            (* identifier *)
  | Parametrized of loc * id * t list   (* identifier with parameters: a procedure call or designator *)
  | Substring    of loc * t * t * int   (* string designator, subscript, substring length *)

  | STAR of loc  (* appears in array designators *)

  | Binary of loc * t * t * t  (* left hand side, operator, right hand side *)
  | EQ 
  | NE 
  | GT 
  | LT 
  | GE 
  | LE 
  | IS 
  | ADD 
  | SUB 
  | OR 
  | MUL 
  | RDIV
  | IDIV
  | REM 
  | AND 
  | PWR 
  | SHL 
  | SHR 

  (* Unary expression and operators *)
  | Unary of loc * t * t   (* operator, parameter *)
  | LONG
  | SHORT
  | ABS
  | NOT
  | NEG
  | IDENTITY

  (* declarations *)
  | Simple     of loc * t * id list                  (* simple type, ids *)
  | RECORD     of loc * id * t list                  (* id, field declarations *)
  | ARRAY      of loc * t * id list * (t * t) list   (* simple type, ids, list of bounds pairs *)
  | PROCEDURE  of loc * t option * id * t list * t   (* simple type (for functions), id, formals, body expression *)

  (* Simple types *)
  | INTEGER
  | BITS
  | STRING of int option
  | REAL
  | COMPLEX
  | LONG_REAL
  | LONG_COMPLEX
  | LOGICAL
  | REFERENCE of loc * id list

  (* formal parameters *)
  | Name_formal         of loc * t * id list   (* simple type, ids *)
  | VALUE_formal        of loc * t * id list
  | RESULT_formal       of loc * t * id list
  | VALUE_RESULT_formal of loc * t * id list
  | PROCEDURE_formal    of loc * t option * id list * t list  (* return type (for functions), ids, formals *)
  | ARRAY_formal        of loc * t * id list * int  (* simple type, ids, number of dimensions *)

  (* external interface procedure body *)
  | External of loc * string


val to_loc : t -> loc                 (* Returns the most sensible source code location for an error message. *)

val str : t -> string                 (* Convert a tree back to Algol W. Mostly used when testing the parser. *)

val str_of_header : t option -> id -> t list -> string  (* Convert the tree for a procedure header back to Algol W. *)

(* end *)

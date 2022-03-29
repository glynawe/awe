(* type.ml 

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

open Printf

module ClassSet = Set.Make(Class)

type definition_t =
  | Variable of simple_t
  | Array of simple_t * int  (* element type, number of dimensions *)
  | Name of simple_t
  | Result of simple_t
  | Control
  | Procedure of procedure_t
  | Standard of standard
  | Analysis of simple_t
  | Field of simple_t * Class.t
  | Record of Class.t * simple_t list
  | Label

and procedure_t = simple_t * formal_t list

and formal_t =
  | By_name of simple_t
  | By_value of simple_t
  | By_result of simple_t
  | By_value_result of simple_t
  | By_procedure of procedure_t
  | By_array of simple_t * int

and simple_t =
  | Number of precision * domain
  | Logical
  | Bits
  | String of int
  | Reference of ClassSet.t
  | Null
  | Statement

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

let integer = Number(Short,Integer)


exception Incompatible

(* In the case of references, assignment compatibility is mostly determined at runtime. *)

let assignment_compatible dest src =
  match dest, src with
  |  Number(_, d1),     Number(_, d2)     -> d1 >= d2
  |  String l1,         String l2         -> l1 >= l2
  |  Reference x,       Reference y       -> ClassSet.inter x y <> ClassSet.empty
  |  Reference _,       Null              -> true
  |  Logical,           Logical           -> true
  |  Bits,              Bits              -> true
  |  _,                 _                 -> false


(* All references are equal in the eyes of Algol W until runtime,
   but references with no classes in common are clearly never equal. *)

let equal_simple_types t0 t1 =
  match t0, t1 with
  | Reference x,           Reference y          -> ClassSet.inter x y <> ClassSet.empty
  | (Reference _ | Null),  (Reference _ | Null) -> true
  | _, _                                        -> t0 = t1


let rec equal_procedure_types (t0, fs0) (t1, fs1) = 
  equal_simple_types t0 t1 && equal_formal_types fs0 fs1

and equal_formal_types fs0 fs1 = 
  List.length fs0 = List.length fs1 && List.for_all2 equal_formal_type fs0 fs1 
  
and equal_formal_type f0 f1 =
  match f0, f1 with
  | By_name t0,         By_name t1         -> equal_simple_types t0 t1
  | By_value t0,        By_value t1        -> equal_simple_types t0 t1
  | By_result t0,       By_result t1       -> equal_simple_types t0 t1
  | By_value_result t0, By_value_result t1 -> equal_simple_types t0 t1
  | By_procedure p0,    By_procedure p1    -> equal_procedure_types p0 p1
  | By_array (t0, n0),  By_array (t1, n1)  -> equal_simple_types t0 t1 && n0 = n1
  | _ -> false


let triplet_rule t1 t2 =
  match t1, t2 with
  | Number (p1, d1),   Number (p2, d2)   -> Number (max p1 p2, max d1 d2)
  | String  l1,        String l2         -> String (max l1 l2)
  | Null,              Reference c       -> Reference c
  | Reference c,       Null              -> Reference c
  | Reference c1,      Reference c2      -> Reference (ClassSet.union c1 c2)
  | Logical,           Logical           -> Logical
  | Bits,              Bits              -> Bits
  | Statement,         Statement         -> Statement
  | _,                 _                 -> raise Incompatible


let rec describe_definition =
  function
  | Variable t -> describe_simple t ^ " variable"
  | Result t -> describe_simple t ^ " variable"
  | Control -> "a FOR loop control identifier"
  | Array (t,d) -> sprintf "a %i dimensional %s ARRAY" d (string_of_simple t)
  | Name t  -> describe_simple t ^ " call-by-name parameter identifier"
  | Procedure (Statement,_)  -> "a proper PROCEDURE identifier"
  | Procedure (t,_)  -> describe_simple t ^ " PROCEDURE identifier"
  | Analysis t  -> describe_simple t ^ " PROCEDURE identifier"
  | Standard t -> "the standard procedure " ^ describe_standard t
  | Record (c, _) -> sprintf "the RECORD %s"  (Class.to_string c)
  | Field (t, _) -> describe_simple t ^ " record field identifier"
  | Label -> "a label"

and string_of_simple =
  function
  | Statement              -> "statement"
  | Number(Long, Integer) -> failwith "string_of_simple (Number(Long, Integer))"
  | Number(Short, Integer)  -> "INTEGER"
  | Number(Short, Real)    -> "REAL"
  | Number(Long, Real)     -> "LONG REAL"
  | Number(Short, Complex) -> "COMPLEX"
  | Number(Long, Complex)  -> "LONG COMPLEX"
  | Logical                -> "LOGICAL"
  | Null                   -> "NULL"
  | Bits                   -> "BITS"
  | String length          -> sprintf "STRING(%i)" length
  | Reference set -> 
      sprintf "REFERENCE(%s)" (String.concat ", " (List.map Class.to_string (ClassSet.elements set)))

and describe_simple = 
  function
  | Bits -> "BITS"
  | Number(_, Integer) as t  -> "an " ^ string_of_simple t
  | t -> "a " ^ string_of_simple t

and describe_formal =
  function
  | By_name t -> describe_simple t ^ " call-by-name parameter"
  | By_value t -> describe_simple t ^ " VALUE parameter"
  | By_result t -> describe_simple t ^ " RESULT parameter"
  | By_value_result t -> describe_simple t ^ " VALUE RESULT parameter"
  | By_procedure (Statement, fs) -> sprintf "a PROCEDURE parameter"
  | By_procedure (t, fs) -> sprintf "%s PROCEDURE parameter" (describe_simple t)
  | By_array (t, d) -> sprintf "a %i dimensional %s ARRAY parameter" d (string_of_simple t)

and describe_procedure =
  function
  | (Statement, fs) -> sprintf "PROCEDURE%s" (describe_formals_briefly fs)
  | (t, fs) -> sprintf "%s PROCEDURE%s" (describe_simple t) (describe_formals_briefly fs)

and describe_formals_briefly fs =
  match fs with
  | [] -> ""
  | _ -> " (" ^ (String.concat "; " (List.map describe_formal_briefly fs)) ^ ")"

and describe_formal_briefly =
  function
  | By_name t -> string_of_simple t
  | By_value t -> string_of_simple t ^ " VALUE"
  | By_result t -> string_of_simple t ^ " RESULT"
  | By_value_result t -> string_of_simple t ^ " VALUE RESULT"
  | By_procedure (Statement, fs) -> sprintf "PROCEDURE%s" (describe_formals_briefly fs)
  | By_procedure (t, fs) -> sprintf "%s PROCEDURE%s" (string_of_simple t) (describe_formals_briefly fs)
  | By_array (t, d) -> sprintf "%s ARRAY (%s)"  (string_of_simple t) (stars d)

and stars = 
  function
  | 1 -> "*"
  | n -> "*, " ^ stars (n - 1)

and describe_standard =
  function
  | Write -> "WRITE"
  | Writeon -> "WRITEON"
  | Writecard -> "WRITECARD"
  | Read -> "READ"
  | Readon -> "READON"
  | Readcard -> "READCARD"
  | Iocontrol -> "IOCONTROL"

(* end *)

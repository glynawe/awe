(* tree.ml -- Algol W parse tree. 

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
type loc = Location.t

type t =
    Integer of loc * string
  | Bits of loc * string
  | String of loc * string
  | Real of loc * string * string
  | Imaginary of loc * string * string
  | LongReal of loc * string * string
  | LongImaginary of loc * string * string
  | TRUE of loc
  | FALSE of loc
  | NULL of loc
  | IF_else of loc * t * t * t
  | IF of loc * t * t
  | CASE of loc * t * t list
  | CASE_expr of loc * t * t list
  | WHILE of loc * t * t
  | FOR of loc * id * t * t * t
  | FOR_step of loc * id * t * t * t * t
  | FOR_list of loc * id * t list * t
  | GOTO of loc * id
  | ASSERT of loc * t
  | Empty of loc
  | BEGIN of loc * t list * t list * id
  | Label of loc * id
  | Assignment of loc * t * t
  | Identifier of loc * id
  | Parametrized of loc * id * t list
  | Substring of loc * t * t * int
  | STAR of loc
  | Binary of loc * t * t * t
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
  | Unary of loc * t * t
  | LONG
  | SHORT
  | ABS
  | NOT
  | NEG
  | IDENTITY
  | Simple of loc * t * id list
  | RECORD of loc * id * t list
  | ARRAY of loc * t * id list * (t * t) list
  | PROCEDURE of loc * t option * id * t list * t
  | INTEGER
  | BITS
  | STRING of int option
  | REAL
  | COMPLEX
  | LONG_REAL
  | LONG_COMPLEX
  | LOGICAL
  | REFERENCE of loc * id list
  | Name_formal of loc * t * id list
  | VALUE_formal of loc * t * id list
  | RESULT_formal of loc * t * id list
  | VALUE_RESULT_formal of loc * t * id list
  | PROCEDURE_formal of loc * t option * id list * t list
  | ARRAY_formal of loc * t * id list * int
  | External of loc * string


let sprintf = Printf.sprintf


let algolw_string_literal s =
  let b = Buffer.create 32 in
  Buffer.add_char b '"';
  for i = 0 to String.length s - 1 do
    match s.[i] with
    | '"' -> Buffer.add_string b "\"\""
    | c   -> Buffer.add_char b c
  done;
  Buffer.add_char b '"';
  Buffer.contents b


(* 'str tree' converts 'tree' back into a string of Algol W code.

   This function is meant for producing small snippets of Algol code
   for compiler error messages and the parser testing program. 

   If you change the format of anything here you will have to update
   testparsing.mll's data files.  Note that the unnecessary-looking
   parentheses are for verifying that operator and statement
   precidences are being parsing correctly. *)

let rec str : t -> string =  
  function
    | Integer (_, s) -> s
    | Bits (_, s) -> sprintf "#%s" s
    | String (_, s) -> algolw_string_literal s
    | Real          (_, r, "") -> r
    | Imaginary     (_, r, "") -> r ^ "I"
    | LongReal      (_, r, "") -> r ^ "L"
    | LongImaginary (_, r, "") -> r ^ "IL"
    | Real          (_, r, e)  -> sprintf "%s'%s" r e
    | Imaginary     (_, r, e)  -> sprintf "%s'%sI" r e
    | LongReal      (_, r, e)  -> sprintf "%s'%sL" r e
    | LongImaginary (_, r, e)  -> sprintf "%s'%sIL" r e
    | TRUE (_) -> "TRUE"
    | FALSE (_) -> "FALSE"
    | NULL (_) -> "NULL"

    | Assignment (_, d, value)         -> sprintf "(%s := %s)" (str d) (str value)
    | Identifier (_, id)                 -> Table.Id.to_string id
    | Parametrized (_, id, actuals )     -> sprintf "%s(%s)" (Table.Id.to_string id) (comma_strs actuals)
    | Substring (_, src, start, length ) -> sprintf "%s(%s | %i)" (str src) (str start) length
    | STAR _  -> "*"

    | Binary (_, left, op, right) -> sprintf "(%s %s %s)" (str left) (str op) (str right)
    | EQ -> "="
    | NE -> "~="
    | GT -> ">"
    | LT -> "<"
    | GE -> ">="
    | LE -> "<="
    | IS -> "IS"
    | ADD -> "+"
    | SUB -> "-"
    | OR -> "OR"
    | MUL -> "*"
    | RDIV -> "/"
    | IDIV -> "DIV"
    | REM -> "REM"
    | AND -> "AND"
    | PWR -> "**"
    | SHL -> "SHL"
    | SHR -> "SHR"

    | Unary (_, op, right) -> sprintf "(%s %s)" (str op) (str right)
    | IDENTITY -> "+"
    | NEG -> "-"
    | NOT-> "~"
    | LONG -> "LONG"
    | SHORT -> "SHORT"
    | ABS -> "ABS"
        
    | IF_else (_, condition, then_branch, else_branch) -> 
        sprintf 
          "(IF %s THEN %s ELSE %s)" 
          (str condition) 
          (str then_branch) 
          (str else_branch)
    | IF (_, condition, then_branch) -> 
        sprintf 
          "(IF %s THEN %s)"
          (str condition)
          (str then_branch)
    | CASE (_, selector, branches) -> 
        ( match branches with
          | [] -> sprintf "CASE %s OF BEGIN END" (str selector)
          | _  -> 
              sprintf 
                "CASE %s OF BEGIN %s END"
                (str selector) 
                (String.concat "; " (List.map str branches))
        )
    | CASE_expr (_, selector, branches) -> 
        sprintf 
          "CASE %s OF (%s)"
          (str selector) 
          (comma_strs branches)
    | WHILE (_, condition, body) -> 
        sprintf "(WHILE %s DO %s)" (str condition) (str body)
    | FOR (_, counter, first, last, body) -> 
        sprintf 
          "(FOR %s := %s UNTIL %s DO %s)" 
          (Table.Id.to_string counter) 
          (str first) 
          (str last) 
          (str body)
    | FOR_step (_, counter, first, step, last, body) -> 
        sprintf 
          "(FOR %s := %s STEP %s UNTIL %s DO %s)" 
          (Table.Id.to_string counter) 
          (str first) 
          (str step) 
          (str last) 
          (str body)
    | FOR_list (_, counter, values, body) -> 
        sprintf 
          "(FOR %s := %s DO %s)" 
          (Table.Id.to_string counter) 
          (comma_strs values)
          (str body)
    | GOTO (_, label) ->
        sprintf 
          "(GOTO %s)" 
          (Table.Id.to_string label)
    | ASSERT (_, condition) ->
        sprintf 
          "(ASSERT %s)" 
          (str condition)
    | Empty (_) -> 
        "(*empty*)"    
        
  | BEGIN (_, ds, ss, id) -> 
     ( let ends =
         if id = Table.Id.dummy then "END"
         else "END " ^ Table.Id.to_string id
       in
       match (ds, ss) with
        | ([], []) -> "BEGIN " ^ ends
        | ([], _) -> sprintf "BEGIN %s %s" (block_body_items ss) ends
        | (_, _) -> 
            sprintf 
              "BEGIN %s; %s %s" 
              (semicolon_strs ds)
              (block_body_items ss)
              ends
      )
        
  | INTEGER -> "INTEGER"
  | BITS -> "BITS"
  | STRING (Some len) -> sprintf "STRING(%i)" len
  | STRING None -> sprintf "STRING"
  | REAL -> "REAL"
  | COMPLEX -> "COMPLEX"
  | LONG_REAL -> "LONG REAL"
  | LONG_COMPLEX -> "LONG COMPLEX"
  | LOGICAL -> "LOGICAL"
  | REFERENCE (_, ids) -> sprintf "REFERENCE(%s)" (String.concat ", " (List.map Table.Id.to_string ids))

  | Simple (_, simpletype, identifiers ) -> 
      sprintf 
        "%s %s" 
        (str simpletype) 
        (comma_ids identifiers)
  | ARRAY (_, simpletype, identifiers, dimensions_list ) ->
      sprintf 
        "%s ARRAY %s (%s)" 
        (str simpletype) 
        (comma_ids identifiers)
        (String.concat ", " (List.map (fun(l, h) -> sprintf "%s :: %s" (str l) (str h)) dimensions_list))
        
  | RECORD (_, recordclass, []) ->
      sprintf 
        "RECORD %s" 
        (Table.Id.to_string recordclass) 
  | RECORD (_, recordclass, field_declarations ) ->
      sprintf 
        "RECORD %s (%s)" 
        (Table.Id.to_string recordclass) 
        (semicolon_strs field_declarations)

  | PROCEDURE (_, st, id, fs, body) ->
      sprintf "%s %s" (str_of_header st id fs) (str body)

  | External (_, link) ->   
      sprintf "ALGOL \"%s\"" link (* all external linkage schemes are the same to Awe *)
        
  | Name_formal         (_, t, ids) -> sprintf "%s %s" (str t) (comma_ids ids)
  | VALUE_formal        (_, t, ids) -> sprintf "%s VALUE %s" (str t) (comma_ids ids)
  | RESULT_formal       (_, t, ids) -> sprintf "%s RESULT %s" (str t) (comma_ids ids)
  | VALUE_RESULT_formal (_, t, ids) -> sprintf "%s VALUE RESULT %s" (str t) (comma_ids ids)
  | PROCEDURE_formal    (_, None, ids, fs) -> sprintf "PROCEDURE %s%s" (comma_ids ids) (formals fs)
  | PROCEDURE_formal    (_, Some t, ids, fs) -> sprintf "%s PROCEDURE %s%s" (str t) (comma_ids ids) (formals fs)
      
  | ARRAY_formal        (_, t, ids, dim) -> sprintf "%s ARRAY %s (%s)" (str t) (comma_ids ids) (stars dim)

  | Label (_, id)  -> sprintf "%s:" (Table.Id.to_string id)

and str_of_header simpletype identifier parameters =
  match simpletype with
  | None -> sprintf "PROCEDURE %s%s;" (Table.Id.to_string identifier) (formals parameters)
  | Some t -> sprintf "%s PROCEDURE %s%s;" (str t) (Table.Id.to_string identifier) (formals parameters)

and comma_strs trees      = (String.concat ", " (List.map str trees))    
and semicolon_strs trees  = (String.concat "; " (List.map str trees))    
and comma_ids ids         = (String.concat ", " (List.map Table.Id.to_string ids))    
and block_body_items = 
  function
  | []                      -> ""
  | Label (_, id) :: []    -> sprintf "%s:" (Table.Id.to_string id)
  | Label (_, id) :: items -> sprintf "%s: " (Table.Id.to_string id) ^ block_body_items items
  | e             :: []    -> str e
  | e             :: items -> str e ^ "; " ^ block_body_items items
and stars = 
  function
  | 1 -> "*"
  | n -> "*, " ^ stars (n - 1)
and formals fs =
  match fs with
  | [] -> ""
  | _ -> sprintf " (%s)" (semicolon_strs fs)
      

(* Finds the last element of a list. *)

let rec last (xs : 'a list) : 'a =
  match xs with 
  | []       -> failwith "last"
  | [x]      -> x
  | x :: xs' -> last xs'


(* Returns the best location to report an error. *)

let rec to_loc : t -> Location.t =
  function
  | Integer (loc, _) -> loc
  | Bits (loc, _) -> loc
  | String (loc, _) -> loc
  | Real (loc, _, _) -> loc
  | Imaginary (loc, _, _  ) -> loc
  | LongReal (loc, _, _) -> loc
  | LongImaginary (loc, _, _  ) -> loc
  | TRUE (loc) -> loc
  | FALSE (loc) -> loc
  | NULL (loc) -> loc
  | IF_else (loc, _, _, _) -> loc
  | IF (loc, _, _) -> loc
  | CASE (loc, _, _) -> loc
  | CASE_expr (loc, _, _) -> loc
  | WHILE (loc, _, _) -> loc
  | FOR (loc, _, _, _, _) -> loc
  | FOR_step (loc, _, _, _, _, _) -> loc
  | FOR_list (loc, _, _, _) -> loc
  | GOTO (loc, _) -> loc
  | ASSERT (loc, _) -> loc
  | Empty (loc) -> loc
  | BEGIN (_, _, ss, _) -> to_loc (last ss)  (* error messages are about the type of the last expression *)
  | Label (loc, _) -> loc
  | Assignment (loc, _, _) -> loc
  | Identifier (loc, _) -> loc
  | Parametrized (loc, _, _) -> loc
  | Substring (loc, _, _, _) -> loc
  | Binary (loc, _, _, _) -> loc
  | Unary (loc, _, _) -> loc
  | Simple (loc, _, _) -> loc
  | RECORD (loc, _, _) -> loc
  | ARRAY (loc, _, _, _) -> loc
  | PROCEDURE (loc, _, _, _, _) -> loc
  | Name_formal (loc, _, _) -> loc
  | VALUE_formal (loc, _, _) -> loc
  | RESULT_formal (loc, _, _) -> loc
  | VALUE_RESULT_formal (loc, _, _) -> loc
  | PROCEDURE_formal (loc, _, _, _) -> loc
  | ARRAY_formal (loc, _, _, _) -> loc
  | External (loc, _) -> loc
  | symbol -> failwith (sprintf "Tree.to_loc: %s has no location" (str symbol))


(* end *)

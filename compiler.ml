(* compiler.ml -- combined type checking and code generation pass *)

(* Use Emacs' outline-minor-mode to navigate *)
(* "egrep -nH -e '\(\* \*|^let|^and' compiler.ml" for a rough index *)

(* The "See section n.n.n" comments refer to 'Algol W Language Description, June 1972'. *)


(* * GNU bafflegab. ----------------------------------------------------------------*)

(* This file is part of Awe. Copyright 2012 Glyn Webster.

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


(* * Support types ---------------------------------------------------------------- *)

open Type   (* for ClassSet module, and all sorts of types and variants *)
open Table  (* for Id module *)


(* Algol expressions and designators are translated into scraps of C code. *)
(* There will be lots of these typed_code_t values flying around.*)

type typed_code_t = {
  c : Code.t;        (* The C code translation of the expression or designator. *)
  t : Type.simple_t  (* The Algol "simple type" of the expression or designator. *)
}


(* Procedure actual parameters may be either designators or expressions.
   How they are used depends on the corresponding formal parameter. *)

type designator_or_expression_t =
  | Designator of typed_code_t
  | Expression of typed_code_t


(* Designators need to be translated into C pointer lvalues in some places, 
   C rvalues in others. (See the function 'designator_or_expression' for details.) *)

type designator_t =
  | Pointer
  | Lvalue


(* These types are used to accumulate data and C code for the declarations in block bodies: *)


(* The Algol scope and C code fragments for constructing a block. See the 'block_expression'. *)

type block_t = {
  scope          : Scope.t;          (* the scope introduced by the block. *)
  outsidescope   : Code.t;           (* code to be executed outside the block (array bounds expressions.) *)
  labels         : Code.t;           (* __label__ definitions, which must appear first in the C block *)
  prototypes     : Code.t;           (* function prototypes, which must all appear before any function definitions *) 
  structs        : Code.t;           (* struct declarations for record classes *)
  variables      : Code.t;           (* simple variable declarations *)
  functions      : Code.t;           (* function definitions *) 
  initialization : Code.t;           (* assignment statements to initialize simple variables and arrays *)
  procedures     : procedure_header_t list  (* see below *)
}

(* An Algol procedure declaration, and its C function header. The translation of a procedure's 
   body is delayed until all definitions in its surrounding block are known. 
   See 'add_procedure_functions' and 'add_procedure_declaration' *)

and procedure_header_t = {
  returntype : Type.simple_t;
  proc_id    : Id.t;
  proc_loc   : Location.t;
  parameters : formal_parameters_t;
  header     : Code.t;               (* C-code header for a procedure's C function and prototype *)
  body       : Tree.t                (* the parse tree of the body of a procedure, saved for later. *)
}
and formal_parameters_t = {
  procedure_locals : Scope.Local.t;       (* definitions of the formal parameters, valid in a procedure's body *)
  formal_types     : Type.formal_t list;  (* the formal types of the parameters, in order *)
  arguments        : Code.t;              (* the C function arguments for the parameters *)
}

(* Pieces of C code gathered while translating procedure actual parameters:
    *)

and actual_parameters_t = {
  decls   : Code.t;  (* temporary variable and thunk function declarations *)
  precall : Code.t;  (* assignments to VALUE RESULT temporary variables *)
  args    : Code.t;  (* C function call arguments *)
  postcall: Code.t   (* assignments to RESULT parameter variables *)
}

let empty_block =
  { scope          = Scope.empty;
    outsidescope   = Code.empty;
    prototypes     = Code.empty;
    labels         = Code.empty;
    variables      = Code.empty;
    structs        = Code.empty;
    functions      = Code.empty;
    initialization = Code.empty;
    procedures     = [] 
  }

let empty_formal_parameters =
  { procedure_locals = Scope.Local.empty;
    formal_types     = [];
    arguments        = Code.empty }


let empty_actual_parameters = 
  { decls    = Code.empty;
    precall  = Code.empty;
    args     = Code.empty;
    postcall = Code.empty }

(* * Support functions ---------------------------------------------------------------- *)


(* Shorthand for constucting C code scraps. *)

let ($$) template args = Code.template template args
let (@$) a b = Code.add a b
let (@$.) a b = Code.add_with_comma a b


(* The Error exception is for reporting errors in the Algol code. 
   These exceptions are caught at the outer level of the compiler and printed. 
   There is no error recovery (but Awe can compile an Algol 68 compiler 
   fast as you can blink.)

   Note: assertion failures and Failure exceptions indicate bugs in the compiler,
   they are never used to signal compilation error messages. *)

exception Error of Location.t * string


(* 'error loc "message" arg1 arg2 ...' is a printf-like function for raising Error. 
   'warning' gives a compiler warning, directed to stderr. (E.g. notes about the use of Name parameters.)
   'output' prints information to stdout. (E.g. the C prototypes of functions that must be supplied externally.) *)

let error loc = Printf.ksprintf (fun message -> (raise (Error(loc, message))))

let warning loc = Printf.kprintf (fun message -> prerr_endline (Location.to_string loc ^ " " ^ message))

let output = Printf.printf


(* map a binary function over a sequence of integers and a list. *)

let mapi (start : int) (f : int -> 'a -> 'b) (xs : 'a list) : 'b list =
  let rec loop i =
    function
    | [] -> []
    | x :: xs' -> f i x :: loop (i + 1) xs'
  in
  loop start xs


(* map  a unary function over a range of integers. *)

let mapn (first : int) (last : int) (f : int -> 'a) : 'a list =
  assert (first <= last);
  let rec loop i xs =
    if i >= first then 
      loop (i - 1) (f i :: xs)
    else 
      xs
  in 
  loop last []


(* 'snip_last' seperates the last element from the rest of a list *)

let snip_last (xs : 'a list) : ('a list * 'a) =
  match List.rev xs with
  | []       -> failwith "snip_last"
  | [x]      -> ([], x)
  | x :: xs' -> (List.rev xs', x)


(* * Types and scopes ---------------------------------------------------------------- *)

(* 'set loc scope id defn' sets 'id' to 'defn' in 'scope' and returns the modified scope. 
   It reports an error at source location 'loc' if there is already a definition for 
   'id' in the innermost block. *)

let set (loc : Location.t) (scope : Scope.t) (id : Id.t) (defn : Type.definition_t) = 
  try 
    Scope.set scope id defn
  with Scope.Redefined (_, defn) -> 
    error loc "'%s' is already defined here, as %s" (Id.to_string id) (describe_definition defn)


(* 'set_local' is the same as 'set', but works on a single-level scope.
   This is used when accumulating the formal parameters of a procedure. *)

let set_local (loc : Location.t) (scope : Scope.Local.t) (id : Id.t) (defn : Type.definition_t) : Scope.Local.t = 
  try 
    Scope.Local.set scope id defn
  with Scope.Redefined (_, defn) -> 
    error loc "'%s' is already defined here, as %s" (Id.to_string id) (describe_definition defn)


(* 'get loc scope id' gets the definition of 'id' in 'scope'.
   It reports an error at source location 'loc' if 'id' is not defined in 'scope'. *)

let get (loc : Location.t) (scope : Scope.t) (id : Id.t) : Type.definition_t = 
  try 
    Scope.get scope id
  with Scope.Undefined _ -> 
    error loc "'%s' is undefined here" (Id.to_string id)


(* 'simple scope tree' returns the Algol simple type represented by a parse tree.  
   The 'scope' parameter is used to look up reference class identifiers. *)

let simple (scope : Scope.t) (tree : Tree.t) : Type.simple_t =
  match tree with
  | Tree.INTEGER              -> Number (Long, Integer)
  | Tree.REAL                 -> Number (Short, Real)
  | Tree.LONG_REAL            -> Number (Long, Real)
  | Tree.COMPLEX              -> Number (Short, Complex)
  | Tree.LONG_COMPLEX         -> Number (Long, Complex)
  | Tree.BITS                 -> Bits
  | Tree.LOGICAL              -> Logical
  | Tree.STRING (Some length) -> String length
  | Tree.STRING (None)        -> String 16
  | Tree.REFERENCE (loc, [])  -> 
      failwith "Compiler.simple: tree is Tree.REFERENCE with no ids."
  | Tree.REFERENCE (loc, [id]) ->
      ( match get loc scope id with
        | Record (n, _) -> Reference (ClassSet.singleton n)
        | defn -> error loc "expected %s to be a record class, it is %s" (Id.to_string id) (describe_definition defn) )
  | Tree.REFERENCE (loc, ids) ->
      let add_class classes id =
        match get loc scope id with
        | Record (n, _) -> ClassSet.add n classes
        | defn -> error loc "expected %s to be a record class, it is %s" (Id.to_string id) (describe_definition defn)
      in
      Reference (List.fold_left add_class ClassSet.empty ids)
  | _ -> 
      failwith "Compiler.simple: tree does not describe a simple type."


(* * C code generation ---------------------------------------------------------------- *)


(* This is the header for all C file generated by Awe. (I've seen people distributing 
   the AWE generated C files in place of Algol W sources. Code is going lost. *)

let notice : Code.t = Code.string
  "/* ****************************************************************************
       This is a TEMPORARY file generated by the Awe Algol W compiler
       from an Algol W source file. You should not edit this file or store it
       in a version control system; delete it freely as you would any other 
       temporary object file. You should NOT distribute this file,
       instead distribute your Algol W source file and the Awe compiler.
   **************************************************************************** */
"


let is_valid_c_identifier s =   (* true if 's' is a valid GCC C identifier. *)
  let first c = (c = '_' || c = '$' || (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')) in
  let rest c = (first c || (c >= '0' && c <= '9')) in
  try
    assert (String.length s > 0);
    assert (first s.[0]);
    for i = 1 to String.length s - 1 do
      assert (rest s.[i])
    done;
    true
  with _ ->
    false


(* 'blank_string n' return a C string constant containing n spaces *)

let blank_string (n : int) : Code.t =
  Code.string ("(_awe_str)\"" ^ String.make n ' ' ^ "\"")


let code_of_int  (i : int) : Code.t = Code.string (string_of_int i)


(* 'code_of_loc' returns an C code function argument denoting an Algol source location.  
    This is used in function calls that might raise runtime errors. *)

let code_of_loc (loc : Location.t) : Code.t =
  Code.string ( sprintf "_awe_at(%i,%i,%i)"
                  (Location.file_number loc)
                  (Location.line loc)
                  (Location.column loc) )


let c_char_const (character : string) : Code.t = 
  assert (String.length character = 1);
  Code.string 
    ( match character.[0] with
    | '\x00' -> "'\\0'"
    | '\x07' -> "'\\a'"
    | '\x08' -> "'\\b'"
    | '\x09' -> "'\\t'"
    | '\x0A' -> "'\\n'"
    | '\x0B' -> "'\\v'"
    | '\x0C' -> "'\\f'"
    | '\x0D' -> "'\\r'"
    | '\''   -> "'\\''"
    | '"'    -> "'\"'"
    | '\\'   -> "'\\\\'"
    | c when (c >= ' ' && c <= '~') -> sprintf "'%c'" c
    | c -> sprintf "'\\x%02X'" (int_of_char c) )
        

let c_str_const (s : string) : Code.t  =
  let b = Buffer.create 32 in
  Buffer.add_char b '"';
  for i = 0 to String.length s - 1 do
      match s.[i] with
      | '\x00' -> Buffer.add_string b "\\0"
      | '\x07' -> Buffer.add_string b "\\a"
      | '\x08' -> Buffer.add_string b "\\b"
      | '\x09' -> Buffer.add_string b "\\t"
      | '\x0A' -> Buffer.add_string b "\\n"
      | '\x0B' -> Buffer.add_string b "\\v"
      | '\x0C' -> Buffer.add_string b "\\f"
      | '\x0D' -> Buffer.add_string b "\\r"
      | '\''   -> Buffer.add_string b "\\'"
      | '"'    -> Buffer.add_string b "\\\""
      | '\\'   -> Buffer.add_string b "\\\\"
      | c when (c >= ' ' && c <= '~') -> Buffer.add_char b c
      | c -> bprintf b "\" \"\\x%02X\" \"" (int_of_char c)
          (* Isolate hexadecimal escape codes in their own C string constants,
             they will confuse GCC if followed by digits. *)
  done;
  Buffer.add_char b '"';
  Code.string (Buffer.contents b)


(* 'cast loc t e' returns the C code that casts a typed_code_t expression 'e' to Algol simple type 't'.
   It raises a type error if the cast is not allowed by Algol's assignment compatibility 
   rules (See section 7.7.2.) In most cases C's type casting rules do the right thing already.

   'loc' is used in reference class casts that can fail at runtime. See sections 5.4 and 6.1.2. *)

let cast (loc : Location.t) (t : simple_t) (e : typed_code_t) : Code.t = 
  if assignment_compatible t e.t  then
    match t, e.t with
    | String 1, String 1 -> 
        e.c
    | String n, String 1 -> 
        "_awe_str_cast_c($, $)" $$ [e.c; code_of_int n]
    | String desired_length, String length when desired_length <> length -> 
        "_awe_str_cast($, $, $)" $$ [e.c; code_of_int length; code_of_int desired_length]
    | Reference d_set, Reference e_set when not (ClassSet.subset e_set d_set) ->
        let append_class_id c l = (Code.id (Class.to_id c)) :: l in
        let class_list = Code.separate ", "  (ClassSet.fold append_class_id d_set []) in
        "_awe_ref_cast($, $, $)" $$ [code_of_loc loc; e.c; class_list]
    | _, _ -> 
        e.c
  else
    error loc "%s is not compatible with %s" (describe_simple e.t) (describe_simple t)


(* 'default t' return the C code value for initializing variable of simple type 't'. 
   Record reference variables must be initalized to "_awe_uninitialized_reference" so that the runtime 
   can catch stray pointer errors.  Most of the rest are rarely used. *)

let default (t : simple_t) : Code.t =
  match t with
  | Number (Short, Integer) -> failwith "default: Number(Short, Integer) shouldn't exist"
  | Statement               -> failwith "default: Statements cannot be initialized"
  | Null                    -> failwith "default: NULL cannot be initialized"
  | Number (Long, Integer)  -> Code.string "0"
  | Number (Short, Real)    -> Code.string "0.0"
  | Number (Long, Real)     -> Code.string "0.0"
  | Number (Short, Complex) -> Code.string "0.0"
  | Number (Long, Complex)  -> Code.string "0.0"
  | Logical                 -> Code.string "0"
  | Bits                    -> Code.string "0"
  | String 1                -> Code.string "' '"
  | String n                -> blank_string n
  | Reference(_)            -> Code.string "_awe_uninitialized_reference"


(* STRING(1) is represented by C characters, which are passed and stored as 
   ordinary C rvalues. 

   Longer strings (which will be referred to as "STRING(s)")
   are represented by the C type "_awe_str", which is a pointer to an 
   array of characters, because of this indirection STRING(n) has be 
   treated specially all through the compiler, but the special treatment 
   is mostly wrapped up in these next few functions. *)


(* This returns the C type used to pass and return values of an Algol simple type. *)

let ctype (t : simple_t) : Code.t =
  match t with
  | Number (Short, Integer) -> failwith "ctype: Number(Short, Integer) shouldn't exist"
  | Number (Long, Integer)  -> Code.string "int"
  | Number (Short, Real)    -> Code.string "double"
  | Number (Long, Real)     -> Code.string "double"
  | Number (Short, Complex) -> Code.string "_Complex double"  (* <complex.h> is not included *)
  | Number (Long, Complex)  -> Code.string "_Complex double"
  | Statement               -> Code.string "void"   (* i.e. returns nothing *)
  | Logical                 -> Code.string "int"
  | Bits                    -> Code.string "unsigned int"
  | String 1                -> Code.string "unsigned char"
  | String _                -> Code.string "_awe_str"
  | Reference(_)            -> Code.string "void *"
  | Null                    -> Code.string "void *"
      

(* The size of the C type for an Algol simple type. *)

let sizeof_ctype (t : simple_t) : Code.t =
  match t with
  | String n -> code_of_int n  (* characters are one byte wide *)
  | _ -> "sizeof($)" $$ [ctype t]
  

(* The C type that points to a value of the simple type 't'. *)

let c_pointer_type (t : simple_t) : Code.t =
  match t with
  | String n when n > 1 -> Code.string "_awe_str "
  | _                   -> "$ *" $$ [ctype t]
      

(* Obtain a pointer to the 't' typed value stored in C variable 'var'. *)

let address_of (t : simple_t) (var : Code.t) : Code.t =
  match t with
  | String n when n > 1 -> var
  | _                   -> "&$" $$ [var]


(* Declare 'var' as a simple type 't' variable. *)

let declare_simple (t : simple_t) (var : Code.t) : Code.t =
  match t with
  | String n when n > 1 -> "unsigned char $[$];\n" $$ [var; code_of_int n]  (* character array *)
  | t ->                   "$ $;\n" $$ [ctype t; var]


(* The assignment expression that assigns expression 'expr' to C variable 'lvalue'. *)

let assignment_expression (loc : Location.t) (lvalue : typed_code_t) (expr : typed_code_t) : typed_code_t =
  if assignment_compatible lvalue.t expr.t then
    match lvalue.t, expr.t with
    | String 1, String 1 -> (* character to character *)
        {t = expr.t; c = "$ = $" $$ [lvalue.c; expr.c]}
    | String dstlen, String 1 ->  (* character to array *)
        {t = expr.t; c = "_awe_str_cpy_sc($, $, $)" $$ [lvalue.c; code_of_int dstlen; expr.c]}
    | String dstlen, String srclen ->  (* array to array *)
        {t = expr.t; c = "_awe_str_cpy($, $, $, $)" $$ [lvalue.c; code_of_int dstlen; expr.c; code_of_int srclen]}
    | _, _ ->
        {t = expr.t; c = "$ = $" $$ [lvalue.c; cast loc lvalue.t expr]}
  else
    error loc "%s cannot be assigned to %s variable" (describe_simple expr.t) (describe_simple lvalue.t)

let assignment_statement (loc : Location.t) (d : typed_code_t) (e : typed_code_t) : Code.t =
  "$;\n" $$ [(assignment_expression loc d e).c]


(*  Returns C code for the statement that initializes a variable of simple type 't',
    (Initialization is usually only done on reference variables, to prevent pointers going stray. 
    This is used in variable, array element and RESULT parameter initializations. *)

let optionally_initialize_simple (t : simple_t) (var : Code.t) : Code.t =
    match t with
    | String n when n > 1 && !Options.initialize_all -> 
        "_awe_str_cpy($, $, $, $);\n" $$ [var; code_of_int n; blank_string n; code_of_int n]
    | Reference _ ->
        "$ = $;\n" $$ [var; default t]
    | _ when !Options.initialize_all -> 
        "$ = $;\n" $$ [var; default t]
    | _ ->
        Code.empty


(* Algol blocks translate to GNU C "Statement Expressions", which are
   blocks containing declarations and which return a value
   (see http://gcc.gnu.org/onlinedocs/gcc/Statement-Exprs.html).

       ({ decl;... statement;... value; })

   If the value is a string pointer then it is possible that it points into an array
   inside the block's declarations, which will go out of scope, invalidating the 
   pointer. The function '_awe_string' copies string arrays into a temporary array
   ('_awe_return_string') and returns a pointer to that.

   Algol W appears to have been designed so that only one such temporary array
   is necessary. *)

let copy_if_string (expr : typed_code_t) : Code.t =
  match expr.t with
  | String n when n > 1 -> "_awe_string($, $)" $$ [expr.c; code_of_int n]
  | _ -> expr.c


(* * Programs ---------------------------------------------------------------------------- *)

(* The combined type checking and code generation pass is one huge recursive function 
   that starts here: the parse tree goes in one end and C code pops out the other. *)

let rec program (tree : Tree.t) : Code.t =
  let program_expr = expression Predeclared.scope tree in
  let loc = code_of_loc (Tree.to_loc tree) in
  if program_expr.t <> Statement then
    error (Tree.to_loc tree) "a program should be a statement, this returns %s" (describe_simple program_expr.t)
  else
    "$
     $
     extern int _awe_argc;
     extern char **_awe_argv;
     int main (int argc, char **argv) {
       _awe_argc = argc;
       _awe_argv = argv;
       _awe_init($);
       $
       _awe_finalize($);
       return 0;
     }
     \n" $$ [ notice; c_program_headers tree; loc; program_expr.c; loc ]


(* A separately compiled Algol procedure contains just headers and a C function. *)

and separate_procedure (procedure : Tree.t) : Code.t =
  match procedure with
  | Tree.PROCEDURE (_, _, _, _, _) -> 
      let block = {empty_block with scope = Predeclared.scope} in
      let block = add_procedure_declaration procedure block in
      let block = add_procedure_functions block in
      "$\n$\n$\n" $$ [notice; c_program_headers procedure; block.functions]
  | _ -> 
      failwith "separate_procedure"


(* Three things head a C code output file:

   * An #include <awe.h> directive, for the prototypes and macros of the a2wc runtime library;

   * A list of constant string declarations for each Algol source file, pointers to these 
     are used by the "_awe_at" arguments of functions that can raise run-time errors 
     (see the 'Runtime messages' section of "awe.h" for details);

   * A list of string declarations for each record class in the program, pointers to these 
     are used to identify records' classes at runtime (see the 'References' section of "awe.h")  *)

and c_program_headers (tree : Tree.t) : Code.t =
  let class_name_code =
    let decls = 
      List.map 
        (fun (id, name) -> "static const char * const $ = $;" $$ [Code.id id; c_str_const name])
        (List.tl (Class.contents ()))
    in
    Code.separate "\n" decls
  in
  let source_name_code =
    let decls = 
      mapi 0
           (fun number name -> "static const char * const _awe_src_$ = $;" $$ [code_of_int number; c_str_const name])
           (Location.source_files ())
    in
    Code.separate "\n" decls
  in
  "\n#include <awe.h>\n$\n$\n" $$ [source_name_code; class_name_code]


(* * Blocks -------------------------------------------------------------------------------- *)

(* 'block_expression' produces a C code block that corresponds to an Algol block.
   Most of the work is done in other functions called from here.

   Typically an Algol program is a block.

   Algol declarations are interdependent and don't necessarily appear in order in the block, 
   so there needs to be several scans to collect them all:

      1. record classes (for simple types and record fields);

      2. procedure headers (for mutually recursive procedure calls),
         also record fields, arrays and simple variables (order doesn't matter here);

      3. labels (for non-local gotos in procedures);

      4. procedure bodies (now that we have their global variables, labels, etc.)

   The following are the declarations that will appear in a C block representing an Algol block, 
   see 'block_t'. Each group of declarations is optional, but they will always be declared 
   in the order shown:

   block.outsidescope:
        If there are array declarartions there will be two nested C blocks.
        The outer one is for array bounds calculations (which must be 
        executed outside the block's scope, see section 5.2.2) and 
        array bounds checking macros.

   block.labels:
        Label declarations. Gnu C "Locally Declared Labels" declarations must appear first 
        in the C block. These declarations allow Gnu C nested functions to execute 
        non-local gotos. See http://gcc.gnu.org/onlinedocs/gcc/Local-Labels.html

   block.structs:
        "struct" declarations for record classes. 

   block.prototypes:
        Prototypes for all C functions. If these appear at the top then the order of the 
        actual function definitions later on becomes unimportant. Algol procedures,
        record designators and record fields are represented by C functions.

   block.variables:
        Declarations for C variables: simple variables, arrays of data for array designator 
        functions and runtime temporary variables.

   block.functions:
        C function declarations.

   block.initialization:
        Initialization assignment statements for REFERENCE arrays and simple variables. 
        (It is important to initialize reference variables to _awe_uninitialized_reference, 
        this prevents prevents stray pointer errors going uncaught. Other initializations 
        are optional.)

   The statements
        If the Algol block ends in an expression then the block is an expression 
        itself, and that final expression is its value. (See section 6) 
        Algol expression blocks translate to GNU C "Statement Expressions". 
        See: http://gcc.gnu.org/onlinedocs/gcc/Statement-Exprs.html  *)

and block_expression (scope : Scope.t) 
                     (block_head : Tree.t list)  (* declarations *)
                     (block_body : Tree.t list)  (* statements, labels *)
                     : typed_code_t =

  let block = {empty_block with scope = Scope.push scope} in  

  (* Compose the declaration scans: *)
  let block = add_record_headers block block_head in
  let block = List.fold_left add_declaration block block_head in
  let block = add_label_declarations block block_body in
  let block = add_procedure_functions block in

  if block_body = [] then failwith "Compiler.block_expression: no block body" ;
  let statement_items, return_expression = snip_last block_body in
  let c_statements =
    List.map
      ( function
          | Tree.Label (_, id) -> "$:\n" $$ [Code.id id]
          | statement          -> expression_expect Statement block.scope statement )
      statement_items
  in
  let body = Code.concat [ block.labels;
                           block.structs;
                           block.prototypes;
                           block.variables;
                           block.functions;
                           block.initialization;
                           Code.concat c_statements ]
  in
  let return_value = expression block.scope return_expression in
  let inside_block = 
    if return_value.t = Statement then 
      "{\n$$}" $$ [body; return_value.c]
    else 
      "({ $ $; })" $$ [ body; copy_if_string return_value]
  in
  let outside_block = 
    if block.outsidescope = Code.empty then 
      inside_block
    else
      (if return_value.t = Statement then "{\n$$\n}\n" else "({\n$$;\n})") $$ [ block.outsidescope; inside_block ]
  in
  {t = return_value.t; c = outside_block}


(* * Expressions -------------------------------------------------------------------------------- *)

(* Almost everything in Algol that is not a declaration is an expression. 
   The compiler treats statements as expressions of the type "Statement" (similar to C's "void" type).

   The 'expression' function takes a parse tree and a scope, and returns C code and a simple type.
   (Note: this function is very long, with a branch for each kind of expression.) *)

and expression (scope : Scope.t) (tree : Tree.t) : typed_code_t =
  match tree with

  | Tree.BEGIN (_, block_head, block_body, _) -> 
      block_expression scope block_head block_body

  (* ** Constants - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -  *)

  | Tree.TRUE  _ -> { t = Logical; c = Code.string "1" }
  | Tree.FALSE _ -> { t = Logical; c = Code.string "0" }
  | Tree.NULL  _ -> { t = Null;    c = Code.string "(void *)0" }

  (* INTEGER and BITS constants must fit into 32-bit words. *)

  | Tree.Integer (loc, s) -> 
      ( try
          let i = Int64.of_string s in  (* might fail *)
          if i >= -2147483648L && i <= 2147483647L then
            {t = Number(Long, Integer); c = Code.string s}
          else
            error loc "integer %s will not fit in a 32 bit word" s
        with Failure _ ->
          error loc "integer %s will not fit in a 32 bit word" s )

  | Tree.Bits (loc, s) -> 
      ( try
          let hex = "0x" ^ s in
          let i = Int64.of_string hex in  (* might fail *)
          if i >= 0L && i <= 4294967295L then
            {t = Bits; c = Code.string hex}
          else
            error loc "BITS constant #%s will not fit in a 32 bit word" s
        with Failure _ ->
          error loc "BITS constant #%s will not fit in a 32 bit word" s )

  (* The real and exponent parts of an Algol real number are reassembled into a C floating point constants.*)

  | Tree.Real          (loc, r, "") -> {t = Number(Short, Real);    c = Code.string r}
  | Tree.Real          (loc, r, e)  -> {t = Number(Short, Real);    c = Code.string (sprintf "%se%s" r e)}
  | Tree.LongReal      (loc, r, "") -> {t = Number(Long, Real);     c = Code.string r}
  | Tree.LongReal      (loc, r, e)  -> {t = Number(Long, Real);     c = Code.string (sprintf "%se%s" r e)}
  | Tree.Imaginary     (loc, r, "") -> {t = Number(Short, Complex); c = Code.string (r ^ "i")}
  | Tree.Imaginary     (loc, r, e)  -> {t = Number(Short, Complex); c = Code.string (sprintf "%se%si" r e)}
  | Tree.LongImaginary (loc, r, "") -> {t = Number(Long, Complex);  c = Code.string (r ^ "i")}
  | Tree.LongImaginary (loc, r, e)  -> {t = Number(Long, Complex);  c = Code.string (sprintf "%se%si" r e)}

  (* STRING constants. The type "_awe_str" is "char *" but C string constants are "const char *". 
     In some places (only conditional expressions, it appears) that would cause a type mismatch, 
     hence the need for a cast. String constants are Algol "expressions", not "designators", 
     so they are safe from modification regardless. *)

  | Tree.String (loc, s) -> 
      ( match String.length s with
        | 0 -> error loc "Empty strings are not allowed in Algol W"
        | 1 -> {t = String 1; c = c_char_const s}
        | n -> {t = String n; c = "(_awe_str)$" $$ [c_str_const s]}
      )


  (* ** Operators: IS, unary and binary  - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -  *)

  (* IS is a special case among the binary operators because its right operand is not an expression.  
     See section 6.4. *)

  | Tree.Binary (loc, reference, Tree.IS, record) ->
      let record_id, record_class = 
        match record with
        | Tree.Identifier (loc, id) ->
            ( match get loc scope id with
              | Record (c, _) -> id, c
              | defn -> error loc "expected a record class identifier here, this is %s" (describe_definition defn) )
        | _ ->
            error (Tree.to_loc record) "expected a record class identifier here"
      in
      let rc = expression scope reference in
      ( match rc.t with
        | Null ->
           {t = Logical; c = Code.string "0"} (* NULL never refers to a record *)
        | Reference class_set  ->
           if ClassSet.mem record_class class_set then  (* test at runtime *)
             {t = Logical; c = "_awe_is($, $)" $$ [rc.c; Code.id (Class.to_id record_class)]}
           else 
             error loc "%s will never refer to a RECORD %s" (describe_simple rc.t) (Id.to_string record_id)
        | _ ->
            error loc "expected a reference, this is %s" (describe_simple rc.t) )

  | Tree.Unary (loc, o, a) ->
      unary_expression loc scope o a

  | Tree.Binary (loc, a, op, b) ->
      binary_expression loc scope a op b

(* ** IF/THEN - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - *)

  (* IF-THEN-ELSE is a Statement if both its branches are Statements, otherwise it is an expression. 
     An IF-THEN without an ELSE is always a statement.

     The THEN branch of an IF THEN ELSE statement should be a <simple statement> 
     (see section 7.5.1), but Hendrik Boom's A68H code does not obey that rule, 
     suggesting that the eariler compiler did not insist on it - so Awe does not either.
*)

  | Tree.IF (loc, condition, then_clause) -> 
      let cc = expression_expect Logical scope condition in
      let ct = expression_expect Statement scope then_clause in 
      { t = Statement; 
        c = "if ($)\n $" $$ [cc; ct] }

  | Tree.IF_else (loc, condition, then_clause, else_clause) ->
      let cc = expression_expect Logical scope condition in
      let ce = expression scope else_clause in
      let ct = expression scope then_clause in
      let rtype =  
        try
          Type.triplet_rule ct.t ce.t
        with Incompatible ->
          error loc "incompatible types: the THEN clause is %s and the ELSE clause is %s"
            (describe_simple ct.t)
            (describe_simple ce.t)
      in
      { t = rtype; 
        c = match rtype with
        | Statement ->
            "if ($)\n $ \n else \n $ \n" $$ [cc; ct.c; ce.c] 
        | _ ->
            "($ ? $ : $)" $$ [cc; cast loc rtype ct; cast loc rtype ce] }

(* ** CASE - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - *)

  (* The CASE-OF-BEGIN-END statement. The selector expression is
     stored in a temprory variable so that it does not get called a
     second time if there is a range error. *)

  | Tree.CASE (loc, selector, branches) -> 
      let cselector = expression_expect integer scope selector in
      let make_branch index branch =
        "case $: $; break;\n" $$ [ code_of_int index; (expression_expect Statement scope branch) ]
      in
      let cbranches = Code.concat (mapi 1 make_branch branches) in
      { t = Statement;
        c = 
          "{ 
             const int _selector = $;
             switch (_selector) {
             $
             default: _awe_case_range_error($, _selector);
             }
           }
          " $$ [cselector; cbranches; code_of_loc loc] }

  | Tree.CASE_expr (loc, selector, branches) -> 
      let cselector = expression_expect integer scope selector in
      let bs = List.map (expression scope) branches in
      let rt = 
        try 
          List.fold_left 
            (fun t c -> Type.triplet_rule t c.t)
            (List.hd bs).t 
            (List.tl bs)
        with Incompatible -> 
          error loc "This CASE expression's branch expressions have incompatible types." 
      in
      ( match rt with
        | String n when n > 1 -> 
            let value = {t = rt; c = Code.string "_awe_return_string"} in
            let make_branch index branch = 
              "case $: $ break;\n" $$ [ code_of_int index; assignment_statement loc value branch ] 
            in
            let cbranches = Code.concat (mapi 1 make_branch bs) in
            { t = rt;
              c = "({ int _selector = $;
                  switch (_selector) {
                  $
                  default: _awe_case_range_error($, _selector);
                  } 
                  _awe_return_string; })" $$ [cselector; cbranches; code_of_loc loc] }
        | _ -> 
            let value = {t = rt; c = Code.string "_value"} in
            let make_branch index branch = 
              "case $: $ break;\n" $$ [ code_of_int index; assignment_statement loc value branch ] 
            in
            let cbranches = Code.concat (mapi 1 make_branch bs) in
            { t = rt;
              c = "({ $ _value;
                  int _selector = $;
                  switch (_selector) {
                  $
                  default: _awe_case_range_error($, _selector);
                  } 
                  _value; })" $$ [ctype rt; cselector; cbranches; code_of_loc loc] }
      )

(* ** Iterative statements: WHILE, FOR - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - *)

  | Tree.WHILE (loc, condition, then_clause) -> 
      let cc = expression_expect Logical scope condition in
      let ct = expression_expect Statement scope then_clause in
      { t = Statement; 
        c = "while ($)\n $ \n" $$ [cc; ct] }

  (* The limit and step expression of FOR statments are placed in
     temporary variables to prevent them from being called more than once. *)

  | Tree.FOR (loc, control, first, last, body) -> 
      let ccontrol = Code.id control in
      let for_body_scope = set loc (Scope.push scope) control Control in
      { t = Statement;
        c = 
          "{ 
             const int _start = $;
             const int _limit = $;
             int $ = _start;
             while ($ <= _limit) {
               $
               ++$;
             }
           }
          " $$ [   expression_expect integer scope first; 
                  expression_expect integer scope last; 
                  ccontrol; 
                  ccontrol; 
                  expression_expect Statement for_body_scope body; 
                  ccontrol ] }

  | Tree.FOR_step (loc, control, first, step, last, body) -> 
      let ccontrol = Code.id control in
      let for_body_scope = set loc (Scope.push scope) control Control in
      { t = Statement;
        c = 
          "{
             const int _start = $;
             const int _step = $;
             const int _limit = $;
             int $ = _start;
             _awe_check_for_step($, _step);
             while (_step > 0 ? $ <= _limit : $ >= _limit) {
               $
               $ += _step;
             }
           }
          " $$ [ expression_expect integer scope first; 
                 expression_expect integer scope step; 
                 expression_expect integer scope last; 
                 ccontrol;
                 code_of_loc loc;
                 ccontrol; ccontrol; 
                 expression_expect Statement for_body_scope body; 
                 ccontrol ] }

  (* As far as I can tell, all of the expressions in the list form of
     the FOR statement must be evaluated before the body is executed, 
     that is why they are being stored in a temporary array here.  *)

  | Tree.FOR_list (loc, control, expressions, body) -> 
      let ccontrol = Code.id control in
      let nexpressions = code_of_int (List.length expressions) in
      let es = List.map (expression_expect integer scope) expressions in
      let cassignments = Code.concat (mapi 0 (fun i e -> "_a[$] = $;\n" $$ [code_of_int i; e]) es) in
      let for_body_scope = set loc (Scope.push scope) control Control in
      let cbody = expression_expect Statement for_body_scope body in
      { t = Statement;
        c = 
          "{
             int $, _i, _a[$];
             $
             for (_i = 0; _i < $; ++_i) {
               $ = _a[_i];
               $
             }
           }
          " $$ [ ccontrol; nexpressions;
                 cassignments; 
                 nexpressions;
                 ccontrol; 
                 cbody ] }

(* ** Other statements: GOTO, ASSERT, empty - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - *)

  | Tree.GOTO (loc, label) -> 
      ( match (get loc scope label) with
        | Label ->
            { t = Statement; 
              c = "goto $;\n" $$ [Code.id label] }
        | defn -> 
            error loc "'%s' should be a label here, it is %s" (Id.to_string label) (describe_definition defn)
      )

  | Tree.ASSERT (loc, condition) -> 
      let e = expression_expect Logical scope condition in
      { t = Statement; 
        c = "_awe_assert($, $);\n" $$ [code_of_loc loc; e] }

  | Tree.Empty (_) -> 
      { t = Statement; 
        c = Code.string "; /*empty*/\n" }

(* ** Assignment expressions: ":="  - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - *)

  | Tree.Assignment (loc, desig, expr) -> 
      let rec multiple_assignment loc' desig' expr' =
        let ecode = 
          match expr' with
          | Tree.Assignment (loc, d, e) -> multiple_assignment loc d e
          | _ -> expression scope expr' 
        in
        assignment_expression loc' (designator Lvalue scope desig') ecode
      in
      { t = Statement;
        c = "$;\n" $$ [(multiple_assignment loc desig expr).c] }

(* ** Designator expressions: variables, procedure calls substrings, etc. - - - - - - - - - - - - - - - - - - - - - *)

  (* A substring designator (see section 6.6) returns a pointer into the character 
     array of a string variable or constant. This pointer can be to a character, 
     in the case of STRING(1) substrings, or a subarray, in the case of longer string. 

     This is safe because string expressions never appear in any context where
     their contents can be modified. *)

  | Tree.Substring (_, _, _, _) as substring ->
      let char_ptr_expr = designator Pointer scope substring in
      ( match char_ptr_expr.t with
        | String 1 ->
            {t = String 1; c = "*$" $$ [char_ptr_expr.c]}
        | String n ->
            {t = String n; c = char_ptr_expr.c}
        | _ -> 
            failwith "Compiler.expression: not a string designator" )

  | Tree.Identifier (loc, id) as variable -> 
      ( match (get loc scope id) with
        | Variable _ | Result _ | Name _     -> designator Lvalue scope variable
        | Control                            -> {t = integer; c = Code.id id}
        | Procedure procedure_type           -> procedure_call loc scope id procedure_type []
        | Record (record_class, field_types) -> reference_expression loc scope id record_class field_types []
        | Standard st  -> error loc "this standard I/O procedure requires one or more actual parameters" 
        | Analysis _   -> error loc "this procedure requires an actual parameter"
        | Array (_, _) -> error loc "this array requires subscripts" 
        | Field (_, _) -> error loc "Record fields expect one actual parameter"
        | Label        -> error loc "expected an expression here, this is a GOTO label" )
  | Tree.Parametrized (loc, id, actuals) as tree ->
      ( match (get loc scope id) with
        | Array (etype, ndims) ->
            designator Lvalue scope tree
        | Procedure procedure_type  -> 
            procedure_call loc scope id procedure_type actuals
        | Standard stdproc ->
            standard_procedure loc scope stdproc actuals
        | Record (record_class, field_types) ->
            reference_expression loc scope id record_class field_types actuals
        | Field (rtype, class_number) ->
            designator Lvalue scope tree
        | Analysis t ->
            if List.length actuals = 1 then
              let arg = expression scope (List.hd actuals) in
              {t = t; c = "_awe_$($, $)" $$ [ Code.id id; code_of_loc loc; cast loc t arg]}
            else
              error loc "the procedure %s requires one actual parameter" (Id.to_string id)
        | defn -> 
            error loc "this is %s, it cannot be called or dereferenced" (describe_definition defn) )

  (* Any Tree node that's not one of the above will be due to a parser error. *)
  | e -> 
      failwith ( sprintf "Compiler.expression: %s is not an expression" (Tree.str e) )


(* 'expression_expect' is used when we already know the type the expression should have, 
   e.g. FOR loops bounds are always Number(Long,Integer). This returns the C code only. *)

and expression_expect (t : simple_t) (scope : Scope.t) (tree : Tree.t) : Code.t =
  let ce = expression scope tree in
  if ce.t = t then
    ce.c
  else
    error (Tree.to_loc tree) "expected %s here, got %s" 
      (describe_simple t) 
      (describe_simple ce.t)
      

(* ** Unary operators: +, -, ABS, LONG, SHORT, ~  See section 6.3 ---------------------------------------------------- *)

(* The branches correspond quite closely to the rules in the Algol Language Description. 
   [Ocaml is sweet like this!] *)

and unary_expression (loc      : Location.t) 
                     (scope    : Scope.t) 
                     (operator : Tree.t) 
                     (atree    : Tree.t) 
                     : typed_code_t =

  let {t=ta; c=ca} as a = expression scope atree in

  match operator, ta with

(* *** Identity and negation. See section 6.3.3.2 *)

  | Tree.IDENTITY, Number(_,_) ->
      a

  | Tree.NEG, Number(_,_) ->
      { t = ta;
        c = "(- $)" $$ [ca] }
        
(* *** Absolute value. See section 6.3.2.6 *)

  | Tree.ABS, Number(_,Integer) ->
      { t = ta;
        c = "_awe_abs($)" $$ [ca] }

  | Tree.ABS, Number(_,Real) ->
      { t = ta;
        c = "_awe_fabs($)" $$ [ca] }

  | Tree.ABS, Number(precision, Complex) ->
      { t = Number(precision, Real);
        c = "_awe_cabs($)" $$ [ca] }

(* *** Precision of arithmetic.  See section 6.3.2.7 *)

  | Tree.LONG, Number(_,Integer) ->
      { t = Number(Long,Real);
        c = "((double) $)" $$ [ca] }

  | Tree.LONG, Number(_, ((Real|Complex) as domain)) ->
      { t = Number(Long, domain);
        c = ca }

  | Tree.SHORT, Number(_, ((Real|Complex) as domain)) ->
      { t = Number(Short, domain);
        c = ca }

(* *** Logical expressions. cf .6.3 *)

  | Tree.NOT, Logical ->
      { t = Logical;
        c = "(! $)" $$ [ca] }

(* *** Bit expressions. cf .6.3 *)

  | Tree.NOT, Bits ->
      { t = Bits;
        c = "(~ $)" $$ [ca] }

    (* All remaining combinations of unary operators and operand types are erroneous. *)
          
    | op, t ->
        error loc "Incorrect operand type: %s %s" (Tree.str op) (string_of_simple t)


(* ** Binary operators  See section 6.3 -------------------------------------------------------------------- *)

(* Algol operators are "overloaded", i.e. there are different operations depending 
   on the types of the operands. The Algol W Language Description describes overloading 
   syntactically using an affix grammar, Awe (which uses a roughly equivalent LALR grammar) 
   deals with it more conventionally, by inspecting the types of operators' arguments. *)

and binary_expression (loc      : Location.t) 
                      (scope    : Scope.t) 
                      (atree    : Tree.t) 
                      (operator : Tree.t) 
                      (btree    : Tree.t) 
                      : typed_code_t =

  let {t=ta; c=ca} = expression scope atree in
  let {t=tb; c=cb} = expression scope btree in

  let cl = code_of_loc loc in

  (* The "triplet rule" for numeric type compatibility, See section 6.*)
  let apply_triplet_rule t1 t2 =
    try
      Type.triplet_rule t1 t2
    with Incompatible ->
        error loc "Incorrect operand types: %s %s %s" 
          (string_of_simple t1)
          (Tree.str operator)
          (string_of_simple t2)
  in
      
  (* C relational operators, See section 6.4.1 *)
  let c_equality operator = 
    Code.string 
      ( match operator with
        | Tree.EQ -> "=="
        | Tree.NE -> "!="
        | _ -> failwith "Compiler.binary_expression: not an equality operator" )
  in
  let c_inequality operator = 
    Code.string 
      ( match operator with
        | Tree.GT -> ">"
        | Tree.GE -> ">="
        | Tree.LT -> "<"
        | Tree.LE -> "<="
        | _ -> failwith "Compiler.binary_expression: not an inequality operator" )
  in
  
  match operator, ta, tb with

(* *** Arithmetic expressions See section 6.3 *)

    (* Addition and subtraction See section 6.3.1 *)

    (* C's rules for automatic numeric type casting correspond to Algol's, so we let C handle it. *)

    | Tree.ADD, Number(_,_), Number(_,_) ->
        { t = apply_triplet_rule ta tb; 
          c = "($ + $)" $$ [ca; cb] }

    | Tree.SUB, Number(_,_), Number(_,_) ->
        { t = apply_triplet_rule ta tb; 
          c = "($ - $)" $$ [ca; cb] }

    (* Multiplication and division. See section 6.3.2.1 *)
          
    (* Division is done by functions in the Awe runtime library, they
       check for division by zero, which is one of Algol W's "Exceptional
       Conditions." *)

    | Tree.MUL, Number(_,_), Number(_,_) ->
        let modified =   (* See section 6.3.2.1 *)
          match apply_triplet_rule ta tb with
          | Number(_,Integer) as t -> t
          | Number(_,domain) -> Number(Long,domain)
          | _ -> failwith "triplet rule failed"
        in
        { t = modified; 
          c = "($ * $)" $$ [ca; cb] }

    | Tree.RDIV, Number(_,Integer), Number(_,Integer) ->
        { t = Number(Long,Real); 
          c = "_awe_rdiv($, $, $)" $$ [cl; ca; cb] }

    | Tree.RDIV, Number(_,_), Number(_,_) ->
        ( let t0 = apply_triplet_rule ta tb in
          match t0 with
          | Number(_,Real) ->
              { t = t0; 
                c = "_awe_rdiv($, $, $)" $$ [cl; ca; cb] }
          | Number(_,Complex) ->
              { t = t0; 
                c = "_awe_cdiv($, $, $)" $$ [cl; ca; cb] } 
          | Number(quality,Integer) ->
              { t = Number(quality,Real);  (* See section 6.3.2.1 *)
                c = "_awe_rdiv($, $, $)" $$ [cl; ca; cb] }
          | _ -> failwith "triplet rule fails for division" )

    | Tree.IDIV, Number(_,Integer), Number(_,Integer) ->
        { t = Number(Long,Integer); c = "_awe_div($, $, $)" $$ [cl; ca; cb] }

    | Tree.REM, Number(_,Integer), Number(_,Integer) ->
        { t = Number(Long,Integer); c = "_awe_rem($, $, $)" $$ [cl; ca; cb] }

    (* Power operator, **. See section 6.3.2.5 *)

    | Tree.PWR, Number(_,(Integer|Real)), Number(_,Integer) ->
        { t = Number(Long,Real); 
          c = "_awe_rpwr($, $, $)" $$ [cl; ca; cb] }

    | Tree.PWR, Number(_,Complex), Number(_,Integer) ->
        { t = Number(Long,Complex); 
          c = "_awe_cpwr($, $, $)" $$ [cl; ca; cb] }

(* *** Logical operators: AND, OR. See section 6.4 *)

    (* AND  and OR are "shortcut operators", like C has.  See section6.4.2.2 *)

    | Tree.AND, Logical, Logical -> 
        { t = Logical; 
          c = "($ && $)" $$ [ca; cb]  }

    | Tree.OR, Logical, Logical -> 
        { t = Logical; 
          c = "($ || $)" $$ [ca; cb]  }

    (* Relations. See section 6.4.1. *)

    (* Equality. See rules about symbols T 6 and T 7.

       Allowing the comparison of LOGICAL values was a Standford ALGOLW extension to
       Algol W.   *)

    | (Tree.EQ | Tree.NE), Bits, Bits ->
        { t = Logical; 
          c = "($ $ $)" $$ [ca; c_equality operator; cb] }

    | (Tree.EQ | Tree.NE), String 1, String 1 ->
        { t = Logical; 
          c = "($ $ $) " $$ [ca; c_equality operator; cb] }
    | (Tree.EQ | Tree.NE), String 1, String lenb ->
        { t = Logical; 
          c = "(_awe_str_cmp_cs($, $, $) $ 0) " $$ [ca; cb; code_of_int lenb; c_equality operator] }
    | (Tree.EQ | Tree.NE), String lena, String 1 ->
        { t = Logical; 
          c = "(_awe_str_cmp_sc($, $, $) $ 0) " $$ [ca; code_of_int lena; cb; c_equality operator] }
    | (Tree.EQ | Tree.NE), String lena, String lenb ->
        { t = Logical; 
          c = "(_awe_str_cmp($, $, $, $) $ 0) " $$ [ca; code_of_int lena; cb; code_of_int lenb; c_equality operator] }

    | (Tree.EQ | Tree.NE), (Reference(_) | Null), (Reference(_) | Null) ->
        { t = Logical; 
          c = "($ $ $)" $$ [ca; c_equality operator; cb] }

    | (Tree.EQ | Tree.NE), Number(_,_), Number(_,_) ->
        { t = Logical; 
          c = "($ $ $)" $$ [ca; c_equality operator; cb] }

    | (Tree.EQ | Tree.NE), Logical, Logical ->
        { t = Logical; 
          c = "((($) != 0)  $ (($) != 0))" $$ [ca; c_equality operator; cb] }

    (* Inequality. (See rules about symbols T 8 and T 9.) *)

    | (Tree.GT  | Tree.GE  | Tree.LT  | Tree.LE), String 1, String 1 ->
        { t = Logical; 
          c = "(_awe_str_cmp_cc($, $) $ 0) " $$ [ca; cb; c_inequality operator] }
    | (Tree.GT  | Tree.GE  | Tree.LT  | Tree.LE), String 1, String lenb ->
        { t = Logical; 
          c = "(_awe_str_cmp_cs($, $, $) $ 0) " 
            $$ [ca; cb; code_of_int lenb; c_inequality operator] }
    | (Tree.GT  | Tree.GE  | Tree.LT  | Tree.LE), String lena, String 1 ->
        { t = Logical; 
          c = "(_awe_str_cmp_sc($, $, $) $ 0) " 
            $$ [ca; code_of_int lena; cb; c_inequality operator] }
    | (Tree.GT  | Tree.GE  | Tree.LT  | Tree.LE), String lena, String lenb ->
        { t = Logical; 
          c = "(_awe_str_cmp($, $, $, $) $ 0) " 
            $$ [ca; code_of_int lena; cb; code_of_int lenb; c_inequality operator] }

    | (Tree.GT  | Tree.GE  | Tree.LT  | Tree.LE), Number(_,(Real|Integer)), Number(_,(Real|Integer)) ->
        { t = Logical; 
          c = "($ $ $)" $$ [ca; c_inequality operator; cb] }

    | (Tree.GT  | Tree.GE  | Tree.LT  | Tree.LE), Logical, Logical ->
        { t = Logical; 
          c = "((($) != 0) $ (($) != 0))" $$ [ca; c_inequality operator; cb] }

(* *** Bit expressions. See section 6.5 *)

    | Tree.AND, Bits, Bits -> 
        { t = Bits; 
          c = "($ & $)" $$ [ca; cb]  }

    | Tree.OR, Bits, Bits -> 
        { t = Bits; 
          c = "($ | $)" $$ [ca; cb]  }

    | Tree.SHL, Bits, Number(_,Integer) -> 
        { t = Bits; 
          c = "_awe_shl($, $)" $$ [ca; cb]  }

    | Tree.SHR, Bits, Number(_,Integer) -> 
        { t = Bits; 
          c = "_awe_shr($, $)" $$ [ca; cb]  }

    (* All remaining combinations of binary operators and operand types are erroneous. *)
          
    | op, t1, t2 ->
        error loc "Incorrect operand types: %s %s %s" (string_of_simple t1) (Tree.str op) (string_of_simple t2)


(* ** Procedure calls ------------------------------------------------------------------------- *)

(* This function creates the C code for a procedure call and finds its Algol simple type.

   A call to a procedure with no parameters or non-STRING VALUE parameters only is
   translated into C in a straightforward manner - C function arguments are values.

   A call to a procedure that requires non-VALUE parameters requires a "pre/post call block",
   i.e. it must be translated into a C block which will contain several kinds of 
   intricate temporary variables, initializations and "thunk" functions to pass 
   as arguments. For function procedure calls (see section 6.2) the pre/post call 
   block will be a GNU C "statement expression" block, which returns a value. 
   (See http://gcc.gnu.org/onlinedocs/gcc/Statement-Exprs.html)

   Awe compiles each type of parameter in a different fashion (see 'add_call_parameter'.)

   "Thunks" are temporary functions passed as auguments to functions, they calculate 
   the addresses of parameters, which are often held in temporary variables. 
   In a proper Algol runtime thunks are supposed to be untyped (have a undefined return 
   type and undefined number of arguments) and used consistently for every type of parameter, 
   which is what allows parameters-to-procedure-parameters to go undeclared in Algol 60. 
   Awe does not use that scheme.

   The 'add_call_parameter' function collects up C code for the parts of a pre/post call 
   block. All parts are optional, but they always appear in the following order:
   
   * 'declarations':
       - variables to hold RESULT or VALUE RESULT parameters;
       - variables to hold STRING(n) VALUE parameters;
       - a variable to hold the result of the function call;
       - thunks for Name parameters;
       - array descriptors for subarray designator parameters;
       - thunks for statements and expressions passed as PROCEDURE parameters.

   - 'precall':

        assignments of actual parameters to VALUE RESULT temporary variables;
        assignments of STRING actual parameters to VALUE temporary variables;
   
   * the function call (using 'call_arguments');

   * 'postcall':
        assignments to RESULT parameters back to actual parameters;

   * the result variable, 
       to pass the procedure's return value out of the GNU statement 
       expression block (if the procedure has a return value.) 
*)

and procedure_call (loc : Location.t) 
                   (scope : Scope.t) 
                   (procedure_id : Id.t) 
                   ((return_type, formals) : procedure_t) 
                   (actuals : Tree.t list)
                   : typed_code_t =

  (* List of (temporary variable name, actual parameter code, formal parameter type) 
     for each parameter in the procedure call.*)
  let parameter_info : (Code.t * Tree.t * Type.formal_t) list =
    try
      mapi 1 
        (fun i (a, f) -> ("_$_arg$" $$ [Code.id procedure_id; code_of_int i], a, f)) 
        (List.combine actuals formals)
    with Invalid_argument _ -> 
      error loc "%s expects %i actual parameters" (Id.to_string procedure_id) (List.length formals)
  in
  
  let add_tracing call =
    if !Options.add_tracing_hooks then
      let id : Code.t = c_str_const (Id.to_string procedure_id) in
      { call with
          precall  = ("_awe_trace_procedure_called($, $);\n" $$ [code_of_loc loc; id]) @$ call.precall;
          postcall = call.postcall @$ ("_awe_trace_procedure_exited($, $);\n" $$ [code_of_loc loc; id]) }
    else call
  in

  let call = add_tracing (List.fold_left (add_call_parameter scope) empty_actual_parameters parameter_info) in

  if return_type = Statement then 
    let ccall = "$($);\n" $$ [Code.id procedure_id; call.args] in
    if call.decls    = Code.empty && 
       call.postcall = Code.empty && 
       call.postcall = Code.empty 
    then 
      {t = Statement; c = ccall}
    else 
      {t = Statement; c = "{\n$$$$}\n" $$ [call.decls; call.precall; ccall; call.postcall]}

  else
    let fcall = {t = return_type; c = "$($)" $$ [Code.id procedure_id; call.args]} in
    if call.decls    = Code.empty && 
       call.postcall = Code.empty && 
       call.postcall = Code.empty 
    then 
      fcall
    else 
      if call.postcall = Code.empty then
        {t = return_type; c = "({ $$$; })" $$ [call.decls; call.precall; copy_if_string fcall]}
      else
        let return_id = "_$_ret" $$ [Code.id procedure_id] in
        let return_var = {t = return_type; c = return_id} in
        { t = return_type; 
          c = "({ $$$$$$; })" $$ [ call.decls;
                                   declare_simple return_type return_id;
                                   call.precall;
                                   assignment_statement loc return_var fcall;
                                   call.postcall;
                                   copy_if_string return_var ] }


(* 'add_call_parameter' accumulates C code fragments for procedure parameter pre/post call blocks.
   Awe translates each type of parameter in a different fashion, they are described 
   by examples at their branches in the code below: *)

and add_call_parameter (scope : Scope.t)
                       (call : actual_parameters_t)
                       ((var, actual, formal): Code.t * Tree.t * Type.formal_t)
                       : actual_parameters_t =

  let loc = Tree.to_loc actual in

  match formal with

  (* *** Value Actual Parameters  - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - *)

  (* Declaration:  INTEGER PROCEDURE F (INTEGER VALUE N)
     Algol call:   I := F(1)
     C call:       i = f(1);

     Declaration:  PROCEDURE P (STRING(2) VALUE S)
     Algol call:   P("X");
     C call:       { unsigned char _p_arg1[2];
                     _awe_str_cpy(_p_arg1, 2, "X", 1);
                     p(_p_arg1); }

     Declaration:  INTEGER PROCEDURE F (STRING(2) VALUE S)
     Algol call:   I := F("X") 
     C call:       i = ({ unsigned char _f_arg1[2]; 
                          _awe_str_cpy(_f_arg1, 2, "X", 1); 
                          f(_f_arg1); });
  *)
  | By_value (String n as ftype) when n > 1 ->
      let ftype_var = {t = ftype; c = var} in
      { call with
          decls   = call.decls   @$ declare_simple ftype var;  (* now that this is non-empty, the call will be wrapped in a block *)
          precall = call.precall @$ assignment_statement loc ftype_var (expression scope actual);
          args    = call.args    @$. var }

  | By_value ftype ->
      {call with args = call.args @$. cast loc ftype (expression scope actual)}

  (* *** VALUE RESULT Actual Parameters  - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - *)

  (* Declaration:  INTEGER PROCEDURE F (INTEGER VALUE RESULT I)
     Algol call:   I := F(T)
     C call:       i = ({ int _ret_f;
                          int _f_arg1;
                          _f_arg1 = t; 
                          _ret_f = f(&_f_arg1); 
                          t = _f_arg1; 
                          _ret_f; 
                       });

     Declaration:  PROCEDURE P (STRING(2) VALUE RESULT S)
     Algol call:   P(T)
     C call:       { unsigned char s[2]; 
                     _awe_str_cpy(s, 2, t, 2);
                     p(s); 
                     _awe_str_cpy(t, 2, s, 2); }

     Declarations: INTEGER ARRAY A (1::5)
                   INTEGER PROCEDURE P (INTEGER VALUE RESULT N)
     Algol call:   P(a(i))
     C call:       { int _p_arg1; 
                     _p_arg1 = *_awe_array_SUB(_awe_HERE, int, &a, i); 
                     p(&_p_arg1); 
                     *_awe_array_SUB(_awe_HERE, int, &a, i) = _p_arg1; }

     Note how the actual parameter designators get called twice: once before the 
     procedure is entered and once after. This is supposed to happen. See section 5.3.2.2. *)

  | By_value_result ftype ->
      let ftype_var = {t = ftype; c = var} in
      { decls    = call.decls    @$  declare_simple ftype var;
        precall  = call.precall  @$  assignment_statement loc ftype_var (expression scope actual);
        args     = call.args     @$. address_of ftype var;
        postcall = call.postcall @$  assignment_statement loc (designator Lvalue scope actual) ftype_var }

  (* *** RESULT Actual Parameters - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - *)

  (* The only difference from VALUE RESULT parameters is that the temporary variable is not
     initialized (unless necessary.)

     Declaration:  INTEGER PROCEDURE P (REFERENCE(R) RESULT N)
     Algol call:   P(X)
     C call:       { void * _p_arg1; 
                     _p_arg1 = (void* )0;
                     p(&_p_arg1);
                     x = _p_arg1; }
  *)

  | By_result ftype ->
      let ftype_var = {t = ftype; c = var} in
      { decls    = call.decls    @$  declare_simple ftype var;
        precall  = call.precall  @$  optionally_initialize_simple ftype var;
        args     = call.args     @$. address_of ftype var;
        postcall = call.postcall @$  assignment_statement loc (designator Lvalue scope actual) ftype_var }

  (* *** PROCEDURE Actual Parameters - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - *)

  (* If the actual parameter is a procedure with a same type as the formal parameter 
     then it is be passed directly:

     Declaration:  PROCEDURE P (INTEGER PROCEDURE Q(INTEGER R))
                   INTEGER PROCEDURE F (INTEGER I)
     Algol call:   P(F)
     C call:       p(f);

     If the formal parameter is of a procedure type with no formal parameters of its own 
     then the the actual parameter may be an expression. The expression will be wrapped 
     in a temporary "thunk" function:

     Declaration:  PROCEDURE P (INTEGER PROCEDURE Q)
     Algol call:   P(X * 2 + 1)
     C call:       { int _p_arg1() { return x * 2 + 1; }
                     p(_p_arg1); }

     It's the same story with statements:

     Declaration:  PROCEDURE P (PROCEDURE Q)
     Algol call:   P(PRINT(X * 2 + 1))
     C call:       { void _p_arg1() { print(x * 2 + 1); }
                     p(_p_arg1); }
  *)

  | By_procedure (ftype, []) ->
      let use_thunk () =
        let procedure_thunk =
          if ftype = Statement then
            "void $(void) { $ }\n" $$ [var; expression_expect Statement scope actual]
          else
            let e = expression scope actual in
            if equal_simple_types ftype e.t then
              "$ $(void) { return $; }\n" $$ [ctype ftype; var; cast loc ftype e]
            else
              error loc  "expected %s, this is %s"  (describe_formal formal) (describe_simple e.t)
        in
        {call with 
           decls = call.decls @$ procedure_thunk; 
           args  = call.args @$. var}
      in
      ( match actual with
      | Tree.Identifier (loc, procedure_id) ->
          ( match get loc scope procedure_id with
          | Procedure (t, []) when equal_simple_types t ftype -> 
              {call with args = call.args @$. Code.id procedure_id}
          | _ -> use_thunk()
          )
      | _ -> use_thunk()
      )
  | By_procedure formal_procedure ->
      ( match actual with
      | Tree.Identifier (loc, procedure_id) ->
          ( match get loc scope procedure_id with
          | Procedure actual_procedure when equal_procedure_types actual_procedure formal_procedure -> 
              {call with args = call.args @$. Code.id procedure_id}
          | Procedure actual_procedure  -> 
              error loc "expected %s here, this is %s" 
                (describe_procedure formal_procedure)
                (describe_procedure actual_procedure)
          | d ->
              error loc "expected %s here, this is %s" (describe_formal formal) (describe_definition d)
          )
      | _ -> error loc "expected %s here" (describe_formal formal)
      )

  (* *** Name Actual Parameters - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - *)

  (* These are a special Algol thing. Name parameters become "thunk" functions, which calculate a 
     pointer to a value. Designator actual parameters:

     Declaration:  INTEGER PROCEDURE P (INTEGER N)
     Algol call:   P (A(I))
     C call:       { int *_p_arg1(void) { return a(_awe_HERE, i); }
                     p(_p_arg1); }

     The thunks for expression actual parameters always return a pointer to a temporary variable:

     Declaration:  INTEGER PROCEDURE P(INTEGER N)
     Algol call:   P (I * 2 + 1)
     C call:       { int _p_arg1_temp;
                     int *_p_arg1(void) { _p_arg1_temp = i * 2 + 1; return &_p_arg1_temp; }
                     p(_p_arg1); }

     When the formal parameter corresponding to an expression actual parameter is used 
     as an expression in the procedure the system above works correctly and as expected.
     If the formal parameter is used as a variable designator then the execution of
     the procedure statement that it is part of is "undefined" (see section 7.3.2). 
     Awe's behaviour is to assign a new value to the actual's temporary variable, 
     and ignore it. ALGOLW's behaviour was to halt with an error message.

     If the actual parameter is another name parameter, and it has the same formal
     type, then there is no need to make a new thunk, it can be passed directly:

     Declaration:  INTEGER PROCEDURE P(INTEGER N);
     Algol call:   P(X)
     C call:       p(x); *)

  | By_name ftype ->
      let name_error kind t =
        error loc "%s %s is not compatible with %s name parameter" 
          (describe_simple t) 
          kind
          (describe_simple ftype) 
      in
      let use_thunk () =
        match designator_or_expression Pointer scope actual with
        | Designator dcode ->
            if equal_simple_types ftype dcode.t then
              let designator_thunk = "$$(void){ return $; }\n" $$ [c_pointer_type ftype; var; dcode.c] in
              { call with
                  decls = call.decls @$  designator_thunk;
                  args  = call.args @$. var }
            else
              name_error "variable" dcode.t
        | Expression ecode ->
            warning loc "Note, this call-by-name parameter is an expression." ;
            if equal_simple_types ftype ecode.t then
              let temp_var = "$_temp" $$ [var] in
              let expression_thunk = 
                "$$(void){ $; return $; }\n" 
                  $$ [ c_pointer_type ftype; var; 
                       assignment_statement loc {t = ftype; c = temp_var} ecode; 
                       address_of ftype temp_var ]
              in
              { call with
                  decls = call.decls @$  declare_simple ftype temp_var @$ expression_thunk;
                  args  = call.args @$. var }
            else
              name_error "expression" ecode.t
      in
      let pass_name_variable variable_id =
        let defn = get loc scope variable_id in
        match defn with 
        | Name t ->
            if equal_simple_types ftype t then
              {call with args = call.args @$.Code.id variable_id}
            else
              name_error "name variable" t
        | _ ->
            use_thunk ()
      in
      ( match actual with
      | Tree.Identifier (_, id) -> pass_name_variable id
      | _ -> use_thunk ()
      )

  (* *** ARRAY Actual Parameters -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - *)

  (*   If the actual parameter and formal parameter have the same type then the actual parameter's 
       access function is reused:
       
       Declarations: REAL ARRAY (1::5, 1::5) 
                     PROCEDURE P (REAL ARRAY ( *, * ))
       Algol call:   P(A)
       C code:       p(a);  /* simple! */

       If the actual parameter is a subarray designator, ie. its actual parameter list contains stars 
       (Cf. 7.3.1 and 7.3.2.3) then a "slice" of the array is passed.

       If the actual parameter is an array designator, ie. it has an actual parameter list without stars,
       then it designates a single element of an array, which is a type error.
       
       Declaration: REAL ARRAY (1::5, 1::5, 1::5, 1::5)
                    PROCEDURE P ( REAL ARRAY ( *, * ) )
       Algol call:  P( A( *, i, *, j ) )
       C code:      {
                      _awe_DECLARE_SLICE(_awe_at(<location>), _p_arg1, 4, {0}, {1, i}, {0}, {1, j});
                      p(&_p_arg1);
                    }
  *)

  | By_array (ftype, n_dimensions) -> 
     ( let rec count_stars : Tree.t list -> int =
         function
         | [] -> 0
         | Tree.STAR _ :: a' -> 1 + count_stars a'
         | _ :: a' -> count_stars a'
       in
       match actual with
       | Tree.Identifier (loc, id) ->   (* not a subarray designator *)
          ( match get loc scope id with
          | Array (t, adims) when equal_simple_types ftype t && adims = n_dimensions -> 
              {call with args = call.args @$.Code.id id}
          | defn -> 
              error loc "expected %s here, this is %s" (describe_formal formal) (describe_definition defn)
          )
       | Tree.Parametrized (loc, array_id, actuals) when count_stars actuals > 0 ->   (* a subarray designator *)
          let defn = get loc scope array_id in
          ( match defn with
          | Array (t, n_dimensions) when equal_simple_types ftype t -> 
              if List.length actuals <> n_dimensions then
                error loc "expected %s here, this is %s" (describe_formal formal) (describe_definition defn)
              else
                let n_stars = count_stars actuals in 
                let n_non_stars = n_dimensions - n_stars in 
                if n_non_stars = n_dimensions then
                  error loc "expected %s here, this designates a single array element" (describe_formal formal)
                else if n_stars = n_dimensions then
                  {call with args = call.args @$.Code.id array_id} (* all stars, therefore subarray = array *)
                else
                  let subarray_declaration =
                    let slice_initializers =
                      List.map
                        ( function
                          | Tree.STAR _ -> Code.string "{0}"
                          | expr -> "{1, $}" $$ [expression_expect integer scope expr] )
                        actuals
                    in
                    "_awe_array_DECLARE_SUBARRAY($, $, $, $, $);\n" $$
                      [ code_of_loc loc;
                        var;
                        code_of_int n_dimensions;
                        Code.id array_id;
                        Code.separate "," slice_initializers ]
                  in
                  {call with decls = call.decls @$ subarray_declaration; args = call.args @$. var}
          | _ -> 
              error loc "expected %s here, this is %s" (describe_formal formal) (describe_definition defn)
          )

  (* *** If the actual parameter did not match the formal parameter in any way: *)

      | _ -> error loc "expected %s here" (describe_formal formal)
      )


(* ** Reference Expressions --------------------------------------------------------- *)

(* Reference Expressions allocate new records. See 6.7. Their expression lists can be 
   absent, in which case no fields are supposed to be initialized. An individual 
   expression may be absent, in which which case the matching field is not initialized. 

   Declaration:  RECORD R (INTEGER I; REFERENCE(R) X);

   Call:         R(14, ptr)
   C Code:       r(_awe_at(loc), 14, ptr)

   Call:         R
   C Code:       r(_awe_at(loc), 0, _awe_uninitialized_reference)   /* default values */


   Declaration:  RECORD REC (INTEGER I; REFERENCE(R) X; STRING(3) S, T);

   Call:         REC (2, NULL, "Oh", )

   C Code:       ({ unsigned char _field3 [3];
                    unsigned char _field4 [3];
                    _awe_str_cpy(_field2, 3, "Oh", 2);
                    rec (_awe_at(loc), 2, (void* )0, _field3, _field4);
                 )}

   Where "loc" is the source code location of the Reference Expression.
*)

and reference_expression (loc          : Location.t) 
                         (scope        : Scope.t) 
                         (record_id    : Id.t) 
                         (record_class : Class.t) 
                         (field_types  : simple_t list)
                         (actuals      : Tree.t list)  : typed_code_t =

  let n_actuals = List.length actuals in
  let n_fields = List.length field_types in

  if n_actuals <> 0 && n_actuals <> n_fields then
    error loc "%s expects 0 or %d parameters" (Id.to_string record_id) n_fields
  else 
    let declarations, assignments, parameters, count = 
      if n_actuals = 0 then
        let f (declarations, assignments, parameters, count) field_t =
          match field_t with
          | String n when n > 1 ->
              let var = "_field$" $$ [code_of_int (count + 1)] in
              (declarations @$ declare_simple field_t var, Code.empty, parameters @$. var, count + 1)
          | _ ->
              (declarations, assignments, parameters @$. default field_t, count + 1)
        in
        List.fold_left f (Code.empty, Code.empty, Code.empty, 0) field_types
      else
        let f (declarations, assignments, parameters, count) (field_t, actual) =
          let loc' = Tree.to_loc actual in
          let e = expression scope actual in
          if e.t = Statement || assignment_compatible field_t e.t then
            match field_t with
            | String n when n > 1 ->
                let var = "_field$" $$ [code_of_int (count + 1)] in
                let assignment =
                  match e.t with
                  | Statement -> optionally_initialize_simple field_t var
                  | _         -> assignment_statement loc' {t=field_t; c=var} e
                in
                ( declarations @$ declare_simple field_t var, 
                  assignments @$ assignment,
                  parameters @$. var, 
                  count + 1 )
            | _ ->
                let parameter =
                  match e.t with
                  | Statement -> default field_t
                  | _         -> cast loc' field_t e
                in
                ( declarations, 
                  assignments,
                  parameters @$. parameter, 
                  count + 1 )
          else
            error loc "expected %s expression here, this is %s" (describe_simple field_t) (describe_simple e.t)
        in
        List.fold_left f (Code.empty, Code.empty, Code.empty, 0) (List.combine field_types actuals)
    in
    if declarations = Code.empty then
      { t = Reference (ClassSet.singleton record_class);
        c = "$($, $)" $$ [ Code.id record_id; code_of_loc loc; parameters ] }
    else
      { t = Reference (ClassSet.singleton record_class);
        c = "({ $$$($, $); })" $$ [declarations; assignments; Code.id record_id; code_of_loc loc; parameters] }


(* ** Standard Input/Output statements ------------------------------------------------------------ *)

(* An Input/Output System statement (see section 7.9) becomes a block of C function calls, 
   one for each actual parameter, based on the parameter's simple type. Sometimes 
   implicit calls to the iocontrol function are inserted to perform linebreaks, etc. 
   Statements are allowed as I/O parameters, they are simply called.

   The editing variables are saved in '_editing_state' at the start of the statement and 
   restored after (see section 7.9.3). 

   Example:
     WRITE(i, st, r)    % integer, statement, real %

   becomes

   { _awe_Editing_t _editing_state;          
     _awe_Editing_save(&_editing_state);        /* save the editing variables */
     _awe_iocontrol(_awe_at(<location>), 2);     /* iocontrol to start a new line */
     _awe_write_integer(_awe_at(<location>), i); /* write the integer parameter */
     st();                                     /* execute the statement parameter */
     _awe_write_real(_awe_at(<location>), r);    /* write the real parameter */
     _awe_Editing_restore(&_editing_state);     /* restore the editing variables */
   }

   <location> is the source code location of the WRITE statement. (WRITEs may raise runtime errors.)
*)

and standard_procedure (loc : Location.t) (scope : Scope.t) 
                       (stdproc : standard) (actuals : Tree.t list) : typed_code_t =

    let write parameter =
      let ploc = Tree.to_loc parameter in
      let pa = expression scope parameter in
      match pa.t with
      | Statement -> pa.c
      | Number(_, Integer) ->     "_awe_write_integer($, $);\n" $$ [code_of_loc loc; pa.c]
      | Number(Short, Real) ->    "_awe_write_real($, $);\n" $$ [code_of_loc loc; pa.c]
      | Number(Long, Real) ->     "_awe_write_long_real($, $);\n" $$ [code_of_loc loc; pa.c]
      | Number(Short, Complex) -> "_awe_write_complex($, $);\n" $$ [code_of_loc loc; pa.c]
      | Number(Long, Complex)  -> "_awe_write_long_complex($, $);\n" $$ [code_of_loc loc; pa.c]
      | Logical ->                "_awe_write_logical($, $);\n" $$ [code_of_loc loc; pa.c]
      | Bits ->                   "_awe_write_bits($, $);\n" $$ [code_of_loc loc; pa.c]
      | String 1 ->               "_awe_write_char($, $);\n" $$ [code_of_loc loc; pa.c]
      | String length ->          "_awe_write_string($, $, $);\n" $$ [code_of_loc loc; pa.c; code_of_int length]
      | Reference _ ->            "_awe_write_reference($, $);\n" $$ [code_of_loc loc; pa.c]
      | _ -> error ploc "%s cannot be written" (describe_simple pa.t)
    in

    let writecard parameter =
      let ploc = Tree.to_loc parameter in
      let pa = expression scope parameter in
      match pa.t with
      | Statement -> pa.c
      | String 1 -> 
          "_awe_iocontrol($, 2);\n_awe_write_char($, $);\n" $$ [code_of_loc loc; code_of_loc loc; pa.c]
      | String length -> 
          "_awe_iocontrol($, 2);\n_awe_write_string($, $, $);\n" $$ [code_of_loc loc; code_of_loc loc; pa.c; code_of_int length]
      | t -> error ploc "Expected a statement or string expression, this is %s expression" (describe_simple t)
    in

    let readcard parameter =
      match designator_or_expression Pointer scope parameter with
      | Designator d ->
          ( match d.t with
          | String 1 -> "_awe_readcard_char($, $);\n" $$ [code_of_loc loc; d.c]
          | String n -> "_awe_readcard($, $, $);\n" $$ [code_of_loc loc; d.c; code_of_int n]
          | t -> error loc "%s cannot be read by READCARD" (describe_simple t)
          )
      | Expression e ->
          ( match e.t with
          | Statement -> e.c
          | t -> error loc "Expected a designator or statement, this is %s expression" (describe_simple t)
          )
    in

    let read parameter =
      match designator_or_expression Pointer scope parameter with
      | Designator d ->
          ( match d.t with
          | String 1 ->          "_awe_read_char($, $);\n" $$ [code_of_loc loc; d.c]
          | String length  ->    "_awe_read_string($, $, $);\n" $$ [code_of_loc loc; d.c; code_of_int length]
          | Number(_,Integer) -> "_awe_read_integer($, $);\n" $$ [code_of_loc loc; d.c]
          | Number(_,Real) ->    "_awe_read_real($, $);\n" $$ [code_of_loc loc; d.c]
          | Number(_,Complex) -> "_awe_read_complex($, $);\n" $$ [code_of_loc loc; d.c]
          | Bits ->              "_awe_read_bits($, $);\n" $$ [code_of_loc loc; d.c]
          | Logical ->           "_awe_read_logical($, $);\n" $$ [code_of_loc loc; d.c]
          | t -> error loc "%s cannot be read" (describe_simple t)
          )
      | Expression e ->
          ( match e.t with
          | Statement -> e.c
          | t -> error loc "Expected a designator or statement, this is %s expression" (describe_simple t)
          )
    in

    let iocontrol parameter =
      let e  = expression scope parameter in
      match e.t with
      | Statement -> e.c
      | Number(_, Integer) -> "_awe_iocontrol($, $);\n" $$ [code_of_loc loc; e.c]
      | t -> 
          let loc = Tree.to_loc parameter in
          let s = describe_simple t in
          error loc "IOCONTROL expects INTEGER or statement actual parameters, this is %s" s
    in

    let io_block f initial final =
        { t = Statement;
          c = "{ _awe_Editing_t _editing_state;
                 _awe_Editing_save(&_editing_state);
                 $$$_awe_Editing_restore(&_editing_state);
               }
              " $$ [initial; Code.concat (List.map f actuals); final] }
    in

    match stdproc with
    | Writeon   -> io_block write     Code.empty Code.empty
    | Write     -> io_block write     ("_awe_iocontrol($, 2);\n" $$ [code_of_loc loc]) Code.empty
    | Writecard -> io_block writecard Code.empty ("_awe_iocontrol($, 2);\n" $$ [code_of_loc loc])
    | Iocontrol -> io_block iocontrol Code.empty Code.empty
    | Readcard  -> io_block readcard  Code.empty Code.empty
    | Read      -> io_block read      ("_awe_iocontrol($, 1);\n" $$ [code_of_loc loc]) Code.empty
    | Readon    -> io_block read      Code.empty Code.empty
        


(* * Designators ---------------------------------------------------------------------------------- *)

(* This parses a tree as either a designator or expression, trying for a designator first 
   (name actual parameters need this behaviour); it returns either a C lvalue or a pointer 
   expression (the "flavour"). *)

and designator_or_expression (flavour : designator_t) 
                             (scope : Scope.t) 
                             (tree : Tree.t) 
                             : designator_or_expression_t =

  let qualifier exprs_flavour t =
    (* E.g. if we have a C pointer variable, but we want an lvalue, we prefix it with "*" *)
    match t, exprs_flavour, flavour with
    | String n, _,       _       when n > 1 -> Code.empty
    | _,        Pointer, Lvalue             -> Code.string "*"
    | _,        Lvalue,  Pointer            -> Code.string "&"
    | _,        _,       _                  -> Code.empty
  in

  match tree with
  | Tree.Identifier (loc, id) ->   (* i.e. no parameter list. This might be a designator *)
      ( match get loc scope id with
      | Variable t -> Designator { t = t; c = "$$"   $$ [qualifier Lvalue  t; Code.id id] }
      | Result t   -> Designator { t = t; c = "$$"   $$ [qualifier Pointer t; Code.id id] }
      | Name t     -> Designator { t = t; c = "$$()" $$ [qualifier Pointer t; Code.id id] }
      | _          -> Expression (expression scope tree)
      )
  | Tree.Parametrized (loc, id, actuals) ->  (* i.e. has a parameter list. This might be a designator. *)
      ( match get loc scope id with
      | Array (etype, ndims) ->
          if List.length actuals <> ndims then
            error loc "Array '%s' requires %i parameter%s" (Id.to_string id) ndims (if ndims = 0 then "" else "s") ;
          Designator { t = etype;
                       c = "$_awe_array_SUB($, $, $, $)" $$
                             [ qualifier Pointer etype;
                               code_of_loc loc;
                               (match etype with String n when n > 1 -> Code.string "unsigned char" | t -> ctype t);
                               Code.id id;
                               Code.separate ", " (List.map (expression_expect integer scope) actuals)] }
      | Field (field_type, field_class) ->
          let field_name = Id.to_string id in
          if List.length actuals <> 1 then
            error loc "Record field designator %s should have one actual parameter" field_name
          else
            let actual = List.hd actuals in
            let reference = expression scope actual in
            ( match reference.t with
            | Reference class_set when Type.ClassSet.mem field_class class_set ->
                Designator 
                  { t = field_type; 
                    c = "$$($, $)" $$ [ qualifier Pointer field_type; Code.id id; code_of_loc loc; reference.c ] }
            | Reference _ ->
                error (Tree.to_loc actual) "%s can never have the field %s" 
                  (describe_simple reference.t) 
                  field_name
            | _ ->
                error loc "Expecting a reference, this is %s" (describe_simple reference.t)
            )
      | _ ->  (* record designators and procedure calls are expressions *)
          Expression (expression scope tree)  
      )
  | Tree.Substring (loc, desig, index, length) ->
      let src = designator Pointer scope desig in
      let index_code = expression_expect integer scope index in
      ( match src.t with
      | String srclen when length <= srclen ->
          Designator
            { t = String length;
              c = "$_awe_str_sub($, $, $, $, $)" 
                $$ [ qualifier Pointer (String length);
                    code_of_loc loc; 
                    src.c; code_of_int srclen; 
                    index_code; code_of_int length ] }
      | String _ ->
          error loc "%s can never contain %i character substrings " (describe_simple src.t) length
      | t -> 
          error loc "The substring operator expects a STRING variable on the right, this is %s" (describe_simple t)
      )
  | _ ->   (* everything else is always an expression *)
      Expression (expression scope tree)


and designator (flavour : designator_t)  (* required C expression result: lvalue or pointer *)
               (scope : Scope.t) 
               (tree : Tree.t) 
               : typed_code_t =

  match designator_or_expression flavour scope tree with
  | Designator dcode -> dcode
  | Expression ecode -> error (Tree.to_loc tree) "expected a designator here, this is %s expression"
      (describe_simple ecode.t)


(* * Declarations --------------------------------------------------------------------------------------------- *)

(* Adds declarations to the block data that 'block_expression' is collecting: 
   the Algol declarations in the block's scope; the C code to initialize and 
   declare variables; various other C declarations.*)

and add_declaration (block : block_t) (decl : Tree.t) : block_t =
  match decl with
  | Tree.Simple (loc, t, ids) -> 
      List.fold_left
        (fun d id ->
           let t = simple block.scope t in
           { d with 
               scope          = set loc d.scope id (Variable t);
               variables      = d.variables @$ (declare_simple t (Code.id id));
               initialization = d.initialization @$ (optionally_initialize_simple t (Code.id id)) } )
        block
        ids

  (* Array bounds are evaluated in a scope outside the block the array is declared in. See section 5.2.2. *)
  | Tree.ARRAY (loc, t, ids, bounds) -> 
      let elttype = simple block.scope t in
      let cbounds = 
        List.map 
          ( fun (l,u) -> 
              let outside_scope = Scope.pop block.scope in
              ( expression_expect integer outside_scope l, 
                expression_expect integer outside_scope u ) )
          bounds
      in
      List.fold_left (add_array_declaration loc elttype cbounds) block ids

  | Tree.PROCEDURE (_, _, _, _, _) as procedure -> 
      add_procedure_declaration procedure block

  | Tree.RECORD (loc, id, []) ->  (* previously defined by 'add_record_declaration' *)
      block

  | Tree.RECORD (loc, id, fields) -> 
      add_record_declaration loc block id fields

  | e -> 
      failwith (sprintf "Compiler.add_declaration: not a declaration: %s\n" (Tree.str e))
  

(* ** Record declarations ---------------------------------------------------------------------- *)

(* A record declaration declares a "record class", which can be used in a "record expression" 
   to allocate a new record, and "field designators", which access the fields in a record.

   Field designators are represented by functions that return pointers into C structures.
   C's "->" operator isn't used because the field designators need to check that they are 
   being applied to the right class of record. (See 6.1.2.)

   An example Algol declaration: 

            RECORD R (INTEGER I);

   Below is the C code for that record declaration, listed by the sections of the 
   surrounding C block they will be placed in (see the 'block_t' type and the 
   'block' function for details):

   C global scope:  

          Records are tagged with pointers to their classes' names so that 
          reference assignment compatibility can be checked at runtime. 
          (See section 7.2.2.) They must be global, so the 'program' function 
          adds this code.

            static const char * const _awe_class_1_r = "r";

   block.structs:

            struct r {
                const char *_class;
                int _number;
                int i;
            };

   block.prototypes: 
                     
       "Reference expression" functions that return pointers to new records. 
       See section 6.7.1

            auto struct r * r (_awe_loc loc, int i);

       "Field designator" functions that return pointers to fields in records.
       One for each field. See section 6.1.2.

            auto int * i (_awe_loc loc, void *ref);

   block.functions:

       The function declarations for the above. See 'awe.h'.

            struct r * r (_awe_loc loc, int i) {
                struct r * ref = (struct r * ) _awe_allocate_record(loc, sizeof(struct r));
                ref->_class = _awe_class_1_r;
                ref->_number = ++_awe_record_counter;
                ref->i = i;
                return (void * ) ref;
            }

            int * i (_awe_loc loc, void *ref) {
                _awe_ref_field_check(loc, ref, _awe_class_1_r, "i");
                return &((struct r * )ref)->i;
            }

   XXX I think maybe record initialization should be done at the site of the 
   reference expression, not by the allocation function.
*)


(* This preliminary scan of a block adds record class identifiers 
   to the block's scope.  All other declarations in the block, 
   including those in records' fields, need to be able look up these
   to determine the simple types of references. *)

and add_record_headers (block : block_t) (block_body : Tree.t list) : block_t =
  List.fold_left
    (fun d item ->
       match item with
       | Tree.RECORD (loc, id, _) -> 
           (* Just the identifier for now, the fields will be added in a later scan *)
           { d with scope = set loc d.scope id (Record (Class.create loc id, []))  }
       | _ -> d )
    block
    block_body


(* This next scan fully declares records: it adds C code for their structures, 
   and code and declarations for field designators. *)

and add_record_declaration (loc : Location.t)
                           (block : block_t) 
                           (record_id : Id.t) 
                           (field_declarations : Tree.t list) : block_t =

  (* The previously recorded class for this record: *)

  let record_class = 
    match get loc block.scope record_id  with
    | Type.Record (c, []) -> c
    | _ -> failwith "add_record_declaration: record_class not previously defined"
  in
  let class_code = Code.id (Class.to_id record_class) in
  let r = Code.id record_id in
  
  (* The types and ids of the record's fields, in order: *)

  let fields : (simple_t * Id.t) list =
    List.fold_left 
      ( fun ds decl ->
          match decl with
          | Tree.Simple (loc, t, ids) -> 
              let t = simple block.scope t in
              let fields = List.map (fun id -> (t, id)) ids in
              ds @ fields
          | d -> error (Tree.to_loc d) "Records may only contain simple variable declarations"
      )
      []
      field_declarations
  in

  (* Redefine the record declaration in the block's scope.
     Record designators translate to C functions that allocate C structures and 
     initialize the structure's fields. There are extra fields for runtime 
     assignment compatibility testing (see awe.h) *)

  let record_struct =
    let field_declarations =
      let declaration (t, id) = declare_simple t (Code.id id) in
      Code.concat (List.map declaration fields)
    in
    "struct $ {
       const char *_class;
       int _number;
       $
     };
    " $$ [Code.id record_id; field_declarations]
  in
  let record_prototype =
    let field_arguments = 
      let argument (t, id) = "$ $" $$ [ctype t; Code.id id] in
      Code.separate ", " (List.map argument fields)
    in
    "struct $ *$(_awe_loc loc, $)" $$ [r; r; field_arguments]
  in
  let record_function =
    let field_assignments = 
      let assignment (t, id) = 
        assignment_statement loc 
          {t = t; c = "ref->$" $$ [Code.id id]} 
          {t = t; c = Code.id id} 
      in
      Code.concat (List.map assignment fields)
    in        
    "$ {
       struct $ *ref = (struct $ *)_awe_allocate_record(loc, sizeof(struct $));
       ref->_class = $;
       ref->_number = ++_awe_record_counter;
       $
       return (void *)ref;
     }
    " $$ [ record_prototype;
          r; r; r;
          class_code;
          field_assignments;
        ]
  in
  let block =
    let field_types = List.map fst fields in
    { block with
        scope = Scope.redefine block.scope record_id (Record (record_class, field_types));
        structs = block.structs @$ record_struct ;
        prototypes = ("$auto $;\n" $$ [block.prototypes; record_prototype]);
        functions = block.functions @$ record_function }
  in

  (* Field designators translate to C functions that calculate pointers to fields 
     in records' structures. Add code for those to the block, and we're done. *)

  let field_prototype t field_id = 
    "$$ (_awe_loc loc, void *ref)" $$ [c_pointer_type t; Code.id field_id] 
  in
  let field_function t field_id prototype = 
    let pointer = address_of t ("((struct $ *)ref)->$" $$ [Code.id record_id; Code.id field_id]) in
    "$ {
       _awe_ref_field_check(loc, ref, $, $);
       return $;
     }
    " $$ [ prototype; 
          class_code; c_str_const (Id.to_string field_id);
          pointer ]
  in
  let add_field (block : block_t) (field_decl : Tree.t) : block_t = 
    match field_decl with
    | Tree.Simple (loc, t, field_ids) ->   
        let t = simple block.scope t in
        List.fold_left
          ( fun block'' field_id ->
              let p = field_prototype t field_id in
              let f = field_function t field_id p in
              { block'' with
                  scope = set loc block''.scope field_id (Field (t, record_class));
                  prototypes = ("$auto $;\n" $$ [block''.prototypes; p]);
                  functions = block''.functions @$ f } )
          block
          field_ids
    | d -> error (Tree.to_loc d) "Records may only contain simple variable declarations"
  in
  List.fold_left add_field block field_declarations


(* ** Procedure declarations ---------------------------------------------------------------- *)

(* All the procedures in an Algol block are visible to one and other, but in C only preceeding
   function declarations are visible, prototypes have to be added to allow mutually 
   recursive functions. Awe handles this difference by adding a prototype for every procedure
   to the top of every C block. 

   There needs to be two scans of a block for procedures: the first to add procedure 
   declarations to the block's scope and build the prototypes; the second to build the 
   code for the procedure's bodies (which require the procedure declarations added by the 
   first scan.)

   Algol procedures are local to their blocks, so their corresponding C functions need to be 
   GNU nested functions. See http://gcc.gnu.org/onlinedocs/gcc/Nested-Functions.html *)

and add_procedure_declaration (procedure : Tree.t) (block : block_t) : block_t  =
  match procedure with
    Tree.PROCEDURE (loc, simple_type, id, formal_trees, procedure_body) ->
      let returntype =
        match simple_type with
        | None -> Statement
        | Some t -> simple block.scope t
      in
      let parameters =
        List.fold_left 
          (add_formal_segment block.scope)
          empty_formal_parameters
          formal_trees
      in
      let c_header c_id = 
        if parameters.arguments = Code.empty then 
          "$ $ (void)" $$ [ctype returntype; c_id] 
        else 
          "$ $ ($)" $$ [ctype returntype; c_id; parameters.arguments]
      in
      let header, prototype =
        match procedure_body with
        | Tree.External (refloc, reference) ->
            if not (is_valid_c_identifier reference) then 
              error refloc "the external reference %S is not a valid C identifier" reference
            else
              let h = c_header (Code.string reference) in
              output "/* %s; */\n" (Tree.str procedure) ;
              output "%s;\n\n" (Code.to_string h) ;
              if reference = Id.to_string id then 
                h, h @$ Code.string ";\n"
              else
                h, "extern $;\n#define $ $\n" $$ [h; Code.id id; Code.string reference]
        | _ -> 
            let h = c_header (Code.id id) in
            h, "auto $;\n" $$ [h]
      in
      (
        ( match procedure_body with
          | Tree.BEGIN (_, _, _, end_id) when end_id <> Table.Id.dummy && end_id <> id  ->
             (* Check that the procedure has the same name as the id at the end of its main block.
                This is not required, but if they do not match then there may be an unclosed BEGIN. *)
             warning loc "Note, this procedure is named %s, but its block ends with %s."
                     (Table.Id.to_string id) (Table.Id.to_string end_id)
          | _ -> ()
        );
        let proc = 
          { returntype = returntype;
            proc_id    = id;
            proc_loc   = loc;
            parameters = parameters; 
            header     = header;
            body       = procedure_body } (* to be defined later, in the complete block scope *)
        in
        { block with
            scope      = set loc block.scope id (Procedure (returntype, parameters.formal_types));
            prototypes = block.prototypes @$ prototype;
            procedures = block.procedures @ [proc]
        }
      )
  | _ -> failwith ("Compiler.add_procedure_declaration: not a procedure: " ^ (Tree.str procedure))


(* This adds C function declarations for Algol procedures to a block.
    It works from the procedure definitions in 'block.procedures', gathered by  
   'add_procedure_declaration' above.) *)

and add_procedure_functions (block : block_t) : block_t =
  let add_function (block : block_t) (procedure : procedure_header_t) : block_t =
    match procedure.body with 
    | Tree.External (_, _) ->  block  (* External reference procedures are prototypes only. See section 5.3.2.4. *)
    | _ ->
        let tracer () =
          if !Options.add_tracing_hooks then
            "_awe_trace_procedure_entered($, $);\n" $$ [ code_of_loc procedure.proc_loc; 
                                                        c_str_const (Table.Id.to_string procedure.proc_id)]
          else Code.empty
        in
        let function_code = 
          let loc = Tree.to_loc procedure.body in
          let procedure_parameter_scope = procedure.parameters.procedure_locals :: block.scope in
          let procedure_body_scope = Scope.push procedure_parameter_scope in
          let body = expression procedure_body_scope procedure.body in
          if body.t <> Statement then 
            "$ {$\nreturn $;\n }\n" $$ [procedure.header; tracer(); cast loc procedure.returntype body] 
          else if procedure.returntype = Statement then
            "$ {$\n$ }\n" $$ [procedure.header; tracer(); body.c]
          else
            error loc "this procedure should return %s, but this is a statement" 
              (describe_simple procedure.returntype)
        in
        { block with functions = block.functions @$ function_code }
  in
  List.fold_left add_function block block.procedures


(* This collects Algol formal parameter declarations and their corresponding C function arguments, 
   one for each identifier in a "formal parameter segment" (see section 5.3) 

   The translation of various kinds of formal parameters to C arguments, by example:

   INTEGER VALUE I, J        int i, int j    one segment declaring two parameters

   INTEGER RESULT I          int *i, int *j  a pointer to a temporary variable at the point-of-call
   INTEGER VALUE RESULT I    int *i

   STRING(1) VALUE S         unsigned char s       STRING(1) is a character, a C rvalue
   STRING(4) VALUE S         _awe_str s       longer strings are always pointers to character arrays
   STRING(4) RESULT S        _awe_str s

   Algol "call by name" parameters are functions that calculate pointers to variables. They
   are called every time the parameter is accessed in the procedure's body -- an imperative 
   form of lazy evaluation. This is Algol's most alien feature:

   INTEGER I      --->       int( *i)(void)  

   Algol arrays are translated into pointers to array descriptors.

   INTEGER ARRAY A ( *, * )   --->   _awe_array_t *a

   Procedure parameters require parameter lists of their own (this is a Awe language extension.)
   Algol W and Algol 60 leave the parameter lists undeclared, but I found that that didn't 
   sit well with C.
   
   REAL PROCEDURE f (REAL VALUE t; LOGICAL VALUE x)   ---> double f (double t, int x)
*)

and add_formal_segment (scope : Scope.t) (formals : formal_parameters_t) (segment : Tree.t) : formal_parameters_t =
  let pointer_qualifier t =
    match t with
    | String n when n > 1 -> Code.empty   
    | _                   -> Code.string "*"
  in
  match segment with
  | Tree.VALUE_formal (loc, t, ids) ->
      let t = simple scope t in
      List.fold_left 
        ( fun f id -> 
            { procedure_locals = set_local loc f.procedure_locals id (Variable t);
              formal_types     = f.formal_types @ [By_value t];
              arguments        = f.arguments @$. ("$ $" $$ [ctype t; Code.id id]) } )
        formals
        ids
  | Tree.VALUE_RESULT_formal (loc, t, ids) ->
      let t = simple scope t in
      List.fold_left 
        ( fun f id -> 
            let r = Code.id id in
            { procedure_locals = set_local loc f.procedure_locals id (Result t);
              formal_types     = f.formal_types @ [By_value_result t];
              arguments        = f.arguments @$. ("$$" $$ [c_pointer_type t; r]) } )
        formals
        ids
  | Tree.RESULT_formal (loc, t, ids) ->
      let t = simple scope t in
      List.fold_left 
        ( fun f id -> 
            let r = Code.id id in
            { procedure_locals = set_local loc f.procedure_locals id (Result t);
              formal_types    = f.formal_types @ [By_result t];
              arguments       = f.arguments @$. ("$$" $$ [c_pointer_type t; r]) } )
        formals
        ids
  | Tree.PROCEDURE_formal (loc, t_opt, ids, formal_trees) ->
      let t = match t_opt with None -> Statement | Some t -> simple scope t in
      (* Get the formal parameters of the procedure parameter: *)
      let fs = List.fold_left (add_formal_segment scope) empty_formal_parameters formal_trees in
      List.fold_left 
        ( fun f id -> 
            { procedure_locals = set_local loc f.procedure_locals id (Procedure (t, fs.formal_types));
              formal_types     = f.formal_types @ [By_procedure (t, fs.formal_types)];
              arguments        = f.arguments @$. ("$ ($$)($)" $$ [ctype t; pointer_qualifier t; Code.id id; fs.arguments]) } )
        formals
        ids
  | Tree.Name_formal (loc, t, ids) ->
      warning loc "Note, this is a call-by-name formal parameter." ;
      let t = simple scope t in
      List.fold_left 
        ( fun f id -> 
            { procedure_locals = set_local loc f.procedure_locals id (Name t);
              formal_types     = f.formal_types @ [By_name t];
              arguments        = f.arguments @$. ("$($$)(void)" $$ [c_pointer_type t; pointer_qualifier t; Code.id id]) } )
        formals
        ids
  | Tree.ARRAY_formal (loc, t, ids, ndims) ->
      let t = simple scope t in
      List.fold_left 
        ( fun f id -> 
            assert (ndims > 0);
            { procedure_locals = set_local loc f.procedure_locals id (Array (t, ndims));
              formal_types     = f.formal_types @ [By_array (t, ndims)];
              arguments        = f.arguments @$. ("_awe_array_t *$" $$ [Code.id id]) } )
        formals
        ids
  | e -> 
      failwith (sprintf "Compiler.add_formal_segment: this is not a formal: %s\n" (Tree.str e))


(* ** Label declarations ------------------------------------------------------------------- *)

(* Algol labels are implicit declarations, so they are scoped, and Algol GOTOs can 
   jump out of procedures. To allow those things they much be given Gnu C "local
   label" declarations. See http://gcc.gnu.org/onlinedocs/gcc/Local-Labels.html

   This function scans a block body for labels, and adds declarations for them 
   to the block's Algol scope and C code. *)

and add_label_declarations (block : block_t) (block_body : Tree.t list) : block_t =
  List.fold_left
    ( fun b item ->
        match item with
        | Tree.Label (loc, label) -> 
            { b with 
                scope = set loc b.scope label Label;
                labels = b.labels @$ ("__label__ $;\n" $$ [Code.id label]) }
        | _ -> b )
    block
    block_body


(* ** Array declarations ---------------------------------------------------------------------  *)

(* Algol W are not very like C arrays: they can be multidimensional;  
   their bounds are set at runtime; they can have non-zero lower bounds;
   and some are "subarrays" that select slices of other array's data.

   An example Algol declaration: 

        REFERENCE(R) ARRAY A (x - 2 :: x + 2,  0 :: 2 * X + 1)

   Below is the C code for that array declaration, listed by the sections of the 
   surrounding C block they will be placed in (see 'block_t' and 'block' 
   for more details about blocks):

   block.outsidescope: Array bounds calculations.

       _awe_array_bounds _a_bounds[] = {{x - 2, x + 2}, {0, 2 * x + 1}};

   block.variables: this macro declares a block of memory and an array descriptor
                    on the stack. The bounds are checked when the descriptor is
                    initialized.

       _awe_array_DECLARE(awe_loc(<location>), a, sizeof(void* ), 2, _a_bounds);

   block.initialization: Initialization of array elements. Arrays of references are 
                         initialized with _awe_uninitialized_reference, for runtime 
                         checking, other types of array are initialized with default 
                         values if !Options.initialize_all == true.

       _awe_array_FILL(void*, &a, _awe_uninitialized_reference);
*)

and add_array_declaration (loc     : Location.t)
                          (elttype : simple_t) 
                          (bounds  : (Code.t * Code.t) list) 
                          (block   : block_t)
                          (id      : Id.t) 
                          : block_t =

  let initialize_bounds =
    let bound_pair (cl, cu) = "{$, $}" $$ [cl; cu] in
    "_awe_array_bound_t _$_bounds[] = {$};\n" $$ [Code.id id; Code.separate ", " (List.map bound_pair bounds)]
  in
  
  let array_variable =
    " _awe_array_DECLARE($, $, $, $, _$_bounds);\n" $$
      [ code_of_loc loc;
        Code.id id;
        sizeof_ctype elttype;
        code_of_int (List.length bounds);
        Code.id id ]
  in

  let element_initialization =
      match elttype with
      | Reference _ ->
         "_awe_array_FILL(void*, $, _awe_uninitialized_reference);\n" $$ [Code.id id]
      | String n when n > 1 && !Options.initialize_all ->
         "_awe_array_FILL_WITH_SPACES($)" $$ [Code.id id]
      | _ when !Options.initialize_all ->
         "_awe_array_FILL($, $, $);\n" $$ [ctype elttype; Code.id id; default elttype]
      | _ ->
         Code.empty
  in
  
  { block with
      scope          = set loc block.scope id (Array (elttype, List.length bounds)); 
      outsidescope   = block.outsidescope   @$ initialize_bounds;
      variables      = block.variables      @$ array_variable;
      initialization = block.initialization @$ element_initialization }

(* end *)


           
    

(* predeclared.ml -- the Standard Functions and Predeclared Identifiers

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

open Type

let scope =

  let real = Number(Short,Real) in
  let long_real = Number(Long,Real) in

  let exception_id = Table.Id.create "exception" in
  let exception_class = Class.create (Location.create "(Predeclared Identifiers)" 0 0) exception_id in
  let exception_reference = Variable (Reference (ClassSet.singleton exception_class)) in

  List.fold_left
    (fun scope' (name, defn) -> Scope.set scope' (Table.Id.create name) defn)
    Scope.empty

    [ "time",      Procedure (integer, [By_value(integer)])

    (* Standard I/O  *)

    ; "s_w",       Variable integer
    ; "i_w",       Variable integer
    ; "r_w",       Variable integer
    ; "r_d",       Variable integer
    ; "r_format",  Variable (String 1)
    ; "write",     Standard Write
    ; "writeon",   Standard Writeon
    ; "writecard", Standard Writecard
    ; "read",      Standard Read
    ; "readon",    Standard Readon
    ; "readcard",  Standard Readcard
    ; "iocontrol", Standard Iocontrol

    (* Standard Transfer Procedures *)

    ; "entier",       Procedure (integer,   [By_value(real)])
    ; "truncate",     Procedure (integer,   [By_value(real)])
    ; "round",        Procedure (integer,   [By_value(real)])
    ; "roundtoreal",  Procedure (real, [By_value(long_real)])
    ; "realpart",     Procedure (real, [By_value(Number(Short,Complex))])
    ; "imagpart",     Procedure (real, [By_value(Number(Short,Complex))])
    ; "longrealpart", Procedure (long_real, [By_value(Number(Long,Complex))]) 
    ; "longimagpart", Procedure (long_real, [By_value(Number(Long,Complex))]) 
    ; "imag",         Procedure (Number(Short,Complex), [By_value(real)])
    ; "longimag",     Procedure (Number(Short,Complex), [By_value(long_real)]) 
    ; "odd",          Procedure (Logical,   [By_value(integer)])
    ; "bitstring",    Procedure (Bits 32,   [By_value(integer)])
    ; "number",       Procedure (integer,   [By_value(Bits 32)])
    ; "decode",       Procedure (integer,   [By_value(String 1)])
    ; "code",         Procedure (String 1,  [By_value(integer)])
    ; "base10",       Procedure (String 12, [By_value(real)])
    ; "longbase10",   Procedure (String 20, [By_value(long_real)])
    ; "intbase10",    Procedure (String 12, [By_value(integer)])
    ; "intbase16",    Procedure (String 12, [By_value(integer)])
      
    (* Standard Functions of Analysis *)

    ; "sqrt",       Analysis real
    ; "exp",        Analysis real
    ; "ln",         Analysis real
    ; "log",        Analysis real
    ; "sin",        Analysis real
    ; "cos",        Analysis real
    ; "arctan",     Analysis real
    ; "gamma",      Analysis real
    ; "longsqrt",   Analysis long_real
    ; "longexp",    Analysis long_real
    ; "longln",     Analysis long_real
    ; "longlog",    Analysis long_real
    ; "longsin",    Analysis long_real
    ; "longcos",    Analysis long_real
    ; "longarctan", Analysis long_real
    ; "longgamma",  Analysis real

    (* Predeclared variables. *)

    ; "maxinteger",  Variable(integer)
    ; "pi",          Variable(real)
    ; "epsilon",     Variable(real)
    ; "longepsilon", Variable(long_real)
    ; "maxreal",     Variable(long_real)

    (* Exceptional Conditions. *)

    ; "exception",  Record (exception_class, [Logical; integer; integer; Logical; String 64])
    ; "xcpnoted",   Field (Logical, exception_class)
    ; "xcpaction",  Field (integer, exception_class)
    ; "xcplimit",   Field (integer, exception_class)
    ; "xcpmark",    Field (Logical, exception_class)
    ; "xcpmsg",     Field (String 64, exception_class)

    ; "divzero",    exception_reference
    ; "intdivzero", exception_reference
    ; "sqrterr",    exception_reference
    ; "experr",     exception_reference
    ; "lnlogerr",   exception_reference
    ; "sincoserr",  exception_reference
    ; "endfile",    exception_reference
    ]

(* end *)

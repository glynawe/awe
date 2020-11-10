(* location.mli -- Algol W source code locations, for runtime error messages

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

type t

val filename    : t -> string
val file_number : t -> int
val line        : t -> int
val column      : t -> int

val source_files : unit -> string list  (* The names of all the source files, in file_number order. *)

val set_source : string -> unit  (* set a source file name as the one for error reports,
                                    appends a new source file to list of sources in needed *)

val create : string -> int -> int -> t  (* Create from source file, line number and column number. *)

val of_position : Lexing.position -> t

val to_string : t -> string  (* Convert to an Emacs-compatible source code location string *)

(* end *)

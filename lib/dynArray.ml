(* dynArray.ml 

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

type 'a t = {
  mutable length : int;
  mutable arr : 'a array;
  filler : 'a
}

let initial_size = 20

let create filler =
  { length = 0;
    arr = Array.make initial_size filler;
    filler = filler }

let get a i  =  Array.get a.arr i

let add a element =
  let len = Array.length a.arr in
  if len = a.length then
    a.arr <- Array.append a.arr (Array.make len a.filler) ; (* double the array length *)
  Array.set a.arr a.length element ;
  a.length <- a.length + 1

let length a = a.length

let to_list (a : 'a t) : 'a list =
  let xs = ref [] in
  for i = a.length - 1 downto 0 do
    xs := a.arr.(i) :: !xs
  done ;
  !xs

(* end *)


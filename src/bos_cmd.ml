(*---------------------------------------------------------------------------
   Copyright (c) 2015 Daniel C. Bünzli. All rights reserved.
   Distributed under the BSD3 license, see license at the end of the file.
   %%NAME%% release %%VERSION%%
  ---------------------------------------------------------------------------*)

open Astring
open Rresult

(* Command line fragments *)

type t = A of string | S of t list

let empty = S []
let is_empty = function S [] -> true | _ -> false

let v a = A a

let ( % ) l a = match l with
| A _ -> S [A a; l]
| S s -> S (A a :: s)

let ( %% ) l0 l1 = match l0, l1 with
| S s0, (A _ as a1) -> S (a1 :: s0)
| S s0, (S _ as s1) -> S (s1 :: s0)
| A _ as a0, a1 -> S [a1; a0]

let add_arg l a = l % a
let add_args l a = l %% a

let on bool l = if bool then l else S []
let cond bool l l' = if bool then l else l'

let p = Bos_path.to_string

let flatten line =
  let rec loop acc current todo = match current with
  | A a :: l -> loop (a :: acc) l todo
  | S s :: l -> loop acc s (l :: todo)
  | [] ->
      match todo with
      | [] -> acc
      | current :: todo -> loop acc current todo
  in
  loop [] [line] []

let to_list line = flatten line
let of_list line = S (List.rev_map (fun s -> A s) line)
let to_string line = String.concat ~sep:" " (flatten line)

(*---------------------------------------------------------------------------
   Copyright (c) 2015 Daniel C. Bünzli.
   All rights reserved.

   Redistribution and use in source and binary forms, with or without
   modification, are permitted provided that the following conditions
   are met:

   1. Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.

   2. Redistributions in binary form must reproduce the above
      copyright notice, this list of conditions and the following
      disclaimer in the documentation and/or other materials provided
      with the distribution.

   3. Neither the name of Daniel C. Bünzli nor the names of
      contributors may be used to endorse or promote products derived
      from this software without specific prior written permission.

   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
   "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
   LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
   A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
   OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
   SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
   LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
   DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
   THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
   (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
   OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
  ---------------------------------------------------------------------------*)

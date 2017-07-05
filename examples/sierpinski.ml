(* Copyright (c) 2016-2017 David Kaloper Meršinjak. All rights reserved.
   See LICENSE.md. *)

(**
 * A classic example in combinatory graphics.
 *
 * Demonstrates interaction.
 *)
open Notty
open Common

let () =
  simpleterm ~s:1
    ~f:(fun s -> function
      | `Key (`Uchar 113, _) -> None
      | `Key (`Arrow a, _) ->
        ( match a with
          | `Up | `Left -> Some (max 1 (s - 1))
          | `Down | `Right -> Some (min 10 (s + 1)) )
      | _ -> Some s)
    ~imgf:I.(fun _ s ->
      string A.empty (string_of_int s) <->
      pad ~l:2 ~t:1 (Images.sierp A.magenta s)
    )

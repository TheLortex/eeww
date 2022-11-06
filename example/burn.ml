open Eio

let spawn ~clock min max =
  Switch.run @@ fun sw ->
  for i = min to max do
    Fiber.fork ~loc:__LOC__ ~sw (fun () -> 
      for _i = 0 to max do Time.sleep clock 0.2; Fiber.yield () done;
      Time.sleep clock (float_of_int i)
    );
    Time.sleep clock (float_of_int (max - i))
  done

(* Based on the Tokio Console example application *)
let main clock =
  let p, r = Promise.create () in
  Switch.run @@ fun sw ->
  (* A long running task *)
  Fiber.fork ~loc:__LOC__ ~sw (fun () -> traceln "stuck waiting :("; Promise.await p; traceln "Done");
  Fiber.both ~loc:__LOC__
    (fun () -> spawn ~clock 5 10)
    (fun () -> spawn ~clock 10 30);
  Promise.resolve r ()

let () =
  Eio_main.run @@ fun env ->
  Ctf.with_tracing @@ fun () ->
  let clock = Stdenv.clock env in
  main clock
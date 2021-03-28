let almost f = f -. Float.epsilon
let ( - ) = Int64.sub

let expect_pp_fixed pp_fixed s f =
  let result = Format.asprintf "%a" (fst pp_fixed) f in
  Alcotest.(check string) "Expected rendering" s result;
  Alcotest.(check int) "Expected length" (snd pp_fixed) (String.length result)

let test_percentage () =
  let expect = expect_pp_fixed Progress.Units.Percentage.pp_fixed in
  expect "  0%" (-0.1);
  expect "  0%" (almost 0.01);
  expect "  1%" 0.01;
  expect "  1%" (0.01 +. Float.epsilon);
  expect " 10%" 0.1;
  expect " 50%" 0.5;
  expect " 99%" 0.99;
  expect " 99%" (almost 1.);
  expect "100%" 1.;
  expect "100%" (1. +. Float.epsilon);
  expect "100%" 1.1;
  ()

let test_bytes () =
  let expect = expect_pp_fixed Progress.Units.Bytes.pp_fixed in
  let open Progress.Units.Bytes in
  expect "   0.0 B  " 0L;
  expect " 999.0 B  " 999L;
  expect "   1.0 KiB" (kib 1);
  expect "1023.0 KiB" (mib 1 - kib 1);
  expect "1023.9 KiB" (mib 1 - 1L);
  expect "   1.0 MiB" (mib 1);
  expect "   1.0 TiB" (tib 1);
  expect "   1.0 PiB" (pib 1);
  expect "   1.0 EiB" (pib 1024);
  ()

let test_seconds () =
  let pp ppf span =
    Progress.Units.seconds (fun ~width:_ pp_time -> pp_time ppf span)
  in
  let expect = expect_pp_fixed (pp, 5) in
  expect "00:00" (Mtime.Span.of_uint64_ns 0L);
  expect "00:29" (Mtime.Span.of_uint64_ns 29_600_000_000L);
  expect "00:30" (Mtime.Span.of_uint64_ns 30_000_000_000L);
  expect "00:30" (Mtime.Span.of_uint64_ns 30_400_000_000L);
  expect "00:59" (Mtime.Span.of_uint64_ns 59_600_000_000L);
  expect "01:00" (Mtime.Span.of_uint64_ns 60_000_000_000L);
  expect "01:00" (Mtime.Span.of_uint64_ns 60_400_000_000L);
  ()

let tests =
  Alcotest.
    [
      test_case "percentage" `Quick test_percentage;
      test_case "bytes" `Quick test_bytes;
      test_case "seconds" `Quick test_seconds;
    ]

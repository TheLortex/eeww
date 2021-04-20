type ecdsa = [
  | `P224 of Mirage_crypto_ec.P224.Dsa.priv
  | `P256 of Mirage_crypto_ec.P256.Dsa.priv
  | `P384 of Mirage_crypto_ec.P384.Dsa.priv
  | `P521 of Mirage_crypto_ec.P521.Dsa.priv
]

type t = [
  ecdsa
  | `RSA of Mirage_crypto_pk.Rsa.priv
  | `ED25519 of Mirage_crypto_ec.Ed25519.priv
]

let key_type = function
  | `RSA _ -> `RSA
  | `ED25519 _ -> `ED25519
  | `P224 _ -> `P224
  | `P256 _ -> `P256
  | `P384 _ -> `P384
  | `P521 _ -> `P521

let generate ?seed ?(bits = 4096) typ =
  let g = match seed with
    | None -> None
    | Some seed -> Some Mirage_crypto_rng.(create ~seed (module Fortuna))
  in
  match typ with
  | `RSA -> `RSA (Mirage_crypto_pk.Rsa.generate ?g ~bits ())
  | `ED25519 -> `ED25519 (fst (Mirage_crypto_ec.Ed25519.generate ?g ()))
  | `P224 -> `P224 (fst (Mirage_crypto_ec.P224.Dsa.generate ?g ()))
  | `P256 -> `P256 (fst (Mirage_crypto_ec.P256.Dsa.generate ?g ()))
  | `P384 -> `P384 (fst (Mirage_crypto_ec.P384.Dsa.generate ?g ()))
  | `P521 -> `P521 (fst (Mirage_crypto_ec.P521.Dsa.generate ?g ()))

let of_cstruct data =
  let open Rresult.R.Infix in
  let open Mirage_crypto_ec in
  let ec_err x = Rresult.R.error_to_msg ~pp_error:Mirage_crypto_ec.pp_error x in
  function
  | `RSA -> Error (`Msg "cannot decode an RSA key")
  | `ED25519 -> ec_err (Ed25519.priv_of_cstruct data) >>| fun k -> `ED25519 k
  | `P224 -> ec_err (P224.Dsa.priv_of_cstruct data) >>| fun k -> `P224 k
  | `P256 -> ec_err (P256.Dsa.priv_of_cstruct data) >>| fun k -> `P256 k
  | `P384 -> ec_err (P384.Dsa.priv_of_cstruct data) >>| fun k -> `P384 k
  | `P521 -> ec_err (P521.Dsa.priv_of_cstruct data) >>| fun k -> `P521 k

let public = function
  | `RSA priv -> `RSA (Mirage_crypto_pk.Rsa.pub_of_priv priv)
  | `ED25519 priv -> `ED25519 (Mirage_crypto_ec.Ed25519.pub_of_priv priv)
  | `P224 priv -> `P224 (Mirage_crypto_ec.P224.Dsa.pub_of_priv priv)
  | `P256 priv -> `P256 (Mirage_crypto_ec.P256.Dsa.pub_of_priv priv)
  | `P384 priv -> `P384 (Mirage_crypto_ec.P384.Dsa.pub_of_priv priv)
  | `P521 priv -> `P521 (Mirage_crypto_ec.P521.Dsa.pub_of_priv priv)

let sign hash ?(scheme = `PSS) key data =
  let open Mirage_crypto_ec in
  let open Rresult.R.Infix in
  let hashed () = Public_key.hashed hash data
  and ecdsa_to_cs s = Algorithm.ecdsa_sig_to_cstruct s
  in
  try
    match key with
    | `RSA key ->
      let open Mirage_crypto_pk in
      begin match scheme with
        | `PSS ->
          let module H = (val (Mirage_crypto.Hash.module_of hash)) in
          let module PSS = Rsa.PSS(H) in
          hashed () >>| fun d -> PSS.sign ~key (`Digest d)
        | `PKCS1 ->
          hashed () >>| fun d -> Rsa.PKCS1.sign ~key ~hash (`Digest d)
      end
    | `ED25519 key ->
      begin match data with
        | `Message m -> Ok (Ed25519.sign ~key m)
        | `Digest _ -> Error (`Msg "Ed25519 only suitable with raw message")
      end
    | `P224 key -> hashed () >>| fun d -> ecdsa_to_cs (P224.Dsa.sign ~key d)
    | `P256 key -> hashed () >>| fun d -> ecdsa_to_cs (P256.Dsa.sign ~key d)
    | `P384 key -> hashed () >>| fun d -> ecdsa_to_cs (P384.Dsa.sign ~key d)
    | `P521 key -> hashed () >>| fun d -> ecdsa_to_cs (P521.Dsa.sign ~key d)
  with
  | Mirage_crypto_pk.Rsa.Insufficient_key ->
    Error (`Msg "RSA key of insufficient length")
  | Message_too_long -> Error (`Msg "message too long")

let signature_scheme = function
  | `RSA _ -> `RSA
  | `ED25519 _ -> `ED25519
  | #ecdsa -> `ECDSA

module Asn = struct
  open Asn.S
  open Mirage_crypto_pk

  (* RSA *)
  let other_prime_infos =
    sequence_of @@
      (sequence3
        (required ~label:"prime"       integer)
        (required ~label:"exponent"    integer)
        (required ~label:"coefficient" integer))

  let rsa_private_key =
    let f (v, (n, (e, (d, (p, (q, (dp, (dq, (q', other))))))))) =
      match (v, other) with
      | (0, None) ->
        begin match Rsa.priv ~e ~d ~n ~p ~q ~dp ~dq ~q' with
          | Ok p -> p
          | Error (`Msg m) -> parse_error "bad RSA private key %s" m
        end
      | _         -> parse_error "multi-prime RSA keys not supported"
    and g { Rsa.e; d; n; p; q; dp; dq; q' } =
      (0, (n, (e, (d, (p, (q, (dp, (dq, (q', None))))))))) in
    map f g @@
    sequence @@
        (required ~label:"version"         int)
      @ (required ~label:"modulus"         integer)  (* n    *)
      @ (required ~label:"publicExponent"  integer)  (* e    *)
      @ (required ~label:"privateExponent" integer)  (* d    *)
      @ (required ~label:"prime1"          integer)  (* p    *)
      @ (required ~label:"prime2"          integer)  (* q    *)
      @ (required ~label:"exponent1"       integer)  (* dp   *)
      @ (required ~label:"exponent2"       integer)  (* dq   *)
      @ (required ~label:"coefficient"     integer)  (* qinv *)
     -@ (optional ~label:"otherPrimeInfos" other_prime_infos)

  (* For outside uses. *)
  let (rsa_private_of_cstruct, rsa_private_to_cstruct) =
    Asn_grammars.projections_of Asn.der rsa_private_key

  (* PKCS8 *)
  let (rsa_priv_of_cs, rsa_priv_to_cs) =
    Asn_grammars.project_exn rsa_private_key

  let ec_to_err = function
    | Ok x -> x
    | Error e -> parse_error "%a" Mirage_crypto_ec.pp_error e

  let ed25519_of_cs, ed25519_to_cs =
    Asn_grammars.project_exn octet_string

  let ec_private_key =
    let f (v, pk, nc, pub) =
      if v <> 1 then
        parse_error "bad version for ec Private key"
      else
        let curve = match nc with
          | Some c -> Some (Algorithm.curve_of_oid c)
          | None -> None
        in
        pk, curve, pub
    and g (pk, curve, pub) =
      let nc = match curve with
        | None -> None | Some c -> Some (Algorithm.curve_to_oid c)
      in
      (1, pk, nc, pub)
    in
    Asn.S.map f g @@
    sequence4
      (required ~label:"version" int) (* ecPrivkeyVer1(1) *)
      (required ~label:"privateKey" octet_string)
      (* from rfc5480: choice3, but only namedCurve is allowed in PKIX *)
      (optional ~label:"namedCurve" (explicit 0 oid))
      (optional ~label:"publicKey" (explicit 1 bit_string))

  let ec_of_cs, ec_to_cs =
    Asn_grammars.project_exn ec_private_key

  let reparse_ec_private curve priv =
    let open Mirage_crypto_ec in
    let open Rresult.R.Infix in
    match curve with
    | `SECP224R1 -> P224.Dsa.priv_of_cstruct priv >>| fun p -> `P224 p
    | `SECP256R1 -> P256.Dsa.priv_of_cstruct priv >>| fun p -> `P256 p
    | `SECP384R1 -> P384.Dsa.priv_of_cstruct priv >>| fun p -> `P384 p
    | `SECP521R1 -> P521.Dsa.priv_of_cstruct priv >>| fun p -> `P521 p

  (* external use (result) *)
  let ec_priv_of_cs =
    let open Rresult.R.Infix in
    let dec, _ = Asn_grammars.projections_of Asn.der ec_private_key in
    fun cs ->
      dec cs >>= fun (priv, curve, _pub) ->
      match curve with
      | None -> Error (`Parse "no curve provided")
      | Some c ->
        Rresult.R.(reword_error
                     (function `Msg e -> `Parse e)
                     (error_to_msg ~pp_error:Mirage_crypto_ec.pp_error
                        (reparse_ec_private c priv)))

  let ec_of_cs ?curve cs =
    let (priv, named_curve, _pub) = ec_of_cs cs in
    let nc =
      match curve, named_curve with
      | Some c, None -> c
      | None, Some c -> c
      | Some c, Some c' -> if c = c' then c else parse_error "conflicting curve"
      | None, None -> parse_error "unknown curve"
    in
    ec_to_err (reparse_ec_private nc priv)

  let ec_to_cs ?curve ?pub key = ec_to_cs (key, curve, pub)

  let reparse_private pk =
    match pk with
    | (0, Algorithm.RSA, cs) -> `RSA (rsa_priv_of_cs cs)
    | (0, Algorithm.ED25519, cs) ->
      let data = ed25519_of_cs cs in
      `ED25519 (ec_to_err (Mirage_crypto_ec.Ed25519.priv_of_cstruct data))
    | (0, Algorithm.EC_pub curve, cs) -> ec_of_cs ~curve cs
    | _ -> parse_error "unknown private key info"

  let unparse_private p =
    let open Mirage_crypto_ec in
    let open Algorithm in
    let alg, cs =
      match p with
      | `RSA pk -> RSA, rsa_priv_to_cs pk
      | `ED25519 pk -> ED25519, ed25519_to_cs (Ed25519.priv_to_cstruct pk)
      | `P224 pk -> EC_pub `SECP224R1, ec_to_cs (P224.Dsa.priv_to_cstruct pk)
      | `P256 pk -> EC_pub `SECP256R1, ec_to_cs (P256.Dsa.priv_to_cstruct pk)
      | `P384 pk -> EC_pub `SECP384R1, ec_to_cs (P384.Dsa.priv_to_cstruct pk)
      | `P521 pk -> EC_pub `SECP521R1, ec_to_cs (P521.Dsa.priv_to_cstruct pk)
    in
    (0, alg, cs)

  let private_key_info =
    map reparse_private unparse_private @@
    sequence3
      (required ~label:"version"             int)
      (required ~label:"privateKeyAlgorithm" Algorithm.identifier)
      (required ~label:"privateKey"          octet_string)
      (* TODO: there's an
         (optional ~label:"attributes" @@ implicit 0 (SET of Attributes)
         which are defined in X.501; but nobody seems to use them anyways *)

  let (private_of_cstruct, private_to_cstruct) =
    Asn_grammars.projections_of Asn.der private_key_info
end

let decode_der cs =
  Asn_grammars.err_to_msg (Asn.private_of_cstruct cs)

let encode_der = Asn.private_to_cstruct

let decode_pem cs =
  let open Rresult.R.Infix in
  Pem.parse cs >>= fun data ->
  let rsa_p (t, _) = String.equal "RSA PRIVATE KEY" t
  and ec_p (t, _) = String.equal "EC PRIVATE KEY" t
  and pk_p (t, _) = String.equal "PRIVATE KEY" t
  in
  let r, _ = List.partition rsa_p data
  and ec, _ = List.partition ec_p data
  and p, _ = List.partition pk_p data
  in
  Pem.foldM (fun (_, k) ->
      Asn_grammars.err_to_msg (Asn.rsa_private_of_cstruct k) >>| fun k ->
      `RSA k) r >>= fun k ->
  Pem.foldM (fun (_, k) ->
      Asn_grammars.err_to_msg (Asn.ec_priv_of_cs k)) ec >>= fun k' ->
  Pem.foldM (fun (_, k) ->
      Asn_grammars.err_to_msg (Asn.private_of_cstruct k)) p >>= fun k'' ->
  Pem.exactly_one ~what:"private key" (k @ k' @ k'')

let encode_pem p =
  Pem.unparse ~tag:"PRIVATE KEY" (Asn.private_to_cstruct p)

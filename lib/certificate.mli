
type certificate

type stack = certificate * certificate list

type host = [ `Strict of string | `Wildcard of string ]

val parse       : Cstruct.t -> certificate option
val parse_stack : Cstruct.t list -> stack option
val cs_of_cert  : certificate -> Cstruct.t
val asn_of_cert : certificate -> Asn_grammars.certificate

type certificate_failure =
  | InvalidCertificate
  | InvalidSignature
  | CertificateExpired
  | InvalidExtensions
  | InvalidPathlen
  | SelfSigned
  | NoTrustAnchor
  | InvalidInput
  | InvalidServerExtensions
  | InvalidServerName
  | InvalidCA

type key_type = [ `RSA | `DH | `ECDH | `ECDSA ]

val cert_type           : certificate -> key_type
val cert_usage          : certificate -> Asn_grammars.Extension.key_usage list option
val cert_extended_usage : certificate -> Asn_grammars.Extension.extended_key_usage list option

val verify_chain_of_trust :
  ?host:host -> ?time:float -> anchors:(certificate list) -> stack
  -> [ `Ok | `Fail of certificate_failure ]

val valid_cas : ?time:float -> certificate list -> certificate list

val common_name_to_string         : certificate -> string
val certificate_failure_to_string : certificate_failure -> string

open Sexplib
val certificate_of_sexp : Sexp.t -> certificate
val sexp_of_certificate : certificate -> Sexp.t

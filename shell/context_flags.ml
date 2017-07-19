#directory "+compiler-libs";;
#load "ocamlcommon.cma";;

let p = String.index Sys.ocaml_version '.' in
let ocaml_major = String.sub Sys.ocaml_version 0 p |> int_of_string in
let p = succ p in
let ocaml_minor = String.sub Sys.ocaml_version p (String.index_from Sys.ocaml_version p '.' - p) |> int_of_string in
match Sys.argv.(1) with
| "flags" ->
  if ocaml_major > 4 || ocaml_major = 4 && ocaml_minor >= 2 then
    Printf.printf "(-safe-string)"
| "compat" ->
  if ocaml_major < 4 || ocaml_major = 4 && ocaml_minor < 1 then begin
    Printf.eprintf "Unsupported version of OCaml: %d.%02d\n" ocaml_major ocaml_minor;
    exit 1
  end else if ocaml_major = 4 && ocaml_minor < 3 then
    Printf.printf "4.0%d" ocaml_minor
  else
    Printf.printf "4.03"
| _ ->
    Printf.eprintf "Unrecognised context instruction: %s\n" Sys.argv.(1);
    exit 1

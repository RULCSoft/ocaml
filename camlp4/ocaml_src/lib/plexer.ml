(* camlp4r *)
(***********************************************************************)
(*                                                                     *)
(*                             Camlp4                                  *)
(*                                                                     *)
(*        Daniel de Rauglaudre, projet Cristal, INRIA Rocquencourt     *)
(*                                                                     *)
(*  Copyright 2002 Institut National de Recherche en Informatique et   *)
(*  Automatique.  Distributed only by permission.                      *)
(*                                                                     *)
(***********************************************************************)

(* $Id: plexer.ml,v 1.16 2003/07/15 09:13:59 mauny Exp $ *)

open Stdpp
open Token

let no_quotations = ref false

(* The string buffering machinery *)

let buff = ref (String.create 80)
let store len x =
  if len >= String.length !buff then
    buff := !buff ^ String.create (String.length !buff);
  !buff.[len] <- x;
  succ len
let mstore len s =
  let rec add_rec len i =
    if i == String.length s then len else add_rec (store len s.[i]) (succ i)
  in
  add_rec len 0
let get_buff len = String.sub !buff 0 len

(* The lexer *)

let stream_peek_nth n strm =
  let rec loop n =
    function
      [] -> None
    | [x] -> if n == 1 then Some x else None
    | _ :: l -> loop (n - 1) l
  in
  loop n (Stream.npeek n strm)

let rec ident len (strm__ : _ Stream.t) =
  match Stream.peek strm__ with
    Some
      ('A'..'Z' | 'a'..'z' | '\192'..'\214' | '\216'..'\246' |
       '\248'..'\255' | '0'..'9' | '_' | '\'' as c) ->
      Stream.junk strm__; ident (store len c) strm__
  | _ -> len
and ident2 len (strm__ : _ Stream.t) =
  match Stream.peek strm__ with
    Some
      ('!' | '?' | '~' | '=' | '@' | '^' | '&' | '+' | '-' | '*' | '/' | '%' |
       '.' | ':' | '<' | '>' | '|' | '$' as c) ->
      Stream.junk strm__; ident2 (store len c) strm__
  | _ -> len
and ident3 len (strm__ : _ Stream.t) =
  match Stream.peek strm__ with
    Some
      ('0'..'9' | 'A'..'Z' | 'a'..'z' | '\192'..'\214' | '\216'..'\246' |
       '\248'..'\255' | '_' | '!' | '%' | '&' | '*' | '+' | '-' | '.' | '/' |
       ':' | '<' | '=' | '>' | '?' | '@' | '^' | '|' | '~' | '\'' | '$' as c
         ) ->
      Stream.junk strm__; ident3 (store len c) strm__
  | _ -> len
and base_number len (strm__ : _ Stream.t) =
  match Stream.peek strm__ with
    Some ('o' | 'O') ->
      Stream.junk strm__; digits octal (store len 'o') strm__
  | Some ('x' | 'X') -> Stream.junk strm__; digits hexa (store len 'x') strm__
  | Some ('b' | 'B') ->
      Stream.junk strm__; digits binary (store len 'b') strm__
  | _ -> number len strm__
and digits kind len (strm__ : _ Stream.t) =
  let d =
    try kind strm__ with
      Stream.Failure -> raise (Stream.Error "ill-formed integer constant")
  in
  digits_under kind (store len d) strm__
and digits_under kind len (strm__ : _ Stream.t) =
  match
    try Some (kind strm__) with
      Stream.Failure -> None
  with
    Some d -> digits_under kind (store len d) strm__
  | _ ->
      match Stream.peek strm__ with
        Some '_' -> Stream.junk strm__; digits_under kind len strm__
      | _ -> "INT", get_buff len
and octal (strm__ : _ Stream.t) =
  match Stream.peek strm__ with
    Some ('0'..'7' as d) -> Stream.junk strm__; d
  | _ -> raise Stream.Failure
and hexa (strm__ : _ Stream.t) =
  match Stream.peek strm__ with
    Some ('0'..'9' | 'a'..'f' | 'A'..'F' as d) -> Stream.junk strm__; d
  | _ -> raise Stream.Failure
and binary (strm__ : _ Stream.t) =
  match Stream.peek strm__ with
    Some ('0'..'1' as d) -> Stream.junk strm__; d
  | _ -> raise Stream.Failure
and number len (strm__ : _ Stream.t) =
  match Stream.peek strm__ with
    Some ('0'..'9' as c) -> Stream.junk strm__; number (store len c) strm__
  | Some '_' -> Stream.junk strm__; number len strm__
  | Some '.' -> Stream.junk strm__; decimal_part (store len '.') strm__
  | Some ('e' | 'E') ->
      Stream.junk strm__; exponent_part (store len 'E') strm__
  | Some 'l' -> Stream.junk strm__; "INT32", get_buff len
  | Some 'L' -> Stream.junk strm__; "INT64", get_buff len
  | Some 'n' -> Stream.junk strm__; "NATIVEINT", get_buff len
  | _ -> "INT", get_buff len
and decimal_part len (strm__ : _ Stream.t) =
  match Stream.peek strm__ with
    Some ('0'..'9' as c) ->
      Stream.junk strm__; decimal_part (store len c) strm__
  | Some '_' -> Stream.junk strm__; decimal_part len strm__
  | Some ('e' | 'E') ->
      Stream.junk strm__; exponent_part (store len 'E') strm__
  | _ -> "FLOAT", get_buff len
and exponent_part len (strm__ : _ Stream.t) =
  match Stream.peek strm__ with
    Some ('+' | '-' as c) ->
      Stream.junk strm__; end_exponent_part (store len c) strm__
  | _ -> end_exponent_part len strm__
and end_exponent_part len (strm__ : _ Stream.t) =
  match Stream.peek strm__ with
    Some ('0'..'9' as c) ->
      Stream.junk strm__; end_exponent_part_under (store len c) strm__
  | _ -> raise (Stream.Error "ill-formed floating-point constant")
and end_exponent_part_under len (strm__ : _ Stream.t) =
  match Stream.peek strm__ with
    Some ('0'..'9' as c) ->
      Stream.junk strm__; end_exponent_part_under (store len c) strm__
  | Some '_' -> Stream.junk strm__; end_exponent_part_under len strm__
  | _ -> "FLOAT", get_buff len

let error_on_unknown_keywords = ref false
let err loc msg = raise_with_loc loc (Token.Error msg)

(*
value next_token_fun dfa find_kwd =
  let keyword_or_error loc s =
    try (("", find_kwd s), loc) with
    [ Not_found ->
        if error_on_unknown_keywords.val then err loc ("illegal token: " ^ s)
        else (("", s), loc) ]
  in
  let rec next_token =
    parser bp
    [ [: `' ' | '\010' | '\013' | '\t' | '\026' | '\012'; s :] ->
        next_token s
    | [: `'('; s :] -> left_paren bp s
    | [: `'#'; s :] -> do { spaces_tabs s; linenum bp s }
    | [: `('A'..'Z' | '\192'..'\214' | '\216'..'\222' as c); s :] ->
        let id = get_buff (ident (store 0 c) s) in
        let loc = (bp, Stream.count s) in
        (try ("", find_kwd id) with [ Not_found -> ("UIDENT", id) ], loc)
    | [: `('a'..'z' | '\223'..'\246' | '\248'..'\255' | '_' as c); s :] ->
        let id = get_buff (ident (store 0 c) s) in
        let loc = (bp, Stream.count s) in
        (try ("", find_kwd id) with [ Not_found -> ("LIDENT", id) ], loc)
    | [: `('1'..'9' as c); s :] ->
        let tok = number (store 0 c) s in
        let loc = (bp, Stream.count s) in
        (tok, loc)
    | [: `'0'; s :] ->
        let tok = base_number (store 0 '0') s in
        let loc = (bp, Stream.count s) in
        (tok, loc)
    | [: `'''; s :] ->
        match Stream.npeek 3 s with
        [ [_; '''; _] | ['\\'; _; _] | ['\x0D'; '\x0A'; '''] ->
            let tok = ("CHAR", get_buff (char bp 0 s)) in
            let loc = (bp, Stream.count s) in
            (tok, loc)
        | _ -> keyword_or_error (bp, Stream.count s) "'" ]
    | [: `'"'; s :] ->
        let tok = ("STRING", get_buff (string bp 0 s)) in
        let loc = (bp, Stream.count s) in
        (tok, loc)
    | [: `'$'; s :] ->
        let tok = dollar bp 0 s in
        let loc = (bp, Stream.count s) in
        (tok, loc)
    | [: `('!' | '=' | '@' | '^' | '&' | '+' | '-' | '*' | '/' | '%' as c);
         s :] ->
        let id = get_buff (ident2 (store 0 c) s) in
        keyword_or_error (bp, Stream.count s) id
    | [: `('~' as c);
         a =
           parser
           [ [: `('a'..'z' as c); len = ident (store 0 c) :] ep ->
               (("TILDEIDENT", get_buff len), (bp, ep))
           | [: s :] ->
               let id = get_buff (ident2 (store 0 c) s) in
               keyword_or_error (bp, Stream.count s) id ] :] ->
        a
    | [: `('?' as c);
         a =
           parser
           [ [: `('a'..'z' as c); len = ident (store 0 c) :] ep ->
               (("QUESTIONIDENT", get_buff len), (bp, ep))
           | [: s :] ->
               let id = get_buff (ident2 (store 0 c) s) in
               keyword_or_error (bp, Stream.count s) id ] :] ->
        a
    | [: `'<'; s :] -> less bp s
    | [: `(':' as c1);
         len =
           parser
           [ [: `(']' | ':' | '=' | '>' as c2) :] -> store (store 0 c1) c2
           | [: :] -> store 0 c1 ] :] ep ->
        let id = get_buff len in
        keyword_or_error (bp, ep) id
    | [: `('>' | '|' as c1);
         len =
           parser
           [ [: `(']' | '}' as c2) :] -> store (store 0 c1) c2
           | [: a = ident2 (store 0 c1) :] -> a ] :] ep ->
        let id = get_buff len in
        keyword_or_error (bp, ep) id
    | [: `('[' | '{' as c1); s :] ->
        let len =
          match Stream.npeek 2 s with
          [ ['<'; '<' | ':'] -> store 0 c1
          | _ ->
              match s with parser
              [ [: `('|' | '<' | ':' as c2) :] -> store (store 0 c1) c2
              | [: :] -> store 0 c1 ] ]
        in
        let ep = Stream.count s in
        let id = get_buff len in
        keyword_or_error (bp, ep) id
    | [: `'.';
         id =
           parser
           [ [: `'.' :] -> ".."
           | [: :] -> if ssd && after_space then " ." else "." ] :] ep ->
        keyword_or_error (bp, ep) id
    | [: `';';
         id =
           parser
           [ [: `';' :] -> ";;"
           | [: :] -> ";" ] :] ep ->
        keyword_or_error (bp, ep) id
    | [: `'\\'; s :] ep -> (("LIDENT", get_buff (ident3 0 s)), (bp, ep))
    | [: `c :] ep -> keyword_or_error (bp, ep) (String.make 1 c)
    | [: _ = Stream.empty :] -> (("EOI", ""), (bp, succ bp)) ]
  and less bp strm =
    if no_quotations.val then
      match strm with parser
      [ [: len = ident2 (store 0 '<') :] ep ->
          let id = get_buff len in
          keyword_or_error (bp, ep) id ]
    else
      match strm with parser
      [ [: `'<'; len = quotation bp 0 :] ep ->
          (("QUOTATION", ":" ^ get_buff len), (bp, ep))
      | [: `':'; i = parser [: len = ident 0 :] -> get_buff len;
           `'<' ? "character '<' expected"; len = quotation bp 0 :] ep ->
          (("QUOTATION", i ^ ":" ^ get_buff len), (bp, ep))
      | [: len = ident2 (store 0 '<') :] ep ->
          let id = get_buff len in
          keyword_or_error (bp, ep) id ]
  and string bp len =
    parser
    [ [: `'"' :] -> len
    | [: `'\\'; `c; s :] -> string bp (store (store len '\\') c) s
    | [: `c; s :] -> string bp (store len c) s
    | [: :] ep -> err (bp, ep) "string not terminated" ]
  and char bp len =
    parser
    [ [: `'''; s :] -> if len = 0 then char bp (store len ''') s else len
    | [: `'\\'; `c; s :] -> char bp (store (store len '\\') c) s
    | [: `c; s :] -> char bp (store len c) s
    | [: :] ep -> err (bp, ep) "char not terminated" ]
  and dollar bp len =
    parser
    [ [: `'$' :] -> ("ANTIQUOT", ":" ^ get_buff len)
    | [: `('a'..'z' | 'A'..'Z' as c); s :] -> antiquot bp (store len c) s
    | [: `('0'..'9' as c); s :] -> maybe_locate bp (store len c) s
    | [: `':'; s :] ->
        let k = get_buff len in
        ("ANTIQUOT", k ^ ":" ^ locate_or_antiquot_rest bp 0 s)
    | [: `'\\'; `c; s :] ->
        ("ANTIQUOT", ":" ^ locate_or_antiquot_rest bp (store len c) s)
    | [: s :] ->
        if dfa then
          match s with parser
          [ [: `c :] ->
              ("ANTIQUOT", ":" ^ locate_or_antiquot_rest bp (store len c) s)
          | [: :] ep -> err (bp, ep) "antiquotation not terminated" ]
        else ("", get_buff (ident2 (store 0 '$') s)) ]
  and maybe_locate bp len =
    parser
    [ [: `'$' :] -> ("ANTIQUOT", ":" ^ get_buff len)
    | [: `('0'..'9' as c); s :] -> maybe_locate bp (store len c) s
    | [: `':'; s :] ->
        ("LOCATE", get_buff len ^ ":" ^ locate_or_antiquot_rest bp 0 s)
    | [: `'\\'; `c; s :] ->
        ("ANTIQUOT", ":" ^ locate_or_antiquot_rest bp (store len c) s)
    | [: `c; s :] ->
        ("ANTIQUOT", ":" ^ locate_or_antiquot_rest bp (store len c) s)
    | [: :] ep -> err (bp, ep) "antiquotation not terminated" ]
  and antiquot bp len =
    parser
    [ [: `'$' :] -> ("ANTIQUOT", ":" ^ get_buff len)
    | [: `('a'..'z' | 'A'..'Z' | '0'..'9' as c); s :] ->
        antiquot bp (store len c) s
    | [: `':'; s :] ->
        let k = get_buff len in
        ("ANTIQUOT", k ^ ":" ^ locate_or_antiquot_rest bp 0 s)
    | [: `'\\'; `c; s :] ->
        ("ANTIQUOT", ":" ^ locate_or_antiquot_rest bp (store len c) s)
    | [: `c; s :] ->
        ("ANTIQUOT", ":" ^ locate_or_antiquot_rest bp (store len c) s)
    | [: :] ep -> err (bp, ep) "antiquotation not terminated" ]
  and locate_or_antiquot_rest bp len =
    parser
    [ [: `'$' :] -> get_buff len
    | [: `'\\'; `c; s :] -> locate_or_antiquot_rest bp (store len c) s
    | [: `c; s :] -> locate_or_antiquot_rest bp (store len c) s
    | [: :] ep -> err (bp, ep) "antiquotation not terminated" ]
  and quotation bp len =
    parser
    [ [: `'>'; s :] -> maybe_end_quotation bp len s
    | [: `'<'; s :] ->
        quotation bp (maybe_nested_quotation bp (store len '<') s) s
    | [: `'\\';
         len =
           parser
           [ [: `('>' | '<' | '\\' as c) :] -> store len c
           | [: :] -> store len '\\' ];
         s :] ->
        quotation bp len s
    | [: `c; s :] -> quotation bp (store len c) s
    | [: :] ep -> err (bp, ep) "quotation not terminated" ]
  and maybe_nested_quotation bp len =
    parser
    [ [: `'<'; s :] -> mstore (quotation bp (store len '<') s) ">>"
    | [: `':'; len = ident (store len ':');
         a =
           parser
           [ [: `'<'; s :] -> mstore (quotation bp (store len '<') s) ">>"
           | [: :] -> len ] :] ->
        a
    | [: :] -> len ]
  and maybe_end_quotation bp len =
    parser
    [ [: `'>' :] -> len
    | [: a = quotation bp (store len '>') :] -> a ]
  and left_paren bp =
    parser
    [ [: `'*'; _ = comment bp; a = next_token True :] -> a
    | [: :] ep -> keyword_or_error (bp, ep) "(" ]
  and comment bp =
    parser
    [ [: `'('; s :] -> left_paren_in_comment bp s
    | [: `'*'; s :] -> star_in_comment bp s
    | [: `'"'; _ = string bp 0; s :] -> comment bp s
    | [: `'''; s :] -> quote_in_comment bp s
    | [: `c; s :] -> comment bp s
    | [: :] ep -> err (bp, ep) "comment not terminated" ]
  and quote_in_comment bp =
    parser
    [ [: `'''; s :] -> comment bp s
    | [: `'\013'; s :] -> quote_cr_in_comment bp s
    | [: `'\\'; s :] -> quote_antislash_in_comment bp s
    | [: `'('; s :] -> quote_left_paren_in_comment bp s
    | [: `'*'; s :] -> quote_star_in_comment bp s
    | [: `'"'; s :] -> quote_doublequote_in_comment bp s
    | [: `_; s :] -> quote_any_in_comment bp s
    | [: s :] -> comment bp s ]
  and quote_any_in_comment bp =
    parser
    [ [: `'''; s :] -> comment bp s
    | [: s :] -> comment bp s ]
  and quote_cr_in_comment bp =
    parser
    [ [: `'\010'; s :] -> quote_any_in_comment bp s
    | [: s :] -> quote_any_in_comment bp s ]
  and quote_left_paren_in_comment bp =
    parser
    [ [: `'''; s :] -> comment bp s
    | [: s :] -> left_paren_in_comment bp s ]
  and quote_star_in_comment bp =
    parser
    [ [: `'''; s :] -> comment bp s
    | [: s :] -> star_in_comment bp s ]
  and quote_doublequote_in_comment bp =
    parser
    [ [: `'''; s :] -> comment bp s
    | [: _ = string bp 0; s :] -> comment bp s ]
  and quote_antislash_in_comment bp =
    parser
    [ [: `'''; s :] -> quote_antislash_quote_in_comment bp s
    | [: `('\\' | '"' | 'n' | 't' | 'b' | 'r'); s :] ->
        quote_any_in_comment bp s
    | [: `('0'..'9'); s :] -> quote_antislash_digit_in_comment bp s
    | [: `'x'; s :] -> quote_antislash_x_in_comment bp s
    | [: s :] -> comment bp s ]
  and quote_antislash_quote_in_comment bp =
    parser
    [ [: `'''; s :] -> comment bp s
    | [: s :] -> quote_in_comment bp s ]
  and quote_antislash_digit_in_comment bp =
    parser
    [ [: `('0'..'9'); s :] -> quote_antislash_digit2_in_comment bp s
    | [: s :] -> comment bp s ]
  and quote_antislash_digit2_in_comment bp =
    parser
    [ [: `('0'..'9'); s :] -> quote_any_in_comment bp s
    | [: s :] -> comment bp s ]
  and quote_antislash_x_in_comment bp =
    parser
    [ [: _ = hexa; s :] -> quote_antislash_x_digit_in_comment bp s
    | [: s :] -> comment bp s ]
  and quote_antislash_x_digit_in_comment bp =
    parser
    [ [: _ = hexa; s :] -> quote_any_in_comment bp s
    | [: s :] -> comment bp s ]
  and left_paren_in_comment bp =
    parser
    [ [: `'*'; s :] -> do { comment bp s; comment bp s }
    | [: a = comment bp :] -> a ]
  and star_in_comment bp =
    parser
    [ [: `')' :] -> ()
    | [: a = comment bp :] -> a ]
  and linedir n s =
    match stream_peek_nth n s with
    [ Some (' ' | '\t') -> linedir (n + 1) s
    | Some ('0'..'9') -> linedir_digits (n + 1) s
    | _ -> False ]
  and linedir_digits n s =
    match stream_peek_nth n s with
    [ Some ('0'..'9') -> linedir_digits (n + 1) s
    | _ -> linedir_quote n s ]
  and linedir_quote n s =
    match stream_peek_nth n s with
    [ Some (' ' | '\t') -> linedir_quote (n + 1) s
    | Some '"' -> True
    | _ -> False ]
  and any_to_nl =
    parser
    [ [: `'\013' | '\010' :] ep -> bolpos.val := ep
    | [: `_; s :] -> any_to_nl s
    | [: :] -> () ]
  in
  fun cstrm ->
    try
      let glex = glexr.val in
      let comm_bp = Stream.count cstrm in
      let r = next_token False cstrm in
      do {
        match glex.tok_comm with
        [ Some list ->
            if fst (snd r) > comm_bp then
              let comm_loc = (comm_bp, fst (snd r)) in
              glex.tok_comm := Some [comm_loc :: list]
            else ()
        | None -> () ];
        r
      }
    with
    [ Stream.Error str ->
        err (Stream.count cstrm, Stream.count cstrm + 1) str ]
;
*)

let next_token_fun dfa ssd find_kwd bolpos glexr =
  let keyword_or_error loc s =
    try ("", find_kwd s), loc with
      Not_found ->
        if !error_on_unknown_keywords then err loc ("illegal token: " ^ s)
        else ("", s), loc
  in
  let rec next_token after_space (strm__ : _ Stream.t) =
    let bp = Stream.count strm__ in
    match Stream.peek strm__ with
      Some ('\010' | '\013') ->
        Stream.junk strm__;
        let s = strm__ in
        let ep = Stream.count strm__ in bolpos := ep; next_token true s
    | Some (' ' | '\t' | '\026' | '\012') ->
        Stream.junk strm__; next_token true strm__
    | Some '#' when bp = !bolpos ->
        Stream.junk strm__;
        let s = strm__ in
        if linedir 1 s then begin any_to_nl s; next_token true s end
        else keyword_or_error (bp, bp + 1) "#"
    | Some '(' -> Stream.junk strm__; left_paren bp strm__
    | Some ('A'..'Z' | '\192'..'\214' | '\216'..'\222' as c) ->
        Stream.junk strm__;
        let s = strm__ in
        let id = get_buff (ident (store 0 c) s) in
        let loc = bp, Stream.count s in
        (try "", find_kwd id with
           Not_found -> "UIDENT", id),
        loc
    | Some ('a'..'z' | '\223'..'\246' | '\248'..'\255' | '_' as c) ->
        Stream.junk strm__;
        let s = strm__ in
        let id = get_buff (ident (store 0 c) s) in
        let loc = bp, Stream.count s in
        (try "", find_kwd id with
           Not_found -> "LIDENT", id),
        loc
    | Some ('1'..'9' as c) ->
        Stream.junk strm__;
        let tok = number (store 0 c) strm__ in
        let loc = bp, Stream.count strm__ in tok, loc
    | Some '0' ->
        Stream.junk strm__;
        let tok = base_number (store 0 '0') strm__ in
        let loc = bp, Stream.count strm__ in tok, loc
    | Some '\'' ->
        Stream.junk strm__;
        let s = strm__ in
        begin match Stream.npeek 2 s with
          [_; '\''] | ['\\'; _] ->
            let tok = "CHAR", get_buff (char bp 0 s) in
            let loc = bp, Stream.count s in tok, loc
        | _ -> keyword_or_error (bp, Stream.count s) "'"
        end
    | Some '\"' ->
        Stream.junk strm__;
        let tok = "STRING", get_buff (string bp 0 strm__) in
        let loc = bp, Stream.count strm__ in tok, loc
    | Some '$' ->
        Stream.junk strm__;
        let tok = dollar bp 0 strm__ in
        let loc = bp, Stream.count strm__ in tok, loc
    | Some ('!' | '=' | '@' | '^' | '&' | '+' | '-' | '*' | '/' | '%' as c) ->
        Stream.junk strm__;
        let id = get_buff (ident2 (store 0 c) strm__) in
        keyword_or_error (bp, Stream.count strm__) id
    | Some ('~' as c) ->
        Stream.junk strm__;
        begin try
          match Stream.peek strm__ with
            Some ('a'..'z' as c) ->
              Stream.junk strm__;
              let len =
                try ident (store 0 c) strm__ with
                  Stream.Failure -> raise (Stream.Error "")
              in
              let ep = Stream.count strm__ in
              ("TILDEIDENT", get_buff len), (bp, ep)
          | _ ->
              let id = get_buff (ident2 (store 0 c) strm__) in
              keyword_or_error (bp, Stream.count strm__) id
        with
          Stream.Failure -> raise (Stream.Error "")
        end
    | Some ('?' as c) ->
        Stream.junk strm__;
        begin try
          match Stream.peek strm__ with
            Some ('a'..'z' as c) ->
              Stream.junk strm__;
              let len =
                try ident (store 0 c) strm__ with
                  Stream.Failure -> raise (Stream.Error "")
              in
              let ep = Stream.count strm__ in
              ("QUESTIONIDENT", get_buff len), (bp, ep)
          | _ ->
              let id = get_buff (ident2 (store 0 c) strm__) in
              keyword_or_error (bp, Stream.count strm__) id
        with
          Stream.Failure -> raise (Stream.Error "")
        end
    | Some '<' -> Stream.junk strm__; less bp strm__
    | Some (':' as c1) ->
        Stream.junk strm__;
        let len =
          try
            match Stream.peek strm__ with
              Some (']' | ':' | '=' | '>' as c2) ->
                Stream.junk strm__; store (store 0 c1) c2
            | _ -> store 0 c1
          with
            Stream.Failure -> raise (Stream.Error "")
        in
        let ep = Stream.count strm__ in
        let id = get_buff len in keyword_or_error (bp, ep) id
    | Some ('>' | '|' as c1) ->
        Stream.junk strm__;
        let len =
          try
            match Stream.peek strm__ with
              Some (']' | '}' as c2) ->
                Stream.junk strm__; store (store 0 c1) c2
            | _ -> ident2 (store 0 c1) strm__
          with
            Stream.Failure -> raise (Stream.Error "")
        in
        let ep = Stream.count strm__ in
        let id = get_buff len in keyword_or_error (bp, ep) id
    | Some ('[' | '{' as c1) ->
        Stream.junk strm__;
        let s = strm__ in
        let len =
          match Stream.npeek 2 s with
            ['<'; '<' | ':'] -> store 0 c1
          | _ ->
              let (strm__ : _ Stream.t) = s in
              match Stream.peek strm__ with
                Some ('|' | '<' | ':' as c2) ->
                  Stream.junk strm__; store (store 0 c1) c2
              | _ -> store 0 c1
        in
        let ep = Stream.count s in
        let id = get_buff len in keyword_or_error (bp, ep) id
    | Some '.' ->
        Stream.junk strm__;
        let id =
          try
            match Stream.peek strm__ with
              Some '.' -> Stream.junk strm__; ".."
            | _ -> if ssd && after_space then " ." else "."
          with
            Stream.Failure -> raise (Stream.Error "")
        in
        let ep = Stream.count strm__ in keyword_or_error (bp, ep) id
    | Some ';' ->
        Stream.junk strm__;
        let id =
          try
            match Stream.peek strm__ with
              Some ';' -> Stream.junk strm__; ";;"
            | _ -> ";"
          with
            Stream.Failure -> raise (Stream.Error "")
        in
        let ep = Stream.count strm__ in keyword_or_error (bp, ep) id
    | Some '\\' ->
        Stream.junk strm__;
        let ep = Stream.count strm__ in
        ("LIDENT", get_buff (ident3 0 strm__)), (bp, ep)
    | Some c ->
        Stream.junk strm__;
        let ep = Stream.count strm__ in
        keyword_or_error (bp, ep) (String.make 1 c)
    | _ -> let _ = Stream.empty strm__ in ("EOI", ""), (bp, succ bp)
  and less bp strm =
    if !no_quotations then
      let (strm__ : _ Stream.t) = strm in
      let len = ident2 (store 0 '<') strm__ in
      let ep = Stream.count strm__ in
      let id = get_buff len in keyword_or_error (bp, ep) id
    else
      let (strm__ : _ Stream.t) = strm in
      match Stream.peek strm__ with
        Some '<' ->
          Stream.junk strm__;
          let len =
            try quotation bp 0 strm__ with
              Stream.Failure -> raise (Stream.Error "")
          in
          let ep = Stream.count strm__ in
          ("QUOTATION", ":" ^ get_buff len), (bp, ep)
      | Some ':' ->
          Stream.junk strm__;
          let i =
            try let len = ident 0 strm__ in get_buff len with
              Stream.Failure -> raise (Stream.Error "")
          in
          begin match Stream.peek strm__ with
            Some '<' ->
              Stream.junk strm__;
              let len =
                try quotation bp 0 strm__ with
                  Stream.Failure -> raise (Stream.Error "")
              in
              let ep = Stream.count strm__ in
              ("QUOTATION", i ^ ":" ^ get_buff len), (bp, ep)
          | _ -> raise (Stream.Error "character '<' expected")
          end
      | _ ->
          let len = ident2 (store 0 '<') strm__ in
          let ep = Stream.count strm__ in
          let id = get_buff len in keyword_or_error (bp, ep) id
  and string bp len (strm__ : _ Stream.t) =
    match Stream.peek strm__ with
      Some '\"' -> Stream.junk strm__; len
    | Some '\\' ->
        Stream.junk strm__;
        begin match Stream.peek strm__ with
          Some c ->
            Stream.junk strm__; string bp (store (store len '\\') c) strm__
        | _ -> raise (Stream.Error "")
        end
    | Some c -> Stream.junk strm__; string bp (store len c) strm__
    | _ ->
        let ep = Stream.count strm__ in err (bp, ep) "string not terminated"
  and char bp len (strm__ : _ Stream.t) =
    match Stream.peek strm__ with
      Some '\'' ->
        Stream.junk strm__;
        let s = strm__ in if len = 0 then char bp (store len '\'') s else len
    | Some '\\' ->
        Stream.junk strm__;
        begin match Stream.peek strm__ with
          Some c ->
            Stream.junk strm__; char bp (store (store len '\\') c) strm__
        | _ -> raise (Stream.Error "")
        end
    | Some c -> Stream.junk strm__; char bp (store len c) strm__
    | _ -> let ep = Stream.count strm__ in err (bp, ep) "char not terminated"
  and dollar bp len (strm__ : _ Stream.t) =
    match Stream.peek strm__ with
      Some '$' -> Stream.junk strm__; "ANTIQUOT", ":" ^ get_buff len
    | Some ('a'..'z' | 'A'..'Z' as c) ->
        Stream.junk strm__; antiquot bp (store len c) strm__
    | Some ('0'..'9' as c) ->
        Stream.junk strm__; maybe_locate bp (store len c) strm__
    | Some ':' ->
        Stream.junk strm__;
        let k = get_buff len in
        "ANTIQUOT", k ^ ":" ^ locate_or_antiquot_rest bp 0 strm__
    | Some '\\' ->
        Stream.junk strm__;
        begin match Stream.peek strm__ with
          Some c ->
            Stream.junk strm__;
            "ANTIQUOT", ":" ^ locate_or_antiquot_rest bp (store len c) strm__
        | _ -> raise (Stream.Error "")
        end
    | _ ->
        let s = strm__ in
        if dfa then
          let (strm__ : _ Stream.t) = s in
          match Stream.peek strm__ with
            Some c ->
              Stream.junk strm__;
              "ANTIQUOT", ":" ^ locate_or_antiquot_rest bp (store len c) s
          | _ ->
              let ep = Stream.count strm__ in
              err (bp, ep) "antiquotation not terminated"
        else "", get_buff (ident2 (store 0 '$') s)
  and maybe_locate bp len (strm__ : _ Stream.t) =
    match Stream.peek strm__ with
      Some '$' -> Stream.junk strm__; "ANTIQUOT", ":" ^ get_buff len
    | Some ('0'..'9' as c) ->
        Stream.junk strm__; maybe_locate bp (store len c) strm__
    | Some ':' ->
        Stream.junk strm__;
        "LOCATE", get_buff len ^ ":" ^ locate_or_antiquot_rest bp 0 strm__
    | Some '\\' ->
        Stream.junk strm__;
        begin match Stream.peek strm__ with
          Some c ->
            Stream.junk strm__;
            "ANTIQUOT", ":" ^ locate_or_antiquot_rest bp (store len c) strm__
        | _ -> raise (Stream.Error "")
        end
    | Some c ->
        Stream.junk strm__;
        "ANTIQUOT", ":" ^ locate_or_antiquot_rest bp (store len c) strm__
    | _ ->
        let ep = Stream.count strm__ in
        err (bp, ep) "antiquotation not terminated"
  and antiquot bp len (strm__ : _ Stream.t) =
    match Stream.peek strm__ with
      Some '$' -> Stream.junk strm__; "ANTIQUOT", ":" ^ get_buff len
    | Some ('a'..'z' | 'A'..'Z' | '0'..'9' as c) ->
        Stream.junk strm__; antiquot bp (store len c) strm__
    | Some ':' ->
        Stream.junk strm__;
        let k = get_buff len in
        "ANTIQUOT", k ^ ":" ^ locate_or_antiquot_rest bp 0 strm__
    | Some '\\' ->
        Stream.junk strm__;
        begin match Stream.peek strm__ with
          Some c ->
            Stream.junk strm__;
            "ANTIQUOT", ":" ^ locate_or_antiquot_rest bp (store len c) strm__
        | _ -> raise (Stream.Error "")
        end
    | Some c ->
        Stream.junk strm__;
        "ANTIQUOT", ":" ^ locate_or_antiquot_rest bp (store len c) strm__
    | _ ->
        let ep = Stream.count strm__ in
        err (bp, ep) "antiquotation not terminated"
  and locate_or_antiquot_rest bp len (strm__ : _ Stream.t) =
    match Stream.peek strm__ with
      Some '$' -> Stream.junk strm__; get_buff len
    | Some '\\' ->
        Stream.junk strm__;
        begin match Stream.peek strm__ with
          Some c ->
            Stream.junk strm__;
            locate_or_antiquot_rest bp (store len c) strm__
        | _ -> raise (Stream.Error "")
        end
    | Some c ->
        Stream.junk strm__; locate_or_antiquot_rest bp (store len c) strm__
    | _ ->
        let ep = Stream.count strm__ in
        err (bp, ep) "antiquotation not terminated"
  and quotation bp len (strm__ : _ Stream.t) =
    match Stream.peek strm__ with
      Some '>' -> Stream.junk strm__; maybe_end_quotation bp len strm__
    | Some '<' ->
        Stream.junk strm__;
        quotation bp (maybe_nested_quotation bp (store len '<') strm__) strm__
    | Some '\\' ->
        Stream.junk strm__;
        let len =
          try
            match Stream.peek strm__ with
              Some ('>' | '<' | '\\' as c) -> Stream.junk strm__; store len c
            | _ -> store len '\\'
          with
            Stream.Failure -> raise (Stream.Error "")
        in
        quotation bp len strm__
    | Some c -> Stream.junk strm__; quotation bp (store len c) strm__
    | _ ->
        let ep = Stream.count strm__ in
        err (bp, ep) "quotation not terminated"
  and maybe_nested_quotation bp len (strm__ : _ Stream.t) =
    match Stream.peek strm__ with
      Some '<' ->
        Stream.junk strm__; mstore (quotation bp (store len '<') strm__) ">>"
    | Some ':' ->
        Stream.junk strm__;
        let len =
          try ident (store len ':') strm__ with
            Stream.Failure -> raise (Stream.Error "")
        in
        begin try
          match Stream.peek strm__ with
            Some '<' ->
              Stream.junk strm__;
              mstore (quotation bp (store len '<') strm__) ">>"
          | _ -> len
        with
          Stream.Failure -> raise (Stream.Error "")
        end
    | _ -> len
  and maybe_end_quotation bp len (strm__ : _ Stream.t) =
    match Stream.peek strm__ with
      Some '>' -> Stream.junk strm__; len
    | _ -> quotation bp (store len '>') strm__
  and left_paren bp (strm__ : _ Stream.t) =
    match Stream.peek strm__ with
      Some '*' ->
        Stream.junk strm__;
        let _ =
          try comment bp strm__ with
            Stream.Failure -> raise (Stream.Error "")
        in
        begin try next_token true strm__ with
          Stream.Failure -> raise (Stream.Error "")
        end
    | _ -> let ep = Stream.count strm__ in keyword_or_error (bp, ep) "("
  and comment bp (strm__ : _ Stream.t) =
    match Stream.peek strm__ with
      Some '(' -> Stream.junk strm__; left_paren_in_comment bp strm__
    | Some '*' -> Stream.junk strm__; star_in_comment bp strm__
    | Some '\"' ->
        Stream.junk strm__;
        let _ =
          try string bp 0 strm__ with
            Stream.Failure -> raise (Stream.Error "")
        in
        comment bp strm__
    | Some '\'' -> Stream.junk strm__; quote_in_comment bp strm__
    | Some c -> Stream.junk strm__; comment bp strm__
    | _ ->
        let ep = Stream.count strm__ in err (bp, ep) "comment not terminated"
  and quote_in_comment bp (strm__ : _ Stream.t) =
    match Stream.peek strm__ with
      Some '\'' -> Stream.junk strm__; comment bp strm__
    | Some '\\' -> Stream.junk strm__; quote_antislash_in_comment bp 0 strm__
    | _ ->
        let s = strm__ in
        begin match Stream.npeek 2 s with
          [_; '\''] -> Stream.junk s; Stream.junk s
        | _ -> ()
        end;
        comment bp s
  and quote_any_in_comment bp (strm__ : _ Stream.t) =
    match Stream.peek strm__ with
      Some '\'' -> Stream.junk strm__; comment bp strm__
    | _ -> comment bp strm__
  and quote_antislash_in_comment bp len (strm__ : _ Stream.t) =
    match Stream.peek strm__ with
      Some '\'' -> Stream.junk strm__; comment bp strm__
    | Some ('\\' | '\"' | 'n' | 't' | 'b' | 'r') ->
        Stream.junk strm__; quote_any_in_comment bp strm__
    | Some ('0'..'9') ->
        Stream.junk strm__; quote_antislash_digit_in_comment bp strm__
    | _ -> comment bp strm__
  and quote_antislash_digit_in_comment bp (strm__ : _ Stream.t) =
    match Stream.peek strm__ with
      Some ('0'..'9') ->
        Stream.junk strm__; quote_antislash_digit2_in_comment bp strm__
    | _ -> comment bp strm__
  and quote_antislash_digit2_in_comment bp (strm__ : _ Stream.t) =
    match Stream.peek strm__ with
      Some ('0'..'9') -> Stream.junk strm__; quote_any_in_comment bp strm__
    | _ -> comment bp strm__
  and left_paren_in_comment bp (strm__ : _ Stream.t) =
    match Stream.peek strm__ with
      Some '*' ->
        Stream.junk strm__; let s = strm__ in comment bp s; comment bp s
    | _ -> comment bp strm__
  and star_in_comment bp (strm__ : _ Stream.t) =
    match Stream.peek strm__ with
      Some ')' -> Stream.junk strm__; ()
    | _ -> comment bp strm__
  and linedir n s =
    match stream_peek_nth n s with
      Some (' ' | '\t') -> linedir (n + 1) s
    | Some ('0'..'9') -> linedir_digits (n + 1) s
    | _ -> false
  and linedir_digits n s =
    match stream_peek_nth n s with
      Some ('0'..'9') -> linedir_digits (n + 1) s
    | _ -> linedir_quote n s
  and linedir_quote n s =
    match stream_peek_nth n s with
      Some (' ' | '\t') -> linedir_quote (n + 1) s
    | Some '\"' -> true
    | _ -> false
  and any_to_nl (strm__ : _ Stream.t) =
    match Stream.peek strm__ with
      Some ('\013' | '\010') ->
        Stream.junk strm__; let ep = Stream.count strm__ in bolpos := ep
    | Some _ -> Stream.junk strm__; any_to_nl strm__
    | _ -> ()
  in
  fun cstrm ->
    try
      let glex = !glexr in
      let comm_bp = Stream.count cstrm in
      let r = next_token false cstrm in
      begin match glex.tok_comm with
        Some list ->
          if fst (snd r) > comm_bp then
            let comm_loc = comm_bp, fst (snd r) in
            glex.tok_comm <- Some (comm_loc :: list)
      | None -> ()
      end;
      r
    with
      Stream.Error str -> err (Stream.count cstrm, Stream.count cstrm + 1) str


let dollar_for_antiquotation = ref true
let specific_space_dot = ref false

let func kwd_table glexr =
  let bolpos = ref 0 in
  let find = Hashtbl.find kwd_table in
  let dfa = !dollar_for_antiquotation in
  let ssd = !specific_space_dot in
  Token.lexer_func_of_parser (next_token_fun dfa ssd find bolpos glexr)

let rec check_keyword_stream (strm__ : _ Stream.t) =
  let _ = check strm__ in
  let _ =
    try Stream.empty strm__ with
      Stream.Failure -> raise (Stream.Error "")
  in
  true
and check (strm__ : _ Stream.t) =
  match Stream.peek strm__ with
    Some
      ('A'..'Z' | 'a'..'z' | '\192'..'\214' | '\216'..'\246' |
       '\248'..'\255') ->
      Stream.junk strm__; check_ident strm__
  | Some
      ('!' | '?' | '~' | '=' | '@' | '^' | '&' | '+' | '-' | '*' | '/' | '%' |
       '.') ->
      Stream.junk strm__; check_ident2 strm__
  | Some '<' ->
      Stream.junk strm__;
      let s = strm__ in
      begin match Stream.npeek 1 s with
        [':' | '<'] -> ()
      | _ -> check_ident2 s
      end
  | Some ':' ->
      Stream.junk strm__;
      let _ =
        try
          match Stream.peek strm__ with
            Some (']' | ':' | '=' | '>') -> Stream.junk strm__; ()
          | _ -> ()
        with
          Stream.Failure -> raise (Stream.Error "")
      in
      let ep = Stream.count strm__ in ()
  | Some ('>' | '|') ->
      Stream.junk strm__;
      let _ =
        try
          match Stream.peek strm__ with
            Some (']' | '}') -> Stream.junk strm__; ()
          | _ -> check_ident2 strm__
        with
          Stream.Failure -> raise (Stream.Error "")
      in
      ()
  | Some ('[' | '{') ->
      Stream.junk strm__;
      let s = strm__ in
      begin match Stream.npeek 2 s with
        ['<'; '<' | ':'] -> ()
      | _ ->
          let (strm__ : _ Stream.t) = s in
          match Stream.peek strm__ with
            Some ('|' | '<' | ':') -> Stream.junk strm__; ()
          | _ -> ()
      end
  | Some ';' ->
      Stream.junk strm__;
      let _ =
        try
          match Stream.peek strm__ with
            Some ';' -> Stream.junk strm__; ()
          | _ -> ()
        with
          Stream.Failure -> raise (Stream.Error "")
      in
      ()
  | Some _ -> Stream.junk strm__; ()
  | _ -> raise Stream.Failure
and check_ident (strm__ : _ Stream.t) =
  match Stream.peek strm__ with
    Some
      ('A'..'Z' | 'a'..'z' | '\192'..'\214' | '\216'..'\246' |
       '\248'..'\255' | '0'..'9' | '_' | '\'') ->
      Stream.junk strm__; check_ident strm__
  | _ -> ()
and check_ident2 (strm__ : _ Stream.t) =
  match Stream.peek strm__ with
    Some
      ('!' | '?' | '~' | '=' | '@' | '^' | '&' | '+' | '-' | '*' | '/' | '%' |
       '.' | ':' | '<' | '>' | '|') ->
      Stream.junk strm__; check_ident2 strm__
  | _ -> ()

let check_keyword s =
  try check_keyword_stream (Stream.of_string s) with
    _ -> false

let error_no_respect_rules p_con p_prm =
  raise
    (Token.Error
       ("the token " ^
          (if p_con = "" then "\"" ^ p_prm ^ "\""
           else if p_prm = "" then p_con
           else p_con ^ " \"" ^ p_prm ^ "\"") ^
          " does not respect Plexer rules"))

let error_ident_and_keyword p_con p_prm =
  raise
    (Token.Error
       ("the token \"" ^ p_prm ^ "\" is used as " ^ p_con ^
          " and as keyword"))

let using_token kwd_table ident_table (p_con, p_prm) =
  match p_con with
    "" ->
      if not (Hashtbl.mem kwd_table p_prm) then
        if check_keyword p_prm then
          if Hashtbl.mem ident_table p_prm then
            error_ident_and_keyword (Hashtbl.find ident_table p_prm) p_prm
          else Hashtbl.add kwd_table p_prm p_prm
        else error_no_respect_rules p_con p_prm
  | "LIDENT" ->
      if p_prm = "" then ()
      else
        begin match p_prm.[0] with
          'A'..'Z' -> error_no_respect_rules p_con p_prm
        | _ ->
            if Hashtbl.mem kwd_table p_prm then
              error_ident_and_keyword p_con p_prm
            else Hashtbl.add ident_table p_prm p_con
        end
  | "UIDENT" ->
      if p_prm = "" then ()
      else
        begin match p_prm.[0] with
          'a'..'z' -> error_no_respect_rules p_con p_prm
        | _ ->
            if Hashtbl.mem kwd_table p_prm then
              error_ident_and_keyword p_con p_prm
            else Hashtbl.add ident_table p_prm p_con
        end
  | "TILDEIDENT" | "QUESTIONIDENT" | "INT" | "INT32" | "INT64" |
    "NATIVEINT" | "FLOAT" | "CHAR" | "STRING" | "QUOTATION" | "ANTIQUOT" |
    "LOCATE" | "EOI" ->
      ()
  | _ ->
      raise
        (Token.Error
           ("the constructor \"" ^ p_con ^ "\" is not recognized by Plexer"))

let removing_token kwd_table ident_table (p_con, p_prm) =
  match p_con with
    "" -> Hashtbl.remove kwd_table p_prm
  | "LIDENT" | "UIDENT" ->
      if p_prm <> "" then Hashtbl.remove ident_table p_prm
  | _ -> ()

let text =
  function
    "", t -> "'" ^ t ^ "'"
  | "LIDENT", "" -> "lowercase identifier"
  | "LIDENT", t -> "'" ^ t ^ "'"
  | "UIDENT", "" -> "uppercase identifier"
  | "UIDENT", t -> "'" ^ t ^ "'"
  | "INT", "" -> "integer"
  | "INT32", "" -> "32 bits integer"
  | "INT64", "" -> "64 bits integer"
  | "NATIVEINT", "" -> "native integer"
  | ("INT" | "INT32" | "NATIVEINT"), s -> "'" ^ s ^ "'"
  | "FLOAT", "" -> "float"
  | "STRING", "" -> "string"
  | "CHAR", "" -> "char"
  | "QUOTATION", "" -> "quotation"
  | "ANTIQUOT", k -> "antiquot \"" ^ k ^ "\""
  | "LOCATE", "" -> "locate"
  | "EOI", "" -> "end of input"
  | con, "" -> con
  | con, prm -> con ^ " \"" ^ prm ^ "\""

let eq_before_colon p e =
  let rec loop i =
    if i == String.length e then
      failwith "Internal error in Plexer: incorrect ANTIQUOT"
    else if i == String.length p then e.[i] == ':'
    else if p.[i] == e.[i] then loop (i + 1)
    else false
  in
  loop 0

let after_colon e =
  try
    let i = String.index e ':' in
    String.sub e (i + 1) (String.length e - i - 1)
  with
    Not_found -> ""

let tok_match =
  function
    "ANTIQUOT", p_prm ->
      begin function
        "ANTIQUOT", prm when eq_before_colon p_prm prm -> after_colon prm
      | _ -> raise Stream.Failure
      end
  | tok -> Token.default_match tok

let gmake () =
  let kwd_table = Hashtbl.create 301 in
  let id_table = Hashtbl.create 301 in
  let glexr =
    ref
      {tok_func =
         (fun _ -> raise (Match_failure ("../../lib/plexer.ml", 959, 17)));
       tok_using =
         (fun _ -> raise (Match_failure ("../../lib/plexer.ml", 959, 37)));
       tok_removing =
         (fun _ -> raise (Match_failure ("../../lib/plexer.ml", 959, 60)));
       tok_match =
         (fun _ -> raise (Match_failure ("../../lib/plexer.ml", 960, 18)));
       tok_text =
         (fun _ -> raise (Match_failure ("../../lib/plexer.ml", 960, 37)));
       tok_comm = None}
  in
  let glex =
    {tok_func = func kwd_table glexr;
     tok_using = using_token kwd_table id_table;
     tok_removing = removing_token kwd_table id_table; tok_match = tok_match;
     tok_text = text; tok_comm = None}
  in
  glexr := glex; glex

let tparse =
  function
    "ANTIQUOT", p_prm ->
      let p (strm__ : _ Stream.t) =
        match Stream.peek strm__ with
          Some ("ANTIQUOT", prm) when eq_before_colon p_prm prm ->
            Stream.junk strm__; after_colon prm
        | _ -> raise Stream.Failure
      in
      Some p
  | _ -> None

let make () =
  let kwd_table = Hashtbl.create 301 in
  let id_table = Hashtbl.create 301 in
  let glexr =
    ref
      {tok_func =
         (fun _ -> raise (Match_failure ("../../lib/plexer.ml", 988, 17)));
       tok_using =
         (fun _ -> raise (Match_failure ("../../lib/plexer.ml", 988, 37)));
       tok_removing =
         (fun _ -> raise (Match_failure ("../../lib/plexer.ml", 988, 60)));
       tok_match =
         (fun _ -> raise (Match_failure ("../../lib/plexer.ml", 989, 18)));
       tok_text =
         (fun _ -> raise (Match_failure ("../../lib/plexer.ml", 989, 37)));
       tok_comm = None}
  in
  {func = func kwd_table glexr; using = using_token kwd_table id_table;
   removing = removing_token kwd_table id_table; tparse = tparse; text = text}

(* camlp4r pa_extend.cmo pa_extend_m.cmo q_MLast.cmo *)
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

(* $Id: q_MLast.ml,v 1.55 2003/07/16 12:50:10 mauny Exp $ *)

let gram = Grammar.gcreate (Plexer.gmake ())

module Qast =
  struct
    type t =
        Node of string * t list
      | List of t list
      | Tuple of t list
      | Option of t option
      | Int of string
      | Str of string
      | Bool of bool
      | Cons of t * t
      | Apply of string * t list
      | Record of (string * t) list
      | Loc
      | Antiquot of MLast.loc * string
    let loc = 0, 0
    let rec to_expr =
      function
        Node (n, al) ->
          List.fold_left (fun e a -> MLast.ExApp (loc, e, to_expr a))
            (MLast.ExAcc
               (loc, MLast.ExUid (loc, "MLast"), MLast.ExUid (loc, n)))
            al
      | List al ->
          List.fold_right
            (fun a e ->
               MLast.ExApp
                 (loc, MLast.ExApp (loc, MLast.ExUid (loc, "::"), to_expr a),
                  e))
            al (MLast.ExUid (loc, "[]"))
      | Tuple al -> MLast.ExTup (loc, List.map to_expr al)
      | Option None -> MLast.ExUid (loc, "None")
      | Option (Some a) ->
          MLast.ExApp (loc, MLast.ExUid (loc, "Some"), to_expr a)
      | Int s -> MLast.ExInt (loc, s)
      | Str s -> MLast.ExStr (loc, s)
      | Bool true -> MLast.ExUid (loc, "True")
      | Bool false -> MLast.ExUid (loc, "False")
      | Cons (a1, a2) ->
          MLast.ExApp
            (loc, MLast.ExApp (loc, MLast.ExUid (loc, "::"), to_expr a1),
             to_expr a2)
      | Apply (f, al) ->
          List.fold_left (fun e a -> MLast.ExApp (loc, e, to_expr a))
            (MLast.ExLid (loc, f)) al
      | Record lal -> MLast.ExRec (loc, List.map to_expr_label lal, None)
      | Loc -> MLast.ExLid (loc, !(Stdpp.loc_name))
      | Antiquot (loc, s) ->
          let e =
            try Grammar.Entry.parse Pcaml.expr_eoi (Stream.of_string s) with
              Stdpp.Exc_located ((bp, ep), exc) ->
                raise (Stdpp.Exc_located ((fst loc + bp, fst loc + ep), exc))
          in
          MLast.ExAnt (loc, e)
    and to_expr_label (l, a) =
      MLast.PaAcc (loc, MLast.PaUid (loc, "MLast"), MLast.PaLid (loc, l)),
      to_expr a
    let rec to_patt =
      function
        Node (n, al) ->
          List.fold_left (fun e a -> MLast.PaApp (loc, e, to_patt a))
            (MLast.PaAcc
               (loc, MLast.PaUid (loc, "MLast"), MLast.PaUid (loc, n)))
            al
      | List al ->
          List.fold_right
            (fun a p ->
               MLast.PaApp
                 (loc, MLast.PaApp (loc, MLast.PaUid (loc, "::"), to_patt a),
                  p))
            al (MLast.PaUid (loc, "[]"))
      | Tuple al -> MLast.PaTup (loc, List.map to_patt al)
      | Option None -> MLast.PaUid (loc, "None")
      | Option (Some a) ->
          MLast.PaApp (loc, MLast.PaUid (loc, "Some"), to_patt a)
      | Int s -> MLast.PaInt (loc, s)
      | Str s -> MLast.PaStr (loc, s)
      | Bool true -> MLast.PaUid (loc, "True")
      | Bool false -> MLast.PaUid (loc, "False")
      | Cons (a1, a2) ->
          MLast.PaApp
            (loc, MLast.PaApp (loc, MLast.PaUid (loc, "::"), to_patt a1),
             to_patt a2)
      | Apply (_, _) -> failwith "bad pattern"
      | Record lal -> MLast.PaRec (loc, List.map to_patt_label lal)
      | Loc -> MLast.PaAny loc
      | Antiquot (loc, s) ->
          let p =
            try Grammar.Entry.parse Pcaml.patt_eoi (Stream.of_string s) with
              Stdpp.Exc_located ((bp, ep), exc) ->
                raise (Stdpp.Exc_located ((fst loc + bp, fst loc + ep), exc))
          in
          MLast.PaAnt (loc, p)
    and to_patt_label (l, a) =
      MLast.PaAcc (loc, MLast.PaUid (loc, "MLast"), MLast.PaLid (loc, l)),
      to_patt a
  end

let antiquot k (bp, ep) x =
  let shift =
    if k = "" then String.length "$"
    else String.length "$" + String.length k + String.length ":"
  in
  Qast.Antiquot ((shift + bp, shift + ep), x)

let sig_item = Grammar.Entry.create gram "signature item"
let str_item = Grammar.Entry.create gram "structure item"
let ctyp = Grammar.Entry.create gram "type"
let patt = Grammar.Entry.create gram "pattern"
let expr = Grammar.Entry.create gram "expression"

let module_type = Grammar.Entry.create gram "module type"
let module_expr = Grammar.Entry.create gram "module expression"

let class_type = Grammar.Entry.create gram "class type"
let class_expr = Grammar.Entry.create gram "class expr"
let class_sig_item = Grammar.Entry.create gram "class signature item"
let class_str_item = Grammar.Entry.create gram "class structure item"

let ipatt = Grammar.Entry.create gram "ipatt"
let let_binding = Grammar.Entry.create gram "let_binding"
let type_declaration = Grammar.Entry.create gram "type_declaration"
let with_constr = Grammar.Entry.create gram "with_constr"
let row_field = Grammar.Entry.create gram "row_field"

let a_list = Grammar.Entry.create gram "a_list"
let a_opt = Grammar.Entry.create gram "a_opt"
let a_UIDENT = Grammar.Entry.create gram "a_UIDENT"
let a_LIDENT = Grammar.Entry.create gram "a_LIDENT"
let a_INT = Grammar.Entry.create gram "a_INT"
let a_FLOAT = Grammar.Entry.create gram "a_FLOAT"
let a_STRING = Grammar.Entry.create gram "a_STRING"
let a_CHAR = Grammar.Entry.create gram "a_CHAR"
let a_TILDEIDENT = Grammar.Entry.create gram "a_TILDEIDENT"
let a_QUESTIONIDENT = Grammar.Entry.create gram "a_QUESTIONIDENT"

let o2b =
  function
    Qast.Option (Some _) -> Qast.Bool true
  | Qast.Option None -> Qast.Bool false
  | x -> x

let mksequence _ =
  function
    Qast.List [e] -> e
  | el -> Qast.Node ("ExSeq", [Qast.Loc; el])

let mkmatchcase _ p aso w e =
  let p =
    match aso with
      Qast.Option (Some p2) -> Qast.Node ("PaAli", [Qast.Loc; p; p2])
    | Qast.Option None -> p
    | _ -> Qast.Node ("PaAli", [Qast.Loc; p; aso])
  in
  Qast.Tuple [p; w; e]

let neg_string n =
  let len = String.length n in
  if len > 0 && n.[0] = '-' then String.sub n 1 (len - 1) else "-" ^ n

let mkumin _ f arg =
  match arg with
    Qast.Node ("ExInt", [Qast.Loc; Qast.Str n]) when int_of_string n > 0 ->
      let n = neg_string n in Qast.Node ("ExInt", [Qast.Loc; Qast.Str n])
  | Qast.Node ("ExFlo", [Qast.Loc; Qast.Str n])
    when float_of_string n > 0.0 ->
      let n = neg_string n in Qast.Node ("ExFlo", [Qast.Loc; Qast.Str n])
  | _ ->
      match f with
        Qast.Str f ->
          let f = "~" ^ f in
          Qast.Node
            ("ExApp",
             [Qast.Loc; Qast.Node ("ExLid", [Qast.Loc; Qast.Str f]); arg])
      | _ -> assert false

let mkuminpat _ f is_int s =
  let s =
    match s with
      Qast.Str s -> Qast.Str (neg_string s)
    | s -> failwith "bad unary minus"
  in
  match is_int with
    Qast.Bool true -> Qast.Node ("PaInt", [Qast.Loc; s])
  | Qast.Bool false -> Qast.Node ("PaFlo", [Qast.Loc; s])
  | _ -> assert false

let mklistexp _ last =
  let rec loop top =
    function
      Qast.List [] ->
        begin match last with
          Qast.Option (Some e) -> e
        | Qast.Option None -> Qast.Node ("ExUid", [Qast.Loc; Qast.Str "[]"])
        | a -> a
        end
    | Qast.List (e1 :: el) ->
        Qast.Node
          ("ExApp",
           [Qast.Loc;
            Qast.Node
              ("ExApp",
               [Qast.Loc; Qast.Node ("ExUid", [Qast.Loc; Qast.Str "::"]);
                e1]);
            loop false (Qast.List el)])
    | a -> a
  in
  loop true

let mklistpat _ last =
  let rec loop top =
    function
      Qast.List [] ->
        begin match last with
          Qast.Option (Some p) -> p
        | Qast.Option None -> Qast.Node ("PaUid", [Qast.Loc; Qast.Str "[]"])
        | a -> a
        end
    | Qast.List (p1 :: pl) ->
        Qast.Node
          ("PaApp",
           [Qast.Loc;
            Qast.Node
              ("PaApp",
               [Qast.Loc; Qast.Node ("PaUid", [Qast.Loc; Qast.Str "::"]);
                p1]);
            loop false (Qast.List pl)])
    | a -> a
  in
  loop true

let mkexprident loc i j =
  let rec loop m =
    function
      Qast.Node ("ExAcc", [_; x; y]) ->
        loop (Qast.Node ("ExAcc", [Qast.Loc; m; x])) y
    | e -> Qast.Node ("ExAcc", [Qast.Loc; m; e])
  in
  loop (Qast.Node ("ExUid", [Qast.Loc; i])) j

let mkassert _ e =
  match e with
    Qast.Node ("ExUid", [_; Qast.Str "False"]) ->
      Qast.Node ("ExAsf", [Qast.Loc])
  | _ -> Qast.Node ("ExAsr", [Qast.Loc; e])

let append_elem el e = Qast.Apply ("@", [el; Qast.List [e]])

let not_yet_warned_antiq = ref true
let warn_antiq loc vers =
  if !not_yet_warned_antiq then
    begin
      not_yet_warned_antiq := false;
      !(Pcaml.warning) loc
        (Printf.sprintf
           "use of antiquotation syntax deprecated since version %s" vers)
    end

let not_yet_warned_variant = ref true
let warn_variant _ =
  if !not_yet_warned_variant then
    begin
      not_yet_warned_variant := false;
      !(Pcaml.warning) (0, 1)
        (Printf.sprintf
           "use of syntax of variants types deprecated since version 3.05")
    end

let not_yet_warned_seq = ref true
let warn_sequence _ =
  if !not_yet_warned_seq then
    begin
      not_yet_warned_seq := false;
      !(Pcaml.warning) (0, 1)
        (Printf.sprintf
           "use of syntax of sequences deprecated since version 3.01.1")
    end

let _ =
  Grammar.extend
    (let _ = (sig_item : 'sig_item Grammar.Entry.e)
     and _ = (str_item : 'str_item Grammar.Entry.e)
     and _ = (ctyp : 'ctyp Grammar.Entry.e)
     and _ = (patt : 'patt Grammar.Entry.e)
     and _ = (expr : 'expr Grammar.Entry.e)
     and _ = (module_type : 'module_type Grammar.Entry.e)
     and _ = (module_expr : 'module_expr Grammar.Entry.e)
     and _ = (class_type : 'class_type Grammar.Entry.e)
     and _ = (class_expr : 'class_expr Grammar.Entry.e)
     and _ = (class_sig_item : 'class_sig_item Grammar.Entry.e)
     and _ = (class_str_item : 'class_str_item Grammar.Entry.e)
     and _ = (let_binding : 'let_binding Grammar.Entry.e)
     and _ = (type_declaration : 'type_declaration Grammar.Entry.e)
     and _ = (ipatt : 'ipatt Grammar.Entry.e)
     and _ = (with_constr : 'with_constr Grammar.Entry.e)
     and _ = (row_field : 'row_field Grammar.Entry.e) in
     let grammar_entry_create s =
       Grammar.Entry.create (Grammar.of_entry sig_item) s
     in
     let rebind_exn : 'rebind_exn Grammar.Entry.e =
       grammar_entry_create "rebind_exn"
     and module_binding : 'module_binding Grammar.Entry.e =
       grammar_entry_create "module_binding"
     and module_rec_binding : 'module_rec_binding Grammar.Entry.e =
       grammar_entry_create "module_rec_binding"
     and module_declaration : 'module_declaration Grammar.Entry.e =
       grammar_entry_create "module_declaration"
     and module_rec_declaration : 'module_rec_declaration Grammar.Entry.e =
       grammar_entry_create "module_rec_declaration"
     and cons_expr_opt : 'cons_expr_opt Grammar.Entry.e =
       grammar_entry_create "cons_expr_opt"
     and dummy : 'dummy Grammar.Entry.e = grammar_entry_create "dummy"
     and fun_binding : 'fun_binding Grammar.Entry.e =
       grammar_entry_create "fun_binding"
     and match_case : 'match_case Grammar.Entry.e =
       grammar_entry_create "match_case"
     and as_patt_opt : 'as_patt_opt Grammar.Entry.e =
       grammar_entry_create "as_patt_opt"
     and label_expr : 'label_expr Grammar.Entry.e =
       grammar_entry_create "label_expr"
     and fun_def : 'fun_def Grammar.Entry.e = grammar_entry_create "fun_def"
     and cons_patt_opt : 'cons_patt_opt Grammar.Entry.e =
       grammar_entry_create "cons_patt_opt"
     and label_patt : 'label_patt Grammar.Entry.e =
       grammar_entry_create "label_patt"
     and label_ipatt : 'label_ipatt Grammar.Entry.e =
       grammar_entry_create "label_ipatt"
     and type_patt : 'type_patt Grammar.Entry.e =
       grammar_entry_create "type_patt"
     and constrain : 'constrain Grammar.Entry.e =
       grammar_entry_create "constrain"
     and type_parameter : 'type_parameter Grammar.Entry.e =
       grammar_entry_create "type_parameter"
     and constructor_declaration : 'constructor_declaration Grammar.Entry.e =
       grammar_entry_create "constructor_declaration"
     and label_declaration : 'label_declaration Grammar.Entry.e =
       grammar_entry_create "label_declaration"
     and ident : 'ident Grammar.Entry.e = grammar_entry_create "ident"
     and class_declaration : 'class_declaration Grammar.Entry.e =
       grammar_entry_create "class_declaration"
     and class_fun_binding : 'class_fun_binding Grammar.Entry.e =
       grammar_entry_create "class_fun_binding"
     and class_type_parameters : 'class_type_parameters Grammar.Entry.e =
       grammar_entry_create "class_type_parameters"
     and class_fun_def : 'class_fun_def Grammar.Entry.e =
       grammar_entry_create "class_fun_def"
     and class_structure : 'class_structure Grammar.Entry.e =
       grammar_entry_create "class_structure"
     and class_self_patt : 'class_self_patt Grammar.Entry.e =
       grammar_entry_create "class_self_patt"
     and as_lident : 'as_lident Grammar.Entry.e =
       grammar_entry_create "as_lident"
     and polyt : 'polyt Grammar.Entry.e = grammar_entry_create "polyt"
     and cvalue_binding : 'cvalue_binding Grammar.Entry.e =
       grammar_entry_create "cvalue_binding"
     and label : 'label Grammar.Entry.e = grammar_entry_create "label"
     and class_self_type : 'class_self_type Grammar.Entry.e =
       grammar_entry_create "class_self_type"
     and class_description : 'class_description Grammar.Entry.e =
       grammar_entry_create "class_description"
     and class_type_declaration : 'class_type_declaration Grammar.Entry.e =
       grammar_entry_create "class_type_declaration"
     and field_expr : 'field_expr Grammar.Entry.e =
       grammar_entry_create "field_expr"
     and field : 'field Grammar.Entry.e = grammar_entry_create "field"
     and typevar : 'typevar Grammar.Entry.e = grammar_entry_create "typevar"
     and row_field_list : 'row_field_list Grammar.Entry.e =
       grammar_entry_create "row_field_list"
     and name_tag : 'name_tag Grammar.Entry.e =
       grammar_entry_create "name_tag"
     and patt_tcon : 'patt_tcon Grammar.Entry.e =
       grammar_entry_create "patt_tcon"
     and ipatt_tcon : 'ipatt_tcon Grammar.Entry.e =
       grammar_entry_create "ipatt_tcon"
     and eq_expr : 'eq_expr Grammar.Entry.e = grammar_entry_create "eq_expr"
     and warning_variant : 'warning_variant Grammar.Entry.e =
       grammar_entry_create "warning_variant"
     and warning_sequence : 'warning_sequence Grammar.Entry.e =
       grammar_entry_create "warning_sequence"
     and sequence : 'sequence Grammar.Entry.e =
       grammar_entry_create "sequence"
     and expr_ident : 'expr_ident Grammar.Entry.e =
       grammar_entry_create "expr_ident"
     and patt_label_ident : 'patt_label_ident Grammar.Entry.e =
       grammar_entry_create "patt_label_ident"
     and when_expr_opt : 'when_expr_opt Grammar.Entry.e =
       grammar_entry_create "when_expr_opt"
     and mod_ident : 'mod_ident Grammar.Entry.e =
       grammar_entry_create "mod_ident"
     and clty_longident : 'clty_longident Grammar.Entry.e =
       grammar_entry_create "clty_longident"
     and class_longident : 'class_longident Grammar.Entry.e =
       grammar_entry_create "class_longident"
     and direction_flag : 'direction_flag Grammar.Entry.e =
       grammar_entry_create "direction_flag"
     in
     [Grammar.Entry.obj (module_expr : 'module_expr Grammar.Entry.e), None,
      [None, None,
       [[Gramext.Stoken ("", "struct");
         Gramext.srules
           [[Gramext.Slist0
               (Gramext.srules
                  [[Gramext.Snterm
                      (Grammar.Entry.obj
                         (str_item : 'str_item Grammar.Entry.e));
                    Gramext.Stoken ("", ";")],
                   Gramext.action
                     (fun _ (s : 'str_item) (loc : int * int) ->
                        (s : 'e__1))])],
            Gramext.action
              (fun (a : 'e__1 list) (loc : int * int) ->
                 (Qast.List a : 'a_list));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_list : 'a_list Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_list) (loc : int * int) -> (a : 'a_list))];
         Gramext.Stoken ("", "end")],
        Gramext.action
          (fun _ (st : 'a_list) _ (loc : int * int) ->
             (Qast.Node ("MeStr", [Qast.Loc; st]) : 'module_expr));
        [Gramext.Stoken ("", "functor"); Gramext.Stoken ("", "(");
         Gramext.Snterm
           (Grammar.Entry.obj (a_UIDENT : 'a_UIDENT Grammar.Entry.e));
         Gramext.Stoken ("", ":");
         Gramext.Snterm
           (Grammar.Entry.obj (module_type : 'module_type Grammar.Entry.e));
         Gramext.Stoken ("", ")"); Gramext.Stoken ("", "->"); Gramext.Sself],
        Gramext.action
          (fun (me : 'module_expr) _ _ (t : 'module_type) _ (i : 'a_UIDENT) _
             _ (loc : int * int) ->
             (Qast.Node ("MeFun", [Qast.Loc; i; t; me]) : 'module_expr))];
       None, None,
       [[Gramext.Sself; Gramext.Sself],
        Gramext.action
          (fun (me2 : 'module_expr) (me1 : 'module_expr) (loc : int * int) ->
             (Qast.Node ("MeApp", [Qast.Loc; me1; me2]) : 'module_expr))];
       None, None,
       [[Gramext.Sself; Gramext.Stoken ("", "."); Gramext.Sself],
        Gramext.action
          (fun (me2 : 'module_expr) _ (me1 : 'module_expr)
             (loc : int * int) ->
             (Qast.Node ("MeAcc", [Qast.Loc; me1; me2]) : 'module_expr))];
       Some "simple", None,
       [[Gramext.Stoken ("", "("); Gramext.Sself; Gramext.Stoken ("", ")")],
        Gramext.action
          (fun _ (me : 'module_expr) _ (loc : int * int) ->
             (me : 'module_expr));
        [Gramext.Stoken ("", "("); Gramext.Sself; Gramext.Stoken ("", ":");
         Gramext.Snterm
           (Grammar.Entry.obj (module_type : 'module_type Grammar.Entry.e));
         Gramext.Stoken ("", ")")],
        Gramext.action
          (fun _ (mt : 'module_type) _ (me : 'module_expr) _
             (loc : int * int) ->
             (Qast.Node ("MeTyc", [Qast.Loc; me; mt]) : 'module_expr));
        [Gramext.Snterm
           (Grammar.Entry.obj (a_UIDENT : 'a_UIDENT Grammar.Entry.e))],
        Gramext.action
          (fun (i : 'a_UIDENT) (loc : int * int) ->
             (Qast.Node ("MeUid", [Qast.Loc; i]) : 'module_expr))]];
      Grammar.Entry.obj (str_item : 'str_item Grammar.Entry.e), None,
      [Some "top", None,
       [[Gramext.Snterm (Grammar.Entry.obj (expr : 'expr Grammar.Entry.e))],
        Gramext.action
          (fun (e : 'expr) (loc : int * int) ->
             (Qast.Node ("StExp", [Qast.Loc; e]) : 'str_item));
        [Gramext.Stoken ("", "value");
         Gramext.srules
           [[Gramext.Sopt
               (Gramext.srules
                  [[Gramext.Stoken ("", "rec")],
                   Gramext.action
                     (fun (x : string) (loc : int * int) ->
                        (Qast.Str x : 'e__3))])],
            Gramext.action
              (fun (a : 'e__3 option) (loc : int * int) ->
                 (Qast.Option a : 'a_opt));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_opt : 'a_opt Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_opt) (loc : int * int) -> (a : 'a_opt))];
         Gramext.srules
           [[Gramext.Slist1sep
               (Gramext.Snterm
                  (Grammar.Entry.obj
                     (let_binding : 'let_binding Grammar.Entry.e)),
                Gramext.Stoken ("", "and"))],
            Gramext.action
              (fun (a : 'let_binding list) (loc : int * int) ->
                 (Qast.List a : 'a_list));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_list : 'a_list Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_list) (loc : int * int) -> (a : 'a_list))]],
        Gramext.action
          (fun (l : 'a_list) (r : 'a_opt) _ (loc : int * int) ->
             (Qast.Node ("StVal", [Qast.Loc; o2b r; l]) : 'str_item));
        [Gramext.Stoken ("", "type");
         Gramext.srules
           [[Gramext.Slist1sep
               (Gramext.Snterm
                  (Grammar.Entry.obj
                     (type_declaration : 'type_declaration Grammar.Entry.e)),
                Gramext.Stoken ("", "and"))],
            Gramext.action
              (fun (a : 'type_declaration list) (loc : int * int) ->
                 (Qast.List a : 'a_list));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_list : 'a_list Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_list) (loc : int * int) -> (a : 'a_list))]],
        Gramext.action
          (fun (tdl : 'a_list) _ (loc : int * int) ->
             (Qast.Node ("StTyp", [Qast.Loc; tdl]) : 'str_item));
        [Gramext.Stoken ("", "open");
         Gramext.Snterm
           (Grammar.Entry.obj (mod_ident : 'mod_ident Grammar.Entry.e))],
        Gramext.action
          (fun (i : 'mod_ident) _ (loc : int * int) ->
             (Qast.Node ("StOpn", [Qast.Loc; i]) : 'str_item));
        [Gramext.Stoken ("", "module"); Gramext.Stoken ("", "type");
         Gramext.Snterm
           (Grammar.Entry.obj (a_UIDENT : 'a_UIDENT Grammar.Entry.e));
         Gramext.Stoken ("", "=");
         Gramext.Snterm
           (Grammar.Entry.obj (module_type : 'module_type Grammar.Entry.e))],
        Gramext.action
          (fun (mt : 'module_type) _ (i : 'a_UIDENT) _ _ (loc : int * int) ->
             (Qast.Node ("StMty", [Qast.Loc; i; mt]) : 'str_item));
        [Gramext.Stoken ("", "module"); Gramext.Stoken ("", "rec");
         Gramext.srules
           [[Gramext.Slist1sep
               (Gramext.Snterm
                  (Grammar.Entry.obj
                     (module_rec_binding :
                      'module_rec_binding Grammar.Entry.e)),
                Gramext.Stoken ("", "and"))],
            Gramext.action
              (fun (a : 'module_rec_binding list) (loc : int * int) ->
                 (Qast.List a : 'a_list));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_list : 'a_list Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_list) (loc : int * int) -> (a : 'a_list))]],
        Gramext.action
          (fun (nmtmes : 'a_list) _ _ (loc : int * int) ->
             (Qast.Node ("StRecMod", [Qast.Loc; nmtmes]) : 'str_item));
        [Gramext.Stoken ("", "module");
         Gramext.Snterm
           (Grammar.Entry.obj (a_UIDENT : 'a_UIDENT Grammar.Entry.e));
         Gramext.Snterm
           (Grammar.Entry.obj
              (module_binding : 'module_binding Grammar.Entry.e))],
        Gramext.action
          (fun (mb : 'module_binding) (i : 'a_UIDENT) _ (loc : int * int) ->
             (Qast.Node ("StMod", [Qast.Loc; i; mb]) : 'str_item));
        [Gramext.Stoken ("", "include");
         Gramext.Snterm
           (Grammar.Entry.obj (module_expr : 'module_expr Grammar.Entry.e))],
        Gramext.action
          (fun (me : 'module_expr) _ (loc : int * int) ->
             (Qast.Node ("StInc", [Qast.Loc; me]) : 'str_item));
        [Gramext.Stoken ("", "external");
         Gramext.Snterm
           (Grammar.Entry.obj (a_LIDENT : 'a_LIDENT Grammar.Entry.e));
         Gramext.Stoken ("", ":");
         Gramext.Snterm (Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e));
         Gramext.Stoken ("", "=");
         Gramext.srules
           [[Gramext.Slist1
               (Gramext.Snterm
                  (Grammar.Entry.obj
                     (a_STRING : 'a_STRING Grammar.Entry.e)))],
            Gramext.action
              (fun (a : 'a_STRING list) (loc : int * int) ->
                 (Qast.List a : 'a_list));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_list : 'a_list Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_list) (loc : int * int) -> (a : 'a_list))]],
        Gramext.action
          (fun (pd : 'a_list) _ (t : 'ctyp) _ (i : 'a_LIDENT) _
             (loc : int * int) ->
             (Qast.Node ("StExt", [Qast.Loc; i; t; pd]) : 'str_item));
        [Gramext.Stoken ("", "exception");
         Gramext.Snterm
           (Grammar.Entry.obj
              (constructor_declaration :
               'constructor_declaration Grammar.Entry.e));
         Gramext.Snterm
           (Grammar.Entry.obj (rebind_exn : 'rebind_exn Grammar.Entry.e))],
        Gramext.action
          (fun (b : 'rebind_exn) (ctl : 'constructor_declaration) _
             (loc : int * int) ->
             (let (_, c, tl) =
                match ctl with
                  Qast.Tuple [xx1; xx2; xx3] -> xx1, xx2, xx3
                | _ ->
                    match () with
                    _ -> raise (Match_failure ("./meta/q_MLast.ml", 300, 19))
              in
              Qast.Node ("StExc", [Qast.Loc; c; tl; b]) :
              'str_item));
        [Gramext.Stoken ("", "declare");
         Gramext.srules
           [[Gramext.Slist0
               (Gramext.srules
                  [[Gramext.Snterm
                      (Grammar.Entry.obj
                         (str_item : 'str_item Grammar.Entry.e));
                    Gramext.Stoken ("", ";")],
                   Gramext.action
                     (fun _ (s : 'str_item) (loc : int * int) ->
                        (s : 'e__2))])],
            Gramext.action
              (fun (a : 'e__2 list) (loc : int * int) ->
                 (Qast.List a : 'a_list));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_list : 'a_list Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_list) (loc : int * int) -> (a : 'a_list))];
         Gramext.Stoken ("", "end")],
        Gramext.action
          (fun _ (st : 'a_list) _ (loc : int * int) ->
             (Qast.Node ("StDcl", [Qast.Loc; st]) : 'str_item))]];
      Grammar.Entry.obj (rebind_exn : 'rebind_exn Grammar.Entry.e), None,
      [None, None,
       [[],
        Gramext.action
          (fun (loc : int * int) -> (Qast.List [] : 'rebind_exn));
        [Gramext.Stoken ("", "=");
         Gramext.Snterm
           (Grammar.Entry.obj (mod_ident : 'mod_ident Grammar.Entry.e))],
        Gramext.action
          (fun (sl : 'mod_ident) _ (loc : int * int) -> (sl : 'rebind_exn))]];
      Grammar.Entry.obj (module_binding : 'module_binding Grammar.Entry.e),
      None,
      [None, Some Gramext.RightA,
       [[Gramext.Stoken ("", "=");
         Gramext.Snterm
           (Grammar.Entry.obj (module_expr : 'module_expr Grammar.Entry.e))],
        Gramext.action
          (fun (me : 'module_expr) _ (loc : int * int) ->
             (me : 'module_binding));
        [Gramext.Stoken ("", ":");
         Gramext.Snterm
           (Grammar.Entry.obj (module_type : 'module_type Grammar.Entry.e));
         Gramext.Stoken ("", "=");
         Gramext.Snterm
           (Grammar.Entry.obj (module_expr : 'module_expr Grammar.Entry.e))],
        Gramext.action
          (fun (me : 'module_expr) _ (mt : 'module_type) _
             (loc : int * int) ->
             (Qast.Node ("MeTyc", [Qast.Loc; me; mt]) : 'module_binding));
        [Gramext.Stoken ("", "(");
         Gramext.Snterm
           (Grammar.Entry.obj (a_UIDENT : 'a_UIDENT Grammar.Entry.e));
         Gramext.Stoken ("", ":");
         Gramext.Snterm
           (Grammar.Entry.obj (module_type : 'module_type Grammar.Entry.e));
         Gramext.Stoken ("", ")"); Gramext.Sself],
        Gramext.action
          (fun (mb : 'module_binding) _ (mt : 'module_type) _ (m : 'a_UIDENT)
             _ (loc : int * int) ->
             (Qast.Node ("MeFun", [Qast.Loc; m; mt; mb]) :
              'module_binding))]];
      Grammar.Entry.obj
        (module_rec_binding : 'module_rec_binding Grammar.Entry.e),
      None,
      [None, None,
       [[Gramext.Snterm
           (Grammar.Entry.obj (a_UIDENT : 'a_UIDENT Grammar.Entry.e));
         Gramext.Stoken ("", ":");
         Gramext.Snterm
           (Grammar.Entry.obj (module_type : 'module_type Grammar.Entry.e));
         Gramext.Stoken ("", "=");
         Gramext.Snterm
           (Grammar.Entry.obj (module_expr : 'module_expr Grammar.Entry.e))],
        Gramext.action
          (fun (me : 'module_expr) _ (mt : 'module_type) _ (m : 'a_UIDENT)
             (loc : int * int) ->
             (Qast.Tuple [m; me; mt] : 'module_rec_binding))]];
      Grammar.Entry.obj (module_type : 'module_type Grammar.Entry.e), None,
      [None, None,
       [[Gramext.Stoken ("", "functor"); Gramext.Stoken ("", "(");
         Gramext.Snterm
           (Grammar.Entry.obj (a_UIDENT : 'a_UIDENT Grammar.Entry.e));
         Gramext.Stoken ("", ":"); Gramext.Sself; Gramext.Stoken ("", ")");
         Gramext.Stoken ("", "->"); Gramext.Sself],
        Gramext.action
          (fun (mt : 'module_type) _ _ (t : 'module_type) _ (i : 'a_UIDENT) _
             _ (loc : int * int) ->
             (Qast.Node ("MtFun", [Qast.Loc; i; t; mt]) : 'module_type))];
       None, None,
       [[Gramext.Sself; Gramext.Stoken ("", "with");
         Gramext.srules
           [[Gramext.Slist1sep
               (Gramext.Snterm
                  (Grammar.Entry.obj
                     (with_constr : 'with_constr Grammar.Entry.e)),
                Gramext.Stoken ("", "and"))],
            Gramext.action
              (fun (a : 'with_constr list) (loc : int * int) ->
                 (Qast.List a : 'a_list));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_list : 'a_list Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_list) (loc : int * int) -> (a : 'a_list))]],
        Gramext.action
          (fun (wcl : 'a_list) _ (mt : 'module_type) (loc : int * int) ->
             (Qast.Node ("MtWit", [Qast.Loc; mt; wcl]) : 'module_type))];
       None, None,
       [[Gramext.Stoken ("", "sig");
         Gramext.srules
           [[Gramext.Slist0
               (Gramext.srules
                  [[Gramext.Snterm
                      (Grammar.Entry.obj
                         (sig_item : 'sig_item Grammar.Entry.e));
                    Gramext.Stoken ("", ";")],
                   Gramext.action
                     (fun _ (s : 'sig_item) (loc : int * int) ->
                        (s : 'e__4))])],
            Gramext.action
              (fun (a : 'e__4 list) (loc : int * int) ->
                 (Qast.List a : 'a_list));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_list : 'a_list Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_list) (loc : int * int) -> (a : 'a_list))];
         Gramext.Stoken ("", "end")],
        Gramext.action
          (fun _ (sg : 'a_list) _ (loc : int * int) ->
             (Qast.Node ("MtSig", [Qast.Loc; sg]) : 'module_type))];
       None, None,
       [[Gramext.Sself; Gramext.Sself],
        Gramext.action
          (fun (m2 : 'module_type) (m1 : 'module_type) (loc : int * int) ->
             (Qast.Node ("MtApp", [Qast.Loc; m1; m2]) : 'module_type))];
       None, None,
       [[Gramext.Sself; Gramext.Stoken ("", "."); Gramext.Sself],
        Gramext.action
          (fun (m2 : 'module_type) _ (m1 : 'module_type) (loc : int * int) ->
             (Qast.Node ("MtAcc", [Qast.Loc; m1; m2]) : 'module_type))];
       Some "simple", None,
       [[Gramext.Stoken ("", "("); Gramext.Sself; Gramext.Stoken ("", ")")],
        Gramext.action
          (fun _ (mt : 'module_type) _ (loc : int * int) ->
             (mt : 'module_type));
        [Gramext.Stoken ("", "'");
         Gramext.Snterm (Grammar.Entry.obj (ident : 'ident Grammar.Entry.e))],
        Gramext.action
          (fun (i : 'ident) _ (loc : int * int) ->
             (Qast.Node ("MtQuo", [Qast.Loc; i]) : 'module_type));
        [Gramext.Snterm
           (Grammar.Entry.obj (a_LIDENT : 'a_LIDENT Grammar.Entry.e))],
        Gramext.action
          (fun (i : 'a_LIDENT) (loc : int * int) ->
             (Qast.Node ("MtLid", [Qast.Loc; i]) : 'module_type));
        [Gramext.Snterm
           (Grammar.Entry.obj (a_UIDENT : 'a_UIDENT Grammar.Entry.e))],
        Gramext.action
          (fun (i : 'a_UIDENT) (loc : int * int) ->
             (Qast.Node ("MtUid", [Qast.Loc; i]) : 'module_type))]];
      Grammar.Entry.obj (sig_item : 'sig_item Grammar.Entry.e), None,
      [Some "top", None,
       [[Gramext.Stoken ("", "value");
         Gramext.Snterm
           (Grammar.Entry.obj (a_LIDENT : 'a_LIDENT Grammar.Entry.e));
         Gramext.Stoken ("", ":");
         Gramext.Snterm (Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e))],
        Gramext.action
          (fun (t : 'ctyp) _ (i : 'a_LIDENT) _ (loc : int * int) ->
             (Qast.Node ("SgVal", [Qast.Loc; i; t]) : 'sig_item));
        [Gramext.Stoken ("", "type");
         Gramext.srules
           [[Gramext.Slist1sep
               (Gramext.Snterm
                  (Grammar.Entry.obj
                     (type_declaration : 'type_declaration Grammar.Entry.e)),
                Gramext.Stoken ("", "and"))],
            Gramext.action
              (fun (a : 'type_declaration list) (loc : int * int) ->
                 (Qast.List a : 'a_list));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_list : 'a_list Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_list) (loc : int * int) -> (a : 'a_list))]],
        Gramext.action
          (fun (tdl : 'a_list) _ (loc : int * int) ->
             (Qast.Node ("SgTyp", [Qast.Loc; tdl]) : 'sig_item));
        [Gramext.Stoken ("", "open");
         Gramext.Snterm
           (Grammar.Entry.obj (mod_ident : 'mod_ident Grammar.Entry.e))],
        Gramext.action
          (fun (i : 'mod_ident) _ (loc : int * int) ->
             (Qast.Node ("SgOpn", [Qast.Loc; i]) : 'sig_item));
        [Gramext.Stoken ("", "module"); Gramext.Stoken ("", "rec");
         Gramext.srules
           [[Gramext.Slist1sep
               (Gramext.Snterm
                  (Grammar.Entry.obj
                     (module_rec_declaration :
                      'module_rec_declaration Grammar.Entry.e)),
                Gramext.Stoken ("", "and"))],
            Gramext.action
              (fun (a : 'module_rec_declaration list) (loc : int * int) ->
                 (Qast.List a : 'a_list));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_list : 'a_list Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_list) (loc : int * int) -> (a : 'a_list))]],
        Gramext.action
          (fun (mds : 'a_list) _ _ (loc : int * int) ->
             (Qast.Node ("SgRecMod", [Qast.Loc; mds]) : 'sig_item));
        [Gramext.Stoken ("", "module"); Gramext.Stoken ("", "type");
         Gramext.Snterm
           (Grammar.Entry.obj (a_UIDENT : 'a_UIDENT Grammar.Entry.e));
         Gramext.Stoken ("", "=");
         Gramext.Snterm
           (Grammar.Entry.obj (module_type : 'module_type Grammar.Entry.e))],
        Gramext.action
          (fun (mt : 'module_type) _ (i : 'a_UIDENT) _ _ (loc : int * int) ->
             (Qast.Node ("SgMty", [Qast.Loc; i; mt]) : 'sig_item));
        [Gramext.Stoken ("", "module");
         Gramext.Snterm
           (Grammar.Entry.obj (a_UIDENT : 'a_UIDENT Grammar.Entry.e));
         Gramext.Snterm
           (Grammar.Entry.obj
              (module_declaration : 'module_declaration Grammar.Entry.e))],
        Gramext.action
          (fun (mt : 'module_declaration) (i : 'a_UIDENT) _
             (loc : int * int) ->
             (Qast.Node ("SgMod", [Qast.Loc; i; mt]) : 'sig_item));
        [Gramext.Stoken ("", "include");
         Gramext.Snterm
           (Grammar.Entry.obj (module_type : 'module_type Grammar.Entry.e))],
        Gramext.action
          (fun (mt : 'module_type) _ (loc : int * int) ->
             (Qast.Node ("SgInc", [Qast.Loc; mt]) : 'sig_item));
        [Gramext.Stoken ("", "external");
         Gramext.Snterm
           (Grammar.Entry.obj (a_LIDENT : 'a_LIDENT Grammar.Entry.e));
         Gramext.Stoken ("", ":");
         Gramext.Snterm (Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e));
         Gramext.Stoken ("", "=");
         Gramext.srules
           [[Gramext.Slist1
               (Gramext.Snterm
                  (Grammar.Entry.obj
                     (a_STRING : 'a_STRING Grammar.Entry.e)))],
            Gramext.action
              (fun (a : 'a_STRING list) (loc : int * int) ->
                 (Qast.List a : 'a_list));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_list : 'a_list Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_list) (loc : int * int) -> (a : 'a_list))]],
        Gramext.action
          (fun (pd : 'a_list) _ (t : 'ctyp) _ (i : 'a_LIDENT) _
             (loc : int * int) ->
             (Qast.Node ("SgExt", [Qast.Loc; i; t; pd]) : 'sig_item));
        [Gramext.Stoken ("", "exception");
         Gramext.Snterm
           (Grammar.Entry.obj
              (constructor_declaration :
               'constructor_declaration Grammar.Entry.e))],
        Gramext.action
          (fun (ctl : 'constructor_declaration) _ (loc : int * int) ->
             (let (_, c, tl) =
                match ctl with
                  Qast.Tuple [xx1; xx2; xx3] -> xx1, xx2, xx3
                | _ ->
                    match () with
                    _ -> raise (Match_failure ("./meta/q_MLast.ml", 358, 19))
              in
              Qast.Node ("SgExc", [Qast.Loc; c; tl]) :
              'sig_item));
        [Gramext.Stoken ("", "declare");
         Gramext.srules
           [[Gramext.Slist0
               (Gramext.srules
                  [[Gramext.Snterm
                      (Grammar.Entry.obj
                         (sig_item : 'sig_item Grammar.Entry.e));
                    Gramext.Stoken ("", ";")],
                   Gramext.action
                     (fun _ (s : 'sig_item) (loc : int * int) ->
                        (s : 'e__5))])],
            Gramext.action
              (fun (a : 'e__5 list) (loc : int * int) ->
                 (Qast.List a : 'a_list));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_list : 'a_list Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_list) (loc : int * int) -> (a : 'a_list))];
         Gramext.Stoken ("", "end")],
        Gramext.action
          (fun _ (st : 'a_list) _ (loc : int * int) ->
             (Qast.Node ("SgDcl", [Qast.Loc; st]) : 'sig_item))]];
      Grammar.Entry.obj
        (module_declaration : 'module_declaration Grammar.Entry.e),
      None,
      [None, Some Gramext.RightA,
       [[Gramext.Stoken ("", "(");
         Gramext.Snterm
           (Grammar.Entry.obj (a_UIDENT : 'a_UIDENT Grammar.Entry.e));
         Gramext.Stoken ("", ":");
         Gramext.Snterm
           (Grammar.Entry.obj (module_type : 'module_type Grammar.Entry.e));
         Gramext.Stoken ("", ")"); Gramext.Sself],
        Gramext.action
          (fun (mt : 'module_declaration) _ (t : 'module_type) _
             (i : 'a_UIDENT) _ (loc : int * int) ->
             (Qast.Node ("MtFun", [Qast.Loc; i; t; mt]) :
              'module_declaration));
        [Gramext.Stoken ("", ":");
         Gramext.Snterm
           (Grammar.Entry.obj (module_type : 'module_type Grammar.Entry.e))],
        Gramext.action
          (fun (mt : 'module_type) _ (loc : int * int) ->
             (mt : 'module_declaration))]];
      Grammar.Entry.obj
        (module_rec_declaration : 'module_rec_declaration Grammar.Entry.e),
      None,
      [None, None,
       [[Gramext.Snterm
           (Grammar.Entry.obj (a_UIDENT : 'a_UIDENT Grammar.Entry.e));
         Gramext.Stoken ("", ":");
         Gramext.Snterm
           (Grammar.Entry.obj (module_type : 'module_type Grammar.Entry.e))],
        Gramext.action
          (fun (mt : 'module_type) _ (m : 'a_UIDENT) (loc : int * int) ->
             (Qast.Tuple [m; mt] : 'module_rec_declaration))]];
      Grammar.Entry.obj (with_constr : 'with_constr Grammar.Entry.e), None,
      [None, None,
       [[Gramext.Stoken ("", "module");
         Gramext.Snterm
           (Grammar.Entry.obj (mod_ident : 'mod_ident Grammar.Entry.e));
         Gramext.Stoken ("", "=");
         Gramext.Snterm
           (Grammar.Entry.obj (module_expr : 'module_expr Grammar.Entry.e))],
        Gramext.action
          (fun (me : 'module_expr) _ (i : 'mod_ident) _ (loc : int * int) ->
             (Qast.Node ("WcMod", [Qast.Loc; i; me]) : 'with_constr));
        [Gramext.Stoken ("", "type");
         Gramext.Snterm
           (Grammar.Entry.obj (mod_ident : 'mod_ident Grammar.Entry.e));
         Gramext.srules
           [[Gramext.Slist0
               (Gramext.Snterm
                  (Grammar.Entry.obj
                     (type_parameter : 'type_parameter Grammar.Entry.e)))],
            Gramext.action
              (fun (a : 'type_parameter list) (loc : int * int) ->
                 (Qast.List a : 'a_list));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_list : 'a_list Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_list) (loc : int * int) -> (a : 'a_list))];
         Gramext.Stoken ("", "=");
         Gramext.Snterm (Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e))],
        Gramext.action
          (fun (t : 'ctyp) _ (tpl : 'a_list) (i : 'mod_ident) _
             (loc : int * int) ->
             (Qast.Node ("WcTyp", [Qast.Loc; i; tpl; t]) : 'with_constr))]];
      Grammar.Entry.obj (expr : 'expr Grammar.Entry.e), None,
      [Some "top", Some Gramext.RightA,
       [[Gramext.Stoken ("", "while"); Gramext.Sself;
         Gramext.Stoken ("", "do"); Gramext.Stoken ("", "{");
         Gramext.Snterm
           (Grammar.Entry.obj (sequence : 'sequence Grammar.Entry.e));
         Gramext.Stoken ("", "}")],
        Gramext.action
          (fun _ (seq : 'sequence) _ _ (e : 'expr) _ (loc : int * int) ->
             (Qast.Node ("ExWhi", [Qast.Loc; e; seq]) : 'expr));
        [Gramext.Stoken ("", "for");
         Gramext.Snterm
           (Grammar.Entry.obj (a_LIDENT : 'a_LIDENT Grammar.Entry.e));
         Gramext.Stoken ("", "="); Gramext.Sself;
         Gramext.Snterm
           (Grammar.Entry.obj
              (direction_flag : 'direction_flag Grammar.Entry.e));
         Gramext.Sself; Gramext.Stoken ("", "do"); Gramext.Stoken ("", "{");
         Gramext.Snterm
           (Grammar.Entry.obj (sequence : 'sequence Grammar.Entry.e));
         Gramext.Stoken ("", "}")],
        Gramext.action
          (fun _ (seq : 'sequence) _ _ (e2 : 'expr) (df : 'direction_flag)
             (e1 : 'expr) _ (i : 'a_LIDENT) _ (loc : int * int) ->
             (Qast.Node ("ExFor", [Qast.Loc; i; e1; e2; df; seq]) : 'expr));
        [Gramext.Stoken ("", "do"); Gramext.Stoken ("", "{");
         Gramext.Snterm
           (Grammar.Entry.obj (sequence : 'sequence Grammar.Entry.e));
         Gramext.Stoken ("", "}")],
        Gramext.action
          (fun _ (seq : 'sequence) _ _ (loc : int * int) ->
             (mksequence Qast.Loc seq : 'expr));
        [Gramext.Stoken ("", "if"); Gramext.Sself;
         Gramext.Stoken ("", "then"); Gramext.Sself;
         Gramext.Stoken ("", "else"); Gramext.Sself],
        Gramext.action
          (fun (e3 : 'expr) _ (e2 : 'expr) _ (e1 : 'expr) _
             (loc : int * int) ->
             (Qast.Node ("ExIfe", [Qast.Loc; e1; e2; e3]) : 'expr));
        [Gramext.Stoken ("", "try"); Gramext.Sself;
         Gramext.Stoken ("", "with");
         Gramext.Snterm (Grammar.Entry.obj (ipatt : 'ipatt Grammar.Entry.e));
         Gramext.Stoken ("", "->"); Gramext.Sself],
        Gramext.action
          (fun (e1 : 'expr) _ (p1 : 'ipatt) _ (e : 'expr) _
             (loc : int * int) ->
             (Qast.Node
                ("ExTry",
                 [Qast.Loc; e;
                  Qast.List [Qast.Tuple [p1; Qast.Option None; e1]]]) :
              'expr));
        [Gramext.Stoken ("", "try"); Gramext.Sself;
         Gramext.Stoken ("", "with"); Gramext.Stoken ("", "[");
         Gramext.srules
           [[Gramext.Slist0sep
               (Gramext.Snterm
                  (Grammar.Entry.obj
                     (match_case : 'match_case Grammar.Entry.e)),
                Gramext.Stoken ("", "|"))],
            Gramext.action
              (fun (a : 'match_case list) (loc : int * int) ->
                 (Qast.List a : 'a_list));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_list : 'a_list Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_list) (loc : int * int) -> (a : 'a_list))];
         Gramext.Stoken ("", "]")],
        Gramext.action
          (fun _ (l : 'a_list) _ _ (e : 'expr) _ (loc : int * int) ->
             (Qast.Node ("ExTry", [Qast.Loc; e; l]) : 'expr));
        [Gramext.Stoken ("", "match"); Gramext.Sself;
         Gramext.Stoken ("", "with");
         Gramext.Snterm (Grammar.Entry.obj (ipatt : 'ipatt Grammar.Entry.e));
         Gramext.Stoken ("", "->"); Gramext.Sself],
        Gramext.action
          (fun (e1 : 'expr) _ (p1 : 'ipatt) _ (e : 'expr) _
             (loc : int * int) ->
             (Qast.Node
                ("ExMat",
                 [Qast.Loc; e;
                  Qast.List [Qast.Tuple [p1; Qast.Option None; e1]]]) :
              'expr));
        [Gramext.Stoken ("", "match"); Gramext.Sself;
         Gramext.Stoken ("", "with"); Gramext.Stoken ("", "[");
         Gramext.srules
           [[Gramext.Slist0sep
               (Gramext.Snterm
                  (Grammar.Entry.obj
                     (match_case : 'match_case Grammar.Entry.e)),
                Gramext.Stoken ("", "|"))],
            Gramext.action
              (fun (a : 'match_case list) (loc : int * int) ->
                 (Qast.List a : 'a_list));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_list : 'a_list Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_list) (loc : int * int) -> (a : 'a_list))];
         Gramext.Stoken ("", "]")],
        Gramext.action
          (fun _ (l : 'a_list) _ _ (e : 'expr) _ (loc : int * int) ->
             (Qast.Node ("ExMat", [Qast.Loc; e; l]) : 'expr));
        [Gramext.Stoken ("", "fun");
         Gramext.Snterm (Grammar.Entry.obj (ipatt : 'ipatt Grammar.Entry.e));
         Gramext.Snterm
           (Grammar.Entry.obj (fun_def : 'fun_def Grammar.Entry.e))],
        Gramext.action
          (fun (e : 'fun_def) (p : 'ipatt) _ (loc : int * int) ->
             (Qast.Node
                ("ExFun",
                 [Qast.Loc;
                  Qast.List [Qast.Tuple [p; Qast.Option None; e]]]) :
              'expr));
        [Gramext.Stoken ("", "fun"); Gramext.Stoken ("", "[");
         Gramext.srules
           [[Gramext.Slist0sep
               (Gramext.Snterm
                  (Grammar.Entry.obj
                     (match_case : 'match_case Grammar.Entry.e)),
                Gramext.Stoken ("", "|"))],
            Gramext.action
              (fun (a : 'match_case list) (loc : int * int) ->
                 (Qast.List a : 'a_list));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_list : 'a_list Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_list) (loc : int * int) -> (a : 'a_list))];
         Gramext.Stoken ("", "]")],
        Gramext.action
          (fun _ (l : 'a_list) _ _ (loc : int * int) ->
             (Qast.Node ("ExFun", [Qast.Loc; l]) : 'expr));
        [Gramext.Stoken ("", "let"); Gramext.Stoken ("", "module");
         Gramext.Snterm
           (Grammar.Entry.obj (a_UIDENT : 'a_UIDENT Grammar.Entry.e));
         Gramext.Snterm
           (Grammar.Entry.obj
              (module_binding : 'module_binding Grammar.Entry.e));
         Gramext.Stoken ("", "in"); Gramext.Sself],
        Gramext.action
          (fun (e : 'expr) _ (mb : 'module_binding) (m : 'a_UIDENT) _ _
             (loc : int * int) ->
             (Qast.Node ("ExLmd", [Qast.Loc; m; mb; e]) : 'expr));
        [Gramext.Stoken ("", "let");
         Gramext.srules
           [[Gramext.Sopt
               (Gramext.srules
                  [[Gramext.Stoken ("", "rec")],
                   Gramext.action
                     (fun (x : string) (loc : int * int) ->
                        (Qast.Str x : 'e__6))])],
            Gramext.action
              (fun (a : 'e__6 option) (loc : int * int) ->
                 (Qast.Option a : 'a_opt));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_opt : 'a_opt Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_opt) (loc : int * int) -> (a : 'a_opt))];
         Gramext.srules
           [[Gramext.Slist1sep
               (Gramext.Snterm
                  (Grammar.Entry.obj
                     (let_binding : 'let_binding Grammar.Entry.e)),
                Gramext.Stoken ("", "and"))],
            Gramext.action
              (fun (a : 'let_binding list) (loc : int * int) ->
                 (Qast.List a : 'a_list));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_list : 'a_list Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_list) (loc : int * int) -> (a : 'a_list))];
         Gramext.Stoken ("", "in"); Gramext.Sself],
        Gramext.action
          (fun (x : 'expr) _ (l : 'a_list) (r : 'a_opt) _ (loc : int * int) ->
             (Qast.Node ("ExLet", [Qast.Loc; o2b r; l; x]) : 'expr))];
       Some "where", None,
       [[Gramext.Sself; Gramext.Stoken ("", "where");
         Gramext.srules
           [[Gramext.Sopt
               (Gramext.srules
                  [[Gramext.Stoken ("", "rec")],
                   Gramext.action
                     (fun (x : string) (loc : int * int) ->
                        (Qast.Str x : 'e__7))])],
            Gramext.action
              (fun (a : 'e__7 option) (loc : int * int) ->
                 (Qast.Option a : 'a_opt));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_opt : 'a_opt Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_opt) (loc : int * int) -> (a : 'a_opt))];
         Gramext.Snterm
           (Grammar.Entry.obj (let_binding : 'let_binding Grammar.Entry.e))],
        Gramext.action
          (fun (lb : 'let_binding) (rf : 'a_opt) _ (e : 'expr)
             (loc : int * int) ->
             (Qast.Node ("ExLet", [Qast.Loc; o2b rf; Qast.List [lb]; e]) :
              'expr))];
       Some ":=", Some Gramext.NonA,
       [[Gramext.Sself; Gramext.Stoken ("", ":="); Gramext.Sself;
         Gramext.Snterm (Grammar.Entry.obj (dummy : 'dummy Grammar.Entry.e))],
        Gramext.action
          (fun _ (e2 : 'expr) _ (e1 : 'expr) (loc : int * int) ->
             (Qast.Node ("ExAss", [Qast.Loc; e1; e2]) : 'expr))];
       Some "||", Some Gramext.RightA,
       [[Gramext.Sself; Gramext.Stoken ("", "||"); Gramext.Sself],
        Gramext.action
          (fun (e2 : 'expr) _ (e1 : 'expr) (loc : int * int) ->
             (Qast.Node
                ("ExApp",
                 [Qast.Loc;
                  Qast.Node
                    ("ExApp",
                     [Qast.Loc;
                      Qast.Node ("ExLid", [Qast.Loc; Qast.Str "||"]); e1]);
                  e2]) :
              'expr))];
       Some "&&", Some Gramext.RightA,
       [[Gramext.Sself; Gramext.Stoken ("", "&&"); Gramext.Sself],
        Gramext.action
          (fun (e2 : 'expr) _ (e1 : 'expr) (loc : int * int) ->
             (Qast.Node
                ("ExApp",
                 [Qast.Loc;
                  Qast.Node
                    ("ExApp",
                     [Qast.Loc;
                      Qast.Node ("ExLid", [Qast.Loc; Qast.Str "&&"]); e1]);
                  e2]) :
              'expr))];
       Some "<", Some Gramext.LeftA,
       [[Gramext.Sself; Gramext.Stoken ("", "!="); Gramext.Sself],
        Gramext.action
          (fun (e2 : 'expr) _ (e1 : 'expr) (loc : int * int) ->
             (Qast.Node
                ("ExApp",
                 [Qast.Loc;
                  Qast.Node
                    ("ExApp",
                     [Qast.Loc;
                      Qast.Node ("ExLid", [Qast.Loc; Qast.Str "!="]); e1]);
                  e2]) :
              'expr));
        [Gramext.Sself; Gramext.Stoken ("", "=="); Gramext.Sself],
        Gramext.action
          (fun (e2 : 'expr) _ (e1 : 'expr) (loc : int * int) ->
             (Qast.Node
                ("ExApp",
                 [Qast.Loc;
                  Qast.Node
                    ("ExApp",
                     [Qast.Loc;
                      Qast.Node ("ExLid", [Qast.Loc; Qast.Str "=="]); e1]);
                  e2]) :
              'expr));
        [Gramext.Sself; Gramext.Stoken ("", "<>"); Gramext.Sself],
        Gramext.action
          (fun (e2 : 'expr) _ (e1 : 'expr) (loc : int * int) ->
             (Qast.Node
                ("ExApp",
                 [Qast.Loc;
                  Qast.Node
                    ("ExApp",
                     [Qast.Loc;
                      Qast.Node ("ExLid", [Qast.Loc; Qast.Str "<>"]); e1]);
                  e2]) :
              'expr));
        [Gramext.Sself; Gramext.Stoken ("", "="); Gramext.Sself],
        Gramext.action
          (fun (e2 : 'expr) _ (e1 : 'expr) (loc : int * int) ->
             (Qast.Node
                ("ExApp",
                 [Qast.Loc;
                  Qast.Node
                    ("ExApp",
                     [Qast.Loc; Qast.Node ("ExLid", [Qast.Loc; Qast.Str "="]);
                      e1]);
                  e2]) :
              'expr));
        [Gramext.Sself; Gramext.Stoken ("", ">="); Gramext.Sself],
        Gramext.action
          (fun (e2 : 'expr) _ (e1 : 'expr) (loc : int * int) ->
             (Qast.Node
                ("ExApp",
                 [Qast.Loc;
                  Qast.Node
                    ("ExApp",
                     [Qast.Loc;
                      Qast.Node ("ExLid", [Qast.Loc; Qast.Str ">="]); e1]);
                  e2]) :
              'expr));
        [Gramext.Sself; Gramext.Stoken ("", "<="); Gramext.Sself],
        Gramext.action
          (fun (e2 : 'expr) _ (e1 : 'expr) (loc : int * int) ->
             (Qast.Node
                ("ExApp",
                 [Qast.Loc;
                  Qast.Node
                    ("ExApp",
                     [Qast.Loc;
                      Qast.Node ("ExLid", [Qast.Loc; Qast.Str "<="]); e1]);
                  e2]) :
              'expr));
        [Gramext.Sself; Gramext.Stoken ("", ">"); Gramext.Sself],
        Gramext.action
          (fun (e2 : 'expr) _ (e1 : 'expr) (loc : int * int) ->
             (Qast.Node
                ("ExApp",
                 [Qast.Loc;
                  Qast.Node
                    ("ExApp",
                     [Qast.Loc; Qast.Node ("ExLid", [Qast.Loc; Qast.Str ">"]);
                      e1]);
                  e2]) :
              'expr));
        [Gramext.Sself; Gramext.Stoken ("", "<"); Gramext.Sself],
        Gramext.action
          (fun (e2 : 'expr) _ (e1 : 'expr) (loc : int * int) ->
             (Qast.Node
                ("ExApp",
                 [Qast.Loc;
                  Qast.Node
                    ("ExApp",
                     [Qast.Loc; Qast.Node ("ExLid", [Qast.Loc; Qast.Str "<"]);
                      e1]);
                  e2]) :
              'expr))];
       Some "^", Some Gramext.RightA,
       [[Gramext.Sself; Gramext.Stoken ("", "@"); Gramext.Sself],
        Gramext.action
          (fun (e2 : 'expr) _ (e1 : 'expr) (loc : int * int) ->
             (Qast.Node
                ("ExApp",
                 [Qast.Loc;
                  Qast.Node
                    ("ExApp",
                     [Qast.Loc; Qast.Node ("ExLid", [Qast.Loc; Qast.Str "@"]);
                      e1]);
                  e2]) :
              'expr));
        [Gramext.Sself; Gramext.Stoken ("", "^"); Gramext.Sself],
        Gramext.action
          (fun (e2 : 'expr) _ (e1 : 'expr) (loc : int * int) ->
             (Qast.Node
                ("ExApp",
                 [Qast.Loc;
                  Qast.Node
                    ("ExApp",
                     [Qast.Loc; Qast.Node ("ExLid", [Qast.Loc; Qast.Str "^"]);
                      e1]);
                  e2]) :
              'expr))];
       Some "+", Some Gramext.LeftA,
       [[Gramext.Sself; Gramext.Stoken ("", "-."); Gramext.Sself],
        Gramext.action
          (fun (e2 : 'expr) _ (e1 : 'expr) (loc : int * int) ->
             (Qast.Node
                ("ExApp",
                 [Qast.Loc;
                  Qast.Node
                    ("ExApp",
                     [Qast.Loc;
                      Qast.Node ("ExLid", [Qast.Loc; Qast.Str "-."]); e1]);
                  e2]) :
              'expr));
        [Gramext.Sself; Gramext.Stoken ("", "+."); Gramext.Sself],
        Gramext.action
          (fun (e2 : 'expr) _ (e1 : 'expr) (loc : int * int) ->
             (Qast.Node
                ("ExApp",
                 [Qast.Loc;
                  Qast.Node
                    ("ExApp",
                     [Qast.Loc;
                      Qast.Node ("ExLid", [Qast.Loc; Qast.Str "+."]); e1]);
                  e2]) :
              'expr));
        [Gramext.Sself; Gramext.Stoken ("", "-"); Gramext.Sself],
        Gramext.action
          (fun (e2 : 'expr) _ (e1 : 'expr) (loc : int * int) ->
             (Qast.Node
                ("ExApp",
                 [Qast.Loc;
                  Qast.Node
                    ("ExApp",
                     [Qast.Loc; Qast.Node ("ExLid", [Qast.Loc; Qast.Str "-"]);
                      e1]);
                  e2]) :
              'expr));
        [Gramext.Sself; Gramext.Stoken ("", "+"); Gramext.Sself],
        Gramext.action
          (fun (e2 : 'expr) _ (e1 : 'expr) (loc : int * int) ->
             (Qast.Node
                ("ExApp",
                 [Qast.Loc;
                  Qast.Node
                    ("ExApp",
                     [Qast.Loc; Qast.Node ("ExLid", [Qast.Loc; Qast.Str "+"]);
                      e1]);
                  e2]) :
              'expr))];
       Some "*", Some Gramext.LeftA,
       [[Gramext.Sself; Gramext.Stoken ("", "mod"); Gramext.Sself],
        Gramext.action
          (fun (e2 : 'expr) _ (e1 : 'expr) (loc : int * int) ->
             (Qast.Node
                ("ExApp",
                 [Qast.Loc;
                  Qast.Node
                    ("ExApp",
                     [Qast.Loc;
                      Qast.Node ("ExLid", [Qast.Loc; Qast.Str "mod"]); e1]);
                  e2]) :
              'expr));
        [Gramext.Sself; Gramext.Stoken ("", "lxor"); Gramext.Sself],
        Gramext.action
          (fun (e2 : 'expr) _ (e1 : 'expr) (loc : int * int) ->
             (Qast.Node
                ("ExApp",
                 [Qast.Loc;
                  Qast.Node
                    ("ExApp",
                     [Qast.Loc;
                      Qast.Node ("ExLid", [Qast.Loc; Qast.Str "lxor"]); e1]);
                  e2]) :
              'expr));
        [Gramext.Sself; Gramext.Stoken ("", "lor"); Gramext.Sself],
        Gramext.action
          (fun (e2 : 'expr) _ (e1 : 'expr) (loc : int * int) ->
             (Qast.Node
                ("ExApp",
                 [Qast.Loc;
                  Qast.Node
                    ("ExApp",
                     [Qast.Loc;
                      Qast.Node ("ExLid", [Qast.Loc; Qast.Str "lor"]); e1]);
                  e2]) :
              'expr));
        [Gramext.Sself; Gramext.Stoken ("", "land"); Gramext.Sself],
        Gramext.action
          (fun (e2 : 'expr) _ (e1 : 'expr) (loc : int * int) ->
             (Qast.Node
                ("ExApp",
                 [Qast.Loc;
                  Qast.Node
                    ("ExApp",
                     [Qast.Loc;
                      Qast.Node ("ExLid", [Qast.Loc; Qast.Str "land"]); e1]);
                  e2]) :
              'expr));
        [Gramext.Sself; Gramext.Stoken ("", "/."); Gramext.Sself],
        Gramext.action
          (fun (e2 : 'expr) _ (e1 : 'expr) (loc : int * int) ->
             (Qast.Node
                ("ExApp",
                 [Qast.Loc;
                  Qast.Node
                    ("ExApp",
                     [Qast.Loc;
                      Qast.Node ("ExLid", [Qast.Loc; Qast.Str "/."]); e1]);
                  e2]) :
              'expr));
        [Gramext.Sself; Gramext.Stoken ("", "*."); Gramext.Sself],
        Gramext.action
          (fun (e2 : 'expr) _ (e1 : 'expr) (loc : int * int) ->
             (Qast.Node
                ("ExApp",
                 [Qast.Loc;
                  Qast.Node
                    ("ExApp",
                     [Qast.Loc;
                      Qast.Node ("ExLid", [Qast.Loc; Qast.Str "*."]); e1]);
                  e2]) :
              'expr));
        [Gramext.Sself; Gramext.Stoken ("", "/"); Gramext.Sself],
        Gramext.action
          (fun (e2 : 'expr) _ (e1 : 'expr) (loc : int * int) ->
             (Qast.Node
                ("ExApp",
                 [Qast.Loc;
                  Qast.Node
                    ("ExApp",
                     [Qast.Loc; Qast.Node ("ExLid", [Qast.Loc; Qast.Str "/"]);
                      e1]);
                  e2]) :
              'expr));
        [Gramext.Sself; Gramext.Stoken ("", "*"); Gramext.Sself],
        Gramext.action
          (fun (e2 : 'expr) _ (e1 : 'expr) (loc : int * int) ->
             (Qast.Node
                ("ExApp",
                 [Qast.Loc;
                  Qast.Node
                    ("ExApp",
                     [Qast.Loc; Qast.Node ("ExLid", [Qast.Loc; Qast.Str "*"]);
                      e1]);
                  e2]) :
              'expr))];
       Some "**", Some Gramext.RightA,
       [[Gramext.Sself; Gramext.Stoken ("", "lsr"); Gramext.Sself],
        Gramext.action
          (fun (e2 : 'expr) _ (e1 : 'expr) (loc : int * int) ->
             (Qast.Node
                ("ExApp",
                 [Qast.Loc;
                  Qast.Node
                    ("ExApp",
                     [Qast.Loc;
                      Qast.Node ("ExLid", [Qast.Loc; Qast.Str "lsr"]); e1]);
                  e2]) :
              'expr));
        [Gramext.Sself; Gramext.Stoken ("", "lsl"); Gramext.Sself],
        Gramext.action
          (fun (e2 : 'expr) _ (e1 : 'expr) (loc : int * int) ->
             (Qast.Node
                ("ExApp",
                 [Qast.Loc;
                  Qast.Node
                    ("ExApp",
                     [Qast.Loc;
                      Qast.Node ("ExLid", [Qast.Loc; Qast.Str "lsl"]); e1]);
                  e2]) :
              'expr));
        [Gramext.Sself; Gramext.Stoken ("", "asr"); Gramext.Sself],
        Gramext.action
          (fun (e2 : 'expr) _ (e1 : 'expr) (loc : int * int) ->
             (Qast.Node
                ("ExApp",
                 [Qast.Loc;
                  Qast.Node
                    ("ExApp",
                     [Qast.Loc;
                      Qast.Node ("ExLid", [Qast.Loc; Qast.Str "asr"]); e1]);
                  e2]) :
              'expr));
        [Gramext.Sself; Gramext.Stoken ("", "**"); Gramext.Sself],
        Gramext.action
          (fun (e2 : 'expr) _ (e1 : 'expr) (loc : int * int) ->
             (Qast.Node
                ("ExApp",
                 [Qast.Loc;
                  Qast.Node
                    ("ExApp",
                     [Qast.Loc;
                      Qast.Node ("ExLid", [Qast.Loc; Qast.Str "**"]); e1]);
                  e2]) :
              'expr))];
       Some "unary minus", Some Gramext.NonA,
       [[Gramext.Stoken ("", "-."); Gramext.Sself],
        Gramext.action
          (fun (e : 'expr) _ (loc : int * int) ->
             (mkumin Qast.Loc (Qast.Str "-.") e : 'expr));
        [Gramext.Stoken ("", "-"); Gramext.Sself],
        Gramext.action
          (fun (e : 'expr) _ (loc : int * int) ->
             (mkumin Qast.Loc (Qast.Str "-") e : 'expr))];
       Some "apply", Some Gramext.LeftA,
       [[Gramext.Stoken ("", "lazy"); Gramext.Sself],
        Gramext.action
          (fun (e : 'expr) _ (loc : int * int) ->
             (Qast.Node ("ExLaz", [Qast.Loc; e]) : 'expr));
        [Gramext.Stoken ("", "assert"); Gramext.Sself],
        Gramext.action
          (fun (e : 'expr) _ (loc : int * int) ->
             (mkassert Qast.Loc e : 'expr));
        [Gramext.Sself; Gramext.Sself],
        Gramext.action
          (fun (e2 : 'expr) (e1 : 'expr) (loc : int * int) ->
             (Qast.Node ("ExApp", [Qast.Loc; e1; e2]) : 'expr))];
       Some ".", Some Gramext.LeftA,
       [[Gramext.Sself; Gramext.Stoken ("", "."); Gramext.Sself],
        Gramext.action
          (fun (e2 : 'expr) _ (e1 : 'expr) (loc : int * int) ->
             (Qast.Node ("ExAcc", [Qast.Loc; e1; e2]) : 'expr));
        [Gramext.Sself; Gramext.Stoken ("", "."); Gramext.Stoken ("", "[");
         Gramext.Sself; Gramext.Stoken ("", "]")],
        Gramext.action
          (fun _ (e2 : 'expr) _ _ (e1 : 'expr) (loc : int * int) ->
             (Qast.Node ("ExSte", [Qast.Loc; e1; e2]) : 'expr));
        [Gramext.Sself; Gramext.Stoken ("", "."); Gramext.Stoken ("", "(");
         Gramext.Sself; Gramext.Stoken ("", ")")],
        Gramext.action
          (fun _ (e2 : 'expr) _ _ (e1 : 'expr) (loc : int * int) ->
             (Qast.Node ("ExAre", [Qast.Loc; e1; e2]) : 'expr))];
       Some "~-", Some Gramext.NonA,
       [[Gramext.Stoken ("", "~-."); Gramext.Sself],
        Gramext.action
          (fun (e : 'expr) _ (loc : int * int) ->
             (Qast.Node
                ("ExApp",
                 [Qast.Loc; Qast.Node ("ExLid", [Qast.Loc; Qast.Str "~-."]);
                  e]) :
              'expr));
        [Gramext.Stoken ("", "~-"); Gramext.Sself],
        Gramext.action
          (fun (e : 'expr) _ (loc : int * int) ->
             (Qast.Node
                ("ExApp",
                 [Qast.Loc; Qast.Node ("ExLid", [Qast.Loc; Qast.Str "~-"]);
                  e]) :
              'expr))];
       Some "simple", None,
       [[Gramext.Stoken ("", "("); Gramext.Sself; Gramext.Stoken ("", ")")],
        Gramext.action (fun _ (e : 'expr) _ (loc : int * int) -> (e : 'expr));
        [Gramext.Stoken ("", "("); Gramext.Sself; Gramext.Stoken ("", ",");
         Gramext.srules
           [[Gramext.Slist1sep
               (Gramext.Snterm
                  (Grammar.Entry.obj (expr : 'expr Grammar.Entry.e)),
                Gramext.Stoken ("", ","))],
            Gramext.action
              (fun (a : 'expr list) (loc : int * int) ->
                 (Qast.List a : 'a_list));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_list : 'a_list Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_list) (loc : int * int) -> (a : 'a_list))];
         Gramext.Stoken ("", ")")],
        Gramext.action
          (fun _ (el : 'a_list) _ (e : 'expr) _ (loc : int * int) ->
             (Qast.Node ("ExTup", [Qast.Loc; Qast.Cons (e, el)]) : 'expr));
        [Gramext.Stoken ("", "("); Gramext.Sself; Gramext.Stoken ("", ":");
         Gramext.Snterm (Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e));
         Gramext.Stoken ("", ")")],
        Gramext.action
          (fun _ (t : 'ctyp) _ (e : 'expr) _ (loc : int * int) ->
             (Qast.Node ("ExTyc", [Qast.Loc; e; t]) : 'expr));
        [Gramext.Stoken ("", "("); Gramext.Stoken ("", ")")],
        Gramext.action
          (fun _ _ (loc : int * int) ->
             (Qast.Node ("ExUid", [Qast.Loc; Qast.Str "()"]) : 'expr));
        [Gramext.Stoken ("", "{"); Gramext.Stoken ("", "("); Gramext.Sself;
         Gramext.Stoken ("", ")"); Gramext.Stoken ("", "with");
         Gramext.srules
           [[Gramext.Slist1sep
               (Gramext.Snterm
                  (Grammar.Entry.obj
                     (label_expr : 'label_expr Grammar.Entry.e)),
                Gramext.Stoken ("", ";"))],
            Gramext.action
              (fun (a : 'label_expr list) (loc : int * int) ->
                 (Qast.List a : 'a_list));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_list : 'a_list Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_list) (loc : int * int) -> (a : 'a_list))];
         Gramext.Stoken ("", "}")],
        Gramext.action
          (fun _ (lel : 'a_list) _ _ (e : 'expr) _ _ (loc : int * int) ->
             (Qast.Node ("ExRec", [Qast.Loc; lel; Qast.Option (Some e)]) :
              'expr));
        [Gramext.Stoken ("", "{");
         Gramext.srules
           [[Gramext.Slist1sep
               (Gramext.Snterm
                  (Grammar.Entry.obj
                     (label_expr : 'label_expr Grammar.Entry.e)),
                Gramext.Stoken ("", ";"))],
            Gramext.action
              (fun (a : 'label_expr list) (loc : int * int) ->
                 (Qast.List a : 'a_list));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_list : 'a_list Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_list) (loc : int * int) -> (a : 'a_list))];
         Gramext.Stoken ("", "}")],
        Gramext.action
          (fun _ (lel : 'a_list) _ (loc : int * int) ->
             (Qast.Node ("ExRec", [Qast.Loc; lel; Qast.Option None]) :
              'expr));
        [Gramext.Stoken ("", "[|");
         Gramext.srules
           [[Gramext.Slist0sep
               (Gramext.Snterm
                  (Grammar.Entry.obj (expr : 'expr Grammar.Entry.e)),
                Gramext.Stoken ("", ";"))],
            Gramext.action
              (fun (a : 'expr list) (loc : int * int) ->
                 (Qast.List a : 'a_list));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_list : 'a_list Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_list) (loc : int * int) -> (a : 'a_list))];
         Gramext.Stoken ("", "|]")],
        Gramext.action
          (fun _ (el : 'a_list) _ (loc : int * int) ->
             (Qast.Node ("ExArr", [Qast.Loc; el]) : 'expr));
        [Gramext.Stoken ("", "[");
         Gramext.srules
           [[Gramext.Slist1sep
               (Gramext.Snterm
                  (Grammar.Entry.obj (expr : 'expr Grammar.Entry.e)),
                Gramext.Stoken ("", ";"))],
            Gramext.action
              (fun (a : 'expr list) (loc : int * int) ->
                 (Qast.List a : 'a_list));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_list : 'a_list Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_list) (loc : int * int) -> (a : 'a_list))];
         Gramext.Snterm
           (Grammar.Entry.obj
              (cons_expr_opt : 'cons_expr_opt Grammar.Entry.e));
         Gramext.Stoken ("", "]")],
        Gramext.action
          (fun _ (last : 'cons_expr_opt) (el : 'a_list) _ (loc : int * int) ->
             (mklistexp Qast.Loc last el : 'expr));
        [Gramext.Stoken ("", "["); Gramext.Stoken ("", "]")],
        Gramext.action
          (fun _ _ (loc : int * int) ->
             (Qast.Node ("ExUid", [Qast.Loc; Qast.Str "[]"]) : 'expr));
        [Gramext.Snterm
           (Grammar.Entry.obj (expr_ident : 'expr_ident Grammar.Entry.e))],
        Gramext.action
          (fun (i : 'expr_ident) (loc : int * int) -> (i : 'expr));
        [Gramext.Snterm
           (Grammar.Entry.obj (a_CHAR : 'a_CHAR Grammar.Entry.e))],
        Gramext.action
          (fun (s : 'a_CHAR) (loc : int * int) ->
             (Qast.Node ("ExChr", [Qast.Loc; s]) : 'expr));
        [Gramext.Snterm
           (Grammar.Entry.obj (a_STRING : 'a_STRING Grammar.Entry.e))],
        Gramext.action
          (fun (s : 'a_STRING) (loc : int * int) ->
             (Qast.Node ("ExStr", [Qast.Loc; s]) : 'expr));
        [Gramext.Snterm
           (Grammar.Entry.obj (a_FLOAT : 'a_FLOAT Grammar.Entry.e))],
        Gramext.action
          (fun (s : 'a_FLOAT) (loc : int * int) ->
             (Qast.Node ("ExFlo", [Qast.Loc; s]) : 'expr));
        [Gramext.Snterm (Grammar.Entry.obj (a_INT : 'a_INT Grammar.Entry.e))],
        Gramext.action
          (fun (s : 'a_INT) (loc : int * int) ->
             (Qast.Node ("ExInt", [Qast.Loc; s]) : 'expr))]];
      Grammar.Entry.obj (cons_expr_opt : 'cons_expr_opt Grammar.Entry.e),
      None,
      [None, None,
       [[],
        Gramext.action
          (fun (loc : int * int) -> (Qast.Option None : 'cons_expr_opt));
        [Gramext.Stoken ("", "::");
         Gramext.Snterm (Grammar.Entry.obj (expr : 'expr Grammar.Entry.e))],
        Gramext.action
          (fun (e : 'expr) _ (loc : int * int) ->
             (Qast.Option (Some e) : 'cons_expr_opt))]];
      Grammar.Entry.obj (dummy : 'dummy Grammar.Entry.e), None,
      [None, None,
       [[], Gramext.action (fun (loc : int * int) -> (() : 'dummy))]];
      Grammar.Entry.obj (sequence : 'sequence Grammar.Entry.e), None,
      [None, None,
       [[Gramext.Snterm (Grammar.Entry.obj (expr : 'expr Grammar.Entry.e))],
        Gramext.action
          (fun (e : 'expr) (loc : int * int) -> (Qast.List [e] : 'sequence));
        [Gramext.Snterm (Grammar.Entry.obj (expr : 'expr Grammar.Entry.e));
         Gramext.Stoken ("", ";")],
        Gramext.action
          (fun _ (e : 'expr) (loc : int * int) ->
             (Qast.List [e] : 'sequence));
        [Gramext.Snterm (Grammar.Entry.obj (expr : 'expr Grammar.Entry.e));
         Gramext.Stoken ("", ";"); Gramext.Sself],
        Gramext.action
          (fun (el : 'sequence) _ (e : 'expr) (loc : int * int) ->
             (Qast.Cons (e, el) : 'sequence));
        [Gramext.Stoken ("", "let");
         Gramext.srules
           [[Gramext.Sopt
               (Gramext.srules
                  [[Gramext.Stoken ("", "rec")],
                   Gramext.action
                     (fun (x : string) (loc : int * int) ->
                        (Qast.Str x : 'e__8))])],
            Gramext.action
              (fun (a : 'e__8 option) (loc : int * int) ->
                 (Qast.Option a : 'a_opt));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_opt : 'a_opt Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_opt) (loc : int * int) -> (a : 'a_opt))];
         Gramext.srules
           [[Gramext.Slist1sep
               (Gramext.Snterm
                  (Grammar.Entry.obj
                     (let_binding : 'let_binding Grammar.Entry.e)),
                Gramext.Stoken ("", "and"))],
            Gramext.action
              (fun (a : 'let_binding list) (loc : int * int) ->
                 (Qast.List a : 'a_list));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_list : 'a_list Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_list) (loc : int * int) -> (a : 'a_list))];
         Gramext.srules
           [[Gramext.Stoken ("", ";")],
            Gramext.action
              (fun (x : string) (loc : int * int) -> (x : 'e__9));
            [Gramext.Stoken ("", "in")],
            Gramext.action
              (fun (x : string) (loc : int * int) -> (x : 'e__9))];
         Gramext.Sself],
        Gramext.action
          (fun (el : 'sequence) _ (l : 'a_list) (rf : 'a_opt) _
             (loc : int * int) ->
             (Qast.List
                [Qast.Node
                   ("ExLet", [Qast.Loc; o2b rf; l; mksequence Qast.Loc el])] :
              'sequence))]];
      Grammar.Entry.obj (let_binding : 'let_binding Grammar.Entry.e), None,
      [None, None,
       [[Gramext.Snterm (Grammar.Entry.obj (ipatt : 'ipatt Grammar.Entry.e));
         Gramext.Snterm
           (Grammar.Entry.obj (fun_binding : 'fun_binding Grammar.Entry.e))],
        Gramext.action
          (fun (e : 'fun_binding) (p : 'ipatt) (loc : int * int) ->
             (Qast.Tuple [p; e] : 'let_binding))]];
      Grammar.Entry.obj (fun_binding : 'fun_binding Grammar.Entry.e), None,
      [None, Some Gramext.RightA,
       [[Gramext.Stoken ("", ":");
         Gramext.Snterm (Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e));
         Gramext.Stoken ("", "=");
         Gramext.Snterm (Grammar.Entry.obj (expr : 'expr Grammar.Entry.e))],
        Gramext.action
          (fun (e : 'expr) _ (t : 'ctyp) _ (loc : int * int) ->
             (Qast.Node ("ExTyc", [Qast.Loc; e; t]) : 'fun_binding));
        [Gramext.Stoken ("", "=");
         Gramext.Snterm (Grammar.Entry.obj (expr : 'expr Grammar.Entry.e))],
        Gramext.action
          (fun (e : 'expr) _ (loc : int * int) -> (e : 'fun_binding));
        [Gramext.Snterm (Grammar.Entry.obj (ipatt : 'ipatt Grammar.Entry.e));
         Gramext.Sself],
        Gramext.action
          (fun (e : 'fun_binding) (p : 'ipatt) (loc : int * int) ->
             (Qast.Node
                ("ExFun",
                 [Qast.Loc;
                  Qast.List [Qast.Tuple [p; Qast.Option None; e]]]) :
              'fun_binding))]];
      Grammar.Entry.obj (match_case : 'match_case Grammar.Entry.e), None,
      [None, None,
       [[Gramext.Snterm (Grammar.Entry.obj (patt : 'patt Grammar.Entry.e));
         Gramext.Snterm
           (Grammar.Entry.obj (as_patt_opt : 'as_patt_opt Grammar.Entry.e));
         Gramext.Snterm
           (Grammar.Entry.obj
              (when_expr_opt : 'when_expr_opt Grammar.Entry.e));
         Gramext.Stoken ("", "->");
         Gramext.Snterm (Grammar.Entry.obj (expr : 'expr Grammar.Entry.e))],
        Gramext.action
          (fun (e : 'expr) _ (w : 'when_expr_opt) (aso : 'as_patt_opt)
             (p : 'patt) (loc : int * int) ->
             (mkmatchcase Qast.Loc p aso w e : 'match_case))]];
      Grammar.Entry.obj (as_patt_opt : 'as_patt_opt Grammar.Entry.e), None,
      [None, None,
       [[],
        Gramext.action
          (fun (loc : int * int) -> (Qast.Option None : 'as_patt_opt));
        [Gramext.Stoken ("", "as");
         Gramext.Snterm (Grammar.Entry.obj (patt : 'patt Grammar.Entry.e))],
        Gramext.action
          (fun (p : 'patt) _ (loc : int * int) ->
             (Qast.Option (Some p) : 'as_patt_opt))]];
      Grammar.Entry.obj (when_expr_opt : 'when_expr_opt Grammar.Entry.e),
      None,
      [None, None,
       [[],
        Gramext.action
          (fun (loc : int * int) -> (Qast.Option None : 'when_expr_opt));
        [Gramext.Stoken ("", "when");
         Gramext.Snterm (Grammar.Entry.obj (expr : 'expr Grammar.Entry.e))],
        Gramext.action
          (fun (e : 'expr) _ (loc : int * int) ->
             (Qast.Option (Some e) : 'when_expr_opt))]];
      Grammar.Entry.obj (label_expr : 'label_expr Grammar.Entry.e), None,
      [None, None,
       [[Gramext.Snterm
           (Grammar.Entry.obj
              (patt_label_ident : 'patt_label_ident Grammar.Entry.e));
         Gramext.Snterm
           (Grammar.Entry.obj (fun_binding : 'fun_binding Grammar.Entry.e))],
        Gramext.action
          (fun (e : 'fun_binding) (i : 'patt_label_ident) (loc : int * int) ->
             (Qast.Tuple [i; e] : 'label_expr))]];
      Grammar.Entry.obj (expr_ident : 'expr_ident Grammar.Entry.e), None,
      [None, Some Gramext.RightA,
       [[Gramext.Snterm
           (Grammar.Entry.obj (a_UIDENT : 'a_UIDENT Grammar.Entry.e));
         Gramext.Stoken ("", "."); Gramext.Sself],
        Gramext.action
          (fun (j : 'expr_ident) _ (i : 'a_UIDENT) (loc : int * int) ->
             (mkexprident Qast.Loc i j : 'expr_ident));
        [Gramext.Snterm
           (Grammar.Entry.obj (a_UIDENT : 'a_UIDENT Grammar.Entry.e))],
        Gramext.action
          (fun (i : 'a_UIDENT) (loc : int * int) ->
             (Qast.Node ("ExUid", [Qast.Loc; i]) : 'expr_ident));
        [Gramext.Snterm
           (Grammar.Entry.obj (a_LIDENT : 'a_LIDENT Grammar.Entry.e))],
        Gramext.action
          (fun (i : 'a_LIDENT) (loc : int * int) ->
             (Qast.Node ("ExLid", [Qast.Loc; i]) : 'expr_ident))]];
      Grammar.Entry.obj (fun_def : 'fun_def Grammar.Entry.e), None,
      [None, Some Gramext.RightA,
       [[Gramext.Stoken ("", "->");
         Gramext.Snterm (Grammar.Entry.obj (expr : 'expr Grammar.Entry.e))],
        Gramext.action
          (fun (e : 'expr) _ (loc : int * int) -> (e : 'fun_def));
        [Gramext.Snterm (Grammar.Entry.obj (ipatt : 'ipatt Grammar.Entry.e));
         Gramext.Sself],
        Gramext.action
          (fun (e : 'fun_def) (p : 'ipatt) (loc : int * int) ->
             (Qast.Node
                ("ExFun",
                 [Qast.Loc;
                  Qast.List [Qast.Tuple [p; Qast.Option None; e]]]) :
              'fun_def))]];
      Grammar.Entry.obj (patt : 'patt Grammar.Entry.e), None,
      [None, Some Gramext.LeftA,
       [[Gramext.Sself; Gramext.Stoken ("", "|"); Gramext.Sself],
        Gramext.action
          (fun (p2 : 'patt) _ (p1 : 'patt) (loc : int * int) ->
             (Qast.Node ("PaOrp", [Qast.Loc; p1; p2]) : 'patt))];
       None, Some Gramext.NonA,
       [[Gramext.Sself; Gramext.Stoken ("", ".."); Gramext.Sself],
        Gramext.action
          (fun (p2 : 'patt) _ (p1 : 'patt) (loc : int * int) ->
             (Qast.Node ("PaRng", [Qast.Loc; p1; p2]) : 'patt))];
       None, Some Gramext.LeftA,
       [[Gramext.Sself; Gramext.Sself],
        Gramext.action
          (fun (p2 : 'patt) (p1 : 'patt) (loc : int * int) ->
             (Qast.Node ("PaApp", [Qast.Loc; p1; p2]) : 'patt))];
       None, Some Gramext.LeftA,
       [[Gramext.Sself; Gramext.Stoken ("", "."); Gramext.Sself],
        Gramext.action
          (fun (p2 : 'patt) _ (p1 : 'patt) (loc : int * int) ->
             (Qast.Node ("PaAcc", [Qast.Loc; p1; p2]) : 'patt))];
       Some "simple", None,
       [[Gramext.Stoken ("", "_")],
        Gramext.action
          (fun _ (loc : int * int) ->
             (Qast.Node ("PaAny", [Qast.Loc]) : 'patt));
        [Gramext.Stoken ("", "("); Gramext.Sself; Gramext.Stoken ("", ",");
         Gramext.srules
           [[Gramext.Slist1sep
               (Gramext.Snterm
                  (Grammar.Entry.obj (patt : 'patt Grammar.Entry.e)),
                Gramext.Stoken ("", ","))],
            Gramext.action
              (fun (a : 'patt list) (loc : int * int) ->
                 (Qast.List a : 'a_list));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_list : 'a_list Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_list) (loc : int * int) -> (a : 'a_list))];
         Gramext.Stoken ("", ")")],
        Gramext.action
          (fun _ (pl : 'a_list) _ (p : 'patt) _ (loc : int * int) ->
             (Qast.Node ("PaTup", [Qast.Loc; Qast.Cons (p, pl)]) : 'patt));
        [Gramext.Stoken ("", "("); Gramext.Sself; Gramext.Stoken ("", "as");
         Gramext.Sself; Gramext.Stoken ("", ")")],
        Gramext.action
          (fun _ (p2 : 'patt) _ (p : 'patt) _ (loc : int * int) ->
             (Qast.Node ("PaAli", [Qast.Loc; p; p2]) : 'patt));
        [Gramext.Stoken ("", "("); Gramext.Sself; Gramext.Stoken ("", ":");
         Gramext.Snterm (Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e));
         Gramext.Stoken ("", ")")],
        Gramext.action
          (fun _ (t : 'ctyp) _ (p : 'patt) _ (loc : int * int) ->
             (Qast.Node ("PaTyc", [Qast.Loc; p; t]) : 'patt));
        [Gramext.Stoken ("", "("); Gramext.Sself; Gramext.Stoken ("", ")")],
        Gramext.action (fun _ (p : 'patt) _ (loc : int * int) -> (p : 'patt));
        [Gramext.Stoken ("", "("); Gramext.Stoken ("", ")")],
        Gramext.action
          (fun _ _ (loc : int * int) ->
             (Qast.Node ("PaUid", [Qast.Loc; Qast.Str "()"]) : 'patt));
        [Gramext.Stoken ("", "{");
         Gramext.srules
           [[Gramext.Slist1sep
               (Gramext.Snterm
                  (Grammar.Entry.obj
                     (label_patt : 'label_patt Grammar.Entry.e)),
                Gramext.Stoken ("", ";"))],
            Gramext.action
              (fun (a : 'label_patt list) (loc : int * int) ->
                 (Qast.List a : 'a_list));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_list : 'a_list Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_list) (loc : int * int) -> (a : 'a_list))];
         Gramext.Stoken ("", "}")],
        Gramext.action
          (fun _ (lpl : 'a_list) _ (loc : int * int) ->
             (Qast.Node ("PaRec", [Qast.Loc; lpl]) : 'patt));
        [Gramext.Stoken ("", "[|");
         Gramext.srules
           [[Gramext.Slist0sep
               (Gramext.Snterm
                  (Grammar.Entry.obj (patt : 'patt Grammar.Entry.e)),
                Gramext.Stoken ("", ";"))],
            Gramext.action
              (fun (a : 'patt list) (loc : int * int) ->
                 (Qast.List a : 'a_list));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_list : 'a_list Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_list) (loc : int * int) -> (a : 'a_list))];
         Gramext.Stoken ("", "|]")],
        Gramext.action
          (fun _ (pl : 'a_list) _ (loc : int * int) ->
             (Qast.Node ("PaArr", [Qast.Loc; pl]) : 'patt));
        [Gramext.Stoken ("", "[");
         Gramext.srules
           [[Gramext.Slist1sep
               (Gramext.Snterm
                  (Grammar.Entry.obj (patt : 'patt Grammar.Entry.e)),
                Gramext.Stoken ("", ";"))],
            Gramext.action
              (fun (a : 'patt list) (loc : int * int) ->
                 (Qast.List a : 'a_list));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_list : 'a_list Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_list) (loc : int * int) -> (a : 'a_list))];
         Gramext.Snterm
           (Grammar.Entry.obj
              (cons_patt_opt : 'cons_patt_opt Grammar.Entry.e));
         Gramext.Stoken ("", "]")],
        Gramext.action
          (fun _ (last : 'cons_patt_opt) (pl : 'a_list) _ (loc : int * int) ->
             (mklistpat Qast.Loc last pl : 'patt));
        [Gramext.Stoken ("", "["); Gramext.Stoken ("", "]")],
        Gramext.action
          (fun _ _ (loc : int * int) ->
             (Qast.Node ("PaUid", [Qast.Loc; Qast.Str "[]"]) : 'patt));
        [Gramext.Stoken ("", "-");
         Gramext.Snterm
           (Grammar.Entry.obj (a_FLOAT : 'a_FLOAT Grammar.Entry.e))],
        Gramext.action
          (fun (s : 'a_FLOAT) _ (loc : int * int) ->
             (mkuminpat Qast.Loc (Qast.Str "-") (Qast.Bool false) s : 'patt));
        [Gramext.Stoken ("", "-");
         Gramext.Snterm (Grammar.Entry.obj (a_INT : 'a_INT Grammar.Entry.e))],
        Gramext.action
          (fun (s : 'a_INT) _ (loc : int * int) ->
             (mkuminpat Qast.Loc (Qast.Str "-") (Qast.Bool true) s : 'patt));
        [Gramext.Snterm
           (Grammar.Entry.obj (a_CHAR : 'a_CHAR Grammar.Entry.e))],
        Gramext.action
          (fun (s : 'a_CHAR) (loc : int * int) ->
             (Qast.Node ("PaChr", [Qast.Loc; s]) : 'patt));
        [Gramext.Snterm
           (Grammar.Entry.obj (a_STRING : 'a_STRING Grammar.Entry.e))],
        Gramext.action
          (fun (s : 'a_STRING) (loc : int * int) ->
             (Qast.Node ("PaStr", [Qast.Loc; s]) : 'patt));
        [Gramext.Snterm
           (Grammar.Entry.obj (a_FLOAT : 'a_FLOAT Grammar.Entry.e))],
        Gramext.action
          (fun (s : 'a_FLOAT) (loc : int * int) ->
             (Qast.Node ("PaFlo", [Qast.Loc; s]) : 'patt));
        [Gramext.Snterm (Grammar.Entry.obj (a_INT : 'a_INT Grammar.Entry.e))],
        Gramext.action
          (fun (s : 'a_INT) (loc : int * int) ->
             (Qast.Node ("PaInt", [Qast.Loc; s]) : 'patt));
        [Gramext.Snterm
           (Grammar.Entry.obj (a_UIDENT : 'a_UIDENT Grammar.Entry.e))],
        Gramext.action
          (fun (s : 'a_UIDENT) (loc : int * int) ->
             (Qast.Node ("PaUid", [Qast.Loc; s]) : 'patt));
        [Gramext.Snterm
           (Grammar.Entry.obj (a_LIDENT : 'a_LIDENT Grammar.Entry.e))],
        Gramext.action
          (fun (s : 'a_LIDENT) (loc : int * int) ->
             (Qast.Node ("PaLid", [Qast.Loc; s]) : 'patt))]];
      Grammar.Entry.obj (cons_patt_opt : 'cons_patt_opt Grammar.Entry.e),
      None,
      [None, None,
       [[],
        Gramext.action
          (fun (loc : int * int) -> (Qast.Option None : 'cons_patt_opt));
        [Gramext.Stoken ("", "::");
         Gramext.Snterm (Grammar.Entry.obj (patt : 'patt Grammar.Entry.e))],
        Gramext.action
          (fun (p : 'patt) _ (loc : int * int) ->
             (Qast.Option (Some p) : 'cons_patt_opt))]];
      Grammar.Entry.obj (label_patt : 'label_patt Grammar.Entry.e), None,
      [None, None,
       [[Gramext.Snterm
           (Grammar.Entry.obj
              (patt_label_ident : 'patt_label_ident Grammar.Entry.e));
         Gramext.Stoken ("", "=");
         Gramext.Snterm (Grammar.Entry.obj (patt : 'patt Grammar.Entry.e))],
        Gramext.action
          (fun (p : 'patt) _ (i : 'patt_label_ident) (loc : int * int) ->
             (Qast.Tuple [i; p] : 'label_patt))]];
      Grammar.Entry.obj
        (patt_label_ident : 'patt_label_ident Grammar.Entry.e),
      None,
      [None, Some Gramext.LeftA,
       [[Gramext.Sself; Gramext.Stoken ("", "."); Gramext.Sself],
        Gramext.action
          (fun (p2 : 'patt_label_ident) _ (p1 : 'patt_label_ident)
             (loc : int * int) ->
             (Qast.Node ("PaAcc", [Qast.Loc; p1; p2]) : 'patt_label_ident))];
       Some "simple", Some Gramext.RightA,
       [[Gramext.Snterm
           (Grammar.Entry.obj (a_LIDENT : 'a_LIDENT Grammar.Entry.e))],
        Gramext.action
          (fun (i : 'a_LIDENT) (loc : int * int) ->
             (Qast.Node ("PaLid", [Qast.Loc; i]) : 'patt_label_ident));
        [Gramext.Snterm
           (Grammar.Entry.obj (a_UIDENT : 'a_UIDENT Grammar.Entry.e))],
        Gramext.action
          (fun (i : 'a_UIDENT) (loc : int * int) ->
             (Qast.Node ("PaUid", [Qast.Loc; i]) : 'patt_label_ident))]];
      Grammar.Entry.obj (ipatt : 'ipatt Grammar.Entry.e), None,
      [None, None,
       [[Gramext.Stoken ("", "_")],
        Gramext.action
          (fun _ (loc : int * int) ->
             (Qast.Node ("PaAny", [Qast.Loc]) : 'ipatt));
        [Gramext.Snterm
           (Grammar.Entry.obj (a_LIDENT : 'a_LIDENT Grammar.Entry.e))],
        Gramext.action
          (fun (s : 'a_LIDENT) (loc : int * int) ->
             (Qast.Node ("PaLid", [Qast.Loc; s]) : 'ipatt));
        [Gramext.Stoken ("", "("); Gramext.Sself; Gramext.Stoken ("", ",");
         Gramext.srules
           [[Gramext.Slist1sep
               (Gramext.Snterm
                  (Grammar.Entry.obj (ipatt : 'ipatt Grammar.Entry.e)),
                Gramext.Stoken ("", ","))],
            Gramext.action
              (fun (a : 'ipatt list) (loc : int * int) ->
                 (Qast.List a : 'a_list));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_list : 'a_list Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_list) (loc : int * int) -> (a : 'a_list))];
         Gramext.Stoken ("", ")")],
        Gramext.action
          (fun _ (pl : 'a_list) _ (p : 'ipatt) _ (loc : int * int) ->
             (Qast.Node ("PaTup", [Qast.Loc; Qast.Cons (p, pl)]) : 'ipatt));
        [Gramext.Stoken ("", "("); Gramext.Sself; Gramext.Stoken ("", "as");
         Gramext.Sself; Gramext.Stoken ("", ")")],
        Gramext.action
          (fun _ (p2 : 'ipatt) _ (p : 'ipatt) _ (loc : int * int) ->
             (Qast.Node ("PaAli", [Qast.Loc; p; p2]) : 'ipatt));
        [Gramext.Stoken ("", "("); Gramext.Sself; Gramext.Stoken ("", ":");
         Gramext.Snterm (Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e));
         Gramext.Stoken ("", ")")],
        Gramext.action
          (fun _ (t : 'ctyp) _ (p : 'ipatt) _ (loc : int * int) ->
             (Qast.Node ("PaTyc", [Qast.Loc; p; t]) : 'ipatt));
        [Gramext.Stoken ("", "("); Gramext.Sself; Gramext.Stoken ("", ")")],
        Gramext.action
          (fun _ (p : 'ipatt) _ (loc : int * int) -> (p : 'ipatt));
        [Gramext.Stoken ("", "("); Gramext.Stoken ("", ")")],
        Gramext.action
          (fun _ _ (loc : int * int) ->
             (Qast.Node ("PaUid", [Qast.Loc; Qast.Str "()"]) : 'ipatt));
        [Gramext.Stoken ("", "{");
         Gramext.srules
           [[Gramext.Slist1sep
               (Gramext.Snterm
                  (Grammar.Entry.obj
                     (label_ipatt : 'label_ipatt Grammar.Entry.e)),
                Gramext.Stoken ("", ";"))],
            Gramext.action
              (fun (a : 'label_ipatt list) (loc : int * int) ->
                 (Qast.List a : 'a_list));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_list : 'a_list Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_list) (loc : int * int) -> (a : 'a_list))];
         Gramext.Stoken ("", "}")],
        Gramext.action
          (fun _ (lpl : 'a_list) _ (loc : int * int) ->
             (Qast.Node ("PaRec", [Qast.Loc; lpl]) : 'ipatt))]];
      Grammar.Entry.obj (label_ipatt : 'label_ipatt Grammar.Entry.e), None,
      [None, None,
       [[Gramext.Snterm
           (Grammar.Entry.obj
              (patt_label_ident : 'patt_label_ident Grammar.Entry.e));
         Gramext.Stoken ("", "=");
         Gramext.Snterm (Grammar.Entry.obj (ipatt : 'ipatt Grammar.Entry.e))],
        Gramext.action
          (fun (p : 'ipatt) _ (i : 'patt_label_ident) (loc : int * int) ->
             (Qast.Tuple [i; p] : 'label_ipatt))]];
      Grammar.Entry.obj
        (type_declaration : 'type_declaration Grammar.Entry.e),
      None,
      [None, None,
       [[Gramext.Snterm
           (Grammar.Entry.obj (type_patt : 'type_patt Grammar.Entry.e));
         Gramext.srules
           [[Gramext.Slist0
               (Gramext.Snterm
                  (Grammar.Entry.obj
                     (type_parameter : 'type_parameter Grammar.Entry.e)))],
            Gramext.action
              (fun (a : 'type_parameter list) (loc : int * int) ->
                 (Qast.List a : 'a_list));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_list : 'a_list Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_list) (loc : int * int) -> (a : 'a_list))];
         Gramext.Stoken ("", "=");
         Gramext.Snterm (Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e));
         Gramext.srules
           [[Gramext.Slist0
               (Gramext.Snterm
                  (Grammar.Entry.obj
                     (constrain : 'constrain Grammar.Entry.e)))],
            Gramext.action
              (fun (a : 'constrain list) (loc : int * int) ->
                 (Qast.List a : 'a_list));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_list : 'a_list Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_list) (loc : int * int) -> (a : 'a_list))]],
        Gramext.action
          (fun (cl : 'a_list) (tk : 'ctyp) _ (tpl : 'a_list) (n : 'type_patt)
             (loc : int * int) ->
             (Qast.Tuple [n; tpl; tk; cl] : 'type_declaration))]];
      Grammar.Entry.obj (type_patt : 'type_patt Grammar.Entry.e), None,
      [None, None,
       [[Gramext.Snterm
           (Grammar.Entry.obj (a_LIDENT : 'a_LIDENT Grammar.Entry.e))],
        Gramext.action
          (fun (n : 'a_LIDENT) (loc : int * int) ->
             (Qast.Tuple [Qast.Loc; n] : 'type_patt))]];
      Grammar.Entry.obj (constrain : 'constrain Grammar.Entry.e), None,
      [None, None,
       [[Gramext.Stoken ("", "constraint");
         Gramext.Snterm (Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e));
         Gramext.Stoken ("", "=");
         Gramext.Snterm (Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e))],
        Gramext.action
          (fun (t2 : 'ctyp) _ (t1 : 'ctyp) _ (loc : int * int) ->
             (Qast.Tuple [t1; t2] : 'constrain))]];
      Grammar.Entry.obj (type_parameter : 'type_parameter Grammar.Entry.e),
      None,
      [None, None,
       [[Gramext.Stoken ("", "-"); Gramext.Stoken ("", "'");
         Gramext.Snterm (Grammar.Entry.obj (ident : 'ident Grammar.Entry.e))],
        Gramext.action
          (fun (i : 'ident) _ _ (loc : int * int) ->
             (Qast.Tuple [i; Qast.Tuple [Qast.Bool false; Qast.Bool true]] :
              'type_parameter));
        [Gramext.Stoken ("", "+"); Gramext.Stoken ("", "'");
         Gramext.Snterm (Grammar.Entry.obj (ident : 'ident Grammar.Entry.e))],
        Gramext.action
          (fun (i : 'ident) _ _ (loc : int * int) ->
             (Qast.Tuple [i; Qast.Tuple [Qast.Bool true; Qast.Bool false]] :
              'type_parameter));
        [Gramext.Stoken ("", "'");
         Gramext.Snterm (Grammar.Entry.obj (ident : 'ident Grammar.Entry.e))],
        Gramext.action
          (fun (i : 'ident) _ (loc : int * int) ->
             (Qast.Tuple [i; Qast.Tuple [Qast.Bool false; Qast.Bool false]] :
              'type_parameter))]];
      Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e), None,
      [None, Some Gramext.LeftA,
       [[Gramext.Sself; Gramext.Stoken ("", "=="); Gramext.Sself],
        Gramext.action
          (fun (t2 : 'ctyp) _ (t1 : 'ctyp) (loc : int * int) ->
             (Qast.Node ("TyMan", [Qast.Loc; t1; t2]) : 'ctyp))];
       None, Some Gramext.LeftA,
       [[Gramext.Sself; Gramext.Stoken ("", "as"); Gramext.Sself],
        Gramext.action
          (fun (t2 : 'ctyp) _ (t1 : 'ctyp) (loc : int * int) ->
             (Qast.Node ("TyAli", [Qast.Loc; t1; t2]) : 'ctyp))];
       None, Some Gramext.LeftA,
       [[Gramext.Stoken ("", "!");
         Gramext.srules
           [[Gramext.Slist1
               (Gramext.Snterm
                  (Grammar.Entry.obj (typevar : 'typevar Grammar.Entry.e)))],
            Gramext.action
              (fun (a : 'typevar list) (loc : int * int) ->
                 (Qast.List a : 'a_list));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_list : 'a_list Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_list) (loc : int * int) -> (a : 'a_list))];
         Gramext.Stoken ("", "."); Gramext.Sself],
        Gramext.action
          (fun (t : 'ctyp) _ (pl : 'a_list) _ (loc : int * int) ->
             (Qast.Node ("TyPol", [Qast.Loc; pl; t]) : 'ctyp))];
       Some "arrow", Some Gramext.RightA,
       [[Gramext.Sself; Gramext.Stoken ("", "->"); Gramext.Sself],
        Gramext.action
          (fun (t2 : 'ctyp) _ (t1 : 'ctyp) (loc : int * int) ->
             (Qast.Node ("TyArr", [Qast.Loc; t1; t2]) : 'ctyp))];
       None, Some Gramext.LeftA,
       [[Gramext.Sself; Gramext.Sself],
        Gramext.action
          (fun (t2 : 'ctyp) (t1 : 'ctyp) (loc : int * int) ->
             (Qast.Node ("TyApp", [Qast.Loc; t1; t2]) : 'ctyp))];
       None, Some Gramext.LeftA,
       [[Gramext.Sself; Gramext.Stoken ("", "."); Gramext.Sself],
        Gramext.action
          (fun (t2 : 'ctyp) _ (t1 : 'ctyp) (loc : int * int) ->
             (Qast.Node ("TyAcc", [Qast.Loc; t1; t2]) : 'ctyp))];
       Some "simple", None,
       [[Gramext.Stoken ("", "{");
         Gramext.srules
           [[Gramext.Slist1sep
               (Gramext.Snterm
                  (Grammar.Entry.obj
                     (label_declaration :
                      'label_declaration Grammar.Entry.e)),
                Gramext.Stoken ("", ";"))],
            Gramext.action
              (fun (a : 'label_declaration list) (loc : int * int) ->
                 (Qast.List a : 'a_list));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_list : 'a_list Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_list) (loc : int * int) -> (a : 'a_list))];
         Gramext.Stoken ("", "}")],
        Gramext.action
          (fun _ (ldl : 'a_list) _ (loc : int * int) ->
             (Qast.Node ("TyRec", [Qast.Loc; Qast.Bool false; ldl]) : 'ctyp));
        [Gramext.Stoken ("", "[");
         Gramext.srules
           [[Gramext.Slist0sep
               (Gramext.Snterm
                  (Grammar.Entry.obj
                     (constructor_declaration :
                      'constructor_declaration Grammar.Entry.e)),
                Gramext.Stoken ("", "|"))],
            Gramext.action
              (fun (a : 'constructor_declaration list) (loc : int * int) ->
                 (Qast.List a : 'a_list));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_list : 'a_list Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_list) (loc : int * int) -> (a : 'a_list))];
         Gramext.Stoken ("", "]")],
        Gramext.action
          (fun _ (cdl : 'a_list) _ (loc : int * int) ->
             (Qast.Node ("TySum", [Qast.Loc; Qast.Bool false; cdl]) : 'ctyp));
        [Gramext.Stoken ("", "private"); Gramext.Stoken ("", "{");
         Gramext.srules
           [[Gramext.Slist1sep
               (Gramext.Snterm
                  (Grammar.Entry.obj
                     (label_declaration :
                      'label_declaration Grammar.Entry.e)),
                Gramext.Stoken ("", ";"))],
            Gramext.action
              (fun (a : 'label_declaration list) (loc : int * int) ->
                 (Qast.List a : 'a_list));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_list : 'a_list Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_list) (loc : int * int) -> (a : 'a_list))];
         Gramext.Stoken ("", "}")],
        Gramext.action
          (fun _ (ldl : 'a_list) _ _ (loc : int * int) ->
             (Qast.Node ("TyRec", [Qast.Loc; Qast.Bool true; ldl]) : 'ctyp));
        [Gramext.Stoken ("", "private"); Gramext.Stoken ("", "[");
         Gramext.srules
           [[Gramext.Slist0sep
               (Gramext.Snterm
                  (Grammar.Entry.obj
                     (constructor_declaration :
                      'constructor_declaration Grammar.Entry.e)),
                Gramext.Stoken ("", "|"))],
            Gramext.action
              (fun (a : 'constructor_declaration list) (loc : int * int) ->
                 (Qast.List a : 'a_list));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_list : 'a_list Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_list) (loc : int * int) -> (a : 'a_list))];
         Gramext.Stoken ("", "]")],
        Gramext.action
          (fun _ (cdl : 'a_list) _ _ (loc : int * int) ->
             (Qast.Node ("TySum", [Qast.Loc; Qast.Bool true; cdl]) : 'ctyp));
        [Gramext.Stoken ("", "("); Gramext.Sself; Gramext.Stoken ("", ")")],
        Gramext.action (fun _ (t : 'ctyp) _ (loc : int * int) -> (t : 'ctyp));
        [Gramext.Stoken ("", "("); Gramext.Sself; Gramext.Stoken ("", "*");
         Gramext.srules
           [[Gramext.Slist1sep
               (Gramext.Snterm
                  (Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e)),
                Gramext.Stoken ("", "*"))],
            Gramext.action
              (fun (a : 'ctyp list) (loc : int * int) ->
                 (Qast.List a : 'a_list));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_list : 'a_list Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_list) (loc : int * int) -> (a : 'a_list))];
         Gramext.Stoken ("", ")")],
        Gramext.action
          (fun _ (tl : 'a_list) _ (t : 'ctyp) _ (loc : int * int) ->
             (Qast.Node ("TyTup", [Qast.Loc; Qast.Cons (t, tl)]) : 'ctyp));
        [Gramext.Snterm
           (Grammar.Entry.obj (a_UIDENT : 'a_UIDENT Grammar.Entry.e))],
        Gramext.action
          (fun (i : 'a_UIDENT) (loc : int * int) ->
             (Qast.Node ("TyUid", [Qast.Loc; i]) : 'ctyp));
        [Gramext.Snterm
           (Grammar.Entry.obj (a_LIDENT : 'a_LIDENT Grammar.Entry.e))],
        Gramext.action
          (fun (i : 'a_LIDENT) (loc : int * int) ->
             (Qast.Node ("TyLid", [Qast.Loc; i]) : 'ctyp));
        [Gramext.Stoken ("", "_")],
        Gramext.action
          (fun _ (loc : int * int) ->
             (Qast.Node ("TyAny", [Qast.Loc]) : 'ctyp));
        [Gramext.Stoken ("", "'");
         Gramext.Snterm (Grammar.Entry.obj (ident : 'ident Grammar.Entry.e))],
        Gramext.action
          (fun (i : 'ident) _ (loc : int * int) ->
             (Qast.Node ("TyQuo", [Qast.Loc; i]) : 'ctyp))]];
      Grammar.Entry.obj
        (constructor_declaration : 'constructor_declaration Grammar.Entry.e),
      None,
      [None, None,
       [[Gramext.Snterm
           (Grammar.Entry.obj (a_UIDENT : 'a_UIDENT Grammar.Entry.e))],
        Gramext.action
          (fun (ci : 'a_UIDENT) (loc : int * int) ->
             (Qast.Tuple [Qast.Loc; ci; Qast.List []] :
              'constructor_declaration));
        [Gramext.Snterm
           (Grammar.Entry.obj (a_UIDENT : 'a_UIDENT Grammar.Entry.e));
         Gramext.Stoken ("", "of");
         Gramext.srules
           [[Gramext.Slist1sep
               (Gramext.Snterm
                  (Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e)),
                Gramext.Stoken ("", "and"))],
            Gramext.action
              (fun (a : 'ctyp list) (loc : int * int) ->
                 (Qast.List a : 'a_list));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_list : 'a_list Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_list) (loc : int * int) -> (a : 'a_list))]],
        Gramext.action
          (fun (cal : 'a_list) _ (ci : 'a_UIDENT) (loc : int * int) ->
             (Qast.Tuple [Qast.Loc; ci; cal] : 'constructor_declaration))]];
      Grammar.Entry.obj
        (label_declaration : 'label_declaration Grammar.Entry.e),
      None,
      [None, None,
       [[Gramext.Snterm
           (Grammar.Entry.obj (a_LIDENT : 'a_LIDENT Grammar.Entry.e));
         Gramext.Stoken ("", ":");
         Gramext.srules
           [[Gramext.Sopt
               (Gramext.srules
                  [[Gramext.Stoken ("", "mutable")],
                   Gramext.action
                     (fun (x : string) (loc : int * int) ->
                        (Qast.Str x : 'e__10))])],
            Gramext.action
              (fun (a : 'e__10 option) (loc : int * int) ->
                 (Qast.Option a : 'a_opt));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_opt : 'a_opt Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_opt) (loc : int * int) -> (a : 'a_opt))];
         Gramext.Snterm (Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e))],
        Gramext.action
          (fun (t : 'ctyp) (mf : 'a_opt) _ (i : 'a_LIDENT)
             (loc : int * int) ->
             (Qast.Tuple [Qast.Loc; i; o2b mf; t] : 'label_declaration))]];
      Grammar.Entry.obj (ident : 'ident Grammar.Entry.e), None,
      [None, None,
       [[Gramext.Snterm
           (Grammar.Entry.obj (a_UIDENT : 'a_UIDENT Grammar.Entry.e))],
        Gramext.action
          (fun (i : 'a_UIDENT) (loc : int * int) -> (i : 'ident));
        [Gramext.Snterm
           (Grammar.Entry.obj (a_LIDENT : 'a_LIDENT Grammar.Entry.e))],
        Gramext.action
          (fun (i : 'a_LIDENT) (loc : int * int) -> (i : 'ident))]];
      Grammar.Entry.obj (mod_ident : 'mod_ident Grammar.Entry.e), None,
      [None, Some Gramext.RightA,
       [[Gramext.Snterm
           (Grammar.Entry.obj (a_UIDENT : 'a_UIDENT Grammar.Entry.e));
         Gramext.Stoken ("", "."); Gramext.Sself],
        Gramext.action
          (fun (j : 'mod_ident) _ (i : 'a_UIDENT) (loc : int * int) ->
             (Qast.Cons (i, j) : 'mod_ident));
        [Gramext.Snterm
           (Grammar.Entry.obj (a_LIDENT : 'a_LIDENT Grammar.Entry.e))],
        Gramext.action
          (fun (i : 'a_LIDENT) (loc : int * int) ->
             (Qast.List [i] : 'mod_ident));
        [Gramext.Snterm
           (Grammar.Entry.obj (a_UIDENT : 'a_UIDENT Grammar.Entry.e))],
        Gramext.action
          (fun (i : 'a_UIDENT) (loc : int * int) ->
             (Qast.List [i] : 'mod_ident))]];
      Grammar.Entry.obj (str_item : 'str_item Grammar.Entry.e), None,
      [None, None,
       [[Gramext.Stoken ("", "class"); Gramext.Stoken ("", "type");
         Gramext.srules
           [[Gramext.Slist1sep
               (Gramext.Snterm
                  (Grammar.Entry.obj
                     (class_type_declaration :
                      'class_type_declaration Grammar.Entry.e)),
                Gramext.Stoken ("", "and"))],
            Gramext.action
              (fun (a : 'class_type_declaration list) (loc : int * int) ->
                 (Qast.List a : 'a_list));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_list : 'a_list Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_list) (loc : int * int) -> (a : 'a_list))]],
        Gramext.action
          (fun (ctd : 'a_list) _ _ (loc : int * int) ->
             (Qast.Node ("StClt", [Qast.Loc; ctd]) : 'str_item));
        [Gramext.Stoken ("", "class");
         Gramext.srules
           [[Gramext.Slist1sep
               (Gramext.Snterm
                  (Grammar.Entry.obj
                     (class_declaration :
                      'class_declaration Grammar.Entry.e)),
                Gramext.Stoken ("", "and"))],
            Gramext.action
              (fun (a : 'class_declaration list) (loc : int * int) ->
                 (Qast.List a : 'a_list));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_list : 'a_list Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_list) (loc : int * int) -> (a : 'a_list))]],
        Gramext.action
          (fun (cd : 'a_list) _ (loc : int * int) ->
             (Qast.Node ("StCls", [Qast.Loc; cd]) : 'str_item))]];
      Grammar.Entry.obj (sig_item : 'sig_item Grammar.Entry.e), None,
      [None, None,
       [[Gramext.Stoken ("", "class"); Gramext.Stoken ("", "type");
         Gramext.srules
           [[Gramext.Slist1sep
               (Gramext.Snterm
                  (Grammar.Entry.obj
                     (class_type_declaration :
                      'class_type_declaration Grammar.Entry.e)),
                Gramext.Stoken ("", "and"))],
            Gramext.action
              (fun (a : 'class_type_declaration list) (loc : int * int) ->
                 (Qast.List a : 'a_list));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_list : 'a_list Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_list) (loc : int * int) -> (a : 'a_list))]],
        Gramext.action
          (fun (ctd : 'a_list) _ _ (loc : int * int) ->
             (Qast.Node ("SgClt", [Qast.Loc; ctd]) : 'sig_item));
        [Gramext.Stoken ("", "class");
         Gramext.srules
           [[Gramext.Slist1sep
               (Gramext.Snterm
                  (Grammar.Entry.obj
                     (class_description :
                      'class_description Grammar.Entry.e)),
                Gramext.Stoken ("", "and"))],
            Gramext.action
              (fun (a : 'class_description list) (loc : int * int) ->
                 (Qast.List a : 'a_list));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_list : 'a_list Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_list) (loc : int * int) -> (a : 'a_list))]],
        Gramext.action
          (fun (cd : 'a_list) _ (loc : int * int) ->
             (Qast.Node ("SgCls", [Qast.Loc; cd]) : 'sig_item))]];
      Grammar.Entry.obj
        (class_declaration : 'class_declaration Grammar.Entry.e),
      None,
      [None, None,
       [[Gramext.srules
           [[Gramext.Sopt
               (Gramext.srules
                  [[Gramext.Stoken ("", "virtual")],
                   Gramext.action
                     (fun (x : string) (loc : int * int) ->
                        (Qast.Str x : 'e__11))])],
            Gramext.action
              (fun (a : 'e__11 option) (loc : int * int) ->
                 (Qast.Option a : 'a_opt));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_opt : 'a_opt Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_opt) (loc : int * int) -> (a : 'a_opt))];
         Gramext.Snterm
           (Grammar.Entry.obj (a_LIDENT : 'a_LIDENT Grammar.Entry.e));
         Gramext.Snterm
           (Grammar.Entry.obj
              (class_type_parameters :
               'class_type_parameters Grammar.Entry.e));
         Gramext.Snterm
           (Grammar.Entry.obj
              (class_fun_binding : 'class_fun_binding Grammar.Entry.e))],
        Gramext.action
          (fun (cfb : 'class_fun_binding) (ctp : 'class_type_parameters)
             (i : 'a_LIDENT) (vf : 'a_opt) (loc : int * int) ->
             (Qast.Record
                ["ciLoc", Qast.Loc; "ciVir", o2b vf; "ciPrm", ctp; "ciNam", i;
                 "ciExp", cfb] :
              'class_declaration))]];
      Grammar.Entry.obj
        (class_fun_binding : 'class_fun_binding Grammar.Entry.e),
      None,
      [None, None,
       [[Gramext.Snterm (Grammar.Entry.obj (ipatt : 'ipatt Grammar.Entry.e));
         Gramext.Sself],
        Gramext.action
          (fun (cfb : 'class_fun_binding) (p : 'ipatt) (loc : int * int) ->
             (Qast.Node ("CeFun", [Qast.Loc; p; cfb]) : 'class_fun_binding));
        [Gramext.Stoken ("", ":");
         Gramext.Snterm
           (Grammar.Entry.obj (class_type : 'class_type Grammar.Entry.e));
         Gramext.Stoken ("", "=");
         Gramext.Snterm
           (Grammar.Entry.obj (class_expr : 'class_expr Grammar.Entry.e))],
        Gramext.action
          (fun (ce : 'class_expr) _ (ct : 'class_type) _ (loc : int * int) ->
             (Qast.Node ("CeTyc", [Qast.Loc; ce; ct]) : 'class_fun_binding));
        [Gramext.Stoken ("", "=");
         Gramext.Snterm
           (Grammar.Entry.obj (class_expr : 'class_expr Grammar.Entry.e))],
        Gramext.action
          (fun (ce : 'class_expr) _ (loc : int * int) ->
             (ce : 'class_fun_binding))]];
      Grammar.Entry.obj
        (class_type_parameters : 'class_type_parameters Grammar.Entry.e),
      None,
      [None, None,
       [[Gramext.Stoken ("", "[");
         Gramext.srules
           [[Gramext.Slist1sep
               (Gramext.Snterm
                  (Grammar.Entry.obj
                     (type_parameter : 'type_parameter Grammar.Entry.e)),
                Gramext.Stoken ("", ","))],
            Gramext.action
              (fun (a : 'type_parameter list) (loc : int * int) ->
                 (Qast.List a : 'a_list));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_list : 'a_list Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_list) (loc : int * int) -> (a : 'a_list))];
         Gramext.Stoken ("", "]")],
        Gramext.action
          (fun _ (tpl : 'a_list) _ (loc : int * int) ->
             (Qast.Tuple [Qast.Loc; tpl] : 'class_type_parameters));
        [],
        Gramext.action
          (fun (loc : int * int) ->
             (Qast.Tuple [Qast.Loc; Qast.List []] :
              'class_type_parameters))]];
      Grammar.Entry.obj (class_fun_def : 'class_fun_def Grammar.Entry.e),
      None,
      [None, None,
       [[Gramext.Stoken ("", "->");
         Gramext.Snterm
           (Grammar.Entry.obj (class_expr : 'class_expr Grammar.Entry.e))],
        Gramext.action
          (fun (ce : 'class_expr) _ (loc : int * int) ->
             (ce : 'class_fun_def));
        [Gramext.Snterm (Grammar.Entry.obj (ipatt : 'ipatt Grammar.Entry.e));
         Gramext.Sself],
        Gramext.action
          (fun (ce : 'class_fun_def) (p : 'ipatt) (loc : int * int) ->
             (Qast.Node ("CeFun", [Qast.Loc; p; ce]) : 'class_fun_def))]];
      Grammar.Entry.obj (class_expr : 'class_expr Grammar.Entry.e), None,
      [Some "top", None,
       [[Gramext.Stoken ("", "let");
         Gramext.srules
           [[Gramext.Sopt
               (Gramext.srules
                  [[Gramext.Stoken ("", "rec")],
                   Gramext.action
                     (fun (x : string) (loc : int * int) ->
                        (Qast.Str x : 'e__12))])],
            Gramext.action
              (fun (a : 'e__12 option) (loc : int * int) ->
                 (Qast.Option a : 'a_opt));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_opt : 'a_opt Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_opt) (loc : int * int) -> (a : 'a_opt))];
         Gramext.srules
           [[Gramext.Slist1sep
               (Gramext.Snterm
                  (Grammar.Entry.obj
                     (let_binding : 'let_binding Grammar.Entry.e)),
                Gramext.Stoken ("", "and"))],
            Gramext.action
              (fun (a : 'let_binding list) (loc : int * int) ->
                 (Qast.List a : 'a_list));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_list : 'a_list Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_list) (loc : int * int) -> (a : 'a_list))];
         Gramext.Stoken ("", "in"); Gramext.Sself],
        Gramext.action
          (fun (ce : 'class_expr) _ (lb : 'a_list) (rf : 'a_opt) _
             (loc : int * int) ->
             (Qast.Node ("CeLet", [Qast.Loc; o2b rf; lb; ce]) : 'class_expr));
        [Gramext.Stoken ("", "fun");
         Gramext.Snterm (Grammar.Entry.obj (ipatt : 'ipatt Grammar.Entry.e));
         Gramext.Snterm
           (Grammar.Entry.obj
              (class_fun_def : 'class_fun_def Grammar.Entry.e))],
        Gramext.action
          (fun (ce : 'class_fun_def) (p : 'ipatt) _ (loc : int * int) ->
             (Qast.Node ("CeFun", [Qast.Loc; p; ce]) : 'class_expr))];
       Some "apply", Some Gramext.NonA,
       [[Gramext.Sself;
         Gramext.Snterml
           (Grammar.Entry.obj (expr : 'expr Grammar.Entry.e), "label")],
        Gramext.action
          (fun (e : 'expr) (ce : 'class_expr) (loc : int * int) ->
             (Qast.Node ("CeApp", [Qast.Loc; ce; e]) : 'class_expr))];
       Some "simple", None,
       [[Gramext.Stoken ("", "("); Gramext.Sself; Gramext.Stoken ("", ")")],
        Gramext.action
          (fun _ (ce : 'class_expr) _ (loc : int * int) ->
             (ce : 'class_expr));
        [Gramext.Stoken ("", "("); Gramext.Sself; Gramext.Stoken ("", ":");
         Gramext.Snterm
           (Grammar.Entry.obj (class_type : 'class_type Grammar.Entry.e));
         Gramext.Stoken ("", ")")],
        Gramext.action
          (fun _ (ct : 'class_type) _ (ce : 'class_expr) _
             (loc : int * int) ->
             (Qast.Node ("CeTyc", [Qast.Loc; ce; ct]) : 'class_expr));
        [Gramext.Stoken ("", "object");
         Gramext.srules
           [[Gramext.Sopt
               (Gramext.Snterm
                  (Grammar.Entry.obj
                     (class_self_patt : 'class_self_patt Grammar.Entry.e)))],
            Gramext.action
              (fun (a : 'class_self_patt option) (loc : int * int) ->
                 (Qast.Option a : 'a_opt));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_opt : 'a_opt Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_opt) (loc : int * int) -> (a : 'a_opt))];
         Gramext.Snterm
           (Grammar.Entry.obj
              (class_structure : 'class_structure Grammar.Entry.e));
         Gramext.Stoken ("", "end")],
        Gramext.action
          (fun _ (cf : 'class_structure) (cspo : 'a_opt) _
             (loc : int * int) ->
             (Qast.Node ("CeStr", [Qast.Loc; cspo; cf]) : 'class_expr));
        [Gramext.Snterm
           (Grammar.Entry.obj
              (class_longident : 'class_longident Grammar.Entry.e))],
        Gramext.action
          (fun (ci : 'class_longident) (loc : int * int) ->
             (Qast.Node ("CeCon", [Qast.Loc; ci; Qast.List []]) :
              'class_expr));
        [Gramext.Snterm
           (Grammar.Entry.obj
              (class_longident : 'class_longident Grammar.Entry.e));
         Gramext.Stoken ("", "[");
         Gramext.srules
           [[Gramext.Slist0sep
               (Gramext.Snterm
                  (Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e)),
                Gramext.Stoken ("", ","))],
            Gramext.action
              (fun (a : 'ctyp list) (loc : int * int) ->
                 (Qast.List a : 'a_list));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_list : 'a_list Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_list) (loc : int * int) -> (a : 'a_list))];
         Gramext.Stoken ("", "]")],
        Gramext.action
          (fun _ (ctcl : 'a_list) _ (ci : 'class_longident)
             (loc : int * int) ->
             (Qast.Node ("CeCon", [Qast.Loc; ci; ctcl]) : 'class_expr))]];
      Grammar.Entry.obj (class_structure : 'class_structure Grammar.Entry.e),
      None,
      [None, None,
       [[Gramext.srules
           [[Gramext.Slist0
               (Gramext.srules
                  [[Gramext.Snterm
                      (Grammar.Entry.obj
                         (class_str_item : 'class_str_item Grammar.Entry.e));
                    Gramext.Stoken ("", ";")],
                   Gramext.action
                     (fun _ (cf : 'class_str_item) (loc : int * int) ->
                        (cf : 'e__13))])],
            Gramext.action
              (fun (a : 'e__13 list) (loc : int * int) ->
                 (Qast.List a : 'a_list));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_list : 'a_list Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_list) (loc : int * int) -> (a : 'a_list))]],
        Gramext.action
          (fun (cf : 'a_list) (loc : int * int) -> (cf : 'class_structure))]];
      Grammar.Entry.obj (class_self_patt : 'class_self_patt Grammar.Entry.e),
      None,
      [None, None,
       [[Gramext.Stoken ("", "(");
         Gramext.Snterm (Grammar.Entry.obj (patt : 'patt Grammar.Entry.e));
         Gramext.Stoken ("", ":");
         Gramext.Snterm (Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e));
         Gramext.Stoken ("", ")")],
        Gramext.action
          (fun _ (t : 'ctyp) _ (p : 'patt) _ (loc : int * int) ->
             (Qast.Node ("PaTyc", [Qast.Loc; p; t]) : 'class_self_patt));
        [Gramext.Stoken ("", "(");
         Gramext.Snterm (Grammar.Entry.obj (patt : 'patt Grammar.Entry.e));
         Gramext.Stoken ("", ")")],
        Gramext.action
          (fun _ (p : 'patt) _ (loc : int * int) -> (p : 'class_self_patt))]];
      Grammar.Entry.obj (class_str_item : 'class_str_item Grammar.Entry.e),
      None,
      [None, None,
       [[Gramext.Stoken ("", "initializer");
         Gramext.Snterm (Grammar.Entry.obj (expr : 'expr Grammar.Entry.e))],
        Gramext.action
          (fun (se : 'expr) _ (loc : int * int) ->
             (Qast.Node ("CrIni", [Qast.Loc; se]) : 'class_str_item));
        [Gramext.Stoken ("", "type");
         Gramext.Snterm (Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e));
         Gramext.Stoken ("", "=");
         Gramext.Snterm (Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e))],
        Gramext.action
          (fun (t2 : 'ctyp) _ (t1 : 'ctyp) _ (loc : int * int) ->
             (Qast.Node ("CrCtr", [Qast.Loc; t1; t2]) : 'class_str_item));
        [Gramext.Stoken ("", "method");
         Gramext.srules
           [[Gramext.Sopt
               (Gramext.srules
                  [[Gramext.Stoken ("", "private")],
                   Gramext.action
                     (fun (x : string) (loc : int * int) ->
                        (Qast.Str x : 'e__17))])],
            Gramext.action
              (fun (a : 'e__17 option) (loc : int * int) ->
                 (Qast.Option a : 'a_opt));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_opt : 'a_opt Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_opt) (loc : int * int) -> (a : 'a_opt))];
         Gramext.Snterm (Grammar.Entry.obj (label : 'label Grammar.Entry.e));
         Gramext.srules
           [[Gramext.Sopt
               (Gramext.Snterm
                  (Grammar.Entry.obj (polyt : 'polyt Grammar.Entry.e)))],
            Gramext.action
              (fun (a : 'polyt option) (loc : int * int) ->
                 (Qast.Option a : 'a_opt));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_opt : 'a_opt Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_opt) (loc : int * int) -> (a : 'a_opt))];
         Gramext.Snterm
           (Grammar.Entry.obj (fun_binding : 'fun_binding Grammar.Entry.e))],
        Gramext.action
          (fun (e : 'fun_binding) (topt : 'a_opt) (l : 'label) (pf : 'a_opt) _
             (loc : int * int) ->
             (Qast.Node ("CrMth", [Qast.Loc; l; o2b pf; e; topt]) :
              'class_str_item));
        [Gramext.Stoken ("", "method"); Gramext.Stoken ("", "virtual");
         Gramext.srules
           [[Gramext.Sopt
               (Gramext.srules
                  [[Gramext.Stoken ("", "private")],
                   Gramext.action
                     (fun (x : string) (loc : int * int) ->
                        (Qast.Str x : 'e__16))])],
            Gramext.action
              (fun (a : 'e__16 option) (loc : int * int) ->
                 (Qast.Option a : 'a_opt));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_opt : 'a_opt Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_opt) (loc : int * int) -> (a : 'a_opt))];
         Gramext.Snterm (Grammar.Entry.obj (label : 'label Grammar.Entry.e));
         Gramext.Stoken ("", ":");
         Gramext.Snterm (Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e))],
        Gramext.action
          (fun (t : 'ctyp) _ (l : 'label) (pf : 'a_opt) _ _
             (loc : int * int) ->
             (Qast.Node ("CrVir", [Qast.Loc; l; o2b pf; t]) :
              'class_str_item));
        [Gramext.Stoken ("", "value");
         Gramext.srules
           [[Gramext.Sopt
               (Gramext.srules
                  [[Gramext.Stoken ("", "mutable")],
                   Gramext.action
                     (fun (x : string) (loc : int * int) ->
                        (Qast.Str x : 'e__15))])],
            Gramext.action
              (fun (a : 'e__15 option) (loc : int * int) ->
                 (Qast.Option a : 'a_opt));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_opt : 'a_opt Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_opt) (loc : int * int) -> (a : 'a_opt))];
         Gramext.Snterm (Grammar.Entry.obj (label : 'label Grammar.Entry.e));
         Gramext.Snterm
           (Grammar.Entry.obj
              (cvalue_binding : 'cvalue_binding Grammar.Entry.e))],
        Gramext.action
          (fun (e : 'cvalue_binding) (lab : 'label) (mf : 'a_opt) _
             (loc : int * int) ->
             (Qast.Node ("CrVal", [Qast.Loc; lab; o2b mf; e]) :
              'class_str_item));
        [Gramext.Stoken ("", "inherit");
         Gramext.Snterm
           (Grammar.Entry.obj (class_expr : 'class_expr Grammar.Entry.e));
         Gramext.srules
           [[Gramext.Sopt
               (Gramext.Snterm
                  (Grammar.Entry.obj
                     (as_lident : 'as_lident Grammar.Entry.e)))],
            Gramext.action
              (fun (a : 'as_lident option) (loc : int * int) ->
                 (Qast.Option a : 'a_opt));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_opt : 'a_opt Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_opt) (loc : int * int) -> (a : 'a_opt))]],
        Gramext.action
          (fun (pb : 'a_opt) (ce : 'class_expr) _ (loc : int * int) ->
             (Qast.Node ("CrInh", [Qast.Loc; ce; pb]) : 'class_str_item));
        [Gramext.Stoken ("", "declare");
         Gramext.srules
           [[Gramext.Slist0
               (Gramext.srules
                  [[Gramext.Snterm
                      (Grammar.Entry.obj
                         (class_str_item : 'class_str_item Grammar.Entry.e));
                    Gramext.Stoken ("", ";")],
                   Gramext.action
                     (fun _ (s : 'class_str_item) (loc : int * int) ->
                        (s : 'e__14))])],
            Gramext.action
              (fun (a : 'e__14 list) (loc : int * int) ->
                 (Qast.List a : 'a_list));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_list : 'a_list Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_list) (loc : int * int) -> (a : 'a_list))];
         Gramext.Stoken ("", "end")],
        Gramext.action
          (fun _ (st : 'a_list) _ (loc : int * int) ->
             (Qast.Node ("CrDcl", [Qast.Loc; st]) : 'class_str_item))]];
      Grammar.Entry.obj (as_lident : 'as_lident Grammar.Entry.e), None,
      [None, None,
       [[Gramext.Stoken ("", "as");
         Gramext.Snterm
           (Grammar.Entry.obj (a_LIDENT : 'a_LIDENT Grammar.Entry.e))],
        Gramext.action
          (fun (i : 'a_LIDENT) _ (loc : int * int) -> (i : 'as_lident))]];
      Grammar.Entry.obj (polyt : 'polyt Grammar.Entry.e), None,
      [None, None,
       [[Gramext.Stoken ("", ":");
         Gramext.Snterm (Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e))],
        Gramext.action
          (fun (t : 'ctyp) _ (loc : int * int) -> (t : 'polyt))]];
      Grammar.Entry.obj (cvalue_binding : 'cvalue_binding Grammar.Entry.e),
      None,
      [None, None,
       [[Gramext.Stoken ("", ":>");
         Gramext.Snterm (Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e));
         Gramext.Stoken ("", "=");
         Gramext.Snterm (Grammar.Entry.obj (expr : 'expr Grammar.Entry.e))],
        Gramext.action
          (fun (e : 'expr) _ (t : 'ctyp) _ (loc : int * int) ->
             (Qast.Node ("ExCoe", [Qast.Loc; e; Qast.Option None; t]) :
              'cvalue_binding));
        [Gramext.Stoken ("", ":");
         Gramext.Snterm (Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e));
         Gramext.Stoken ("", ":>");
         Gramext.Snterm (Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e));
         Gramext.Stoken ("", "=");
         Gramext.Snterm (Grammar.Entry.obj (expr : 'expr Grammar.Entry.e))],
        Gramext.action
          (fun (e : 'expr) _ (t2 : 'ctyp) _ (t : 'ctyp) _ (loc : int * int) ->
             (Qast.Node ("ExCoe", [Qast.Loc; e; Qast.Option (Some t); t2]) :
              'cvalue_binding));
        [Gramext.Stoken ("", ":");
         Gramext.Snterm (Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e));
         Gramext.Stoken ("", "=");
         Gramext.Snterm (Grammar.Entry.obj (expr : 'expr Grammar.Entry.e))],
        Gramext.action
          (fun (e : 'expr) _ (t : 'ctyp) _ (loc : int * int) ->
             (Qast.Node ("ExTyc", [Qast.Loc; e; t]) : 'cvalue_binding));
        [Gramext.Stoken ("", "=");
         Gramext.Snterm (Grammar.Entry.obj (expr : 'expr Grammar.Entry.e))],
        Gramext.action
          (fun (e : 'expr) _ (loc : int * int) -> (e : 'cvalue_binding))]];
      Grammar.Entry.obj (label : 'label Grammar.Entry.e), None,
      [None, None,
       [[Gramext.Snterm
           (Grammar.Entry.obj (a_LIDENT : 'a_LIDENT Grammar.Entry.e))],
        Gramext.action
          (fun (i : 'a_LIDENT) (loc : int * int) -> (i : 'label))]];
      Grammar.Entry.obj (class_type : 'class_type Grammar.Entry.e), None,
      [None, None,
       [[Gramext.Stoken ("", "object");
         Gramext.srules
           [[Gramext.Sopt
               (Gramext.Snterm
                  (Grammar.Entry.obj
                     (class_self_type : 'class_self_type Grammar.Entry.e)))],
            Gramext.action
              (fun (a : 'class_self_type option) (loc : int * int) ->
                 (Qast.Option a : 'a_opt));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_opt : 'a_opt Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_opt) (loc : int * int) -> (a : 'a_opt))];
         Gramext.srules
           [[Gramext.Slist0
               (Gramext.srules
                  [[Gramext.Snterm
                      (Grammar.Entry.obj
                         (class_sig_item : 'class_sig_item Grammar.Entry.e));
                    Gramext.Stoken ("", ";")],
                   Gramext.action
                     (fun _ (csf : 'class_sig_item) (loc : int * int) ->
                        (csf : 'e__18))])],
            Gramext.action
              (fun (a : 'e__18 list) (loc : int * int) ->
                 (Qast.List a : 'a_list));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_list : 'a_list Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_list) (loc : int * int) -> (a : 'a_list))];
         Gramext.Stoken ("", "end")],
        Gramext.action
          (fun _ (csf : 'a_list) (cst : 'a_opt) _ (loc : int * int) ->
             (Qast.Node ("CtSig", [Qast.Loc; cst; csf]) : 'class_type));
        [Gramext.Snterm
           (Grammar.Entry.obj
              (clty_longident : 'clty_longident Grammar.Entry.e))],
        Gramext.action
          (fun (id : 'clty_longident) (loc : int * int) ->
             (Qast.Node ("CtCon", [Qast.Loc; id; Qast.List []]) :
              'class_type));
        [Gramext.Snterm
           (Grammar.Entry.obj
              (clty_longident : 'clty_longident Grammar.Entry.e));
         Gramext.Stoken ("", "[");
         Gramext.srules
           [[Gramext.Slist1sep
               (Gramext.Snterm
                  (Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e)),
                Gramext.Stoken ("", ","))],
            Gramext.action
              (fun (a : 'ctyp list) (loc : int * int) ->
                 (Qast.List a : 'a_list));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_list : 'a_list Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_list) (loc : int * int) -> (a : 'a_list))];
         Gramext.Stoken ("", "]")],
        Gramext.action
          (fun _ (tl : 'a_list) _ (id : 'clty_longident) (loc : int * int) ->
             (Qast.Node ("CtCon", [Qast.Loc; id; tl]) : 'class_type));
        [Gramext.Stoken ("", "[");
         Gramext.Snterm (Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e));
         Gramext.Stoken ("", "]"); Gramext.Stoken ("", "->"); Gramext.Sself],
        Gramext.action
          (fun (ct : 'class_type) _ _ (t : 'ctyp) _ (loc : int * int) ->
             (Qast.Node ("CtFun", [Qast.Loc; t; ct]) : 'class_type))]];
      Grammar.Entry.obj (class_self_type : 'class_self_type Grammar.Entry.e),
      None,
      [None, None,
       [[Gramext.Stoken ("", "(");
         Gramext.Snterm (Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e));
         Gramext.Stoken ("", ")")],
        Gramext.action
          (fun _ (t : 'ctyp) _ (loc : int * int) -> (t : 'class_self_type))]];
      Grammar.Entry.obj (class_sig_item : 'class_sig_item Grammar.Entry.e),
      None,
      [None, None,
       [[Gramext.Stoken ("", "type");
         Gramext.Snterm (Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e));
         Gramext.Stoken ("", "=");
         Gramext.Snterm (Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e))],
        Gramext.action
          (fun (t2 : 'ctyp) _ (t1 : 'ctyp) _ (loc : int * int) ->
             (Qast.Node ("CgCtr", [Qast.Loc; t1; t2]) : 'class_sig_item));
        [Gramext.Stoken ("", "method");
         Gramext.srules
           [[Gramext.Sopt
               (Gramext.srules
                  [[Gramext.Stoken ("", "private")],
                   Gramext.action
                     (fun (x : string) (loc : int * int) ->
                        (Qast.Str x : 'e__22))])],
            Gramext.action
              (fun (a : 'e__22 option) (loc : int * int) ->
                 (Qast.Option a : 'a_opt));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_opt : 'a_opt Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_opt) (loc : int * int) -> (a : 'a_opt))];
         Gramext.Snterm (Grammar.Entry.obj (label : 'label Grammar.Entry.e));
         Gramext.Stoken ("", ":");
         Gramext.Snterm (Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e))],
        Gramext.action
          (fun (t : 'ctyp) _ (l : 'label) (pf : 'a_opt) _ (loc : int * int) ->
             (Qast.Node ("CgMth", [Qast.Loc; l; o2b pf; t]) :
              'class_sig_item));
        [Gramext.Stoken ("", "method"); Gramext.Stoken ("", "virtual");
         Gramext.srules
           [[Gramext.Sopt
               (Gramext.srules
                  [[Gramext.Stoken ("", "private")],
                   Gramext.action
                     (fun (x : string) (loc : int * int) ->
                        (Qast.Str x : 'e__21))])],
            Gramext.action
              (fun (a : 'e__21 option) (loc : int * int) ->
                 (Qast.Option a : 'a_opt));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_opt : 'a_opt Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_opt) (loc : int * int) -> (a : 'a_opt))];
         Gramext.Snterm (Grammar.Entry.obj (label : 'label Grammar.Entry.e));
         Gramext.Stoken ("", ":");
         Gramext.Snterm (Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e))],
        Gramext.action
          (fun (t : 'ctyp) _ (l : 'label) (pf : 'a_opt) _ _
             (loc : int * int) ->
             (Qast.Node ("CgVir", [Qast.Loc; l; o2b pf; t]) :
              'class_sig_item));
        [Gramext.Stoken ("", "value");
         Gramext.srules
           [[Gramext.Sopt
               (Gramext.srules
                  [[Gramext.Stoken ("", "mutable")],
                   Gramext.action
                     (fun (x : string) (loc : int * int) ->
                        (Qast.Str x : 'e__20))])],
            Gramext.action
              (fun (a : 'e__20 option) (loc : int * int) ->
                 (Qast.Option a : 'a_opt));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_opt : 'a_opt Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_opt) (loc : int * int) -> (a : 'a_opt))];
         Gramext.Snterm (Grammar.Entry.obj (label : 'label Grammar.Entry.e));
         Gramext.Stoken ("", ":");
         Gramext.Snterm (Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e))],
        Gramext.action
          (fun (t : 'ctyp) _ (l : 'label) (mf : 'a_opt) _ (loc : int * int) ->
             (Qast.Node ("CgVal", [Qast.Loc; l; o2b mf; t]) :
              'class_sig_item));
        [Gramext.Stoken ("", "inherit");
         Gramext.Snterm
           (Grammar.Entry.obj (class_type : 'class_type Grammar.Entry.e))],
        Gramext.action
          (fun (cs : 'class_type) _ (loc : int * int) ->
             (Qast.Node ("CgInh", [Qast.Loc; cs]) : 'class_sig_item));
        [Gramext.Stoken ("", "declare");
         Gramext.srules
           [[Gramext.Slist0
               (Gramext.srules
                  [[Gramext.Snterm
                      (Grammar.Entry.obj
                         (class_sig_item : 'class_sig_item Grammar.Entry.e));
                    Gramext.Stoken ("", ";")],
                   Gramext.action
                     (fun _ (s : 'class_sig_item) (loc : int * int) ->
                        (s : 'e__19))])],
            Gramext.action
              (fun (a : 'e__19 list) (loc : int * int) ->
                 (Qast.List a : 'a_list));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_list : 'a_list Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_list) (loc : int * int) -> (a : 'a_list))];
         Gramext.Stoken ("", "end")],
        Gramext.action
          (fun _ (st : 'a_list) _ (loc : int * int) ->
             (Qast.Node ("CgDcl", [Qast.Loc; st]) : 'class_sig_item))]];
      Grammar.Entry.obj
        (class_description : 'class_description Grammar.Entry.e),
      None,
      [None, None,
       [[Gramext.srules
           [[Gramext.Sopt
               (Gramext.srules
                  [[Gramext.Stoken ("", "virtual")],
                   Gramext.action
                     (fun (x : string) (loc : int * int) ->
                        (Qast.Str x : 'e__23))])],
            Gramext.action
              (fun (a : 'e__23 option) (loc : int * int) ->
                 (Qast.Option a : 'a_opt));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_opt : 'a_opt Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_opt) (loc : int * int) -> (a : 'a_opt))];
         Gramext.Snterm
           (Grammar.Entry.obj (a_LIDENT : 'a_LIDENT Grammar.Entry.e));
         Gramext.Snterm
           (Grammar.Entry.obj
              (class_type_parameters :
               'class_type_parameters Grammar.Entry.e));
         Gramext.Stoken ("", ":");
         Gramext.Snterm
           (Grammar.Entry.obj (class_type : 'class_type Grammar.Entry.e))],
        Gramext.action
          (fun (ct : 'class_type) _ (ctp : 'class_type_parameters)
             (n : 'a_LIDENT) (vf : 'a_opt) (loc : int * int) ->
             (Qast.Record
                ["ciLoc", Qast.Loc; "ciVir", o2b vf; "ciPrm", ctp; "ciNam", n;
                 "ciExp", ct] :
              'class_description))]];
      Grammar.Entry.obj
        (class_type_declaration : 'class_type_declaration Grammar.Entry.e),
      None,
      [None, None,
       [[Gramext.srules
           [[Gramext.Sopt
               (Gramext.srules
                  [[Gramext.Stoken ("", "virtual")],
                   Gramext.action
                     (fun (x : string) (loc : int * int) ->
                        (Qast.Str x : 'e__24))])],
            Gramext.action
              (fun (a : 'e__24 option) (loc : int * int) ->
                 (Qast.Option a : 'a_opt));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_opt : 'a_opt Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_opt) (loc : int * int) -> (a : 'a_opt))];
         Gramext.Snterm
           (Grammar.Entry.obj (a_LIDENT : 'a_LIDENT Grammar.Entry.e));
         Gramext.Snterm
           (Grammar.Entry.obj
              (class_type_parameters :
               'class_type_parameters Grammar.Entry.e));
         Gramext.Stoken ("", "=");
         Gramext.Snterm
           (Grammar.Entry.obj (class_type : 'class_type Grammar.Entry.e))],
        Gramext.action
          (fun (cs : 'class_type) _ (ctp : 'class_type_parameters)
             (n : 'a_LIDENT) (vf : 'a_opt) (loc : int * int) ->
             (Qast.Record
                ["ciLoc", Qast.Loc; "ciVir", o2b vf; "ciPrm", ctp; "ciNam", n;
                 "ciExp", cs] :
              'class_type_declaration))]];
      Grammar.Entry.obj (expr : 'expr Grammar.Entry.e),
      Some (Gramext.Level "apply"),
      [None, Some Gramext.LeftA,
       [[Gramext.Stoken ("", "new");
         Gramext.Snterm
           (Grammar.Entry.obj
              (class_longident : 'class_longident Grammar.Entry.e))],
        Gramext.action
          (fun (i : 'class_longident) _ (loc : int * int) ->
             (Qast.Node ("ExNew", [Qast.Loc; i]) : 'expr))]];
      Grammar.Entry.obj (expr : 'expr Grammar.Entry.e),
      Some (Gramext.Level "."),
      [None, None,
       [[Gramext.Sself; Gramext.Stoken ("", "#");
         Gramext.Snterm (Grammar.Entry.obj (label : 'label Grammar.Entry.e))],
        Gramext.action
          (fun (lab : 'label) _ (e : 'expr) (loc : int * int) ->
             (Qast.Node ("ExSnd", [Qast.Loc; e; lab]) : 'expr))]];
      Grammar.Entry.obj (expr : 'expr Grammar.Entry.e),
      Some (Gramext.Level "simple"),
      [None, None,
       [[Gramext.Stoken ("", "{<");
         Gramext.srules
           [[Gramext.Slist0sep
               (Gramext.Snterm
                  (Grammar.Entry.obj
                     (field_expr : 'field_expr Grammar.Entry.e)),
                Gramext.Stoken ("", ";"))],
            Gramext.action
              (fun (a : 'field_expr list) (loc : int * int) ->
                 (Qast.List a : 'a_list));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_list : 'a_list Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_list) (loc : int * int) -> (a : 'a_list))];
         Gramext.Stoken ("", ">}")],
        Gramext.action
          (fun _ (fel : 'a_list) _ (loc : int * int) ->
             (Qast.Node ("ExOvr", [Qast.Loc; fel]) : 'expr));
        [Gramext.Stoken ("", "("); Gramext.Sself; Gramext.Stoken ("", ":>");
         Gramext.Snterm (Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e));
         Gramext.Stoken ("", ")")],
        Gramext.action
          (fun _ (t : 'ctyp) _ (e : 'expr) _ (loc : int * int) ->
             (Qast.Node ("ExCoe", [Qast.Loc; e; Qast.Option None; t]) :
              'expr));
        [Gramext.Stoken ("", "("); Gramext.Sself; Gramext.Stoken ("", ":");
         Gramext.Snterm (Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e));
         Gramext.Stoken ("", ":>");
         Gramext.Snterm (Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e));
         Gramext.Stoken ("", ")")],
        Gramext.action
          (fun _ (t2 : 'ctyp) _ (t : 'ctyp) _ (e : 'expr) _
             (loc : int * int) ->
             (Qast.Node ("ExCoe", [Qast.Loc; e; Qast.Option (Some t); t2]) :
              'expr))]];
      Grammar.Entry.obj (field_expr : 'field_expr Grammar.Entry.e), None,
      [None, None,
       [[Gramext.Snterm (Grammar.Entry.obj (label : 'label Grammar.Entry.e));
         Gramext.Stoken ("", "=");
         Gramext.Snterm (Grammar.Entry.obj (expr : 'expr Grammar.Entry.e))],
        Gramext.action
          (fun (e : 'expr) _ (l : 'label) (loc : int * int) ->
             (Qast.Tuple [l; e] : 'field_expr))]];
      Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e),
      Some (Gramext.Level "simple"),
      [None, None,
       [[Gramext.Stoken ("", "<");
         Gramext.srules
           [[Gramext.Slist0sep
               (Gramext.Snterm
                  (Grammar.Entry.obj (field : 'field Grammar.Entry.e)),
                Gramext.Stoken ("", ";"))],
            Gramext.action
              (fun (a : 'field list) (loc : int * int) ->
                 (Qast.List a : 'a_list));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_list : 'a_list Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_list) (loc : int * int) -> (a : 'a_list))];
         Gramext.srules
           [[Gramext.Sopt
               (Gramext.srules
                  [[Gramext.Stoken ("", "..")],
                   Gramext.action
                     (fun (x : string) (loc : int * int) ->
                        (Qast.Str x : 'e__25))])],
            Gramext.action
              (fun (a : 'e__25 option) (loc : int * int) ->
                 (Qast.Option a : 'a_opt));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_opt : 'a_opt Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_opt) (loc : int * int) -> (a : 'a_opt))];
         Gramext.Stoken ("", ">")],
        Gramext.action
          (fun _ (v : 'a_opt) (ml : 'a_list) _ (loc : int * int) ->
             (Qast.Node ("TyObj", [Qast.Loc; ml; o2b v]) : 'ctyp));
        [Gramext.Stoken ("", "#");
         Gramext.Snterm
           (Grammar.Entry.obj
              (class_longident : 'class_longident Grammar.Entry.e))],
        Gramext.action
          (fun (id : 'class_longident) _ (loc : int * int) ->
             (Qast.Node ("TyCls", [Qast.Loc; id]) : 'ctyp))]];
      Grammar.Entry.obj (field : 'field Grammar.Entry.e), None,
      [None, None,
       [[Gramext.Snterm
           (Grammar.Entry.obj (a_LIDENT : 'a_LIDENT Grammar.Entry.e));
         Gramext.Stoken ("", ":");
         Gramext.Snterm (Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e))],
        Gramext.action
          (fun (t : 'ctyp) _ (lab : 'a_LIDENT) (loc : int * int) ->
             (Qast.Tuple [lab; t] : 'field))]];
      Grammar.Entry.obj (typevar : 'typevar Grammar.Entry.e), None,
      [None, None,
       [[Gramext.Stoken ("", "'");
         Gramext.Snterm (Grammar.Entry.obj (ident : 'ident Grammar.Entry.e))],
        Gramext.action
          (fun (i : 'ident) _ (loc : int * int) -> (i : 'typevar))]];
      Grammar.Entry.obj (clty_longident : 'clty_longident Grammar.Entry.e),
      None,
      [None, None,
       [[Gramext.Snterm
           (Grammar.Entry.obj (a_LIDENT : 'a_LIDENT Grammar.Entry.e))],
        Gramext.action
          (fun (i : 'a_LIDENT) (loc : int * int) ->
             (Qast.List [i] : 'clty_longident));
        [Gramext.Snterm
           (Grammar.Entry.obj (a_UIDENT : 'a_UIDENT Grammar.Entry.e));
         Gramext.Stoken ("", "."); Gramext.Sself],
        Gramext.action
          (fun (l : 'clty_longident) _ (m : 'a_UIDENT) (loc : int * int) ->
             (Qast.Cons (m, l) : 'clty_longident))]];
      Grammar.Entry.obj (class_longident : 'class_longident Grammar.Entry.e),
      None,
      [None, None,
       [[Gramext.Snterm
           (Grammar.Entry.obj (a_LIDENT : 'a_LIDENT Grammar.Entry.e))],
        Gramext.action
          (fun (i : 'a_LIDENT) (loc : int * int) ->
             (Qast.List [i] : 'class_longident));
        [Gramext.Snterm
           (Grammar.Entry.obj (a_UIDENT : 'a_UIDENT Grammar.Entry.e));
         Gramext.Stoken ("", "."); Gramext.Sself],
        Gramext.action
          (fun (l : 'class_longident) _ (m : 'a_UIDENT) (loc : int * int) ->
             (Qast.Cons (m, l) : 'class_longident))]];
      Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e),
      Some (Gramext.After "arrow"),
      [None, Some Gramext.NonA,
       [[Gramext.Snterm
           (Grammar.Entry.obj
              (a_QUESTIONIDENT : 'a_QUESTIONIDENT Grammar.Entry.e));
         Gramext.Stoken ("", ":"); Gramext.Sself],
        Gramext.action
          (fun (t : 'ctyp) _ (i : 'a_QUESTIONIDENT) (loc : int * int) ->
             (Qast.Node ("TyOlb", [Qast.Loc; i; t]) : 'ctyp));
        [Gramext.Snterm
           (Grammar.Entry.obj (a_TILDEIDENT : 'a_TILDEIDENT Grammar.Entry.e));
         Gramext.Stoken ("", ":"); Gramext.Sself],
        Gramext.action
          (fun (t : 'ctyp) _ (i : 'a_TILDEIDENT) (loc : int * int) ->
             (Qast.Node ("TyLab", [Qast.Loc; i; t]) : 'ctyp))]];
      Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e),
      Some (Gramext.Level "simple"),
      [None, None,
       [[Gramext.Stoken ("", "["); Gramext.Stoken ("", "<");
         Gramext.Snterm
           (Grammar.Entry.obj
              (row_field_list : 'row_field_list Grammar.Entry.e));
         Gramext.Stoken ("", ">");
         Gramext.srules
           [[Gramext.Slist1
               (Gramext.Snterm
                  (Grammar.Entry.obj
                     (name_tag : 'name_tag Grammar.Entry.e)))],
            Gramext.action
              (fun (a : 'name_tag list) (loc : int * int) ->
                 (Qast.List a : 'a_list));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_list : 'a_list Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_list) (loc : int * int) -> (a : 'a_list))];
         Gramext.Stoken ("", "]")],
        Gramext.action
          (fun _ (ntl : 'a_list) _ (rfl : 'row_field_list) _ _
             (loc : int * int) ->
             (Qast.Node
                ("TyVrn",
                 [Qast.Loc; rfl;
                  Qast.Option (Some (Qast.Option (Some ntl)))]) :
              'ctyp));
        [Gramext.Stoken ("", "["); Gramext.Stoken ("", "<");
         Gramext.Snterm
           (Grammar.Entry.obj
              (row_field_list : 'row_field_list Grammar.Entry.e));
         Gramext.Stoken ("", "]")],
        Gramext.action
          (fun _ (rfl : 'row_field_list) _ _ (loc : int * int) ->
             (Qast.Node
                ("TyVrn",
                 [Qast.Loc; rfl;
                  Qast.Option (Some (Qast.Option (Some (Qast.List []))))]) :
              'ctyp));
        [Gramext.Stoken ("", "["); Gramext.Stoken ("", ">");
         Gramext.Snterm
           (Grammar.Entry.obj
              (row_field_list : 'row_field_list Grammar.Entry.e));
         Gramext.Stoken ("", "]")],
        Gramext.action
          (fun _ (rfl : 'row_field_list) _ _ (loc : int * int) ->
             (Qast.Node
                ("TyVrn",
                 [Qast.Loc; rfl; Qast.Option (Some (Qast.Option None))]) :
              'ctyp));
        [Gramext.Stoken ("", "["); Gramext.Stoken ("", "=");
         Gramext.Snterm
           (Grammar.Entry.obj
              (row_field_list : 'row_field_list Grammar.Entry.e));
         Gramext.Stoken ("", "]")],
        Gramext.action
          (fun _ (rfl : 'row_field_list) _ _ (loc : int * int) ->
             (Qast.Node ("TyVrn", [Qast.Loc; rfl; Qast.Option None]) :
              'ctyp))]];
      Grammar.Entry.obj (row_field_list : 'row_field_list Grammar.Entry.e),
      None,
      [None, None,
       [[Gramext.srules
           [[Gramext.Slist0sep
               (Gramext.Snterm
                  (Grammar.Entry.obj
                     (row_field : 'row_field Grammar.Entry.e)),
                Gramext.Stoken ("", "|"))],
            Gramext.action
              (fun (a : 'row_field list) (loc : int * int) ->
                 (Qast.List a : 'a_list));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_list : 'a_list Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_list) (loc : int * int) -> (a : 'a_list))]],
        Gramext.action
          (fun (rfl : 'a_list) (loc : int * int) ->
             (rfl : 'row_field_list))]];
      Grammar.Entry.obj (row_field : 'row_field Grammar.Entry.e), None,
      [None, None,
       [[Gramext.Snterm (Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e))],
        Gramext.action
          (fun (t : 'ctyp) (loc : int * int) ->
             (Qast.Node ("RfInh", [t]) : 'row_field));
        [Gramext.Stoken ("", "`");
         Gramext.Snterm (Grammar.Entry.obj (ident : 'ident Grammar.Entry.e));
         Gramext.Stoken ("", "of");
         Gramext.srules
           [[Gramext.Sopt
               (Gramext.srules
                  [[Gramext.Stoken ("", "&")],
                   Gramext.action
                     (fun (x : string) (loc : int * int) ->
                        (Qast.Str x : 'e__26))])],
            Gramext.action
              (fun (a : 'e__26 option) (loc : int * int) ->
                 (Qast.Option a : 'a_opt));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_opt : 'a_opt Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_opt) (loc : int * int) -> (a : 'a_opt))];
         Gramext.srules
           [[Gramext.Slist1sep
               (Gramext.Snterm
                  (Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e)),
                Gramext.Stoken ("", "&"))],
            Gramext.action
              (fun (a : 'ctyp list) (loc : int * int) ->
                 (Qast.List a : 'a_list));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_list : 'a_list Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_list) (loc : int * int) -> (a : 'a_list))]],
        Gramext.action
          (fun (l : 'a_list) (ao : 'a_opt) _ (i : 'ident) _
             (loc : int * int) ->
             (Qast.Node ("RfTag", [i; o2b ao; l]) : 'row_field));
        [Gramext.Stoken ("", "`");
         Gramext.Snterm (Grammar.Entry.obj (ident : 'ident Grammar.Entry.e))],
        Gramext.action
          (fun (i : 'ident) _ (loc : int * int) ->
             (Qast.Node ("RfTag", [i; Qast.Bool true; Qast.List []]) :
              'row_field))]];
      Grammar.Entry.obj (name_tag : 'name_tag Grammar.Entry.e), None,
      [None, None,
       [[Gramext.Stoken ("", "`");
         Gramext.Snterm (Grammar.Entry.obj (ident : 'ident Grammar.Entry.e))],
        Gramext.action
          (fun (i : 'ident) _ (loc : int * int) -> (i : 'name_tag))]];
      Grammar.Entry.obj (patt : 'patt Grammar.Entry.e),
      Some (Gramext.Level "simple"),
      [None, None,
       [[Gramext.Stoken ("", "?"); Gramext.Stoken ("", "(");
         Gramext.Snterm
           (Grammar.Entry.obj (patt_tcon : 'patt_tcon Grammar.Entry.e));
         Gramext.srules
           [[Gramext.Sopt
               (Gramext.Snterm
                  (Grammar.Entry.obj (eq_expr : 'eq_expr Grammar.Entry.e)))],
            Gramext.action
              (fun (a : 'eq_expr option) (loc : int * int) ->
                 (Qast.Option a : 'a_opt));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_opt : 'a_opt Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_opt) (loc : int * int) -> (a : 'a_opt))];
         Gramext.Stoken ("", ")")],
        Gramext.action
          (fun _ (eo : 'a_opt) (p : 'patt_tcon) _ _ (loc : int * int) ->
             (Qast.Node
                ("PaOlb",
                 [Qast.Loc; Qast.Str "";
                  Qast.Option (Some (Qast.Tuple [p; eo]))]) :
              'patt));
        [Gramext.Snterm
           (Grammar.Entry.obj
              (a_QUESTIONIDENT : 'a_QUESTIONIDENT Grammar.Entry.e))],
        Gramext.action
          (fun (i : 'a_QUESTIONIDENT) (loc : int * int) ->
             (Qast.Node ("PaOlb", [Qast.Loc; i; Qast.Option None]) : 'patt));
        [Gramext.Snterm
           (Grammar.Entry.obj
              (a_QUESTIONIDENT : 'a_QUESTIONIDENT Grammar.Entry.e));
         Gramext.Stoken ("", ":"); Gramext.Stoken ("", "(");
         Gramext.Snterm
           (Grammar.Entry.obj (patt_tcon : 'patt_tcon Grammar.Entry.e));
         Gramext.srules
           [[Gramext.Sopt
               (Gramext.Snterm
                  (Grammar.Entry.obj (eq_expr : 'eq_expr Grammar.Entry.e)))],
            Gramext.action
              (fun (a : 'eq_expr option) (loc : int * int) ->
                 (Qast.Option a : 'a_opt));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_opt : 'a_opt Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_opt) (loc : int * int) -> (a : 'a_opt))];
         Gramext.Stoken ("", ")")],
        Gramext.action
          (fun _ (eo : 'a_opt) (p : 'patt_tcon) _ _ (i : 'a_QUESTIONIDENT)
             (loc : int * int) ->
             (Qast.Node
                ("PaOlb",
                 [Qast.Loc; i; Qast.Option (Some (Qast.Tuple [p; eo]))]) :
              'patt));
        [Gramext.Snterm
           (Grammar.Entry.obj
              (a_TILDEIDENT : 'a_TILDEIDENT Grammar.Entry.e))],
        Gramext.action
          (fun (i : 'a_TILDEIDENT) (loc : int * int) ->
             (Qast.Node ("PaLab", [Qast.Loc; i; Qast.Option None]) : 'patt));
        [Gramext.Snterm
           (Grammar.Entry.obj (a_TILDEIDENT : 'a_TILDEIDENT Grammar.Entry.e));
         Gramext.Stoken ("", ":"); Gramext.Sself],
        Gramext.action
          (fun (p : 'patt) _ (i : 'a_TILDEIDENT) (loc : int * int) ->
             (Qast.Node ("PaLab", [Qast.Loc; i; Qast.Option (Some p)]) :
              'patt));
        [Gramext.Stoken ("", "#");
         Gramext.Snterm
           (Grammar.Entry.obj (mod_ident : 'mod_ident Grammar.Entry.e))],
        Gramext.action
          (fun (sl : 'mod_ident) _ (loc : int * int) ->
             (Qast.Node ("PaTyp", [Qast.Loc; sl]) : 'patt));
        [Gramext.Stoken ("", "`");
         Gramext.Snterm (Grammar.Entry.obj (ident : 'ident Grammar.Entry.e))],
        Gramext.action
          (fun (s : 'ident) _ (loc : int * int) ->
             (Qast.Node ("PaVrn", [Qast.Loc; s]) : 'patt))]];
      Grammar.Entry.obj (patt_tcon : 'patt_tcon Grammar.Entry.e), None,
      [None, None,
       [[Gramext.Snterm (Grammar.Entry.obj (patt : 'patt Grammar.Entry.e))],
        Gramext.action
          (fun (p : 'patt) (loc : int * int) -> (p : 'patt_tcon));
        [Gramext.Snterm (Grammar.Entry.obj (patt : 'patt Grammar.Entry.e));
         Gramext.Stoken ("", ":");
         Gramext.Snterm (Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e))],
        Gramext.action
          (fun (t : 'ctyp) _ (p : 'patt) (loc : int * int) ->
             (Qast.Node ("PaTyc", [Qast.Loc; p; t]) : 'patt_tcon))]];
      Grammar.Entry.obj (ipatt : 'ipatt Grammar.Entry.e), None,
      [None, None,
       [[Gramext.Stoken ("", "?"); Gramext.Stoken ("", "(");
         Gramext.Snterm
           (Grammar.Entry.obj (ipatt_tcon : 'ipatt_tcon Grammar.Entry.e));
         Gramext.srules
           [[Gramext.Sopt
               (Gramext.Snterm
                  (Grammar.Entry.obj (eq_expr : 'eq_expr Grammar.Entry.e)))],
            Gramext.action
              (fun (a : 'eq_expr option) (loc : int * int) ->
                 (Qast.Option a : 'a_opt));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_opt : 'a_opt Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_opt) (loc : int * int) -> (a : 'a_opt))];
         Gramext.Stoken ("", ")")],
        Gramext.action
          (fun _ (eo : 'a_opt) (p : 'ipatt_tcon) _ _ (loc : int * int) ->
             (Qast.Node
                ("PaOlb",
                 [Qast.Loc; Qast.Str "";
                  Qast.Option (Some (Qast.Tuple [p; eo]))]) :
              'ipatt));
        [Gramext.Snterm
           (Grammar.Entry.obj
              (a_QUESTIONIDENT : 'a_QUESTIONIDENT Grammar.Entry.e))],
        Gramext.action
          (fun (i : 'a_QUESTIONIDENT) (loc : int * int) ->
             (Qast.Node ("PaOlb", [Qast.Loc; i; Qast.Option None]) : 'ipatt));
        [Gramext.Snterm
           (Grammar.Entry.obj
              (a_QUESTIONIDENT : 'a_QUESTIONIDENT Grammar.Entry.e));
         Gramext.Stoken ("", ":"); Gramext.Stoken ("", "(");
         Gramext.Snterm
           (Grammar.Entry.obj (ipatt_tcon : 'ipatt_tcon Grammar.Entry.e));
         Gramext.srules
           [[Gramext.Sopt
               (Gramext.Snterm
                  (Grammar.Entry.obj (eq_expr : 'eq_expr Grammar.Entry.e)))],
            Gramext.action
              (fun (a : 'eq_expr option) (loc : int * int) ->
                 (Qast.Option a : 'a_opt));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_opt : 'a_opt Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_opt) (loc : int * int) -> (a : 'a_opt))];
         Gramext.Stoken ("", ")")],
        Gramext.action
          (fun _ (eo : 'a_opt) (p : 'ipatt_tcon) _ _ (i : 'a_QUESTIONIDENT)
             (loc : int * int) ->
             (Qast.Node
                ("PaOlb",
                 [Qast.Loc; i; Qast.Option (Some (Qast.Tuple [p; eo]))]) :
              'ipatt));
        [Gramext.Snterm
           (Grammar.Entry.obj
              (a_TILDEIDENT : 'a_TILDEIDENT Grammar.Entry.e))],
        Gramext.action
          (fun (i : 'a_TILDEIDENT) (loc : int * int) ->
             (Qast.Node ("PaLab", [Qast.Loc; i; Qast.Option None]) : 'ipatt));
        [Gramext.Snterm
           (Grammar.Entry.obj (a_TILDEIDENT : 'a_TILDEIDENT Grammar.Entry.e));
         Gramext.Stoken ("", ":"); Gramext.Sself],
        Gramext.action
          (fun (p : 'ipatt) _ (i : 'a_TILDEIDENT) (loc : int * int) ->
             (Qast.Node ("PaLab", [Qast.Loc; i; Qast.Option (Some p)]) :
              'ipatt))]];
      Grammar.Entry.obj (ipatt_tcon : 'ipatt_tcon Grammar.Entry.e), None,
      [None, None,
       [[Gramext.Snterm (Grammar.Entry.obj (ipatt : 'ipatt Grammar.Entry.e))],
        Gramext.action
          (fun (p : 'ipatt) (loc : int * int) -> (p : 'ipatt_tcon));
        [Gramext.Snterm (Grammar.Entry.obj (ipatt : 'ipatt Grammar.Entry.e));
         Gramext.Stoken ("", ":");
         Gramext.Snterm (Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e))],
        Gramext.action
          (fun (t : 'ctyp) _ (p : 'ipatt) (loc : int * int) ->
             (Qast.Node ("PaTyc", [Qast.Loc; p; t]) : 'ipatt_tcon))]];
      Grammar.Entry.obj (eq_expr : 'eq_expr Grammar.Entry.e), None,
      [None, None,
       [[Gramext.Stoken ("", "=");
         Gramext.Snterm (Grammar.Entry.obj (expr : 'expr Grammar.Entry.e))],
        Gramext.action
          (fun (e : 'expr) _ (loc : int * int) -> (e : 'eq_expr))]];
      Grammar.Entry.obj (expr : 'expr Grammar.Entry.e),
      Some (Gramext.After "apply"),
      [Some "label", Some Gramext.NonA,
       [[Gramext.Snterm
           (Grammar.Entry.obj
              (a_QUESTIONIDENT : 'a_QUESTIONIDENT Grammar.Entry.e))],
        Gramext.action
          (fun (i : 'a_QUESTIONIDENT) (loc : int * int) ->
             (Qast.Node ("ExOlb", [Qast.Loc; i; Qast.Option None]) : 'expr));
        [Gramext.Snterm
           (Grammar.Entry.obj
              (a_QUESTIONIDENT : 'a_QUESTIONIDENT Grammar.Entry.e));
         Gramext.Stoken ("", ":"); Gramext.Sself],
        Gramext.action
          (fun (e : 'expr) _ (i : 'a_QUESTIONIDENT) (loc : int * int) ->
             (Qast.Node ("ExOlb", [Qast.Loc; i; Qast.Option (Some e)]) :
              'expr));
        [Gramext.Snterm
           (Grammar.Entry.obj
              (a_TILDEIDENT : 'a_TILDEIDENT Grammar.Entry.e))],
        Gramext.action
          (fun (i : 'a_TILDEIDENT) (loc : int * int) ->
             (Qast.Node ("ExLab", [Qast.Loc; i; Qast.Option None]) : 'expr));
        [Gramext.Snterm
           (Grammar.Entry.obj (a_TILDEIDENT : 'a_TILDEIDENT Grammar.Entry.e));
         Gramext.Stoken ("", ":"); Gramext.Sself],
        Gramext.action
          (fun (e : 'expr) _ (i : 'a_TILDEIDENT) (loc : int * int) ->
             (Qast.Node ("ExLab", [Qast.Loc; i; Qast.Option (Some e)]) :
              'expr))]];
      Grammar.Entry.obj (expr : 'expr Grammar.Entry.e),
      Some (Gramext.Level "simple"),
      [None, None,
       [[Gramext.Stoken ("", "`");
         Gramext.Snterm (Grammar.Entry.obj (ident : 'ident Grammar.Entry.e))],
        Gramext.action
          (fun (s : 'ident) _ (loc : int * int) ->
             (Qast.Node ("ExVrn", [Qast.Loc; s]) : 'expr))]];
      Grammar.Entry.obj (direction_flag : 'direction_flag Grammar.Entry.e),
      None,
      [None, None,
       [[Gramext.Stoken ("", "downto")],
        Gramext.action
          (fun _ (loc : int * int) -> (Qast.Bool false : 'direction_flag));
        [Gramext.Stoken ("", "to")],
        Gramext.action
          (fun _ (loc : int * int) -> (Qast.Bool true : 'direction_flag))]];
      Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e),
      Some (Gramext.Level "simple"),
      [None, None,
       [[Gramext.Stoken ("", "[|");
         Gramext.Snterm
           (Grammar.Entry.obj
              (warning_variant : 'warning_variant Grammar.Entry.e));
         Gramext.Stoken ("", "<");
         Gramext.Snterm
           (Grammar.Entry.obj
              (row_field_list : 'row_field_list Grammar.Entry.e));
         Gramext.Stoken ("", ">");
         Gramext.srules
           [[Gramext.Slist1
               (Gramext.Snterm
                  (Grammar.Entry.obj
                     (name_tag : 'name_tag Grammar.Entry.e)))],
            Gramext.action
              (fun (a : 'name_tag list) (loc : int * int) ->
                 (Qast.List a : 'a_list));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_list : 'a_list Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_list) (loc : int * int) -> (a : 'a_list))];
         Gramext.Stoken ("", "|]")],
        Gramext.action
          (fun _ (ntl : 'a_list) _ (rfl : 'row_field_list) _ _ _
             (loc : int * int) ->
             (Qast.Node
                ("TyVrn",
                 [Qast.Loc; rfl;
                  Qast.Option (Some (Qast.Option (Some ntl)))]) :
              'ctyp));
        [Gramext.Stoken ("", "[|");
         Gramext.Snterm
           (Grammar.Entry.obj
              (warning_variant : 'warning_variant Grammar.Entry.e));
         Gramext.Stoken ("", "<");
         Gramext.Snterm
           (Grammar.Entry.obj
              (row_field_list : 'row_field_list Grammar.Entry.e));
         Gramext.Stoken ("", "|]")],
        Gramext.action
          (fun _ (rfl : 'row_field_list) _ _ _ (loc : int * int) ->
             (Qast.Node
                ("TyVrn",
                 [Qast.Loc; rfl;
                  Qast.Option (Some (Qast.Option (Some (Qast.List []))))]) :
              'ctyp));
        [Gramext.Stoken ("", "[|");
         Gramext.Snterm
           (Grammar.Entry.obj
              (warning_variant : 'warning_variant Grammar.Entry.e));
         Gramext.Stoken ("", ">");
         Gramext.Snterm
           (Grammar.Entry.obj
              (row_field_list : 'row_field_list Grammar.Entry.e));
         Gramext.Stoken ("", "|]")],
        Gramext.action
          (fun _ (rfl : 'row_field_list) _ _ _ (loc : int * int) ->
             (Qast.Node
                ("TyVrn",
                 [Qast.Loc; rfl; Qast.Option (Some (Qast.Option None))]) :
              'ctyp));
        [Gramext.Stoken ("", "[|");
         Gramext.Snterm
           (Grammar.Entry.obj
              (warning_variant : 'warning_variant Grammar.Entry.e));
         Gramext.Snterm
           (Grammar.Entry.obj
              (row_field_list : 'row_field_list Grammar.Entry.e));
         Gramext.Stoken ("", "|]")],
        Gramext.action
          (fun _ (rfl : 'row_field_list) _ _ (loc : int * int) ->
             (Qast.Node ("TyVrn", [Qast.Loc; rfl; Qast.Option None]) :
              'ctyp))]];
      Grammar.Entry.obj (warning_variant : 'warning_variant Grammar.Entry.e),
      None,
      [None, None,
       [[],
        Gramext.action
          (fun (loc : int * int) ->
             (warn_variant Qast.Loc : 'warning_variant))]];
      Grammar.Entry.obj (expr : 'expr Grammar.Entry.e),
      Some (Gramext.Level "top"),
      [None, None,
       [[Gramext.Stoken ("", "while"); Gramext.Sself;
         Gramext.Stoken ("", "do");
         Gramext.srules
           [[Gramext.Slist0
               (Gramext.srules
                  [[Gramext.Snterm
                      (Grammar.Entry.obj (expr : 'expr Grammar.Entry.e));
                    Gramext.Stoken ("", ";")],
                   Gramext.action
                     (fun _ (e : 'expr) (loc : int * int) -> (e : 'e__29))])],
            Gramext.action
              (fun (a : 'e__29 list) (loc : int * int) ->
                 (Qast.List a : 'a_list));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_list : 'a_list Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_list) (loc : int * int) -> (a : 'a_list))];
         Gramext.Snterm
           (Grammar.Entry.obj
              (warning_sequence : 'warning_sequence Grammar.Entry.e));
         Gramext.Stoken ("", "done")],
        Gramext.action
          (fun _ _ (seq : 'a_list) _ (e : 'expr) _ (loc : int * int) ->
             (Qast.Node ("ExWhi", [Qast.Loc; e; seq]) : 'expr));
        [Gramext.Stoken ("", "for");
         Gramext.Snterm
           (Grammar.Entry.obj (a_LIDENT : 'a_LIDENT Grammar.Entry.e));
         Gramext.Stoken ("", "="); Gramext.Sself;
         Gramext.Snterm
           (Grammar.Entry.obj
              (direction_flag : 'direction_flag Grammar.Entry.e));
         Gramext.Sself; Gramext.Stoken ("", "do");
         Gramext.srules
           [[Gramext.Slist0
               (Gramext.srules
                  [[Gramext.Snterm
                      (Grammar.Entry.obj (expr : 'expr Grammar.Entry.e));
                    Gramext.Stoken ("", ";")],
                   Gramext.action
                     (fun _ (e : 'expr) (loc : int * int) -> (e : 'e__28))])],
            Gramext.action
              (fun (a : 'e__28 list) (loc : int * int) ->
                 (Qast.List a : 'a_list));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_list : 'a_list Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_list) (loc : int * int) -> (a : 'a_list))];
         Gramext.Snterm
           (Grammar.Entry.obj
              (warning_sequence : 'warning_sequence Grammar.Entry.e));
         Gramext.Stoken ("", "done")],
        Gramext.action
          (fun _ _ (seq : 'a_list) _ (e2 : 'expr) (df : 'direction_flag)
             (e1 : 'expr) _ (i : 'a_LIDENT) _ (loc : int * int) ->
             (Qast.Node ("ExFor", [Qast.Loc; i; e1; e2; df; seq]) : 'expr));
        [Gramext.Stoken ("", "do");
         Gramext.srules
           [[Gramext.Slist0
               (Gramext.srules
                  [[Gramext.Snterm
                      (Grammar.Entry.obj (expr : 'expr Grammar.Entry.e));
                    Gramext.Stoken ("", ";")],
                   Gramext.action
                     (fun _ (e : 'expr) (loc : int * int) -> (e : 'e__27))])],
            Gramext.action
              (fun (a : 'e__27 list) (loc : int * int) ->
                 (Qast.List a : 'a_list));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_list : 'a_list Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_list) (loc : int * int) -> (a : 'a_list))];
         Gramext.Stoken ("", "return");
         Gramext.Snterm
           (Grammar.Entry.obj
              (warning_sequence : 'warning_sequence Grammar.Entry.e));
         Gramext.Sself],
        Gramext.action
          (fun (e : 'expr) _ _ (seq : 'a_list) _ (loc : int * int) ->
             (Qast.Node ("ExSeq", [Qast.Loc; append_elem seq e]) : 'expr))]];
      Grammar.Entry.obj
        (warning_sequence : 'warning_sequence Grammar.Entry.e),
      None,
      [None, None,
       [[],
        Gramext.action
          (fun (loc : int * int) ->
             (warn_sequence Qast.Loc : 'warning_sequence))]];
      Grammar.Entry.obj (sequence : 'sequence Grammar.Entry.e), None,
      [None, None,
       [[Gramext.Stoken ("ANTIQUOT", "list")],
        Gramext.action
          (fun (a : string) (loc : int * int) ->
             (antiquot "list" loc a : 'sequence))]];
      Grammar.Entry.obj (expr_ident : 'expr_ident Grammar.Entry.e), None,
      [None, None,
       [[Gramext.Stoken ("ANTIQUOT", "")],
        Gramext.action
          (fun (a : string) (loc : int * int) ->
             (antiquot "" loc a : 'expr_ident))]];
      Grammar.Entry.obj
        (patt_label_ident : 'patt_label_ident Grammar.Entry.e),
      Some (Gramext.Level "simple"),
      [None, None,
       [[Gramext.Stoken ("ANTIQUOT", "")],
        Gramext.action
          (fun (a : string) (loc : int * int) ->
             (antiquot "" loc a : 'patt_label_ident))]];
      Grammar.Entry.obj (when_expr_opt : 'when_expr_opt Grammar.Entry.e),
      None,
      [None, None,
       [[Gramext.Stoken ("ANTIQUOT", "when")],
        Gramext.action
          (fun (a : string) (loc : int * int) ->
             (antiquot "when" loc a : 'when_expr_opt))]];
      Grammar.Entry.obj (mod_ident : 'mod_ident Grammar.Entry.e), None,
      [None, None,
       [[Gramext.Stoken ("ANTIQUOT", "")],
        Gramext.action
          (fun (a : string) (loc : int * int) ->
             (antiquot "" loc a : 'mod_ident))]];
      Grammar.Entry.obj (clty_longident : 'clty_longident Grammar.Entry.e),
      None,
      [None, None,
       [[Gramext.Snterm
           (Grammar.Entry.obj (a_list : 'a_list Grammar.Entry.e))],
        Gramext.action
          (fun (a : 'a_list) (loc : int * int) -> (a : 'clty_longident))]];
      Grammar.Entry.obj (class_longident : 'class_longident Grammar.Entry.e),
      None,
      [None, None,
       [[Gramext.Snterm
           (Grammar.Entry.obj (a_list : 'a_list Grammar.Entry.e))],
        Gramext.action
          (fun (a : 'a_list) (loc : int * int) -> (a : 'class_longident))]];
      Grammar.Entry.obj (direction_flag : 'direction_flag Grammar.Entry.e),
      None,
      [None, None,
       [[Gramext.Stoken ("ANTIQUOT", "to")],
        Gramext.action
          (fun (a : string) (loc : int * int) ->
             (antiquot "to" loc a : 'direction_flag))]];
      Grammar.Entry.obj (class_expr : 'class_expr Grammar.Entry.e),
      Some (Gramext.Level "simple"),
      [None, None,
       [[Gramext.Stoken ("", "object"); Gramext.Stoken ("ANTIQUOT", "");
         Gramext.Stoken ("", ";");
         Gramext.srules
           [[Gramext.Slist0
               (Gramext.srules
                  [[Gramext.Snterm
                      (Grammar.Entry.obj
                         (class_str_item : 'class_str_item Grammar.Entry.e));
                    Gramext.Stoken ("", ";")],
                   Gramext.action
                     (fun _ (cf : 'class_str_item) (loc : int * int) ->
                        (cf : 'e__30))])],
            Gramext.action
              (fun (a : 'e__30 list) (loc : int * int) ->
                 (Qast.List a : 'a_list));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_list : 'a_list Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_list) (loc : int * int) -> (a : 'a_list))];
         Gramext.Stoken ("", "end")],
        Gramext.action
          (fun _ (csl : 'a_list) _ (x : string) _ (loc : int * int) ->
             (let _ = warn_antiq loc "3.05" in
              Qast.Node
                ("CeStr",
                 [Qast.Loc; Qast.Option None;
                  Qast.Cons (antiquot "" loc x, csl)]) :
              'class_expr));
        [Gramext.Stoken ("", "object"); Gramext.Stoken ("ANTIQUOT", "");
         Gramext.Snterm
           (Grammar.Entry.obj
              (class_structure : 'class_structure Grammar.Entry.e));
         Gramext.Stoken ("", "end")],
        Gramext.action
          (fun _ (cf : 'class_structure) (x : string) _ (loc : int * int) ->
             (let _ = warn_antiq loc "3.05" in
              Qast.Node ("CeStr", [Qast.Loc; antiquot "" loc x; cf]) :
              'class_expr))]];
      Grammar.Entry.obj (class_type : 'class_type Grammar.Entry.e), None,
      [None, None,
       [[Gramext.Stoken ("", "object"); Gramext.Stoken ("ANTIQUOT", "");
         Gramext.Stoken ("", ";");
         Gramext.srules
           [[Gramext.Slist0
               (Gramext.srules
                  [[Gramext.Snterm
                      (Grammar.Entry.obj
                         (class_sig_item : 'class_sig_item Grammar.Entry.e));
                    Gramext.Stoken ("", ";")],
                   Gramext.action
                     (fun _ (csf : 'class_sig_item) (loc : int * int) ->
                        (csf : 'e__32))])],
            Gramext.action
              (fun (a : 'e__32 list) (loc : int * int) ->
                 (Qast.List a : 'a_list));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_list : 'a_list Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_list) (loc : int * int) -> (a : 'a_list))];
         Gramext.Stoken ("", "end")],
        Gramext.action
          (fun _ (csf : 'a_list) _ (x : string) _ (loc : int * int) ->
             (let _ = warn_antiq loc "3.05" in
              Qast.Node
                ("CtSig",
                 [Qast.Loc; Qast.Option None;
                  Qast.Cons (antiquot "" loc x, csf)]) :
              'class_type));
        [Gramext.Stoken ("", "object"); Gramext.Stoken ("ANTIQUOT", "");
         Gramext.srules
           [[Gramext.Slist0
               (Gramext.srules
                  [[Gramext.Snterm
                      (Grammar.Entry.obj
                         (class_sig_item : 'class_sig_item Grammar.Entry.e));
                    Gramext.Stoken ("", ";")],
                   Gramext.action
                     (fun _ (csf : 'class_sig_item) (loc : int * int) ->
                        (csf : 'e__31))])],
            Gramext.action
              (fun (a : 'e__31 list) (loc : int * int) ->
                 (Qast.List a : 'a_list));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_list : 'a_list Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_list) (loc : int * int) -> (a : 'a_list))];
         Gramext.Stoken ("", "end")],
        Gramext.action
          (fun _ (csf : 'a_list) (x : string) _ (loc : int * int) ->
             (let _ = warn_antiq loc "3.05" in
              Qast.Node ("CtSig", [Qast.Loc; antiquot "" loc x; csf]) :
              'class_type))]];
      Grammar.Entry.obj (expr : 'expr Grammar.Entry.e),
      Some (Gramext.Level "top"),
      [None, None,
       [[Gramext.Stoken ("", "let"); Gramext.Stoken ("ANTIQUOT", "rec");
         Gramext.srules
           [[Gramext.Slist1sep
               (Gramext.Snterm
                  (Grammar.Entry.obj
                     (let_binding : 'let_binding Grammar.Entry.e)),
                Gramext.Stoken ("", "and"))],
            Gramext.action
              (fun (a : 'let_binding list) (loc : int * int) ->
                 (Qast.List a : 'a_list));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_list : 'a_list Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_list) (loc : int * int) -> (a : 'a_list))];
         Gramext.Stoken ("", "in"); Gramext.Sself],
        Gramext.action
          (fun (x : 'expr) _ (l : 'a_list) (r : string) _ (loc : int * int) ->
             (let _ = warn_antiq loc "3.06+18" in
              Qast.Node ("ExLet", [Qast.Loc; antiquot "rec" loc r; l; x]) :
              'expr))]];
      Grammar.Entry.obj (str_item : 'str_item Grammar.Entry.e),
      Some (Gramext.Level "top"),
      [None, None,
       [[Gramext.Stoken ("", "value"); Gramext.Stoken ("ANTIQUOT", "rec");
         Gramext.srules
           [[Gramext.Slist1sep
               (Gramext.Snterm
                  (Grammar.Entry.obj
                     (let_binding : 'let_binding Grammar.Entry.e)),
                Gramext.Stoken ("", "and"))],
            Gramext.action
              (fun (a : 'let_binding list) (loc : int * int) ->
                 (Qast.List a : 'a_list));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_list : 'a_list Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_list) (loc : int * int) -> (a : 'a_list))]],
        Gramext.action
          (fun (l : 'a_list) (r : string) _ (loc : int * int) ->
             (let _ = warn_antiq loc "3.06+18" in
              Qast.Node ("StVal", [Qast.Loc; antiquot "rec" loc r; l]) :
              'str_item))]];
      Grammar.Entry.obj (class_expr : 'class_expr Grammar.Entry.e),
      Some (Gramext.Level "top"),
      [None, None,
       [[Gramext.Stoken ("", "let"); Gramext.Stoken ("ANTIQUOT", "rec");
         Gramext.srules
           [[Gramext.Slist1sep
               (Gramext.Snterm
                  (Grammar.Entry.obj
                     (let_binding : 'let_binding Grammar.Entry.e)),
                Gramext.Stoken ("", "and"))],
            Gramext.action
              (fun (a : 'let_binding list) (loc : int * int) ->
                 (Qast.List a : 'a_list));
            [Gramext.Snterm
               (Grammar.Entry.obj (a_list : 'a_list Grammar.Entry.e))],
            Gramext.action
              (fun (a : 'a_list) (loc : int * int) -> (a : 'a_list))];
         Gramext.Stoken ("", "in"); Gramext.Sself],
        Gramext.action
          (fun (ce : 'class_expr) _ (lb : 'a_list) (r : string) _
             (loc : int * int) ->
             (let _ = warn_antiq loc "3.06+18" in
              Qast.Node ("CeLet", [Qast.Loc; antiquot "rec" loc r; lb; ce]) :
              'class_expr))]];
      Grammar.Entry.obj (class_str_item : 'class_str_item Grammar.Entry.e),
      None,
      [None, None,
       [[Gramext.Stoken ("", "value"); Gramext.Stoken ("ANTIQUOT", "mut");
         Gramext.Snterm (Grammar.Entry.obj (label : 'label Grammar.Entry.e));
         Gramext.Snterm
           (Grammar.Entry.obj
              (cvalue_binding : 'cvalue_binding Grammar.Entry.e))],
        Gramext.action
          (fun (e : 'cvalue_binding) (lab : 'label) (mf : string) _
             (loc : int * int) ->
             (let _ = warn_antiq loc "3.06+18" in
              Qast.Node ("CrVal", [Qast.Loc; lab; antiquot "mut" loc mf; e]) :
              'class_str_item));
        [Gramext.Stoken ("", "inherit");
         Gramext.Snterm
           (Grammar.Entry.obj (class_expr : 'class_expr Grammar.Entry.e));
         Gramext.Stoken ("ANTIQUOT", "as")],
        Gramext.action
          (fun (pb : string) (ce : 'class_expr) _ (loc : int * int) ->
             (let _ = warn_antiq loc "3.06+18" in
              Qast.Node ("CrInh", [Qast.Loc; ce; antiquot "as" loc pb]) :
              'class_str_item))]];
      Grammar.Entry.obj (class_sig_item : 'class_sig_item Grammar.Entry.e),
      None,
      [None, None,
       [[Gramext.Stoken ("", "value"); Gramext.Stoken ("ANTIQUOT", "mut");
         Gramext.Snterm (Grammar.Entry.obj (label : 'label Grammar.Entry.e));
         Gramext.Stoken ("", ":");
         Gramext.Snterm (Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e))],
        Gramext.action
          (fun (t : 'ctyp) _ (l : 'label) (mf : string) _ (loc : int * int) ->
             (let _ = warn_antiq loc "3.06+18" in
              Qast.Node ("CgVal", [Qast.Loc; l; antiquot "mut" loc mf; t]) :
              'class_sig_item))]]])

let _ =
  Grammar.extend
    (let _ = (str_item : 'str_item Grammar.Entry.e)
     and _ = (sig_item : 'sig_item Grammar.Entry.e) in
     let grammar_entry_create s =
       Grammar.Entry.create (Grammar.of_entry str_item) s
     in
     let dir_param : 'dir_param Grammar.Entry.e =
       grammar_entry_create "dir_param"
     in
     [Grammar.Entry.obj (str_item : 'str_item Grammar.Entry.e), None,
      [None, None,
       [[Gramext.Stoken ("", "#");
         Gramext.Snterm
           (Grammar.Entry.obj (a_LIDENT : 'a_LIDENT Grammar.Entry.e));
         Gramext.Snterm
           (Grammar.Entry.obj (dir_param : 'dir_param Grammar.Entry.e))],
        Gramext.action
          (fun (dp : 'dir_param) (n : 'a_LIDENT) _ (loc : int * int) ->
             (Qast.Node ("StDir", [Qast.Loc; n; dp]) : 'str_item))]];
      Grammar.Entry.obj (sig_item : 'sig_item Grammar.Entry.e), None,
      [None, None,
       [[Gramext.Stoken ("", "#");
         Gramext.Snterm
           (Grammar.Entry.obj (a_LIDENT : 'a_LIDENT Grammar.Entry.e));
         Gramext.Snterm
           (Grammar.Entry.obj (dir_param : 'dir_param Grammar.Entry.e))],
        Gramext.action
          (fun (dp : 'dir_param) (n : 'a_LIDENT) _ (loc : int * int) ->
             (Qast.Node ("SgDir", [Qast.Loc; n; dp]) : 'sig_item))]];
      Grammar.Entry.obj (dir_param : 'dir_param Grammar.Entry.e), None,
      [None, None,
       [[],
        Gramext.action
          (fun (loc : int * int) -> (Qast.Option None : 'dir_param));
        [Gramext.Snterm (Grammar.Entry.obj (expr : 'expr Grammar.Entry.e))],
        Gramext.action
          (fun (e : 'expr) (loc : int * int) ->
             (Qast.Option (Some e) : 'dir_param));
        [Gramext.Stoken ("ANTIQUOT", "opt")],
        Gramext.action
          (fun (a : string) (loc : int * int) ->
             (antiquot "opt" loc a : 'dir_param))]]])

(* Antiquotations *)

let _ =
  Grammar.extend
    [Grammar.Entry.obj (module_expr : 'module_expr Grammar.Entry.e),
     Some (Gramext.Level "simple"),
     [None, None,
      [[Gramext.Stoken ("ANTIQUOT", "")],
       Gramext.action
         (fun (a : string) (loc : int * int) ->
            (antiquot "" loc a : 'module_expr));
       [Gramext.Stoken ("ANTIQUOT", "mexp")],
       Gramext.action
         (fun (a : string) (loc : int * int) ->
            (antiquot "mexp" loc a : 'module_expr))]];
     Grammar.Entry.obj (str_item : 'str_item Grammar.Entry.e),
     Some (Gramext.Level "top"),
     [None, None,
      [[Gramext.Stoken ("ANTIQUOT", "")],
       Gramext.action
         (fun (a : string) (loc : int * int) ->
            (antiquot "" loc a : 'str_item));
       [Gramext.Stoken ("ANTIQUOT", "stri")],
       Gramext.action
         (fun (a : string) (loc : int * int) ->
            (antiquot "stri" loc a : 'str_item))]];
     Grammar.Entry.obj (module_type : 'module_type Grammar.Entry.e),
     Some (Gramext.Level "simple"),
     [None, None,
      [[Gramext.Stoken ("ANTIQUOT", "")],
       Gramext.action
         (fun (a : string) (loc : int * int) ->
            (antiquot "" loc a : 'module_type));
       [Gramext.Stoken ("ANTIQUOT", "mtyp")],
       Gramext.action
         (fun (a : string) (loc : int * int) ->
            (antiquot "mtyp" loc a : 'module_type))]];
     Grammar.Entry.obj (sig_item : 'sig_item Grammar.Entry.e),
     Some (Gramext.Level "top"),
     [None, None,
      [[Gramext.Stoken ("ANTIQUOT", "")],
       Gramext.action
         (fun (a : string) (loc : int * int) ->
            (antiquot "" loc a : 'sig_item));
       [Gramext.Stoken ("ANTIQUOT", "sigi")],
       Gramext.action
         (fun (a : string) (loc : int * int) ->
            (antiquot "sigi" loc a : 'sig_item))]];
     Grammar.Entry.obj (expr : 'expr Grammar.Entry.e),
     Some (Gramext.Level "simple"),
     [None, None,
      [[Gramext.Stoken ("", "(");
        Gramext.Snterm (Grammar.Entry.obj (a_list : 'a_list Grammar.Entry.e));
        Gramext.Stoken ("", ")")],
       Gramext.action
         (fun _ (el : 'a_list) _ (loc : int * int) ->
            (Qast.Node ("ExTup", [Qast.Loc; el]) : 'expr));
       [Gramext.Stoken ("ANTIQUOT", "anti")],
       Gramext.action
         (fun (a : string) (loc : int * int) ->
            (Qast.Node ("ExAnt", [Qast.Loc; antiquot "anti" loc a]) : 'expr));
       [Gramext.Stoken ("ANTIQUOT", "")],
       Gramext.action
         (fun (a : string) (loc : int * int) -> (antiquot "" loc a : 'expr));
       [Gramext.Stoken ("ANTIQUOT", "exp")],
       Gramext.action
         (fun (a : string) (loc : int * int) ->
            (antiquot "exp" loc a : 'expr))]];
     Grammar.Entry.obj (patt : 'patt Grammar.Entry.e),
     Some (Gramext.Level "simple"),
     [None, None,
      [[Gramext.Stoken ("", "(");
        Gramext.Snterm (Grammar.Entry.obj (a_list : 'a_list Grammar.Entry.e));
        Gramext.Stoken ("", ")")],
       Gramext.action
         (fun _ (pl : 'a_list) _ (loc : int * int) ->
            (Qast.Node ("PaTup", [Qast.Loc; pl]) : 'patt));
       [Gramext.Stoken ("ANTIQUOT", "anti")],
       Gramext.action
         (fun (a : string) (loc : int * int) ->
            (Qast.Node ("PaAnt", [Qast.Loc; antiquot "anti" loc a]) : 'patt));
       [Gramext.Stoken ("ANTIQUOT", "")],
       Gramext.action
         (fun (a : string) (loc : int * int) -> (antiquot "" loc a : 'patt));
       [Gramext.Stoken ("ANTIQUOT", "pat")],
       Gramext.action
         (fun (a : string) (loc : int * int) ->
            (antiquot "pat" loc a : 'patt))]];
     Grammar.Entry.obj (ipatt : 'ipatt Grammar.Entry.e), None,
     [None, None,
      [[Gramext.Stoken ("", "(");
        Gramext.Snterm (Grammar.Entry.obj (a_list : 'a_list Grammar.Entry.e));
        Gramext.Stoken ("", ")")],
       Gramext.action
         (fun _ (pl : 'a_list) _ (loc : int * int) ->
            (Qast.Node ("PaTup", [Qast.Loc; pl]) : 'ipatt));
       [Gramext.Stoken ("ANTIQUOT", "anti")],
       Gramext.action
         (fun (a : string) (loc : int * int) ->
            (Qast.Node ("PaAnt", [Qast.Loc; antiquot "anti" loc a]) :
             'ipatt));
       [Gramext.Stoken ("ANTIQUOT", "")],
       Gramext.action
         (fun (a : string) (loc : int * int) -> (antiquot "" loc a : 'ipatt));
       [Gramext.Stoken ("ANTIQUOT", "pat")],
       Gramext.action
         (fun (a : string) (loc : int * int) ->
            (antiquot "pat" loc a : 'ipatt))]];
     Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e),
     Some (Gramext.Level "simple"),
     [None, None,
      [[Gramext.Stoken ("", "(");
        Gramext.Snterm (Grammar.Entry.obj (a_list : 'a_list Grammar.Entry.e));
        Gramext.Stoken ("", ")")],
       Gramext.action
         (fun _ (tl : 'a_list) _ (loc : int * int) ->
            (Qast.Node ("TyTup", [Qast.Loc; tl]) : 'ctyp));
       [Gramext.Stoken ("ANTIQUOT", "")],
       Gramext.action
         (fun (a : string) (loc : int * int) -> (antiquot "" loc a : 'ctyp));
       [Gramext.Stoken ("ANTIQUOT", "typ")],
       Gramext.action
         (fun (a : string) (loc : int * int) ->
            (antiquot "typ" loc a : 'ctyp))]];
     Grammar.Entry.obj (class_expr : 'class_expr Grammar.Entry.e),
     Some (Gramext.Level "simple"),
     [None, None,
      [[Gramext.Stoken ("ANTIQUOT", "")],
       Gramext.action
         (fun (a : string) (loc : int * int) ->
            (antiquot "" loc a : 'class_expr))]];
     Grammar.Entry.obj (class_str_item : 'class_str_item Grammar.Entry.e),
     None,
     [None, None,
      [[Gramext.Stoken ("ANTIQUOT", "")],
       Gramext.action
         (fun (a : string) (loc : int * int) ->
            (antiquot "" loc a : 'class_str_item))]];
     Grammar.Entry.obj (class_sig_item : 'class_sig_item Grammar.Entry.e),
     None,
     [None, None,
      [[Gramext.Stoken ("ANTIQUOT", "")],
       Gramext.action
         (fun (a : string) (loc : int * int) ->
            (antiquot "" loc a : 'class_sig_item))]];
     Grammar.Entry.obj (class_type : 'class_type Grammar.Entry.e), None,
     [None, None,
      [[Gramext.Stoken ("ANTIQUOT", "")],
       Gramext.action
         (fun (a : string) (loc : int * int) ->
            (antiquot "" loc a : 'class_type))]];
     Grammar.Entry.obj (expr : 'expr Grammar.Entry.e),
     Some (Gramext.Level "simple"),
     [None, None,
      [[Gramext.Stoken ("", "{<");
        Gramext.Snterm (Grammar.Entry.obj (a_list : 'a_list Grammar.Entry.e));
        Gramext.Stoken ("", ">}")],
       Gramext.action
         (fun _ (fel : 'a_list) _ (loc : int * int) ->
            (Qast.Node ("ExOvr", [Qast.Loc; fel]) : 'expr))]];
     Grammar.Entry.obj (patt : 'patt Grammar.Entry.e),
     Some (Gramext.Level "simple"),
     [None, None,
      [[Gramext.Stoken ("", "#");
        Gramext.Snterm
          (Grammar.Entry.obj (a_list : 'a_list Grammar.Entry.e))],
       Gramext.action
         (fun (a : 'a_list) _ (loc : int * int) ->
            (Qast.Node ("PaTyp", [Qast.Loc; a]) : 'patt))]];
     Grammar.Entry.obj (a_list : 'a_list Grammar.Entry.e), None,
     [None, None,
      [[Gramext.Stoken ("ANTIQUOT", "list")],
       Gramext.action
         (fun (a : string) (loc : int * int) ->
            (antiquot "list" loc a : 'a_list))]];
     Grammar.Entry.obj (a_opt : 'a_opt Grammar.Entry.e), None,
     [None, None,
      [[Gramext.Stoken ("ANTIQUOT", "opt")],
       Gramext.action
         (fun (a : string) (loc : int * int) ->
            (antiquot "opt" loc a : 'a_opt))]];
     Grammar.Entry.obj (a_UIDENT : 'a_UIDENT Grammar.Entry.e), None,
     [None, None,
      [[Gramext.Stoken ("UIDENT", "")],
       Gramext.action
         (fun (i : string) (loc : int * int) -> (Qast.Str i : 'a_UIDENT));
       [Gramext.Stoken ("ANTIQUOT", "")],
       Gramext.action
         (fun (a : string) (loc : int * int) ->
            (antiquot "" loc a : 'a_UIDENT));
       [Gramext.Stoken ("ANTIQUOT", "uid")],
       Gramext.action
         (fun (a : string) (loc : int * int) ->
            (antiquot "uid" loc a : 'a_UIDENT))]];
     Grammar.Entry.obj (a_LIDENT : 'a_LIDENT Grammar.Entry.e), None,
     [None, None,
      [[Gramext.Stoken ("LIDENT", "")],
       Gramext.action
         (fun (i : string) (loc : int * int) -> (Qast.Str i : 'a_LIDENT));
       [Gramext.Stoken ("ANTIQUOT", "")],
       Gramext.action
         (fun (a : string) (loc : int * int) ->
            (antiquot "" loc a : 'a_LIDENT));
       [Gramext.Stoken ("ANTIQUOT", "lid")],
       Gramext.action
         (fun (a : string) (loc : int * int) ->
            (antiquot "lid" loc a : 'a_LIDENT))]];
     Grammar.Entry.obj (a_INT : 'a_INT Grammar.Entry.e), None,
     [None, None,
      [[Gramext.Stoken ("INT", "")],
       Gramext.action
         (fun (s : string) (loc : int * int) -> (Qast.Str s : 'a_INT));
       [Gramext.Stoken ("ANTIQUOT", "")],
       Gramext.action
         (fun (a : string) (loc : int * int) -> (antiquot "" loc a : 'a_INT));
       [Gramext.Stoken ("ANTIQUOT", "int")],
       Gramext.action
         (fun (a : string) (loc : int * int) ->
            (antiquot "int" loc a : 'a_INT))]];
     Grammar.Entry.obj (a_FLOAT : 'a_FLOAT Grammar.Entry.e), None,
     [None, None,
      [[Gramext.Stoken ("FLOAT", "")],
       Gramext.action
         (fun (s : string) (loc : int * int) -> (Qast.Str s : 'a_FLOAT));
       [Gramext.Stoken ("ANTIQUOT", "")],
       Gramext.action
         (fun (a : string) (loc : int * int) ->
            (antiquot "" loc a : 'a_FLOAT));
       [Gramext.Stoken ("ANTIQUOT", "flo")],
       Gramext.action
         (fun (a : string) (loc : int * int) ->
            (antiquot "flo" loc a : 'a_FLOAT))]];
     Grammar.Entry.obj (a_STRING : 'a_STRING Grammar.Entry.e), None,
     [None, None,
      [[Gramext.Stoken ("STRING", "")],
       Gramext.action
         (fun (s : string) (loc : int * int) -> (Qast.Str s : 'a_STRING));
       [Gramext.Stoken ("ANTIQUOT", "")],
       Gramext.action
         (fun (a : string) (loc : int * int) ->
            (antiquot "" loc a : 'a_STRING));
       [Gramext.Stoken ("ANTIQUOT", "str")],
       Gramext.action
         (fun (a : string) (loc : int * int) ->
            (antiquot "str" loc a : 'a_STRING))]];
     Grammar.Entry.obj (a_CHAR : 'a_CHAR Grammar.Entry.e), None,
     [None, None,
      [[Gramext.Stoken ("CHAR", "")],
       Gramext.action
         (fun (s : string) (loc : int * int) -> (Qast.Str s : 'a_CHAR));
       [Gramext.Stoken ("ANTIQUOT", "")],
       Gramext.action
         (fun (a : string) (loc : int * int) ->
            (antiquot "" loc a : 'a_CHAR));
       [Gramext.Stoken ("ANTIQUOT", "chr")],
       Gramext.action
         (fun (a : string) (loc : int * int) ->
            (antiquot "chr" loc a : 'a_CHAR))]];
     Grammar.Entry.obj (a_TILDEIDENT : 'a_TILDEIDENT Grammar.Entry.e), None,
     [None, None,
      [[Gramext.Stoken ("TILDEIDENT", "")],
       Gramext.action
         (fun (s : string) (loc : int * int) -> (Qast.Str s : 'a_TILDEIDENT));
       [Gramext.Stoken ("", "~"); Gramext.Stoken ("ANTIQUOT", "")],
       Gramext.action
         (fun (a : string) _ (loc : int * int) ->
            (antiquot "" loc a : 'a_TILDEIDENT))]];
     Grammar.Entry.obj (a_QUESTIONIDENT : 'a_QUESTIONIDENT Grammar.Entry.e),
     None,
     [None, None,
      [[Gramext.Stoken ("QUESTIONIDENT", "")],
       Gramext.action
         (fun (s : string) (loc : int * int) ->
            (Qast.Str s : 'a_QUESTIONIDENT));
       [Gramext.Stoken ("", "?"); Gramext.Stoken ("ANTIQUOT", "")],
       Gramext.action
         (fun (a : string) _ (loc : int * int) ->
            (antiquot "" loc a : 'a_QUESTIONIDENT))]]]

let apply_entry e =
  let f s = Grammar.Entry.parse e (Stream.of_string s) in
  let expr s = Qast.to_expr (f s) in
  let patt s = Qast.to_patt (f s) in Quotation.ExAst (expr, patt)

let _ =
  let sig_item_eoi = Grammar.Entry.create gram "signature item" in
  Grammar.extend
    [Grammar.Entry.obj (sig_item_eoi : 'sig_item_eoi Grammar.Entry.e), None,
     [None, None,
      [[Gramext.Snterm
          (Grammar.Entry.obj (sig_item : 'sig_item Grammar.Entry.e));
        Gramext.Stoken ("EOI", "")],
       Gramext.action
         (fun _ (x : 'sig_item) (loc : int * int) -> (x : 'sig_item_eoi))]]];
  Quotation.add "sig_item" (apply_entry sig_item_eoi)

let _ =
  let str_item_eoi = Grammar.Entry.create gram "structure item" in
  Grammar.extend
    [Grammar.Entry.obj (str_item_eoi : 'str_item_eoi Grammar.Entry.e), None,
     [None, None,
      [[Gramext.Snterm
          (Grammar.Entry.obj (str_item : 'str_item Grammar.Entry.e));
        Gramext.Stoken ("EOI", "")],
       Gramext.action
         (fun _ (x : 'str_item) (loc : int * int) -> (x : 'str_item_eoi))]]];
  Quotation.add "str_item" (apply_entry str_item_eoi)

let _ =
  let ctyp_eoi = Grammar.Entry.create gram "type" in
  Grammar.extend
    [Grammar.Entry.obj (ctyp_eoi : 'ctyp_eoi Grammar.Entry.e), None,
     [None, None,
      [[Gramext.Snterm (Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e));
        Gramext.Stoken ("EOI", "")],
       Gramext.action
         (fun _ (x : 'ctyp) (loc : int * int) -> (x : 'ctyp_eoi))]]];
  Quotation.add "ctyp" (apply_entry ctyp_eoi)

let _ =
  let patt_eoi = Grammar.Entry.create gram "pattern" in
  Grammar.extend
    [Grammar.Entry.obj (patt_eoi : 'patt_eoi Grammar.Entry.e), None,
     [None, None,
      [[Gramext.Snterm (Grammar.Entry.obj (patt : 'patt Grammar.Entry.e));
        Gramext.Stoken ("EOI", "")],
       Gramext.action
         (fun _ (x : 'patt) (loc : int * int) -> (x : 'patt_eoi))]]];
  Quotation.add "patt" (apply_entry patt_eoi)

let _ =
  let expr_eoi = Grammar.Entry.create gram "expression" in
  Grammar.extend
    [Grammar.Entry.obj (expr_eoi : 'expr_eoi Grammar.Entry.e), None,
     [None, None,
      [[Gramext.Snterm (Grammar.Entry.obj (expr : 'expr Grammar.Entry.e));
        Gramext.Stoken ("EOI", "")],
       Gramext.action
         (fun _ (x : 'expr) (loc : int * int) -> (x : 'expr_eoi))]]];
  Quotation.add "expr" (apply_entry expr_eoi)

let _ =
  let module_type_eoi = Grammar.Entry.create gram "module type" in
  Grammar.extend
    [Grammar.Entry.obj (module_type_eoi : 'module_type_eoi Grammar.Entry.e),
     None,
     [None, None,
      [[Gramext.Snterm
          (Grammar.Entry.obj (module_type : 'module_type Grammar.Entry.e));
        Gramext.Stoken ("EOI", "")],
       Gramext.action
         (fun _ (x : 'module_type) (loc : int * int) ->
            (x : 'module_type_eoi))]]];
  Quotation.add "module_type" (apply_entry module_type_eoi)

let _ =
  let module_expr_eoi = Grammar.Entry.create gram "module expression" in
  Grammar.extend
    [Grammar.Entry.obj (module_expr_eoi : 'module_expr_eoi Grammar.Entry.e),
     None,
     [None, None,
      [[Gramext.Snterm
          (Grammar.Entry.obj (module_expr : 'module_expr Grammar.Entry.e));
        Gramext.Stoken ("EOI", "")],
       Gramext.action
         (fun _ (x : 'module_expr) (loc : int * int) ->
            (x : 'module_expr_eoi))]]];
  Quotation.add "module_expr" (apply_entry module_expr_eoi)

let _ =
  let class_type_eoi = Grammar.Entry.create gram "class_type" in
  Grammar.extend
    [Grammar.Entry.obj (class_type_eoi : 'class_type_eoi Grammar.Entry.e),
     None,
     [None, None,
      [[Gramext.Snterm
          (Grammar.Entry.obj (class_type : 'class_type Grammar.Entry.e));
        Gramext.Stoken ("EOI", "")],
       Gramext.action
         (fun _ (x : 'class_type) (loc : int * int) ->
            (x : 'class_type_eoi))]]];
  Quotation.add "class_type" (apply_entry class_type_eoi)

let _ =
  let class_expr_eoi = Grammar.Entry.create gram "class_expr" in
  Grammar.extend
    [Grammar.Entry.obj (class_expr_eoi : 'class_expr_eoi Grammar.Entry.e),
     None,
     [None, None,
      [[Gramext.Snterm
          (Grammar.Entry.obj (class_expr : 'class_expr Grammar.Entry.e));
        Gramext.Stoken ("EOI", "")],
       Gramext.action
         (fun _ (x : 'class_expr) (loc : int * int) ->
            (x : 'class_expr_eoi))]]];
  Quotation.add "class_expr" (apply_entry class_expr_eoi)

let _ =
  let class_sig_item_eoi = Grammar.Entry.create gram "class_sig_item" in
  Grammar.extend
    [Grammar.Entry.obj
       (class_sig_item_eoi : 'class_sig_item_eoi Grammar.Entry.e),
     None,
     [None, None,
      [[Gramext.Snterm
          (Grammar.Entry.obj
             (class_sig_item : 'class_sig_item Grammar.Entry.e));
        Gramext.Stoken ("EOI", "")],
       Gramext.action
         (fun _ (x : 'class_sig_item) (loc : int * int) ->
            (x : 'class_sig_item_eoi))]]];
  Quotation.add "class_sig_item" (apply_entry class_sig_item_eoi)

let _ =
  let class_str_item_eoi = Grammar.Entry.create gram "class_str_item" in
  Grammar.extend
    [Grammar.Entry.obj
       (class_str_item_eoi : 'class_str_item_eoi Grammar.Entry.e),
     None,
     [None, None,
      [[Gramext.Snterm
          (Grammar.Entry.obj
             (class_str_item : 'class_str_item Grammar.Entry.e));
        Gramext.Stoken ("EOI", "")],
       Gramext.action
         (fun _ (x : 'class_str_item) (loc : int * int) ->
            (x : 'class_str_item_eoi))]]];
  Quotation.add "class_str_item" (apply_entry class_str_item_eoi)

let _ =
  let with_constr_eoi = Grammar.Entry.create gram "with constr" in
  Grammar.extend
    [Grammar.Entry.obj (with_constr_eoi : 'with_constr_eoi Grammar.Entry.e),
     None,
     [None, None,
      [[Gramext.Snterm
          (Grammar.Entry.obj (with_constr : 'with_constr Grammar.Entry.e));
        Gramext.Stoken ("EOI", "")],
       Gramext.action
         (fun _ (x : 'with_constr) (loc : int * int) ->
            (x : 'with_constr_eoi))]]];
  Quotation.add "with_constr" (apply_entry with_constr_eoi)

let _ =
  let row_field_eoi = Grammar.Entry.create gram "row_field" in
  Grammar.extend
    [Grammar.Entry.obj (row_field_eoi : 'row_field_eoi Grammar.Entry.e), None,
     [None, None,
      [[Gramext.Snterm
          (Grammar.Entry.obj (row_field : 'row_field Grammar.Entry.e));
        Gramext.Stoken ("EOI", "")],
       Gramext.action
         (fun _ (x : 'row_field) (loc : int * int) ->
            (x : 'row_field_eoi))]]];
  Quotation.add "row_field" (apply_entry row_field_eoi)

(* camlp4r pa_extend.cmo q_MLast.cmo *)
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

(* $Id: pa_r.ml,v 1.46 2003/07/16 12:50:09 mauny Exp $ *)

open Stdpp
open Pcaml

let _ = Pcaml.no_constructors_arity := false

let help_sequences () =
  Printf.eprintf "\
New syntax:
     do {e1; e2; ... ; en}
     while e do {e1; e2; ... ; en}
     for v = v1 to/downto v2 do {e1; e2; ... ; en}
Old (discouraged) syntax:
     do e1; e2; ... ; en-1; return en
     while e do e1; e2; ... ; en; done
     for v = v1 to/downto v2 do e1; e2; ... ; en; done
To avoid compilation warning use the new syntax.
";
  flush stderr;
  exit 1
let _ =
  Pcaml.add_option "-help_seq" (Arg.Unit help_sequences)
    "Print explanations about new sequences and exit."

let _ =
  let odfa = !(Plexer.dollar_for_antiquotation) in
  Plexer.dollar_for_antiquotation := false;
  Grammar.Unsafe.gram_reinit gram (Plexer.gmake ());
  Plexer.dollar_for_antiquotation := odfa;
  Grammar.Unsafe.clear_entry interf;
  Grammar.Unsafe.clear_entry implem;
  Grammar.Unsafe.clear_entry top_phrase;
  Grammar.Unsafe.clear_entry use_file;
  Grammar.Unsafe.clear_entry module_type;
  Grammar.Unsafe.clear_entry module_expr;
  Grammar.Unsafe.clear_entry sig_item;
  Grammar.Unsafe.clear_entry str_item;
  Grammar.Unsafe.clear_entry expr;
  Grammar.Unsafe.clear_entry patt;
  Grammar.Unsafe.clear_entry ctyp;
  Grammar.Unsafe.clear_entry let_binding;
  Grammar.Unsafe.clear_entry type_declaration;
  Grammar.Unsafe.clear_entry class_type;
  Grammar.Unsafe.clear_entry class_expr;
  Grammar.Unsafe.clear_entry class_sig_item;
  Grammar.Unsafe.clear_entry class_str_item

let _ = Pcaml.parse_interf := Grammar.Entry.parse interf
let _ = Pcaml.parse_implem := Grammar.Entry.parse implem

let o2b =
  function
    Some _ -> true
  | None -> false

let mksequence loc =
  function
    [e] -> e
  | el -> MLast.ExSeq (loc, el)

let mkmatchcase loc p aso w e =
  let p =
    match aso with
      Some p2 -> MLast.PaAli (loc, p, p2)
    | _ -> p
  in
  p, w, e
      
let neg_string n =
  let len = String.length n in
  if len > 0 && n.[0] = '-' then String.sub n 1 (len - 1) else "-" ^ n

let mkumin loc f arg =
  match arg with
    MLast.ExInt (_, n) -> MLast.ExInt (loc, neg_string n)
  | MLast.ExInt32 (loc, n) -> MLast.ExInt32 (loc, neg_string n)
  | MLast.ExInt64 (loc, n) -> MLast.ExInt64 (loc, neg_string n)
  | MLast.ExNativeInt (loc, n) -> MLast.ExNativeInt (loc, neg_string n)
  | MLast.ExFlo (_, n) -> MLast.ExFlo (loc, neg_string n)
  | _ -> let f = "~" ^ f in MLast.ExApp (loc, MLast.ExLid (loc, f), arg)

let mklistexp loc last =
  let rec loop top =
    function
      [] ->
        begin match last with
          Some e -> e
        | None -> MLast.ExUid (loc, "[]")
        end
    | e1 :: el ->
        let loc = if top then loc else fst (MLast.loc_of_expr e1), snd loc in
        MLast.ExApp
          (loc, MLast.ExApp (loc, MLast.ExUid (loc, "::"), e1), loop false el)
  in
  loop true

let mklistpat loc last =
  let rec loop top =
    function
      [] ->
        begin match last with
          Some p -> p
        | None -> MLast.PaUid (loc, "[]")
        end
    | p1 :: pl ->
        let loc = if top then loc else fst (MLast.loc_of_patt p1), snd loc in
        MLast.PaApp
          (loc, MLast.PaApp (loc, MLast.PaUid (loc, "::"), p1), loop false pl)
  in
  loop true

let mkexprident loc i j =
  let rec loop m =
    function
      MLast.ExAcc (_, x, y) -> loop (MLast.ExAcc (loc, m, x)) y
    | e -> MLast.ExAcc (loc, m, e)
  in
  loop (MLast.ExUid (loc, i)) j

let mkassert loc e =
  match e with
    MLast.ExUid (_, "False") -> MLast.ExAsf loc
  | _ -> MLast.ExAsr (loc, e)

let append_elem el e = el @ [e]

(* ...suppose to flush the input in case of syntax error to avoid multiple
   errors in case of cut-and-paste in the xterm, but work bad: for example
   the input "for x = 1;" waits for another line before displaying the
   error...
value rec sync cs =
  match cs with parser
  [ [: `';' :] -> sync_semi cs
  | [: `_ :] -> sync cs ]
and sync_semi cs =
  match Stream.peek cs with 
  [ Some ('\010' | '\013') -> ()
  | _ -> sync cs ]
;
Pcaml.sync.val := sync;
*)

let ipatt = Grammar.Entry.create gram "ipatt"
let with_constr = Grammar.Entry.create gram "with_constr"
let row_field = Grammar.Entry.create gram "row_field"

let not_yet_warned_variant = ref true
let warn_variant loc =
  if !not_yet_warned_variant then
    begin
      not_yet_warned_variant := false;
      !(Pcaml.warning) loc
        (Printf.sprintf
           "use of syntax of variants types deprecated since version 3.05")
    end

let not_yet_warned = ref true
let warn_sequence loc =
  if !not_yet_warned then
    begin
      not_yet_warned := false;
      !(Pcaml.warning) loc
        "use of syntax of sequences deprecated since version 3.01.1"
    end
let _ =
  Pcaml.add_option "-no_warn_seq" (Arg.Clear not_yet_warned)
    "No warning when using old syntax for sequences."

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
     and sequence : 'sequence Grammar.Entry.e =
       grammar_entry_create "sequence"
     and fun_binding : 'fun_binding Grammar.Entry.e =
       grammar_entry_create "fun_binding"
     and match_case : 'match_case Grammar.Entry.e =
       grammar_entry_create "match_case"
     and as_patt_opt : 'as_patt_opt Grammar.Entry.e =
       grammar_entry_create "as_patt_opt"
     and when_expr_opt : 'when_expr_opt Grammar.Entry.e =
       grammar_entry_create "when_expr_opt"
     and label_expr : 'label_expr Grammar.Entry.e =
       grammar_entry_create "label_expr"
     and expr_ident : 'expr_ident Grammar.Entry.e =
       grammar_entry_create "expr_ident"
     and fun_def : 'fun_def Grammar.Entry.e = grammar_entry_create "fun_def"
     and cons_patt_opt : 'cons_patt_opt Grammar.Entry.e =
       grammar_entry_create "cons_patt_opt"
     and label_patt : 'label_patt Grammar.Entry.e =
       grammar_entry_create "label_patt"
     and patt_label_ident : 'patt_label_ident Grammar.Entry.e =
       grammar_entry_create "patt_label_ident"
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
     and mod_ident : 'mod_ident Grammar.Entry.e =
       grammar_entry_create "mod_ident"
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
     and clty_longident : 'clty_longident Grammar.Entry.e =
       grammar_entry_create "clty_longident"
     and class_longident : 'class_longident Grammar.Entry.e =
       grammar_entry_create "class_longident"
     and row_field_list : 'row_field_list Grammar.Entry.e =
       grammar_entry_create "row_field_list"
     and name_tag : 'name_tag Grammar.Entry.e =
       grammar_entry_create "name_tag"
     and patt_tcon : 'patt_tcon Grammar.Entry.e =
       grammar_entry_create "patt_tcon"
     and ipatt_tcon : 'ipatt_tcon Grammar.Entry.e =
       grammar_entry_create "ipatt_tcon"
     and eq_expr : 'eq_expr Grammar.Entry.e = grammar_entry_create "eq_expr"
     and direction_flag : 'direction_flag Grammar.Entry.e =
       grammar_entry_create "direction_flag"
     and warning_variant : 'warning_variant Grammar.Entry.e =
       grammar_entry_create "warning_variant"
     and warning_sequence : 'warning_sequence Grammar.Entry.e =
       grammar_entry_create "warning_sequence"
     in
     [Grammar.Entry.obj (module_expr : 'module_expr Grammar.Entry.e), None,
      [None, None,
       [[Gramext.Stoken ("", "struct");
         Gramext.Slist0
           (Gramext.srules
              [[Gramext.Snterm
                  (Grammar.Entry.obj (str_item : 'str_item Grammar.Entry.e));
                Gramext.Stoken ("", ";")],
               Gramext.action
                 (fun _ (s : 'str_item) (loc : int * int) -> (s : 'e__1))]);
         Gramext.Stoken ("", "end")],
        Gramext.action
          (fun _ (st : 'e__1 list) _ (loc : int * int) ->
             (MLast.MeStr (loc, st) : 'module_expr));
        [Gramext.Stoken ("", "functor"); Gramext.Stoken ("", "(");
         Gramext.Stoken ("UIDENT", ""); Gramext.Stoken ("", ":");
         Gramext.Snterm
           (Grammar.Entry.obj (module_type : 'module_type Grammar.Entry.e));
         Gramext.Stoken ("", ")"); Gramext.Stoken ("", "->"); Gramext.Sself],
        Gramext.action
          (fun (me : 'module_expr) _ _ (t : 'module_type) _ (i : string) _ _
             (loc : int * int) ->
             (MLast.MeFun (loc, i, t, me) : 'module_expr))];
       None, None,
       [[Gramext.Sself; Gramext.Sself],
        Gramext.action
          (fun (me2 : 'module_expr) (me1 : 'module_expr) (loc : int * int) ->
             (MLast.MeApp (loc, me1, me2) : 'module_expr))];
       None, None,
       [[Gramext.Sself; Gramext.Stoken ("", "."); Gramext.Sself],
        Gramext.action
          (fun (me2 : 'module_expr) _ (me1 : 'module_expr)
             (loc : int * int) ->
             (MLast.MeAcc (loc, me1, me2) : 'module_expr))];
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
             (MLast.MeTyc (loc, me, mt) : 'module_expr));
        [Gramext.Stoken ("UIDENT", "")],
        Gramext.action
          (fun (i : string) (loc : int * int) ->
             (MLast.MeUid (loc, i) : 'module_expr))]];
      Grammar.Entry.obj (str_item : 'str_item Grammar.Entry.e), None,
      [Some "top", None,
       [[Gramext.Snterm (Grammar.Entry.obj (expr : 'expr Grammar.Entry.e))],
        Gramext.action
          (fun (e : 'expr) (loc : int * int) ->
             (MLast.StExp (loc, e) : 'str_item));
        [Gramext.Stoken ("", "value");
         Gramext.Sopt (Gramext.Stoken ("", "rec"));
         Gramext.Slist1sep
           (Gramext.Snterm
              (Grammar.Entry.obj
                 (let_binding : 'let_binding Grammar.Entry.e)),
            Gramext.Stoken ("", "and"))],
        Gramext.action
          (fun (l : 'let_binding list) (r : string option) _
             (loc : int * int) ->
             (MLast.StVal (loc, o2b r, l) : 'str_item));
        [Gramext.Stoken ("", "type");
         Gramext.Slist1sep
           (Gramext.Snterm
              (Grammar.Entry.obj
                 (type_declaration : 'type_declaration Grammar.Entry.e)),
            Gramext.Stoken ("", "and"))],
        Gramext.action
          (fun (tdl : 'type_declaration list) _ (loc : int * int) ->
             (MLast.StTyp (loc, tdl) : 'str_item));
        [Gramext.Stoken ("", "open");
         Gramext.Snterm
           (Grammar.Entry.obj (mod_ident : 'mod_ident Grammar.Entry.e))],
        Gramext.action
          (fun (i : 'mod_ident) _ (loc : int * int) ->
             (MLast.StOpn (loc, i) : 'str_item));
        [Gramext.Stoken ("", "module"); Gramext.Stoken ("", "type");
         Gramext.Stoken ("UIDENT", ""); Gramext.Stoken ("", "=");
         Gramext.Snterm
           (Grammar.Entry.obj (module_type : 'module_type Grammar.Entry.e))],
        Gramext.action
          (fun (mt : 'module_type) _ (i : string) _ _ (loc : int * int) ->
             (MLast.StMty (loc, i, mt) : 'str_item));
        [Gramext.Stoken ("", "module"); Gramext.Stoken ("", "rec");
         Gramext.Slist1sep
           (Gramext.Snterm
              (Grammar.Entry.obj
                 (module_rec_binding : 'module_rec_binding Grammar.Entry.e)),
            Gramext.Stoken ("", "and"))],
        Gramext.action
          (fun (nmtmes : 'module_rec_binding list) _ _ (loc : int * int) ->
             (MLast.StRecMod (loc, nmtmes) : 'str_item));
        [Gramext.Stoken ("", "module"); Gramext.Stoken ("UIDENT", "");
         Gramext.Snterm
           (Grammar.Entry.obj
              (module_binding : 'module_binding Grammar.Entry.e))],
        Gramext.action
          (fun (mb : 'module_binding) (i : string) _ (loc : int * int) ->
             (MLast.StMod (loc, i, mb) : 'str_item));
        [Gramext.Stoken ("", "include");
         Gramext.Snterm
           (Grammar.Entry.obj (module_expr : 'module_expr Grammar.Entry.e))],
        Gramext.action
          (fun (me : 'module_expr) _ (loc : int * int) ->
             (MLast.StInc (loc, me) : 'str_item));
        [Gramext.Stoken ("", "external"); Gramext.Stoken ("LIDENT", "");
         Gramext.Stoken ("", ":");
         Gramext.Snterm (Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e));
         Gramext.Stoken ("", "=");
         Gramext.Slist1 (Gramext.Stoken ("STRING", ""))],
        Gramext.action
          (fun (pd : string list) _ (t : 'ctyp) _ (i : string) _
             (loc : int * int) ->
             (MLast.StExt (loc, i, t, pd) : 'str_item));
        [Gramext.Stoken ("", "exception");
         Gramext.Snterm
           (Grammar.Entry.obj
              (constructor_declaration :
               'constructor_declaration Grammar.Entry.e));
         Gramext.Snterm
           (Grammar.Entry.obj (rebind_exn : 'rebind_exn Grammar.Entry.e))],
        Gramext.action
          (fun (b : 'rebind_exn) (_, c, tl : 'constructor_declaration) _
             (loc : int * int) ->
             (MLast.StExc (loc, c, tl, b) : 'str_item));
        [Gramext.Stoken ("", "declare");
         Gramext.Slist0
           (Gramext.srules
              [[Gramext.Snterm
                  (Grammar.Entry.obj (str_item : 'str_item Grammar.Entry.e));
                Gramext.Stoken ("", ";")],
               Gramext.action
                 (fun _ (s : 'str_item) (loc : int * int) -> (s : 'e__2))]);
         Gramext.Stoken ("", "end")],
        Gramext.action
          (fun _ (st : 'e__2 list) _ (loc : int * int) ->
             (MLast.StDcl (loc, st) : 'str_item))]];
      Grammar.Entry.obj (rebind_exn : 'rebind_exn Grammar.Entry.e), None,
      [None, None,
       [[], Gramext.action (fun (loc : int * int) -> ([] : 'rebind_exn));
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
             (MLast.MeTyc (loc, me, mt) : 'module_binding));
        [Gramext.Stoken ("", "("); Gramext.Stoken ("UIDENT", "");
         Gramext.Stoken ("", ":");
         Gramext.Snterm
           (Grammar.Entry.obj (module_type : 'module_type Grammar.Entry.e));
         Gramext.Stoken ("", ")"); Gramext.Sself],
        Gramext.action
          (fun (mb : 'module_binding) _ (mt : 'module_type) _ (m : string) _
             (loc : int * int) ->
             (MLast.MeFun (loc, m, mt, mb) : 'module_binding))]];
      Grammar.Entry.obj
        (module_rec_binding : 'module_rec_binding Grammar.Entry.e),
      None,
      [None, None,
       [[Gramext.Stoken ("UIDENT", ""); Gramext.Stoken ("", ":");
         Gramext.Snterm
           (Grammar.Entry.obj (module_type : 'module_type Grammar.Entry.e));
         Gramext.Stoken ("", "=");
         Gramext.Snterm
           (Grammar.Entry.obj (module_expr : 'module_expr Grammar.Entry.e))],
        Gramext.action
          (fun (me : 'module_expr) _ (mt : 'module_type) _ (m : string)
             (loc : int * int) ->
             (m, mt, me : 'module_rec_binding))]];
      Grammar.Entry.obj (module_type : 'module_type Grammar.Entry.e), None,
      [None, None,
       [[Gramext.Stoken ("", "functor"); Gramext.Stoken ("", "(");
         Gramext.Stoken ("UIDENT", ""); Gramext.Stoken ("", ":");
         Gramext.Sself; Gramext.Stoken ("", ")"); Gramext.Stoken ("", "->");
         Gramext.Sself],
        Gramext.action
          (fun (mt : 'module_type) _ _ (t : 'module_type) _ (i : string) _ _
             (loc : int * int) ->
             (MLast.MtFun (loc, i, t, mt) : 'module_type))];
       None, None,
       [[Gramext.Sself; Gramext.Stoken ("", "with");
         Gramext.Slist1sep
           (Gramext.Snterm
              (Grammar.Entry.obj
                 (with_constr : 'with_constr Grammar.Entry.e)),
            Gramext.Stoken ("", "and"))],
        Gramext.action
          (fun (wcl : 'with_constr list) _ (mt : 'module_type)
             (loc : int * int) ->
             (MLast.MtWit (loc, mt, wcl) : 'module_type))];
       None, None,
       [[Gramext.Stoken ("", "sig");
         Gramext.Slist0
           (Gramext.srules
              [[Gramext.Snterm
                  (Grammar.Entry.obj (sig_item : 'sig_item Grammar.Entry.e));
                Gramext.Stoken ("", ";")],
               Gramext.action
                 (fun _ (s : 'sig_item) (loc : int * int) -> (s : 'e__3))]);
         Gramext.Stoken ("", "end")],
        Gramext.action
          (fun _ (sg : 'e__3 list) _ (loc : int * int) ->
             (MLast.MtSig (loc, sg) : 'module_type))];
       None, None,
       [[Gramext.Sself; Gramext.Sself],
        Gramext.action
          (fun (m2 : 'module_type) (m1 : 'module_type) (loc : int * int) ->
             (MLast.MtApp (loc, m1, m2) : 'module_type))];
       None, None,
       [[Gramext.Sself; Gramext.Stoken ("", "."); Gramext.Sself],
        Gramext.action
          (fun (m2 : 'module_type) _ (m1 : 'module_type) (loc : int * int) ->
             (MLast.MtAcc (loc, m1, m2) : 'module_type))];
       Some "simple", None,
       [[Gramext.Stoken ("", "("); Gramext.Sself; Gramext.Stoken ("", ")")],
        Gramext.action
          (fun _ (mt : 'module_type) _ (loc : int * int) ->
             (mt : 'module_type));
        [Gramext.Stoken ("", "'");
         Gramext.Snterm (Grammar.Entry.obj (ident : 'ident Grammar.Entry.e))],
        Gramext.action
          (fun (i : 'ident) _ (loc : int * int) ->
             (MLast.MtQuo (loc, i) : 'module_type));
        [Gramext.Stoken ("LIDENT", "")],
        Gramext.action
          (fun (i : string) (loc : int * int) ->
             (MLast.MtLid (loc, i) : 'module_type));
        [Gramext.Stoken ("UIDENT", "")],
        Gramext.action
          (fun (i : string) (loc : int * int) ->
             (MLast.MtUid (loc, i) : 'module_type))]];
      Grammar.Entry.obj (sig_item : 'sig_item Grammar.Entry.e), None,
      [Some "top", None,
       [[Gramext.Stoken ("", "value"); Gramext.Stoken ("LIDENT", "");
         Gramext.Stoken ("", ":");
         Gramext.Snterm (Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e))],
        Gramext.action
          (fun (t : 'ctyp) _ (i : string) _ (loc : int * int) ->
             (MLast.SgVal (loc, i, t) : 'sig_item));
        [Gramext.Stoken ("", "type");
         Gramext.Slist1sep
           (Gramext.Snterm
              (Grammar.Entry.obj
                 (type_declaration : 'type_declaration Grammar.Entry.e)),
            Gramext.Stoken ("", "and"))],
        Gramext.action
          (fun (tdl : 'type_declaration list) _ (loc : int * int) ->
             (MLast.SgTyp (loc, tdl) : 'sig_item));
        [Gramext.Stoken ("", "open");
         Gramext.Snterm
           (Grammar.Entry.obj (mod_ident : 'mod_ident Grammar.Entry.e))],
        Gramext.action
          (fun (i : 'mod_ident) _ (loc : int * int) ->
             (MLast.SgOpn (loc, i) : 'sig_item));
        [Gramext.Stoken ("", "module"); Gramext.Stoken ("", "type");
         Gramext.Stoken ("UIDENT", ""); Gramext.Stoken ("", "=");
         Gramext.Snterm
           (Grammar.Entry.obj (module_type : 'module_type Grammar.Entry.e))],
        Gramext.action
          (fun (mt : 'module_type) _ (i : string) _ _ (loc : int * int) ->
             (MLast.SgMty (loc, i, mt) : 'sig_item));
        [Gramext.Stoken ("", "module"); Gramext.Stoken ("", "rec");
         Gramext.Slist1sep
           (Gramext.Snterm
              (Grammar.Entry.obj
                 (module_rec_declaration :
                  'module_rec_declaration Grammar.Entry.e)),
            Gramext.Stoken ("", "and"))],
        Gramext.action
          (fun (mds : 'module_rec_declaration list) _ _ (loc : int * int) ->
             (MLast.SgRecMod (loc, mds) : 'sig_item));
        [Gramext.Stoken ("", "module"); Gramext.Stoken ("UIDENT", "");
         Gramext.Snterm
           (Grammar.Entry.obj
              (module_declaration : 'module_declaration Grammar.Entry.e))],
        Gramext.action
          (fun (mt : 'module_declaration) (i : string) _ (loc : int * int) ->
             (MLast.SgMod (loc, i, mt) : 'sig_item));
        [Gramext.Stoken ("", "include");
         Gramext.Snterm
           (Grammar.Entry.obj (module_type : 'module_type Grammar.Entry.e))],
        Gramext.action
          (fun (mt : 'module_type) _ (loc : int * int) ->
             (MLast.SgInc (loc, mt) : 'sig_item));
        [Gramext.Stoken ("", "external"); Gramext.Stoken ("LIDENT", "");
         Gramext.Stoken ("", ":");
         Gramext.Snterm (Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e));
         Gramext.Stoken ("", "=");
         Gramext.Slist1 (Gramext.Stoken ("STRING", ""))],
        Gramext.action
          (fun (pd : string list) _ (t : 'ctyp) _ (i : string) _
             (loc : int * int) ->
             (MLast.SgExt (loc, i, t, pd) : 'sig_item));
        [Gramext.Stoken ("", "exception");
         Gramext.Snterm
           (Grammar.Entry.obj
              (constructor_declaration :
               'constructor_declaration Grammar.Entry.e))],
        Gramext.action
          (fun (_, c, tl : 'constructor_declaration) _ (loc : int * int) ->
             (MLast.SgExc (loc, c, tl) : 'sig_item));
        [Gramext.Stoken ("", "declare");
         Gramext.Slist0
           (Gramext.srules
              [[Gramext.Snterm
                  (Grammar.Entry.obj (sig_item : 'sig_item Grammar.Entry.e));
                Gramext.Stoken ("", ";")],
               Gramext.action
                 (fun _ (s : 'sig_item) (loc : int * int) -> (s : 'e__4))]);
         Gramext.Stoken ("", "end")],
        Gramext.action
          (fun _ (st : 'e__4 list) _ (loc : int * int) ->
             (MLast.SgDcl (loc, st) : 'sig_item))]];
      Grammar.Entry.obj
        (module_declaration : 'module_declaration Grammar.Entry.e),
      None,
      [None, Some Gramext.RightA,
       [[Gramext.Stoken ("", "("); Gramext.Stoken ("UIDENT", "");
         Gramext.Stoken ("", ":");
         Gramext.Snterm
           (Grammar.Entry.obj (module_type : 'module_type Grammar.Entry.e));
         Gramext.Stoken ("", ")"); Gramext.Sself],
        Gramext.action
          (fun (mt : 'module_declaration) _ (t : 'module_type) _ (i : string)
             _ (loc : int * int) ->
             (MLast.MtFun (loc, i, t, mt) : 'module_declaration));
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
       [[Gramext.Stoken ("UIDENT", ""); Gramext.Stoken ("", ":");
         Gramext.Snterm
           (Grammar.Entry.obj (module_type : 'module_type Grammar.Entry.e))],
        Gramext.action
          (fun (mt : 'module_type) _ (m : string) (loc : int * int) ->
             (m, mt : 'module_rec_declaration))]];
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
             (MLast.WcMod (loc, i, me) : 'with_constr));
        [Gramext.Stoken ("", "type");
         Gramext.Snterm
           (Grammar.Entry.obj (mod_ident : 'mod_ident Grammar.Entry.e));
         Gramext.Slist0
           (Gramext.Snterm
              (Grammar.Entry.obj
                 (type_parameter : 'type_parameter Grammar.Entry.e)));
         Gramext.Stoken ("", "=");
         Gramext.Snterm (Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e))],
        Gramext.action
          (fun (t : 'ctyp) _ (tpl : 'type_parameter list) (i : 'mod_ident) _
             (loc : int * int) ->
             (MLast.WcTyp (loc, i, tpl, t) : 'with_constr))]];
      Grammar.Entry.obj (expr : 'expr Grammar.Entry.e), None,
      [Some "top", Some Gramext.RightA,
       [[Gramext.Stoken ("", "while"); Gramext.Sself;
         Gramext.Stoken ("", "do"); Gramext.Stoken ("", "{");
         Gramext.Snterm
           (Grammar.Entry.obj (sequence : 'sequence Grammar.Entry.e));
         Gramext.Stoken ("", "}")],
        Gramext.action
          (fun _ (seq : 'sequence) _ _ (e : 'expr) _ (loc : int * int) ->
             (MLast.ExWhi (loc, e, seq) : 'expr));
        [Gramext.Stoken ("", "for"); Gramext.Stoken ("LIDENT", "");
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
             (e1 : 'expr) _ (i : string) _ (loc : int * int) ->
             (MLast.ExFor (loc, i, e1, e2, df, seq) : 'expr));
        [Gramext.Stoken ("", "do"); Gramext.Stoken ("", "{");
         Gramext.Snterm
           (Grammar.Entry.obj (sequence : 'sequence Grammar.Entry.e));
         Gramext.Stoken ("", "}")],
        Gramext.action
          (fun _ (seq : 'sequence) _ _ (loc : int * int) ->
             (mksequence loc seq : 'expr));
        [Gramext.Stoken ("", "if"); Gramext.Sself;
         Gramext.Stoken ("", "then"); Gramext.Sself;
         Gramext.Stoken ("", "else"); Gramext.Sself],
        Gramext.action
          (fun (e3 : 'expr) _ (e2 : 'expr) _ (e1 : 'expr) _
             (loc : int * int) ->
             (MLast.ExIfe (loc, e1, e2, e3) : 'expr));
        [Gramext.Stoken ("", "try"); Gramext.Sself;
         Gramext.Stoken ("", "with");
         Gramext.Snterm (Grammar.Entry.obj (ipatt : 'ipatt Grammar.Entry.e));
         Gramext.Stoken ("", "->"); Gramext.Sself],
        Gramext.action
          (fun (e1 : 'expr) _ (p1 : 'ipatt) _ (e : 'expr) _
             (loc : int * int) ->
             (MLast.ExTry (loc, e, [p1, None, e1]) : 'expr));
        [Gramext.Stoken ("", "try"); Gramext.Sself;
         Gramext.Stoken ("", "with"); Gramext.Stoken ("", "[");
         Gramext.Slist0sep
           (Gramext.Snterm
              (Grammar.Entry.obj (match_case : 'match_case Grammar.Entry.e)),
            Gramext.Stoken ("", "|"));
         Gramext.Stoken ("", "]")],
        Gramext.action
          (fun _ (l : 'match_case list) _ _ (e : 'expr) _ (loc : int * int) ->
             (MLast.ExTry (loc, e, l) : 'expr));
        [Gramext.Stoken ("", "match"); Gramext.Sself;
         Gramext.Stoken ("", "with");
         Gramext.Snterm (Grammar.Entry.obj (ipatt : 'ipatt Grammar.Entry.e));
         Gramext.Stoken ("", "->"); Gramext.Sself],
        Gramext.action
          (fun (e1 : 'expr) _ (p1 : 'ipatt) _ (e : 'expr) _
             (loc : int * int) ->
             (MLast.ExMat (loc, e, [p1, None, e1]) : 'expr));
        [Gramext.Stoken ("", "match"); Gramext.Sself;
         Gramext.Stoken ("", "with"); Gramext.Stoken ("", "[");
         Gramext.Slist0sep
           (Gramext.Snterm
              (Grammar.Entry.obj (match_case : 'match_case Grammar.Entry.e)),
            Gramext.Stoken ("", "|"));
         Gramext.Stoken ("", "]")],
        Gramext.action
          (fun _ (l : 'match_case list) _ _ (e : 'expr) _ (loc : int * int) ->
             (MLast.ExMat (loc, e, l) : 'expr));
        [Gramext.Stoken ("", "fun");
         Gramext.Snterm (Grammar.Entry.obj (ipatt : 'ipatt Grammar.Entry.e));
         Gramext.Snterm
           (Grammar.Entry.obj (fun_def : 'fun_def Grammar.Entry.e))],
        Gramext.action
          (fun (e : 'fun_def) (p : 'ipatt) _ (loc : int * int) ->
             (MLast.ExFun (loc, [p, None, e]) : 'expr));
        [Gramext.Stoken ("", "fun"); Gramext.Stoken ("", "[");
         Gramext.Slist0sep
           (Gramext.Snterm
              (Grammar.Entry.obj (match_case : 'match_case Grammar.Entry.e)),
            Gramext.Stoken ("", "|"));
         Gramext.Stoken ("", "]")],
        Gramext.action
          (fun _ (l : 'match_case list) _ _ (loc : int * int) ->
             (MLast.ExFun (loc, l) : 'expr));
        [Gramext.Stoken ("", "let"); Gramext.Stoken ("", "module");
         Gramext.Stoken ("UIDENT", "");
         Gramext.Snterm
           (Grammar.Entry.obj
              (module_binding : 'module_binding Grammar.Entry.e));
         Gramext.Stoken ("", "in"); Gramext.Sself],
        Gramext.action
          (fun (e : 'expr) _ (mb : 'module_binding) (m : string) _ _
             (loc : int * int) ->
             (MLast.ExLmd (loc, m, mb, e) : 'expr));
        [Gramext.Stoken ("", "let");
         Gramext.Sopt (Gramext.Stoken ("", "rec"));
         Gramext.Slist1sep
           (Gramext.Snterm
              (Grammar.Entry.obj
                 (let_binding : 'let_binding Grammar.Entry.e)),
            Gramext.Stoken ("", "and"));
         Gramext.Stoken ("", "in"); Gramext.Sself],
        Gramext.action
          (fun (x : 'expr) _ (l : 'let_binding list) (r : string option) _
             (loc : int * int) ->
             (MLast.ExLet (loc, o2b r, l, x) : 'expr))];
       Some "where", None,
       [[Gramext.Sself; Gramext.Stoken ("", "where");
         Gramext.Sopt (Gramext.Stoken ("", "rec"));
         Gramext.Snterm
           (Grammar.Entry.obj (let_binding : 'let_binding Grammar.Entry.e))],
        Gramext.action
          (fun (lb : 'let_binding) (rf : string option) _ (e : 'expr)
             (loc : int * int) ->
             (MLast.ExLet (loc, o2b rf, [lb], e) : 'expr))];
       Some ":=", Some Gramext.NonA,
       [[Gramext.Sself; Gramext.Stoken ("", ":="); Gramext.Sself;
         Gramext.Snterm (Grammar.Entry.obj (dummy : 'dummy Grammar.Entry.e))],
        Gramext.action
          (fun _ (e2 : 'expr) _ (e1 : 'expr) (loc : int * int) ->
             (MLast.ExAss (loc, e1, e2) : 'expr))];
       Some "||", Some Gramext.RightA,
       [[Gramext.Sself; Gramext.Stoken ("", "||"); Gramext.Sself],
        Gramext.action
          (fun (e2 : 'expr) _ (e1 : 'expr) (loc : int * int) ->
             (MLast.ExApp
                (loc, MLast.ExApp (loc, MLast.ExLid (loc, "||"), e1), e2) :
              'expr))];
       Some "&&", Some Gramext.RightA,
       [[Gramext.Sself; Gramext.Stoken ("", "&&"); Gramext.Sself],
        Gramext.action
          (fun (e2 : 'expr) _ (e1 : 'expr) (loc : int * int) ->
             (MLast.ExApp
                (loc, MLast.ExApp (loc, MLast.ExLid (loc, "&&"), e1), e2) :
              'expr))];
       Some "<", Some Gramext.LeftA,
       [[Gramext.Sself; Gramext.Stoken ("", "!="); Gramext.Sself],
        Gramext.action
          (fun (e2 : 'expr) _ (e1 : 'expr) (loc : int * int) ->
             (MLast.ExApp
                (loc, MLast.ExApp (loc, MLast.ExLid (loc, "!="), e1), e2) :
              'expr));
        [Gramext.Sself; Gramext.Stoken ("", "=="); Gramext.Sself],
        Gramext.action
          (fun (e2 : 'expr) _ (e1 : 'expr) (loc : int * int) ->
             (MLast.ExApp
                (loc, MLast.ExApp (loc, MLast.ExLid (loc, "=="), e1), e2) :
              'expr));
        [Gramext.Sself; Gramext.Stoken ("", "<>"); Gramext.Sself],
        Gramext.action
          (fun (e2 : 'expr) _ (e1 : 'expr) (loc : int * int) ->
             (MLast.ExApp
                (loc, MLast.ExApp (loc, MLast.ExLid (loc, "<>"), e1), e2) :
              'expr));
        [Gramext.Sself; Gramext.Stoken ("", "="); Gramext.Sself],
        Gramext.action
          (fun (e2 : 'expr) _ (e1 : 'expr) (loc : int * int) ->
             (MLast.ExApp
                (loc, MLast.ExApp (loc, MLast.ExLid (loc, "="), e1), e2) :
              'expr));
        [Gramext.Sself; Gramext.Stoken ("", ">="); Gramext.Sself],
        Gramext.action
          (fun (e2 : 'expr) _ (e1 : 'expr) (loc : int * int) ->
             (MLast.ExApp
                (loc, MLast.ExApp (loc, MLast.ExLid (loc, ">="), e1), e2) :
              'expr));
        [Gramext.Sself; Gramext.Stoken ("", "<="); Gramext.Sself],
        Gramext.action
          (fun (e2 : 'expr) _ (e1 : 'expr) (loc : int * int) ->
             (MLast.ExApp
                (loc, MLast.ExApp (loc, MLast.ExLid (loc, "<="), e1), e2) :
              'expr));
        [Gramext.Sself; Gramext.Stoken ("", ">"); Gramext.Sself],
        Gramext.action
          (fun (e2 : 'expr) _ (e1 : 'expr) (loc : int * int) ->
             (MLast.ExApp
                (loc, MLast.ExApp (loc, MLast.ExLid (loc, ">"), e1), e2) :
              'expr));
        [Gramext.Sself; Gramext.Stoken ("", "<"); Gramext.Sself],
        Gramext.action
          (fun (e2 : 'expr) _ (e1 : 'expr) (loc : int * int) ->
             (MLast.ExApp
                (loc, MLast.ExApp (loc, MLast.ExLid (loc, "<"), e1), e2) :
              'expr))];
       Some "^", Some Gramext.RightA,
       [[Gramext.Sself; Gramext.Stoken ("", "@"); Gramext.Sself],
        Gramext.action
          (fun (e2 : 'expr) _ (e1 : 'expr) (loc : int * int) ->
             (MLast.ExApp
                (loc, MLast.ExApp (loc, MLast.ExLid (loc, "@"), e1), e2) :
              'expr));
        [Gramext.Sself; Gramext.Stoken ("", "^"); Gramext.Sself],
        Gramext.action
          (fun (e2 : 'expr) _ (e1 : 'expr) (loc : int * int) ->
             (MLast.ExApp
                (loc, MLast.ExApp (loc, MLast.ExLid (loc, "^"), e1), e2) :
              'expr))];
       Some "+", Some Gramext.LeftA,
       [[Gramext.Sself; Gramext.Stoken ("", "-."); Gramext.Sself],
        Gramext.action
          (fun (e2 : 'expr) _ (e1 : 'expr) (loc : int * int) ->
             (MLast.ExApp
                (loc, MLast.ExApp (loc, MLast.ExLid (loc, "-."), e1), e2) :
              'expr));
        [Gramext.Sself; Gramext.Stoken ("", "+."); Gramext.Sself],
        Gramext.action
          (fun (e2 : 'expr) _ (e1 : 'expr) (loc : int * int) ->
             (MLast.ExApp
                (loc, MLast.ExApp (loc, MLast.ExLid (loc, "+."), e1), e2) :
              'expr));
        [Gramext.Sself; Gramext.Stoken ("", "-"); Gramext.Sself],
        Gramext.action
          (fun (e2 : 'expr) _ (e1 : 'expr) (loc : int * int) ->
             (MLast.ExApp
                (loc, MLast.ExApp (loc, MLast.ExLid (loc, "-"), e1), e2) :
              'expr));
        [Gramext.Sself; Gramext.Stoken ("", "+"); Gramext.Sself],
        Gramext.action
          (fun (e2 : 'expr) _ (e1 : 'expr) (loc : int * int) ->
             (MLast.ExApp
                (loc, MLast.ExApp (loc, MLast.ExLid (loc, "+"), e1), e2) :
              'expr))];
       Some "*", Some Gramext.LeftA,
       [[Gramext.Sself; Gramext.Stoken ("", "mod"); Gramext.Sself],
        Gramext.action
          (fun (e2 : 'expr) _ (e1 : 'expr) (loc : int * int) ->
             (MLast.ExApp
                (loc, MLast.ExApp (loc, MLast.ExLid (loc, "mod"), e1), e2) :
              'expr));
        [Gramext.Sself; Gramext.Stoken ("", "lxor"); Gramext.Sself],
        Gramext.action
          (fun (e2 : 'expr) _ (e1 : 'expr) (loc : int * int) ->
             (MLast.ExApp
                (loc, MLast.ExApp (loc, MLast.ExLid (loc, "lxor"), e1), e2) :
              'expr));
        [Gramext.Sself; Gramext.Stoken ("", "lor"); Gramext.Sself],
        Gramext.action
          (fun (e2 : 'expr) _ (e1 : 'expr) (loc : int * int) ->
             (MLast.ExApp
                (loc, MLast.ExApp (loc, MLast.ExLid (loc, "lor"), e1), e2) :
              'expr));
        [Gramext.Sself; Gramext.Stoken ("", "land"); Gramext.Sself],
        Gramext.action
          (fun (e2 : 'expr) _ (e1 : 'expr) (loc : int * int) ->
             (MLast.ExApp
                (loc, MLast.ExApp (loc, MLast.ExLid (loc, "land"), e1), e2) :
              'expr));
        [Gramext.Sself; Gramext.Stoken ("", "/."); Gramext.Sself],
        Gramext.action
          (fun (e2 : 'expr) _ (e1 : 'expr) (loc : int * int) ->
             (MLast.ExApp
                (loc, MLast.ExApp (loc, MLast.ExLid (loc, "/."), e1), e2) :
              'expr));
        [Gramext.Sself; Gramext.Stoken ("", "*."); Gramext.Sself],
        Gramext.action
          (fun (e2 : 'expr) _ (e1 : 'expr) (loc : int * int) ->
             (MLast.ExApp
                (loc, MLast.ExApp (loc, MLast.ExLid (loc, "*."), e1), e2) :
              'expr));
        [Gramext.Sself; Gramext.Stoken ("", "/"); Gramext.Sself],
        Gramext.action
          (fun (e2 : 'expr) _ (e1 : 'expr) (loc : int * int) ->
             (MLast.ExApp
                (loc, MLast.ExApp (loc, MLast.ExLid (loc, "/"), e1), e2) :
              'expr));
        [Gramext.Sself; Gramext.Stoken ("", "*"); Gramext.Sself],
        Gramext.action
          (fun (e2 : 'expr) _ (e1 : 'expr) (loc : int * int) ->
             (MLast.ExApp
                (loc, MLast.ExApp (loc, MLast.ExLid (loc, "*"), e1), e2) :
              'expr))];
       Some "**", Some Gramext.RightA,
       [[Gramext.Sself; Gramext.Stoken ("", "lsr"); Gramext.Sself],
        Gramext.action
          (fun (e2 : 'expr) _ (e1 : 'expr) (loc : int * int) ->
             (MLast.ExApp
                (loc, MLast.ExApp (loc, MLast.ExLid (loc, "lsr"), e1), e2) :
              'expr));
        [Gramext.Sself; Gramext.Stoken ("", "lsl"); Gramext.Sself],
        Gramext.action
          (fun (e2 : 'expr) _ (e1 : 'expr) (loc : int * int) ->
             (MLast.ExApp
                (loc, MLast.ExApp (loc, MLast.ExLid (loc, "lsl"), e1), e2) :
              'expr));
        [Gramext.Sself; Gramext.Stoken ("", "asr"); Gramext.Sself],
        Gramext.action
          (fun (e2 : 'expr) _ (e1 : 'expr) (loc : int * int) ->
             (MLast.ExApp
                (loc, MLast.ExApp (loc, MLast.ExLid (loc, "asr"), e1), e2) :
              'expr));
        [Gramext.Sself; Gramext.Stoken ("", "**"); Gramext.Sself],
        Gramext.action
          (fun (e2 : 'expr) _ (e1 : 'expr) (loc : int * int) ->
             (MLast.ExApp
                (loc, MLast.ExApp (loc, MLast.ExLid (loc, "**"), e1), e2) :
              'expr))];
       Some "unary minus", Some Gramext.NonA,
       [[Gramext.Stoken ("", "-."); Gramext.Sself],
        Gramext.action
          (fun (e : 'expr) _ (loc : int * int) ->
             (mkumin loc "-." e : 'expr));
        [Gramext.Stoken ("", "-"); Gramext.Sself],
        Gramext.action
          (fun (e : 'expr) _ (loc : int * int) ->
             (mkumin loc "-" e : 'expr))];
       Some "apply", Some Gramext.LeftA,
       [[Gramext.Stoken ("", "lazy"); Gramext.Sself],
        Gramext.action
          (fun (e : 'expr) _ (loc : int * int) ->
             (MLast.ExLaz (loc, e) : 'expr));
        [Gramext.Stoken ("", "assert"); Gramext.Sself],
        Gramext.action
          (fun (e : 'expr) _ (loc : int * int) -> (mkassert loc e : 'expr));
        [Gramext.Sself; Gramext.Sself],
        Gramext.action
          (fun (e2 : 'expr) (e1 : 'expr) (loc : int * int) ->
             (MLast.ExApp (loc, e1, e2) : 'expr))];
       Some ".", Some Gramext.LeftA,
       [[Gramext.Sself; Gramext.Stoken ("", "."); Gramext.Sself],
        Gramext.action
          (fun (e2 : 'expr) _ (e1 : 'expr) (loc : int * int) ->
             (MLast.ExAcc (loc, e1, e2) : 'expr));
        [Gramext.Sself; Gramext.Stoken ("", "."); Gramext.Stoken ("", "[");
         Gramext.Sself; Gramext.Stoken ("", "]")],
        Gramext.action
          (fun _ (e2 : 'expr) _ _ (e1 : 'expr) (loc : int * int) ->
             (MLast.ExSte (loc, e1, e2) : 'expr));
        [Gramext.Sself; Gramext.Stoken ("", "."); Gramext.Stoken ("", "(");
         Gramext.Sself; Gramext.Stoken ("", ")")],
        Gramext.action
          (fun _ (e2 : 'expr) _ _ (e1 : 'expr) (loc : int * int) ->
             (MLast.ExAre (loc, e1, e2) : 'expr))];
       Some "~-", Some Gramext.NonA,
       [[Gramext.Stoken ("", "~-."); Gramext.Sself],
        Gramext.action
          (fun (e : 'expr) _ (loc : int * int) ->
             (MLast.ExApp (loc, MLast.ExLid (loc, "~-."), e) : 'expr));
        [Gramext.Stoken ("", "~-"); Gramext.Sself],
        Gramext.action
          (fun (e : 'expr) _ (loc : int * int) ->
             (MLast.ExApp (loc, MLast.ExLid (loc, "~-"), e) : 'expr))];
       Some "simple", None,
       [[Gramext.Stoken ("", "("); Gramext.Sself; Gramext.Stoken ("", ")")],
        Gramext.action (fun _ (e : 'expr) _ (loc : int * int) -> (e : 'expr));
        [Gramext.Stoken ("", "("); Gramext.Sself; Gramext.Stoken ("", ",");
         Gramext.Slist1sep
           (Gramext.Snterm (Grammar.Entry.obj (expr : 'expr Grammar.Entry.e)),
            Gramext.Stoken ("", ","));
         Gramext.Stoken ("", ")")],
        Gramext.action
          (fun _ (el : 'expr list) _ (e : 'expr) _ (loc : int * int) ->
             (MLast.ExTup (loc, (e :: el)) : 'expr));
        [Gramext.Stoken ("", "("); Gramext.Sself; Gramext.Stoken ("", ":");
         Gramext.Snterm (Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e));
         Gramext.Stoken ("", ")")],
        Gramext.action
          (fun _ (t : 'ctyp) _ (e : 'expr) _ (loc : int * int) ->
             (MLast.ExTyc (loc, e, t) : 'expr));
        [Gramext.Stoken ("", "("); Gramext.Stoken ("", ")")],
        Gramext.action
          (fun _ _ (loc : int * int) -> (MLast.ExUid (loc, "()") : 'expr));
        [Gramext.Stoken ("", "{"); Gramext.Stoken ("", "("); Gramext.Sself;
         Gramext.Stoken ("", ")"); Gramext.Stoken ("", "with");
         Gramext.Slist1sep
           (Gramext.Snterm
              (Grammar.Entry.obj (label_expr : 'label_expr Grammar.Entry.e)),
            Gramext.Stoken ("", ";"));
         Gramext.Stoken ("", "}")],
        Gramext.action
          (fun _ (lel : 'label_expr list) _ _ (e : 'expr) _ _
             (loc : int * int) ->
             (MLast.ExRec (loc, lel, Some e) : 'expr));
        [Gramext.Stoken ("", "{");
         Gramext.Slist1sep
           (Gramext.Snterm
              (Grammar.Entry.obj (label_expr : 'label_expr Grammar.Entry.e)),
            Gramext.Stoken ("", ";"));
         Gramext.Stoken ("", "}")],
        Gramext.action
          (fun _ (lel : 'label_expr list) _ (loc : int * int) ->
             (MLast.ExRec (loc, lel, None) : 'expr));
        [Gramext.Stoken ("", "[|");
         Gramext.Slist0sep
           (Gramext.Snterm (Grammar.Entry.obj (expr : 'expr Grammar.Entry.e)),
            Gramext.Stoken ("", ";"));
         Gramext.Stoken ("", "|]")],
        Gramext.action
          (fun _ (el : 'expr list) _ (loc : int * int) ->
             (MLast.ExArr (loc, el) : 'expr));
        [Gramext.Stoken ("", "[");
         Gramext.Slist1sep
           (Gramext.Snterm (Grammar.Entry.obj (expr : 'expr Grammar.Entry.e)),
            Gramext.Stoken ("", ";"));
         Gramext.Snterm
           (Grammar.Entry.obj
              (cons_expr_opt : 'cons_expr_opt Grammar.Entry.e));
         Gramext.Stoken ("", "]")],
        Gramext.action
          (fun _ (last : 'cons_expr_opt) (el : 'expr list) _
             (loc : int * int) ->
             (mklistexp loc last el : 'expr));
        [Gramext.Stoken ("", "["); Gramext.Stoken ("", "]")],
        Gramext.action
          (fun _ _ (loc : int * int) -> (MLast.ExUid (loc, "[]") : 'expr));
        [Gramext.Snterm
           (Grammar.Entry.obj (expr_ident : 'expr_ident Grammar.Entry.e))],
        Gramext.action
          (fun (i : 'expr_ident) (loc : int * int) -> (i : 'expr));
        [Gramext.Stoken ("CHAR", "")],
        Gramext.action
          (fun (s : string) (loc : int * int) ->
             (MLast.ExChr (loc, s) : 'expr));
        [Gramext.Stoken ("STRING", "")],
        Gramext.action
          (fun (s : string) (loc : int * int) ->
             (MLast.ExStr (loc, s) : 'expr));
        [Gramext.Stoken ("FLOAT", "")],
        Gramext.action
          (fun (s : string) (loc : int * int) ->
             (MLast.ExFlo (loc, s) : 'expr));
        [Gramext.Stoken ("NATIVEINT", "")],
        Gramext.action
          (fun (s : string) (loc : int * int) ->
             (MLast.ExNativeInt (loc, s) : 'expr));
        [Gramext.Stoken ("INT64", "")],
        Gramext.action
          (fun (s : string) (loc : int * int) ->
             (MLast.ExInt64 (loc, s) : 'expr));
        [Gramext.Stoken ("INT32", "")],
        Gramext.action
          (fun (s : string) (loc : int * int) ->
             (MLast.ExInt32 (loc, s) : 'expr));
        [Gramext.Stoken ("INT", "")],
        Gramext.action
          (fun (s : string) (loc : int * int) ->
             (MLast.ExInt (loc, s) : 'expr))]];
      Grammar.Entry.obj (cons_expr_opt : 'cons_expr_opt Grammar.Entry.e),
      None,
      [None, None,
       [[], Gramext.action (fun (loc : int * int) -> (None : 'cons_expr_opt));
        [Gramext.Stoken ("", "::");
         Gramext.Snterm (Grammar.Entry.obj (expr : 'expr Grammar.Entry.e))],
        Gramext.action
          (fun (e : 'expr) _ (loc : int * int) ->
             (Some e : 'cons_expr_opt))]];
      Grammar.Entry.obj (dummy : 'dummy Grammar.Entry.e), None,
      [None, None,
       [[], Gramext.action (fun (loc : int * int) -> (() : 'dummy))]];
      Grammar.Entry.obj (sequence : 'sequence Grammar.Entry.e), None,
      [None, None,
       [[Gramext.Snterm (Grammar.Entry.obj (expr : 'expr Grammar.Entry.e))],
        Gramext.action
          (fun (e : 'expr) (loc : int * int) -> ([e] : 'sequence));
        [Gramext.Snterm (Grammar.Entry.obj (expr : 'expr Grammar.Entry.e));
         Gramext.Stoken ("", ";")],
        Gramext.action
          (fun _ (e : 'expr) (loc : int * int) -> ([e] : 'sequence));
        [Gramext.Snterm (Grammar.Entry.obj (expr : 'expr Grammar.Entry.e));
         Gramext.Stoken ("", ";"); Gramext.Sself],
        Gramext.action
          (fun (el : 'sequence) _ (e : 'expr) (loc : int * int) ->
             (e :: el : 'sequence));
        [Gramext.Stoken ("", "let");
         Gramext.Sopt (Gramext.Stoken ("", "rec"));
         Gramext.Slist1sep
           (Gramext.Snterm
              (Grammar.Entry.obj
                 (let_binding : 'let_binding Grammar.Entry.e)),
            Gramext.Stoken ("", "and"));
         Gramext.srules
           [[Gramext.Stoken ("", ";")],
            Gramext.action
              (fun (x : string) (loc : int * int) -> (x : 'e__5));
            [Gramext.Stoken ("", "in")],
            Gramext.action
              (fun (x : string) (loc : int * int) -> (x : 'e__5))];
         Gramext.Sself],
        Gramext.action
          (fun (el : 'sequence) _ (l : 'let_binding list) (rf : string option)
             _ (loc : int * int) ->
             ([MLast.ExLet (loc, o2b rf, l, mksequence loc el)] :
              'sequence))]];
      Grammar.Entry.obj (let_binding : 'let_binding Grammar.Entry.e), None,
      [None, None,
       [[Gramext.Snterm (Grammar.Entry.obj (ipatt : 'ipatt Grammar.Entry.e));
         Gramext.Snterm
           (Grammar.Entry.obj (fun_binding : 'fun_binding Grammar.Entry.e))],
        Gramext.action
          (fun (e : 'fun_binding) (p : 'ipatt) (loc : int * int) ->
             (p, e : 'let_binding))]];
      Grammar.Entry.obj (fun_binding : 'fun_binding Grammar.Entry.e), None,
      [None, Some Gramext.RightA,
       [[Gramext.Stoken ("", ":");
         Gramext.Snterm (Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e));
         Gramext.Stoken ("", "=");
         Gramext.Snterm (Grammar.Entry.obj (expr : 'expr Grammar.Entry.e))],
        Gramext.action
          (fun (e : 'expr) _ (t : 'ctyp) _ (loc : int * int) ->
             (MLast.ExTyc (loc, e, t) : 'fun_binding));
        [Gramext.Stoken ("", "=");
         Gramext.Snterm (Grammar.Entry.obj (expr : 'expr Grammar.Entry.e))],
        Gramext.action
          (fun (e : 'expr) _ (loc : int * int) -> (e : 'fun_binding));
        [Gramext.Snterm (Grammar.Entry.obj (ipatt : 'ipatt Grammar.Entry.e));
         Gramext.Sself],
        Gramext.action
          (fun (e : 'fun_binding) (p : 'ipatt) (loc : int * int) ->
             (MLast.ExFun (loc, [p, None, e]) : 'fun_binding))]];
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
             (mkmatchcase loc p aso w e : 'match_case))]];
      Grammar.Entry.obj (as_patt_opt : 'as_patt_opt Grammar.Entry.e), None,
      [None, None,
       [[], Gramext.action (fun (loc : int * int) -> (None : 'as_patt_opt));
        [Gramext.Stoken ("", "as");
         Gramext.Snterm (Grammar.Entry.obj (patt : 'patt Grammar.Entry.e))],
        Gramext.action
          (fun (p : 'patt) _ (loc : int * int) -> (Some p : 'as_patt_opt))]];
      Grammar.Entry.obj (when_expr_opt : 'when_expr_opt Grammar.Entry.e),
      None,
      [None, None,
       [[], Gramext.action (fun (loc : int * int) -> (None : 'when_expr_opt));
        [Gramext.Stoken ("", "when");
         Gramext.Snterm (Grammar.Entry.obj (expr : 'expr Grammar.Entry.e))],
        Gramext.action
          (fun (e : 'expr) _ (loc : int * int) ->
             (Some e : 'when_expr_opt))]];
      Grammar.Entry.obj (label_expr : 'label_expr Grammar.Entry.e), None,
      [None, None,
       [[Gramext.Snterm
           (Grammar.Entry.obj
              (patt_label_ident : 'patt_label_ident Grammar.Entry.e));
         Gramext.Snterm
           (Grammar.Entry.obj (fun_binding : 'fun_binding Grammar.Entry.e))],
        Gramext.action
          (fun (e : 'fun_binding) (i : 'patt_label_ident) (loc : int * int) ->
             (i, e : 'label_expr))]];
      Grammar.Entry.obj (expr_ident : 'expr_ident Grammar.Entry.e), None,
      [None, Some Gramext.RightA,
       [[Gramext.Stoken ("UIDENT", ""); Gramext.Stoken ("", ".");
         Gramext.Sself],
        Gramext.action
          (fun (j : 'expr_ident) _ (i : string) (loc : int * int) ->
             (mkexprident loc i j : 'expr_ident));
        [Gramext.Stoken ("UIDENT", "")],
        Gramext.action
          (fun (i : string) (loc : int * int) ->
             (MLast.ExUid (loc, i) : 'expr_ident));
        [Gramext.Stoken ("LIDENT", "")],
        Gramext.action
          (fun (i : string) (loc : int * int) ->
             (MLast.ExLid (loc, i) : 'expr_ident))]];
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
             (MLast.ExFun (loc, [p, None, e]) : 'fun_def))]];
      Grammar.Entry.obj (patt : 'patt Grammar.Entry.e), None,
      [None, Some Gramext.LeftA,
       [[Gramext.Sself; Gramext.Stoken ("", "|"); Gramext.Sself],
        Gramext.action
          (fun (p2 : 'patt) _ (p1 : 'patt) (loc : int * int) ->
             (MLast.PaOrp (loc, p1, p2) : 'patt))];
       None, Some Gramext.NonA,
       [[Gramext.Sself; Gramext.Stoken ("", ".."); Gramext.Sself],
        Gramext.action
          (fun (p2 : 'patt) _ (p1 : 'patt) (loc : int * int) ->
             (MLast.PaRng (loc, p1, p2) : 'patt))];
       None, Some Gramext.LeftA,
       [[Gramext.Sself; Gramext.Sself],
        Gramext.action
          (fun (p2 : 'patt) (p1 : 'patt) (loc : int * int) ->
             (MLast.PaApp (loc, p1, p2) : 'patt))];
       None, Some Gramext.LeftA,
       [[Gramext.Sself; Gramext.Stoken ("", "."); Gramext.Sself],
        Gramext.action
          (fun (p2 : 'patt) _ (p1 : 'patt) (loc : int * int) ->
             (MLast.PaAcc (loc, p1, p2) : 'patt))];
       Some "simple", None,
       [[Gramext.Stoken ("", "_")],
        Gramext.action (fun _ (loc : int * int) -> (MLast.PaAny loc : 'patt));
        [Gramext.Stoken ("", "("); Gramext.Sself; Gramext.Stoken ("", ",");
         Gramext.Slist1sep
           (Gramext.Snterm (Grammar.Entry.obj (patt : 'patt Grammar.Entry.e)),
            Gramext.Stoken ("", ","));
         Gramext.Stoken ("", ")")],
        Gramext.action
          (fun _ (pl : 'patt list) _ (p : 'patt) _ (loc : int * int) ->
             (MLast.PaTup (loc, (p :: pl)) : 'patt));
        [Gramext.Stoken ("", "("); Gramext.Sself; Gramext.Stoken ("", "as");
         Gramext.Sself; Gramext.Stoken ("", ")")],
        Gramext.action
          (fun _ (p2 : 'patt) _ (p : 'patt) _ (loc : int * int) ->
             (MLast.PaAli (loc, p, p2) : 'patt));
        [Gramext.Stoken ("", "("); Gramext.Sself; Gramext.Stoken ("", ":");
         Gramext.Snterm (Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e));
         Gramext.Stoken ("", ")")],
        Gramext.action
          (fun _ (t : 'ctyp) _ (p : 'patt) _ (loc : int * int) ->
             (MLast.PaTyc (loc, p, t) : 'patt));
        [Gramext.Stoken ("", "("); Gramext.Sself; Gramext.Stoken ("", ")")],
        Gramext.action (fun _ (p : 'patt) _ (loc : int * int) -> (p : 'patt));
        [Gramext.Stoken ("", "("); Gramext.Stoken ("", ")")],
        Gramext.action
          (fun _ _ (loc : int * int) -> (MLast.PaUid (loc, "()") : 'patt));
        [Gramext.Stoken ("", "{");
         Gramext.Slist1sep
           (Gramext.Snterm
              (Grammar.Entry.obj (label_patt : 'label_patt Grammar.Entry.e)),
            Gramext.Stoken ("", ";"));
         Gramext.Stoken ("", "}")],
        Gramext.action
          (fun _ (lpl : 'label_patt list) _ (loc : int * int) ->
             (MLast.PaRec (loc, lpl) : 'patt));
        [Gramext.Stoken ("", "[|");
         Gramext.Slist0sep
           (Gramext.Snterm (Grammar.Entry.obj (patt : 'patt Grammar.Entry.e)),
            Gramext.Stoken ("", ";"));
         Gramext.Stoken ("", "|]")],
        Gramext.action
          (fun _ (pl : 'patt list) _ (loc : int * int) ->
             (MLast.PaArr (loc, pl) : 'patt));
        [Gramext.Stoken ("", "[");
         Gramext.Slist1sep
           (Gramext.Snterm (Grammar.Entry.obj (patt : 'patt Grammar.Entry.e)),
            Gramext.Stoken ("", ";"));
         Gramext.Snterm
           (Grammar.Entry.obj
              (cons_patt_opt : 'cons_patt_opt Grammar.Entry.e));
         Gramext.Stoken ("", "]")],
        Gramext.action
          (fun _ (last : 'cons_patt_opt) (pl : 'patt list) _
             (loc : int * int) ->
             (mklistpat loc last pl : 'patt));
        [Gramext.Stoken ("", "["); Gramext.Stoken ("", "]")],
        Gramext.action
          (fun _ _ (loc : int * int) -> (MLast.PaUid (loc, "[]") : 'patt));
        [Gramext.Stoken ("", "-"); Gramext.Stoken ("FLOAT", "")],
        Gramext.action
          (fun (s : string) _ (loc : int * int) ->
             (MLast.PaFlo (loc, neg_string s) : 'patt));
        [Gramext.Stoken ("", "-"); Gramext.Stoken ("NATIVEINT", "")],
        Gramext.action
          (fun (s : string) _ (loc : int * int) ->
             (MLast.PaNativeInt (loc, neg_string s) : 'patt));
        [Gramext.Stoken ("", "-"); Gramext.Stoken ("INT64", "")],
        Gramext.action
          (fun (s : string) _ (loc : int * int) ->
             (MLast.PaInt64 (loc, neg_string s) : 'patt));
        [Gramext.Stoken ("", "-"); Gramext.Stoken ("INT32", "")],
        Gramext.action
          (fun (s : string) _ (loc : int * int) ->
             (MLast.PaInt32 (loc, neg_string s) : 'patt));
        [Gramext.Stoken ("", "-"); Gramext.Stoken ("INT", "")],
        Gramext.action
          (fun (s : string) _ (loc : int * int) ->
             (MLast.PaInt (loc, neg_string s) : 'patt));
        [Gramext.Stoken ("CHAR", "")],
        Gramext.action
          (fun (s : string) (loc : int * int) ->
             (MLast.PaChr (loc, s) : 'patt));
        [Gramext.Stoken ("STRING", "")],
        Gramext.action
          (fun (s : string) (loc : int * int) ->
             (MLast.PaStr (loc, s) : 'patt));
        [Gramext.Stoken ("FLOAT", "")],
        Gramext.action
          (fun (s : string) (loc : int * int) ->
             (MLast.PaFlo (loc, s) : 'patt));
        [Gramext.Stoken ("NATIVEINT", "")],
        Gramext.action
          (fun (s : string) (loc : int * int) ->
             (MLast.PaNativeInt (loc, s) : 'patt));
        [Gramext.Stoken ("INT64", "")],
        Gramext.action
          (fun (s : string) (loc : int * int) ->
             (MLast.PaInt64 (loc, s) : 'patt));
        [Gramext.Stoken ("INT32", "")],
        Gramext.action
          (fun (s : string) (loc : int * int) ->
             (MLast.PaInt32 (loc, s) : 'patt));
        [Gramext.Stoken ("INT", "")],
        Gramext.action
          (fun (s : string) (loc : int * int) ->
             (MLast.PaInt (loc, s) : 'patt));
        [Gramext.Stoken ("UIDENT", "")],
        Gramext.action
          (fun (s : string) (loc : int * int) ->
             (MLast.PaUid (loc, s) : 'patt));
        [Gramext.Stoken ("LIDENT", "")],
        Gramext.action
          (fun (s : string) (loc : int * int) ->
             (MLast.PaLid (loc, s) : 'patt))]];
      Grammar.Entry.obj (cons_patt_opt : 'cons_patt_opt Grammar.Entry.e),
      None,
      [None, None,
       [[], Gramext.action (fun (loc : int * int) -> (None : 'cons_patt_opt));
        [Gramext.Stoken ("", "::");
         Gramext.Snterm (Grammar.Entry.obj (patt : 'patt Grammar.Entry.e))],
        Gramext.action
          (fun (p : 'patt) _ (loc : int * int) ->
             (Some p : 'cons_patt_opt))]];
      Grammar.Entry.obj (label_patt : 'label_patt Grammar.Entry.e), None,
      [None, None,
       [[Gramext.Snterm
           (Grammar.Entry.obj
              (patt_label_ident : 'patt_label_ident Grammar.Entry.e));
         Gramext.Stoken ("", "=");
         Gramext.Snterm (Grammar.Entry.obj (patt : 'patt Grammar.Entry.e))],
        Gramext.action
          (fun (p : 'patt) _ (i : 'patt_label_ident) (loc : int * int) ->
             (i, p : 'label_patt))]];
      Grammar.Entry.obj
        (patt_label_ident : 'patt_label_ident Grammar.Entry.e),
      None,
      [None, Some Gramext.LeftA,
       [[Gramext.Sself; Gramext.Stoken ("", "."); Gramext.Sself],
        Gramext.action
          (fun (p2 : 'patt_label_ident) _ (p1 : 'patt_label_ident)
             (loc : int * int) ->
             (MLast.PaAcc (loc, p1, p2) : 'patt_label_ident))];
       Some "simple", Some Gramext.RightA,
       [[Gramext.Stoken ("LIDENT", "")],
        Gramext.action
          (fun (i : string) (loc : int * int) ->
             (MLast.PaLid (loc, i) : 'patt_label_ident));
        [Gramext.Stoken ("UIDENT", "")],
        Gramext.action
          (fun (i : string) (loc : int * int) ->
             (MLast.PaUid (loc, i) : 'patt_label_ident))]];
      Grammar.Entry.obj (ipatt : 'ipatt Grammar.Entry.e), None,
      [None, None,
       [[Gramext.Stoken ("", "_")],
        Gramext.action
          (fun _ (loc : int * int) -> (MLast.PaAny loc : 'ipatt));
        [Gramext.Stoken ("LIDENT", "")],
        Gramext.action
          (fun (s : string) (loc : int * int) ->
             (MLast.PaLid (loc, s) : 'ipatt));
        [Gramext.Stoken ("", "("); Gramext.Sself; Gramext.Stoken ("", ",");
         Gramext.Slist1sep
           (Gramext.Snterm
              (Grammar.Entry.obj (ipatt : 'ipatt Grammar.Entry.e)),
            Gramext.Stoken ("", ","));
         Gramext.Stoken ("", ")")],
        Gramext.action
          (fun _ (pl : 'ipatt list) _ (p : 'ipatt) _ (loc : int * int) ->
             (MLast.PaTup (loc, (p :: pl)) : 'ipatt));
        [Gramext.Stoken ("", "("); Gramext.Sself; Gramext.Stoken ("", "as");
         Gramext.Sself; Gramext.Stoken ("", ")")],
        Gramext.action
          (fun _ (p2 : 'ipatt) _ (p : 'ipatt) _ (loc : int * int) ->
             (MLast.PaAli (loc, p, p2) : 'ipatt));
        [Gramext.Stoken ("", "("); Gramext.Sself; Gramext.Stoken ("", ":");
         Gramext.Snterm (Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e));
         Gramext.Stoken ("", ")")],
        Gramext.action
          (fun _ (t : 'ctyp) _ (p : 'ipatt) _ (loc : int * int) ->
             (MLast.PaTyc (loc, p, t) : 'ipatt));
        [Gramext.Stoken ("", "("); Gramext.Sself; Gramext.Stoken ("", ")")],
        Gramext.action
          (fun _ (p : 'ipatt) _ (loc : int * int) -> (p : 'ipatt));
        [Gramext.Stoken ("", "("); Gramext.Stoken ("", ")")],
        Gramext.action
          (fun _ _ (loc : int * int) -> (MLast.PaUid (loc, "()") : 'ipatt));
        [Gramext.Stoken ("", "{");
         Gramext.Slist1sep
           (Gramext.Snterm
              (Grammar.Entry.obj
                 (label_ipatt : 'label_ipatt Grammar.Entry.e)),
            Gramext.Stoken ("", ";"));
         Gramext.Stoken ("", "}")],
        Gramext.action
          (fun _ (lpl : 'label_ipatt list) _ (loc : int * int) ->
             (MLast.PaRec (loc, lpl) : 'ipatt))]];
      Grammar.Entry.obj (label_ipatt : 'label_ipatt Grammar.Entry.e), None,
      [None, None,
       [[Gramext.Snterm
           (Grammar.Entry.obj
              (patt_label_ident : 'patt_label_ident Grammar.Entry.e));
         Gramext.Stoken ("", "=");
         Gramext.Snterm (Grammar.Entry.obj (ipatt : 'ipatt Grammar.Entry.e))],
        Gramext.action
          (fun (p : 'ipatt) _ (i : 'patt_label_ident) (loc : int * int) ->
             (i, p : 'label_ipatt))]];
      Grammar.Entry.obj
        (type_declaration : 'type_declaration Grammar.Entry.e),
      None,
      [None, None,
       [[Gramext.Snterm
           (Grammar.Entry.obj (type_patt : 'type_patt Grammar.Entry.e));
         Gramext.Slist0
           (Gramext.Snterm
              (Grammar.Entry.obj
                 (type_parameter : 'type_parameter Grammar.Entry.e)));
         Gramext.Stoken ("", "=");
         Gramext.Snterm (Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e));
         Gramext.Slist0
           (Gramext.Snterm
              (Grammar.Entry.obj (constrain : 'constrain Grammar.Entry.e)))],
        Gramext.action
          (fun (cl : 'constrain list) (tk : 'ctyp) _
             (tpl : 'type_parameter list) (n : 'type_patt)
             (loc : int * int) ->
             (n, tpl, tk, cl : 'type_declaration))]];
      Grammar.Entry.obj (type_patt : 'type_patt Grammar.Entry.e), None,
      [None, None,
       [[Gramext.Stoken ("LIDENT", "")],
        Gramext.action
          (fun (n : string) (loc : int * int) -> (loc, n : 'type_patt))]];
      Grammar.Entry.obj (constrain : 'constrain Grammar.Entry.e), None,
      [None, None,
       [[Gramext.Stoken ("", "constraint");
         Gramext.Snterm (Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e));
         Gramext.Stoken ("", "=");
         Gramext.Snterm (Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e))],
        Gramext.action
          (fun (t2 : 'ctyp) _ (t1 : 'ctyp) _ (loc : int * int) ->
             (t1, t2 : 'constrain))]];
      Grammar.Entry.obj (type_parameter : 'type_parameter Grammar.Entry.e),
      None,
      [None, None,
       [[Gramext.Stoken ("", "-"); Gramext.Stoken ("", "'");
         Gramext.Snterm (Grammar.Entry.obj (ident : 'ident Grammar.Entry.e))],
        Gramext.action
          (fun (i : 'ident) _ _ (loc : int * int) ->
             (i, (false, true) : 'type_parameter));
        [Gramext.Stoken ("", "+"); Gramext.Stoken ("", "'");
         Gramext.Snterm (Grammar.Entry.obj (ident : 'ident Grammar.Entry.e))],
        Gramext.action
          (fun (i : 'ident) _ _ (loc : int * int) ->
             (i, (true, false) : 'type_parameter));
        [Gramext.Stoken ("", "'");
         Gramext.Snterm (Grammar.Entry.obj (ident : 'ident Grammar.Entry.e))],
        Gramext.action
          (fun (i : 'ident) _ (loc : int * int) ->
             (i, (false, false) : 'type_parameter))]];
      Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e), None,
      [None, Some Gramext.LeftA,
       [[Gramext.Sself; Gramext.Stoken ("", "=="); Gramext.Sself],
        Gramext.action
          (fun (t2 : 'ctyp) _ (t1 : 'ctyp) (loc : int * int) ->
             (MLast.TyMan (loc, t1, t2) : 'ctyp))];
       None, Some Gramext.LeftA,
       [[Gramext.Sself; Gramext.Stoken ("", "as"); Gramext.Sself],
        Gramext.action
          (fun (t2 : 'ctyp) _ (t1 : 'ctyp) (loc : int * int) ->
             (MLast.TyAli (loc, t1, t2) : 'ctyp))];
       None, Some Gramext.LeftA,
       [[Gramext.Stoken ("", "!");
         Gramext.Slist1
           (Gramext.Snterm
              (Grammar.Entry.obj (typevar : 'typevar Grammar.Entry.e)));
         Gramext.Stoken ("", "."); Gramext.Sself],
        Gramext.action
          (fun (t : 'ctyp) _ (pl : 'typevar list) _ (loc : int * int) ->
             (MLast.TyPol (loc, pl, t) : 'ctyp))];
       Some "arrow", Some Gramext.RightA,
       [[Gramext.Sself; Gramext.Stoken ("", "->"); Gramext.Sself],
        Gramext.action
          (fun (t2 : 'ctyp) _ (t1 : 'ctyp) (loc : int * int) ->
             (MLast.TyArr (loc, t1, t2) : 'ctyp))];
       None, Some Gramext.LeftA,
       [[Gramext.Sself; Gramext.Sself],
        Gramext.action
          (fun (t2 : 'ctyp) (t1 : 'ctyp) (loc : int * int) ->
             (MLast.TyApp (loc, t1, t2) : 'ctyp))];
       None, Some Gramext.LeftA,
       [[Gramext.Sself; Gramext.Stoken ("", "."); Gramext.Sself],
        Gramext.action
          (fun (t2 : 'ctyp) _ (t1 : 'ctyp) (loc : int * int) ->
             (MLast.TyAcc (loc, t1, t2) : 'ctyp))];
       Some "simple", None,
       [[Gramext.Stoken ("", "{");
         Gramext.Slist1sep
           (Gramext.Snterm
              (Grammar.Entry.obj
                 (label_declaration : 'label_declaration Grammar.Entry.e)),
            Gramext.Stoken ("", ";"));
         Gramext.Stoken ("", "}")],
        Gramext.action
          (fun _ (ldl : 'label_declaration list) _ (loc : int * int) ->
             (MLast.TyRec (loc, false, ldl) : 'ctyp));
        [Gramext.Stoken ("", "[");
         Gramext.Slist0sep
           (Gramext.Snterm
              (Grammar.Entry.obj
                 (constructor_declaration :
                  'constructor_declaration Grammar.Entry.e)),
            Gramext.Stoken ("", "|"));
         Gramext.Stoken ("", "]")],
        Gramext.action
          (fun _ (cdl : 'constructor_declaration list) _ (loc : int * int) ->
             (MLast.TySum (loc, false, cdl) : 'ctyp));
        [Gramext.Stoken ("", "private"); Gramext.Stoken ("", "{");
         Gramext.Slist1sep
           (Gramext.Snterm
              (Grammar.Entry.obj
                 (label_declaration : 'label_declaration Grammar.Entry.e)),
            Gramext.Stoken ("", ";"));
         Gramext.Stoken ("", "}")],
        Gramext.action
          (fun _ (ldl : 'label_declaration list) _ _ (loc : int * int) ->
             (MLast.TyRec (loc, true, ldl) : 'ctyp));
        [Gramext.Stoken ("", "private"); Gramext.Stoken ("", "[");
         Gramext.Slist0sep
           (Gramext.Snterm
              (Grammar.Entry.obj
                 (constructor_declaration :
                  'constructor_declaration Grammar.Entry.e)),
            Gramext.Stoken ("", "|"));
         Gramext.Stoken ("", "]")],
        Gramext.action
          (fun _ (cdl : 'constructor_declaration list) _ _
             (loc : int * int) ->
             (MLast.TySum (loc, true, cdl) : 'ctyp));
        [Gramext.Stoken ("", "("); Gramext.Sself; Gramext.Stoken ("", ")")],
        Gramext.action (fun _ (t : 'ctyp) _ (loc : int * int) -> (t : 'ctyp));
        [Gramext.Stoken ("", "("); Gramext.Sself; Gramext.Stoken ("", "*");
         Gramext.Slist1sep
           (Gramext.Snterm (Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e)),
            Gramext.Stoken ("", "*"));
         Gramext.Stoken ("", ")")],
        Gramext.action
          (fun _ (tl : 'ctyp list) _ (t : 'ctyp) _ (loc : int * int) ->
             (MLast.TyTup (loc, (t :: tl)) : 'ctyp));
        [Gramext.Stoken ("UIDENT", "")],
        Gramext.action
          (fun (i : string) (loc : int * int) ->
             (MLast.TyUid (loc, i) : 'ctyp));
        [Gramext.Stoken ("LIDENT", "")],
        Gramext.action
          (fun (i : string) (loc : int * int) ->
             (MLast.TyLid (loc, i) : 'ctyp));
        [Gramext.Stoken ("", "_")],
        Gramext.action (fun _ (loc : int * int) -> (MLast.TyAny loc : 'ctyp));
        [Gramext.Stoken ("", "'");
         Gramext.Snterm (Grammar.Entry.obj (ident : 'ident Grammar.Entry.e))],
        Gramext.action
          (fun (i : 'ident) _ (loc : int * int) ->
             (MLast.TyQuo (loc, i) : 'ctyp))]];
      Grammar.Entry.obj
        (constructor_declaration : 'constructor_declaration Grammar.Entry.e),
      None,
      [None, None,
       [[Gramext.Stoken ("UIDENT", "")],
        Gramext.action
          (fun (ci : string) (loc : int * int) ->
             (loc, ci, [] : 'constructor_declaration));
        [Gramext.Stoken ("UIDENT", ""); Gramext.Stoken ("", "of");
         Gramext.Slist1sep
           (Gramext.Snterm (Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e)),
            Gramext.Stoken ("", "and"))],
        Gramext.action
          (fun (cal : 'ctyp list) _ (ci : string) (loc : int * int) ->
             (loc, ci, cal : 'constructor_declaration))]];
      Grammar.Entry.obj
        (label_declaration : 'label_declaration Grammar.Entry.e),
      None,
      [None, None,
       [[Gramext.Stoken ("LIDENT", ""); Gramext.Stoken ("", ":");
         Gramext.Sopt (Gramext.Stoken ("", "mutable"));
         Gramext.Snterm (Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e))],
        Gramext.action
          (fun (t : 'ctyp) (mf : string option) _ (i : string)
             (loc : int * int) ->
             (loc, i, o2b mf, t : 'label_declaration))]];
      Grammar.Entry.obj (ident : 'ident Grammar.Entry.e), None,
      [None, None,
       [[Gramext.Stoken ("UIDENT", "")],
        Gramext.action (fun (i : string) (loc : int * int) -> (i : 'ident));
        [Gramext.Stoken ("LIDENT", "")],
        Gramext.action (fun (i : string) (loc : int * int) -> (i : 'ident))]];
      Grammar.Entry.obj (mod_ident : 'mod_ident Grammar.Entry.e), None,
      [None, Some Gramext.RightA,
       [[Gramext.Stoken ("UIDENT", ""); Gramext.Stoken ("", ".");
         Gramext.Sself],
        Gramext.action
          (fun (j : 'mod_ident) _ (i : string) (loc : int * int) ->
             (i :: j : 'mod_ident));
        [Gramext.Stoken ("LIDENT", "")],
        Gramext.action
          (fun (i : string) (loc : int * int) -> ([i] : 'mod_ident));
        [Gramext.Stoken ("UIDENT", "")],
        Gramext.action
          (fun (i : string) (loc : int * int) -> ([i] : 'mod_ident))]];
      Grammar.Entry.obj (str_item : 'str_item Grammar.Entry.e), None,
      [None, None,
       [[Gramext.Stoken ("", "class"); Gramext.Stoken ("", "type");
         Gramext.Slist1sep
           (Gramext.Snterm
              (Grammar.Entry.obj
                 (class_type_declaration :
                  'class_type_declaration Grammar.Entry.e)),
            Gramext.Stoken ("", "and"))],
        Gramext.action
          (fun (ctd : 'class_type_declaration list) _ _ (loc : int * int) ->
             (MLast.StClt (loc, ctd) : 'str_item));
        [Gramext.Stoken ("", "class");
         Gramext.Slist1sep
           (Gramext.Snterm
              (Grammar.Entry.obj
                 (class_declaration : 'class_declaration Grammar.Entry.e)),
            Gramext.Stoken ("", "and"))],
        Gramext.action
          (fun (cd : 'class_declaration list) _ (loc : int * int) ->
             (MLast.StCls (loc, cd) : 'str_item))]];
      Grammar.Entry.obj (sig_item : 'sig_item Grammar.Entry.e), None,
      [None, None,
       [[Gramext.Stoken ("", "class"); Gramext.Stoken ("", "type");
         Gramext.Slist1sep
           (Gramext.Snterm
              (Grammar.Entry.obj
                 (class_type_declaration :
                  'class_type_declaration Grammar.Entry.e)),
            Gramext.Stoken ("", "and"))],
        Gramext.action
          (fun (ctd : 'class_type_declaration list) _ _ (loc : int * int) ->
             (MLast.SgClt (loc, ctd) : 'sig_item));
        [Gramext.Stoken ("", "class");
         Gramext.Slist1sep
           (Gramext.Snterm
              (Grammar.Entry.obj
                 (class_description : 'class_description Grammar.Entry.e)),
            Gramext.Stoken ("", "and"))],
        Gramext.action
          (fun (cd : 'class_description list) _ (loc : int * int) ->
             (MLast.SgCls (loc, cd) : 'sig_item))]];
      Grammar.Entry.obj
        (class_declaration : 'class_declaration Grammar.Entry.e),
      None,
      [None, None,
       [[Gramext.Sopt (Gramext.Stoken ("", "virtual"));
         Gramext.Stoken ("LIDENT", "");
         Gramext.Snterm
           (Grammar.Entry.obj
              (class_type_parameters :
               'class_type_parameters Grammar.Entry.e));
         Gramext.Snterm
           (Grammar.Entry.obj
              (class_fun_binding : 'class_fun_binding Grammar.Entry.e))],
        Gramext.action
          (fun (cfb : 'class_fun_binding) (ctp : 'class_type_parameters)
             (i : string) (vf : string option) (loc : int * int) ->
             ({MLast.ciLoc = loc; MLast.ciVir = o2b vf; MLast.ciPrm = ctp;
               MLast.ciNam = i; MLast.ciExp = cfb} :
              'class_declaration))]];
      Grammar.Entry.obj
        (class_fun_binding : 'class_fun_binding Grammar.Entry.e),
      None,
      [None, None,
       [[Gramext.Snterm (Grammar.Entry.obj (ipatt : 'ipatt Grammar.Entry.e));
         Gramext.Sself],
        Gramext.action
          (fun (cfb : 'class_fun_binding) (p : 'ipatt) (loc : int * int) ->
             (MLast.CeFun (loc, p, cfb) : 'class_fun_binding));
        [Gramext.Stoken ("", ":");
         Gramext.Snterm
           (Grammar.Entry.obj (class_type : 'class_type Grammar.Entry.e));
         Gramext.Stoken ("", "=");
         Gramext.Snterm
           (Grammar.Entry.obj (class_expr : 'class_expr Grammar.Entry.e))],
        Gramext.action
          (fun (ce : 'class_expr) _ (ct : 'class_type) _ (loc : int * int) ->
             (MLast.CeTyc (loc, ce, ct) : 'class_fun_binding));
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
         Gramext.Slist1sep
           (Gramext.Snterm
              (Grammar.Entry.obj
                 (type_parameter : 'type_parameter Grammar.Entry.e)),
            Gramext.Stoken ("", ","));
         Gramext.Stoken ("", "]")],
        Gramext.action
          (fun _ (tpl : 'type_parameter list) _ (loc : int * int) ->
             (loc, tpl : 'class_type_parameters));
        [],
        Gramext.action
          (fun (loc : int * int) -> (loc, [] : 'class_type_parameters))]];
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
             (MLast.CeFun (loc, p, ce) : 'class_fun_def))]];
      Grammar.Entry.obj (class_expr : 'class_expr Grammar.Entry.e), None,
      [Some "top", None,
       [[Gramext.Stoken ("", "let");
         Gramext.Sopt (Gramext.Stoken ("", "rec"));
         Gramext.Slist1sep
           (Gramext.Snterm
              (Grammar.Entry.obj
                 (let_binding : 'let_binding Grammar.Entry.e)),
            Gramext.Stoken ("", "and"));
         Gramext.Stoken ("", "in"); Gramext.Sself],
        Gramext.action
          (fun (ce : 'class_expr) _ (lb : 'let_binding list)
             (rf : string option) _ (loc : int * int) ->
             (MLast.CeLet (loc, o2b rf, lb, ce) : 'class_expr));
        [Gramext.Stoken ("", "fun");
         Gramext.Snterm (Grammar.Entry.obj (ipatt : 'ipatt Grammar.Entry.e));
         Gramext.Snterm
           (Grammar.Entry.obj
              (class_fun_def : 'class_fun_def Grammar.Entry.e))],
        Gramext.action
          (fun (ce : 'class_fun_def) (p : 'ipatt) _ (loc : int * int) ->
             (MLast.CeFun (loc, p, ce) : 'class_expr))];
       Some "apply", Some Gramext.NonA,
       [[Gramext.Sself;
         Gramext.Snterml
           (Grammar.Entry.obj (expr : 'expr Grammar.Entry.e), "label")],
        Gramext.action
          (fun (e : 'expr) (ce : 'class_expr) (loc : int * int) ->
             (MLast.CeApp (loc, ce, e) : 'class_expr))];
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
             (MLast.CeTyc (loc, ce, ct) : 'class_expr));
        [Gramext.Stoken ("", "object");
         Gramext.Sopt
           (Gramext.Snterm
              (Grammar.Entry.obj
                 (class_self_patt : 'class_self_patt Grammar.Entry.e)));
         Gramext.Snterm
           (Grammar.Entry.obj
              (class_structure : 'class_structure Grammar.Entry.e));
         Gramext.Stoken ("", "end")],
        Gramext.action
          (fun _ (cf : 'class_structure) (cspo : 'class_self_patt option) _
             (loc : int * int) ->
             (MLast.CeStr (loc, cspo, cf) : 'class_expr));
        [Gramext.Snterm
           (Grammar.Entry.obj
              (class_longident : 'class_longident Grammar.Entry.e))],
        Gramext.action
          (fun (ci : 'class_longident) (loc : int * int) ->
             (MLast.CeCon (loc, ci, []) : 'class_expr));
        [Gramext.Snterm
           (Grammar.Entry.obj
              (class_longident : 'class_longident Grammar.Entry.e));
         Gramext.Stoken ("", "[");
         Gramext.Slist0sep
           (Gramext.Snterm (Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e)),
            Gramext.Stoken ("", ","));
         Gramext.Stoken ("", "]")],
        Gramext.action
          (fun _ (ctcl : 'ctyp list) _ (ci : 'class_longident)
             (loc : int * int) ->
             (MLast.CeCon (loc, ci, ctcl) : 'class_expr))]];
      Grammar.Entry.obj (class_structure : 'class_structure Grammar.Entry.e),
      None,
      [None, None,
       [[Gramext.Slist0
           (Gramext.srules
              [[Gramext.Snterm
                  (Grammar.Entry.obj
                     (class_str_item : 'class_str_item Grammar.Entry.e));
                Gramext.Stoken ("", ";")],
               Gramext.action
                 (fun _ (cf : 'class_str_item) (loc : int * int) ->
                    (cf : 'e__6))])],
        Gramext.action
          (fun (cf : 'e__6 list) (loc : int * int) ->
             (cf : 'class_structure))]];
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
             (MLast.PaTyc (loc, p, t) : 'class_self_patt));
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
             (MLast.CrIni (loc, se) : 'class_str_item));
        [Gramext.Stoken ("", "type");
         Gramext.Snterm (Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e));
         Gramext.Stoken ("", "=");
         Gramext.Snterm (Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e))],
        Gramext.action
          (fun (t2 : 'ctyp) _ (t1 : 'ctyp) _ (loc : int * int) ->
             (MLast.CrCtr (loc, t1, t2) : 'class_str_item));
        [Gramext.Stoken ("", "method");
         Gramext.Sopt (Gramext.Stoken ("", "private"));
         Gramext.Snterm (Grammar.Entry.obj (label : 'label Grammar.Entry.e));
         Gramext.Sopt
           (Gramext.Snterm
              (Grammar.Entry.obj (polyt : 'polyt Grammar.Entry.e)));
         Gramext.Snterm
           (Grammar.Entry.obj (fun_binding : 'fun_binding Grammar.Entry.e))],
        Gramext.action
          (fun (e : 'fun_binding) (topt : 'polyt option) (l : 'label)
             (pf : string option) _ (loc : int * int) ->
             (MLast.CrMth (loc, l, o2b pf, e, topt) : 'class_str_item));
        [Gramext.Stoken ("", "method"); Gramext.Stoken ("", "virtual");
         Gramext.Sopt (Gramext.Stoken ("", "private"));
         Gramext.Snterm (Grammar.Entry.obj (label : 'label Grammar.Entry.e));
         Gramext.Stoken ("", ":");
         Gramext.Snterm (Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e))],
        Gramext.action
          (fun (t : 'ctyp) _ (l : 'label) (pf : string option) _ _
             (loc : int * int) ->
             (MLast.CrVir (loc, l, o2b pf, t) : 'class_str_item));
        [Gramext.Stoken ("", "value");
         Gramext.Sopt (Gramext.Stoken ("", "mutable"));
         Gramext.Snterm (Grammar.Entry.obj (label : 'label Grammar.Entry.e));
         Gramext.Snterm
           (Grammar.Entry.obj
              (cvalue_binding : 'cvalue_binding Grammar.Entry.e))],
        Gramext.action
          (fun (e : 'cvalue_binding) (lab : 'label) (mf : string option) _
             (loc : int * int) ->
             (MLast.CrVal (loc, lab, o2b mf, e) : 'class_str_item));
        [Gramext.Stoken ("", "inherit");
         Gramext.Snterm
           (Grammar.Entry.obj (class_expr : 'class_expr Grammar.Entry.e));
         Gramext.Sopt
           (Gramext.Snterm
              (Grammar.Entry.obj (as_lident : 'as_lident Grammar.Entry.e)))],
        Gramext.action
          (fun (pb : 'as_lident option) (ce : 'class_expr) _
             (loc : int * int) ->
             (MLast.CrInh (loc, ce, pb) : 'class_str_item));
        [Gramext.Stoken ("", "declare");
         Gramext.Slist0
           (Gramext.srules
              [[Gramext.Snterm
                  (Grammar.Entry.obj
                     (class_str_item : 'class_str_item Grammar.Entry.e));
                Gramext.Stoken ("", ";")],
               Gramext.action
                 (fun _ (s : 'class_str_item) (loc : int * int) ->
                    (s : 'e__7))]);
         Gramext.Stoken ("", "end")],
        Gramext.action
          (fun _ (st : 'e__7 list) _ (loc : int * int) ->
             (MLast.CrDcl (loc, st) : 'class_str_item))]];
      Grammar.Entry.obj (as_lident : 'as_lident Grammar.Entry.e), None,
      [None, None,
       [[Gramext.Stoken ("", "as"); Gramext.Stoken ("LIDENT", "")],
        Gramext.action
          (fun (i : string) _ (loc : int * int) -> (i : 'as_lident))]];
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
             (MLast.ExCoe (loc, e, None, t) : 'cvalue_binding));
        [Gramext.Stoken ("", ":");
         Gramext.Snterm (Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e));
         Gramext.Stoken ("", ":>");
         Gramext.Snterm (Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e));
         Gramext.Stoken ("", "=");
         Gramext.Snterm (Grammar.Entry.obj (expr : 'expr Grammar.Entry.e))],
        Gramext.action
          (fun (e : 'expr) _ (t2 : 'ctyp) _ (t : 'ctyp) _ (loc : int * int) ->
             (MLast.ExCoe (loc, e, Some t, t2) : 'cvalue_binding));
        [Gramext.Stoken ("", ":");
         Gramext.Snterm (Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e));
         Gramext.Stoken ("", "=");
         Gramext.Snterm (Grammar.Entry.obj (expr : 'expr Grammar.Entry.e))],
        Gramext.action
          (fun (e : 'expr) _ (t : 'ctyp) _ (loc : int * int) ->
             (MLast.ExTyc (loc, e, t) : 'cvalue_binding));
        [Gramext.Stoken ("", "=");
         Gramext.Snterm (Grammar.Entry.obj (expr : 'expr Grammar.Entry.e))],
        Gramext.action
          (fun (e : 'expr) _ (loc : int * int) -> (e : 'cvalue_binding))]];
      Grammar.Entry.obj (label : 'label Grammar.Entry.e), None,
      [None, None,
       [[Gramext.Stoken ("LIDENT", "")],
        Gramext.action (fun (i : string) (loc : int * int) -> (i : 'label))]];
      Grammar.Entry.obj (class_type : 'class_type Grammar.Entry.e), None,
      [None, None,
       [[Gramext.Stoken ("", "object");
         Gramext.Sopt
           (Gramext.Snterm
              (Grammar.Entry.obj
                 (class_self_type : 'class_self_type Grammar.Entry.e)));
         Gramext.Slist0
           (Gramext.srules
              [[Gramext.Snterm
                  (Grammar.Entry.obj
                     (class_sig_item : 'class_sig_item Grammar.Entry.e));
                Gramext.Stoken ("", ";")],
               Gramext.action
                 (fun _ (csf : 'class_sig_item) (loc : int * int) ->
                    (csf : 'e__8))]);
         Gramext.Stoken ("", "end")],
        Gramext.action
          (fun _ (csf : 'e__8 list) (cst : 'class_self_type option) _
             (loc : int * int) ->
             (MLast.CtSig (loc, cst, csf) : 'class_type));
        [Gramext.Snterm
           (Grammar.Entry.obj
              (clty_longident : 'clty_longident Grammar.Entry.e))],
        Gramext.action
          (fun (id : 'clty_longident) (loc : int * int) ->
             (MLast.CtCon (loc, id, []) : 'class_type));
        [Gramext.Snterm
           (Grammar.Entry.obj
              (clty_longident : 'clty_longident Grammar.Entry.e));
         Gramext.Stoken ("", "[");
         Gramext.Slist1sep
           (Gramext.Snterm (Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e)),
            Gramext.Stoken ("", ","));
         Gramext.Stoken ("", "]")],
        Gramext.action
          (fun _ (tl : 'ctyp list) _ (id : 'clty_longident)
             (loc : int * int) ->
             (MLast.CtCon (loc, id, tl) : 'class_type));
        [Gramext.Stoken ("", "[");
         Gramext.Snterm (Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e));
         Gramext.Stoken ("", "]"); Gramext.Stoken ("", "->"); Gramext.Sself],
        Gramext.action
          (fun (ct : 'class_type) _ _ (t : 'ctyp) _ (loc : int * int) ->
             (MLast.CtFun (loc, t, ct) : 'class_type))]];
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
             (MLast.CgCtr (loc, t1, t2) : 'class_sig_item));
        [Gramext.Stoken ("", "method");
         Gramext.Sopt (Gramext.Stoken ("", "private"));
         Gramext.Snterm (Grammar.Entry.obj (label : 'label Grammar.Entry.e));
         Gramext.Stoken ("", ":");
         Gramext.Snterm (Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e))],
        Gramext.action
          (fun (t : 'ctyp) _ (l : 'label) (pf : string option) _
             (loc : int * int) ->
             (MLast.CgMth (loc, l, o2b pf, t) : 'class_sig_item));
        [Gramext.Stoken ("", "method"); Gramext.Stoken ("", "virtual");
         Gramext.Sopt (Gramext.Stoken ("", "private"));
         Gramext.Snterm (Grammar.Entry.obj (label : 'label Grammar.Entry.e));
         Gramext.Stoken ("", ":");
         Gramext.Snterm (Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e))],
        Gramext.action
          (fun (t : 'ctyp) _ (l : 'label) (pf : string option) _ _
             (loc : int * int) ->
             (MLast.CgVir (loc, l, o2b pf, t) : 'class_sig_item));
        [Gramext.Stoken ("", "value");
         Gramext.Sopt (Gramext.Stoken ("", "mutable"));
         Gramext.Snterm (Grammar.Entry.obj (label : 'label Grammar.Entry.e));
         Gramext.Stoken ("", ":");
         Gramext.Snterm (Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e))],
        Gramext.action
          (fun (t : 'ctyp) _ (l : 'label) (mf : string option) _
             (loc : int * int) ->
             (MLast.CgVal (loc, l, o2b mf, t) : 'class_sig_item));
        [Gramext.Stoken ("", "inherit");
         Gramext.Snterm
           (Grammar.Entry.obj (class_type : 'class_type Grammar.Entry.e))],
        Gramext.action
          (fun (cs : 'class_type) _ (loc : int * int) ->
             (MLast.CgInh (loc, cs) : 'class_sig_item));
        [Gramext.Stoken ("", "declare");
         Gramext.Slist0
           (Gramext.srules
              [[Gramext.Snterm
                  (Grammar.Entry.obj
                     (class_sig_item : 'class_sig_item Grammar.Entry.e));
                Gramext.Stoken ("", ";")],
               Gramext.action
                 (fun _ (s : 'class_sig_item) (loc : int * int) ->
                    (s : 'e__9))]);
         Gramext.Stoken ("", "end")],
        Gramext.action
          (fun _ (st : 'e__9 list) _ (loc : int * int) ->
             (MLast.CgDcl (loc, st) : 'class_sig_item))]];
      Grammar.Entry.obj
        (class_description : 'class_description Grammar.Entry.e),
      None,
      [None, None,
       [[Gramext.Sopt (Gramext.Stoken ("", "virtual"));
         Gramext.Stoken ("LIDENT", "");
         Gramext.Snterm
           (Grammar.Entry.obj
              (class_type_parameters :
               'class_type_parameters Grammar.Entry.e));
         Gramext.Stoken ("", ":");
         Gramext.Snterm
           (Grammar.Entry.obj (class_type : 'class_type Grammar.Entry.e))],
        Gramext.action
          (fun (ct : 'class_type) _ (ctp : 'class_type_parameters)
             (n : string) (vf : string option) (loc : int * int) ->
             ({MLast.ciLoc = loc; MLast.ciVir = o2b vf; MLast.ciPrm = ctp;
               MLast.ciNam = n; MLast.ciExp = ct} :
              'class_description))]];
      Grammar.Entry.obj
        (class_type_declaration : 'class_type_declaration Grammar.Entry.e),
      None,
      [None, None,
       [[Gramext.Sopt (Gramext.Stoken ("", "virtual"));
         Gramext.Stoken ("LIDENT", "");
         Gramext.Snterm
           (Grammar.Entry.obj
              (class_type_parameters :
               'class_type_parameters Grammar.Entry.e));
         Gramext.Stoken ("", "=");
         Gramext.Snterm
           (Grammar.Entry.obj (class_type : 'class_type Grammar.Entry.e))],
        Gramext.action
          (fun (cs : 'class_type) _ (ctp : 'class_type_parameters)
             (n : string) (vf : string option) (loc : int * int) ->
             ({MLast.ciLoc = loc; MLast.ciVir = o2b vf; MLast.ciPrm = ctp;
               MLast.ciNam = n; MLast.ciExp = cs} :
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
             (MLast.ExNew (loc, i) : 'expr))]];
      Grammar.Entry.obj (expr : 'expr Grammar.Entry.e),
      Some (Gramext.Level "."),
      [None, None,
       [[Gramext.Sself; Gramext.Stoken ("", "#");
         Gramext.Snterm (Grammar.Entry.obj (label : 'label Grammar.Entry.e))],
        Gramext.action
          (fun (lab : 'label) _ (e : 'expr) (loc : int * int) ->
             (MLast.ExSnd (loc, e, lab) : 'expr))]];
      Grammar.Entry.obj (expr : 'expr Grammar.Entry.e),
      Some (Gramext.Level "simple"),
      [None, None,
       [[Gramext.Stoken ("", "{<");
         Gramext.Slist0sep
           (Gramext.Snterm
              (Grammar.Entry.obj (field_expr : 'field_expr Grammar.Entry.e)),
            Gramext.Stoken ("", ";"));
         Gramext.Stoken ("", ">}")],
        Gramext.action
          (fun _ (fel : 'field_expr list) _ (loc : int * int) ->
             (MLast.ExOvr (loc, fel) : 'expr));
        [Gramext.Stoken ("", "("); Gramext.Sself; Gramext.Stoken ("", ":>");
         Gramext.Snterm (Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e));
         Gramext.Stoken ("", ")")],
        Gramext.action
          (fun _ (t : 'ctyp) _ (e : 'expr) _ (loc : int * int) ->
             (MLast.ExCoe (loc, e, None, t) : 'expr));
        [Gramext.Stoken ("", "("); Gramext.Sself; Gramext.Stoken ("", ":");
         Gramext.Snterm (Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e));
         Gramext.Stoken ("", ":>");
         Gramext.Snterm (Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e));
         Gramext.Stoken ("", ")")],
        Gramext.action
          (fun _ (t2 : 'ctyp) _ (t : 'ctyp) _ (e : 'expr) _
             (loc : int * int) ->
             (MLast.ExCoe (loc, e, Some t, t2) : 'expr))]];
      Grammar.Entry.obj (field_expr : 'field_expr Grammar.Entry.e), None,
      [None, None,
       [[Gramext.Snterm (Grammar.Entry.obj (label : 'label Grammar.Entry.e));
         Gramext.Stoken ("", "=");
         Gramext.Snterm (Grammar.Entry.obj (expr : 'expr Grammar.Entry.e))],
        Gramext.action
          (fun (e : 'expr) _ (l : 'label) (loc : int * int) ->
             (l, e : 'field_expr))]];
      Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e),
      Some (Gramext.Level "simple"),
      [None, None,
       [[Gramext.Stoken ("", "<");
         Gramext.Slist0sep
           (Gramext.Snterm
              (Grammar.Entry.obj (field : 'field Grammar.Entry.e)),
            Gramext.Stoken ("", ";"));
         Gramext.Sopt (Gramext.Stoken ("", "..")); Gramext.Stoken ("", ">")],
        Gramext.action
          (fun _ (v : string option) (ml : 'field list) _ (loc : int * int) ->
             (MLast.TyObj (loc, ml, o2b v) : 'ctyp));
        [Gramext.Stoken ("", "#");
         Gramext.Snterm
           (Grammar.Entry.obj
              (class_longident : 'class_longident Grammar.Entry.e))],
        Gramext.action
          (fun (id : 'class_longident) _ (loc : int * int) ->
             (MLast.TyCls (loc, id) : 'ctyp))]];
      Grammar.Entry.obj (field : 'field Grammar.Entry.e), None,
      [None, None,
       [[Gramext.Stoken ("LIDENT", ""); Gramext.Stoken ("", ":");
         Gramext.Snterm (Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e))],
        Gramext.action
          (fun (t : 'ctyp) _ (lab : string) (loc : int * int) ->
             (lab, t : 'field))]];
      Grammar.Entry.obj (typevar : 'typevar Grammar.Entry.e), None,
      [None, None,
       [[Gramext.Stoken ("", "'");
         Gramext.Snterm (Grammar.Entry.obj (ident : 'ident Grammar.Entry.e))],
        Gramext.action
          (fun (i : 'ident) _ (loc : int * int) -> (i : 'typevar))]];
      Grammar.Entry.obj (clty_longident : 'clty_longident Grammar.Entry.e),
      None,
      [None, None,
       [[Gramext.Stoken ("LIDENT", "")],
        Gramext.action
          (fun (i : string) (loc : int * int) -> ([i] : 'clty_longident));
        [Gramext.Stoken ("UIDENT", ""); Gramext.Stoken ("", ".");
         Gramext.Sself],
        Gramext.action
          (fun (l : 'clty_longident) _ (m : string) (loc : int * int) ->
             (m :: l : 'clty_longident))]];
      Grammar.Entry.obj (class_longident : 'class_longident Grammar.Entry.e),
      None,
      [None, None,
       [[Gramext.Stoken ("LIDENT", "")],
        Gramext.action
          (fun (i : string) (loc : int * int) -> ([i] : 'class_longident));
        [Gramext.Stoken ("UIDENT", ""); Gramext.Stoken ("", ".");
         Gramext.Sself],
        Gramext.action
          (fun (l : 'class_longident) _ (m : string) (loc : int * int) ->
             (m :: l : 'class_longident))]];
      Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e),
      Some (Gramext.After "arrow"),
      [None, Some Gramext.NonA,
       [[Gramext.Stoken ("QUESTIONIDENT", ""); Gramext.Stoken ("", ":");
         Gramext.Sself],
        Gramext.action
          (fun (t : 'ctyp) _ (i : string) (loc : int * int) ->
             (MLast.TyOlb (loc, i, t) : 'ctyp));
        [Gramext.Stoken ("TILDEIDENT", ""); Gramext.Stoken ("", ":");
         Gramext.Sself],
        Gramext.action
          (fun (t : 'ctyp) _ (i : string) (loc : int * int) ->
             (MLast.TyLab (loc, i, t) : 'ctyp))]];
      Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e),
      Some (Gramext.Level "simple"),
      [None, None,
       [[Gramext.Stoken ("", "["); Gramext.Stoken ("", "<");
         Gramext.Snterm
           (Grammar.Entry.obj
              (row_field_list : 'row_field_list Grammar.Entry.e));
         Gramext.Stoken ("", ">");
         Gramext.Slist1
           (Gramext.Snterm
              (Grammar.Entry.obj (name_tag : 'name_tag Grammar.Entry.e)));
         Gramext.Stoken ("", "]")],
        Gramext.action
          (fun _ (ntl : 'name_tag list) _ (rfl : 'row_field_list) _ _
             (loc : int * int) ->
             (MLast.TyVrn (loc, rfl, Some (Some ntl)) : 'ctyp));
        [Gramext.Stoken ("", "["); Gramext.Stoken ("", "<");
         Gramext.Snterm
           (Grammar.Entry.obj
              (row_field_list : 'row_field_list Grammar.Entry.e));
         Gramext.Stoken ("", "]")],
        Gramext.action
          (fun _ (rfl : 'row_field_list) _ _ (loc : int * int) ->
             (MLast.TyVrn (loc, rfl, Some (Some [])) : 'ctyp));
        [Gramext.Stoken ("", "["); Gramext.Stoken ("", ">");
         Gramext.Snterm
           (Grammar.Entry.obj
              (row_field_list : 'row_field_list Grammar.Entry.e));
         Gramext.Stoken ("", "]")],
        Gramext.action
          (fun _ (rfl : 'row_field_list) _ _ (loc : int * int) ->
             (MLast.TyVrn (loc, rfl, Some None) : 'ctyp));
        [Gramext.Stoken ("", "["); Gramext.Stoken ("", "=");
         Gramext.Snterm
           (Grammar.Entry.obj
              (row_field_list : 'row_field_list Grammar.Entry.e));
         Gramext.Stoken ("", "]")],
        Gramext.action
          (fun _ (rfl : 'row_field_list) _ _ (loc : int * int) ->
             (MLast.TyVrn (loc, rfl, None) : 'ctyp))]];
      Grammar.Entry.obj (row_field_list : 'row_field_list Grammar.Entry.e),
      None,
      [None, None,
       [[Gramext.Slist0sep
           (Gramext.Snterm
              (Grammar.Entry.obj (row_field : 'row_field Grammar.Entry.e)),
            Gramext.Stoken ("", "|"))],
        Gramext.action
          (fun (rfl : 'row_field list) (loc : int * int) ->
             (rfl : 'row_field_list))]];
      Grammar.Entry.obj (row_field : 'row_field Grammar.Entry.e), None,
      [None, None,
       [[Gramext.Snterm (Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e))],
        Gramext.action
          (fun (t : 'ctyp) (loc : int * int) -> (MLast.RfInh t : 'row_field));
        [Gramext.Stoken ("", "`");
         Gramext.Snterm (Grammar.Entry.obj (ident : 'ident Grammar.Entry.e));
         Gramext.Stoken ("", "of"); Gramext.Sopt (Gramext.Stoken ("", "&"));
         Gramext.Slist1sep
           (Gramext.Snterm (Grammar.Entry.obj (ctyp : 'ctyp Grammar.Entry.e)),
            Gramext.Stoken ("", "&"))],
        Gramext.action
          (fun (l : 'ctyp list) (ao : string option) _ (i : 'ident) _
             (loc : int * int) ->
             (MLast.RfTag (i, o2b ao, l) : 'row_field));
        [Gramext.Stoken ("", "`");
         Gramext.Snterm (Grammar.Entry.obj (ident : 'ident Grammar.Entry.e))],
        Gramext.action
          (fun (i : 'ident) _ (loc : int * int) ->
             (MLast.RfTag (i, true, []) : 'row_field))]];
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
         Gramext.Sopt
           (Gramext.Snterm
              (Grammar.Entry.obj (eq_expr : 'eq_expr Grammar.Entry.e)));
         Gramext.Stoken ("", ")")],
        Gramext.action
          (fun _ (eo : 'eq_expr option) (p : 'patt_tcon) _ _
             (loc : int * int) ->
             (MLast.PaOlb (loc, "", Some (p, eo)) : 'patt));
        [Gramext.Stoken ("QUESTIONIDENT", "")],
        Gramext.action
          (fun (i : string) (loc : int * int) ->
             (MLast.PaOlb (loc, i, None) : 'patt));
        [Gramext.Stoken ("QUESTIONIDENT", ""); Gramext.Stoken ("", ":");
         Gramext.Stoken ("", "(");
         Gramext.Snterm
           (Grammar.Entry.obj (patt_tcon : 'patt_tcon Grammar.Entry.e));
         Gramext.Sopt
           (Gramext.Snterm
              (Grammar.Entry.obj (eq_expr : 'eq_expr Grammar.Entry.e)));
         Gramext.Stoken ("", ")")],
        Gramext.action
          (fun _ (eo : 'eq_expr option) (p : 'patt_tcon) _ _ (i : string)
             (loc : int * int) ->
             (MLast.PaOlb (loc, i, Some (p, eo)) : 'patt));
        [Gramext.Stoken ("TILDEIDENT", "")],
        Gramext.action
          (fun (i : string) (loc : int * int) ->
             (MLast.PaLab (loc, i, None) : 'patt));
        [Gramext.Stoken ("TILDEIDENT", ""); Gramext.Stoken ("", ":");
         Gramext.Sself],
        Gramext.action
          (fun (p : 'patt) _ (i : string) (loc : int * int) ->
             (MLast.PaLab (loc, i, Some p) : 'patt));
        [Gramext.Stoken ("", "#");
         Gramext.Snterm
           (Grammar.Entry.obj (mod_ident : 'mod_ident Grammar.Entry.e))],
        Gramext.action
          (fun (sl : 'mod_ident) _ (loc : int * int) ->
             (MLast.PaTyp (loc, sl) : 'patt));
        [Gramext.Stoken ("", "`");
         Gramext.Snterm (Grammar.Entry.obj (ident : 'ident Grammar.Entry.e))],
        Gramext.action
          (fun (s : 'ident) _ (loc : int * int) ->
             (MLast.PaVrn (loc, s) : 'patt))]];
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
             (MLast.PaTyc (loc, p, t) : 'patt_tcon))]];
      Grammar.Entry.obj (ipatt : 'ipatt Grammar.Entry.e), None,
      [None, None,
       [[Gramext.Stoken ("", "?"); Gramext.Stoken ("", "(");
         Gramext.Snterm
           (Grammar.Entry.obj (ipatt_tcon : 'ipatt_tcon Grammar.Entry.e));
         Gramext.Sopt
           (Gramext.Snterm
              (Grammar.Entry.obj (eq_expr : 'eq_expr Grammar.Entry.e)));
         Gramext.Stoken ("", ")")],
        Gramext.action
          (fun _ (eo : 'eq_expr option) (p : 'ipatt_tcon) _ _
             (loc : int * int) ->
             (MLast.PaOlb (loc, "", Some (p, eo)) : 'ipatt));
        [Gramext.Stoken ("QUESTIONIDENT", "")],
        Gramext.action
          (fun (i : string) (loc : int * int) ->
             (MLast.PaOlb (loc, i, None) : 'ipatt));
        [Gramext.Stoken ("QUESTIONIDENT", ""); Gramext.Stoken ("", ":");
         Gramext.Stoken ("", "(");
         Gramext.Snterm
           (Grammar.Entry.obj (ipatt_tcon : 'ipatt_tcon Grammar.Entry.e));
         Gramext.Sopt
           (Gramext.Snterm
              (Grammar.Entry.obj (eq_expr : 'eq_expr Grammar.Entry.e)));
         Gramext.Stoken ("", ")")],
        Gramext.action
          (fun _ (eo : 'eq_expr option) (p : 'ipatt_tcon) _ _ (i : string)
             (loc : int * int) ->
             (MLast.PaOlb (loc, i, Some (p, eo)) : 'ipatt));
        [Gramext.Stoken ("TILDEIDENT", "")],
        Gramext.action
          (fun (i : string) (loc : int * int) ->
             (MLast.PaLab (loc, i, None) : 'ipatt));
        [Gramext.Stoken ("TILDEIDENT", ""); Gramext.Stoken ("", ":");
         Gramext.Sself],
        Gramext.action
          (fun (p : 'ipatt) _ (i : string) (loc : int * int) ->
             (MLast.PaLab (loc, i, Some p) : 'ipatt))]];
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
             (MLast.PaTyc (loc, p, t) : 'ipatt_tcon))]];
      Grammar.Entry.obj (eq_expr : 'eq_expr Grammar.Entry.e), None,
      [None, None,
       [[Gramext.Stoken ("", "=");
         Gramext.Snterm (Grammar.Entry.obj (expr : 'expr Grammar.Entry.e))],
        Gramext.action
          (fun (e : 'expr) _ (loc : int * int) -> (e : 'eq_expr))]];
      Grammar.Entry.obj (expr : 'expr Grammar.Entry.e),
      Some (Gramext.After "apply"),
      [Some "label", Some Gramext.NonA,
       [[Gramext.Stoken ("QUESTIONIDENT", "")],
        Gramext.action
          (fun (i : string) (loc : int * int) ->
             (MLast.ExOlb (loc, i, None) : 'expr));
        [Gramext.Stoken ("QUESTIONIDENT", ""); Gramext.Stoken ("", ":");
         Gramext.Sself],
        Gramext.action
          (fun (e : 'expr) _ (i : string) (loc : int * int) ->
             (MLast.ExOlb (loc, i, Some e) : 'expr));
        [Gramext.Stoken ("TILDEIDENT", "")],
        Gramext.action
          (fun (i : string) (loc : int * int) ->
             (MLast.ExLab (loc, i, None) : 'expr));
        [Gramext.Stoken ("TILDEIDENT", ""); Gramext.Stoken ("", ":");
         Gramext.Sself],
        Gramext.action
          (fun (e : 'expr) _ (i : string) (loc : int * int) ->
             (MLast.ExLab (loc, i, Some e) : 'expr))]];
      Grammar.Entry.obj (expr : 'expr Grammar.Entry.e),
      Some (Gramext.Level "simple"),
      [None, None,
       [[Gramext.Stoken ("", "`");
         Gramext.Snterm (Grammar.Entry.obj (ident : 'ident Grammar.Entry.e))],
        Gramext.action
          (fun (s : 'ident) _ (loc : int * int) ->
             (MLast.ExVrn (loc, s) : 'expr))]];
      Grammar.Entry.obj (direction_flag : 'direction_flag Grammar.Entry.e),
      None,
      [None, None,
       [[Gramext.Stoken ("", "downto")],
        Gramext.action (fun _ (loc : int * int) -> (false : 'direction_flag));
        [Gramext.Stoken ("", "to")],
        Gramext.action
          (fun _ (loc : int * int) -> (true : 'direction_flag))]];
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
         Gramext.Slist1
           (Gramext.Snterm
              (Grammar.Entry.obj (name_tag : 'name_tag Grammar.Entry.e)));
         Gramext.Stoken ("", "|]")],
        Gramext.action
          (fun _ (ntl : 'name_tag list) _ (rfl : 'row_field_list) _ _ _
             (loc : int * int) ->
             (MLast.TyVrn (loc, rfl, Some (Some ntl)) : 'ctyp));
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
             (MLast.TyVrn (loc, rfl, Some (Some [])) : 'ctyp));
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
             (MLast.TyVrn (loc, rfl, Some None) : 'ctyp));
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
             (MLast.TyVrn (loc, rfl, None) : 'ctyp))]];
      Grammar.Entry.obj (warning_variant : 'warning_variant Grammar.Entry.e),
      None,
      [None, None,
       [[],
        Gramext.action
          (fun (loc : int * int) -> (warn_variant loc : 'warning_variant))]];
      Grammar.Entry.obj (expr : 'expr Grammar.Entry.e),
      Some (Gramext.Level "top"),
      [None, None,
       [[Gramext.Stoken ("", "while"); Gramext.Sself;
         Gramext.Stoken ("", "do");
         Gramext.Slist0
           (Gramext.srules
              [[Gramext.Snterm
                  (Grammar.Entry.obj (expr : 'expr Grammar.Entry.e));
                Gramext.Stoken ("", ";")],
               Gramext.action
                 (fun _ (e : 'expr) (loc : int * int) -> (e : 'e__12))]);
         Gramext.Snterm
           (Grammar.Entry.obj
              (warning_sequence : 'warning_sequence Grammar.Entry.e));
         Gramext.Stoken ("", "done")],
        Gramext.action
          (fun _ _ (seq : 'e__12 list) _ (e : 'expr) _ (loc : int * int) ->
             (MLast.ExWhi (loc, e, seq) : 'expr));
        [Gramext.Stoken ("", "for"); Gramext.Stoken ("LIDENT", "");
         Gramext.Stoken ("", "="); Gramext.Sself;
         Gramext.Snterm
           (Grammar.Entry.obj
              (direction_flag : 'direction_flag Grammar.Entry.e));
         Gramext.Sself; Gramext.Stoken ("", "do");
         Gramext.Slist0
           (Gramext.srules
              [[Gramext.Snterm
                  (Grammar.Entry.obj (expr : 'expr Grammar.Entry.e));
                Gramext.Stoken ("", ";")],
               Gramext.action
                 (fun _ (e : 'expr) (loc : int * int) -> (e : 'e__11))]);
         Gramext.Snterm
           (Grammar.Entry.obj
              (warning_sequence : 'warning_sequence Grammar.Entry.e));
         Gramext.Stoken ("", "done")],
        Gramext.action
          (fun _ _ (seq : 'e__11 list) _ (e2 : 'expr) (df : 'direction_flag)
             (e1 : 'expr) _ (i : string) _ (loc : int * int) ->
             (MLast.ExFor (loc, i, e1, e2, df, seq) : 'expr));
        [Gramext.Stoken ("", "do");
         Gramext.Slist0
           (Gramext.srules
              [[Gramext.Snterm
                  (Grammar.Entry.obj (expr : 'expr Grammar.Entry.e));
                Gramext.Stoken ("", ";")],
               Gramext.action
                 (fun _ (e : 'expr) (loc : int * int) -> (e : 'e__10))]);
         Gramext.Stoken ("", "return");
         Gramext.Snterm
           (Grammar.Entry.obj
              (warning_sequence : 'warning_sequence Grammar.Entry.e));
         Gramext.Sself],
        Gramext.action
          (fun (e : 'expr) _ _ (seq : 'e__10 list) _ (loc : int * int) ->
             (MLast.ExSeq (loc, append_elem seq e) : 'expr))]];
      Grammar.Entry.obj
        (warning_sequence : 'warning_sequence Grammar.Entry.e),
      None,
      [None, None,
       [[],
        Gramext.action
          (fun (loc : int * int) ->
             (warn_sequence loc : 'warning_sequence))]]])

let _ =
  Grammar.extend
    (let _ = (interf : 'interf Grammar.Entry.e)
     and _ = (implem : 'implem Grammar.Entry.e)
     and _ = (use_file : 'use_file Grammar.Entry.e)
     and _ = (top_phrase : 'top_phrase Grammar.Entry.e)
     and _ = (expr : 'expr Grammar.Entry.e)
     and _ = (patt : 'patt Grammar.Entry.e) in
     let grammar_entry_create s =
       Grammar.Entry.create (Grammar.of_entry interf) s
     in
     let sig_item_semi : 'sig_item_semi Grammar.Entry.e =
       grammar_entry_create "sig_item_semi"
     and str_item_semi : 'str_item_semi Grammar.Entry.e =
       grammar_entry_create "str_item_semi"
     and phrase : 'phrase Grammar.Entry.e = grammar_entry_create "phrase" in
     [Grammar.Entry.obj (interf : 'interf Grammar.Entry.e), None,
      [None, None,
       [[Gramext.Stoken ("EOI", "")],
        Gramext.action (fun _ (loc : int * int) -> ([], false : 'interf));
        [Gramext.Snterm
           (Grammar.Entry.obj
              (sig_item_semi : 'sig_item_semi Grammar.Entry.e));
         Gramext.Sself],
        Gramext.action
          (fun (sil, stopped : 'interf) (si : 'sig_item_semi)
             (loc : int * int) ->
             (si :: sil, stopped : 'interf));
        [Gramext.Stoken ("", "#"); Gramext.Stoken ("LIDENT", "");
         Gramext.Sopt
           (Gramext.Snterm
              (Grammar.Entry.obj (expr : 'expr Grammar.Entry.e)));
         Gramext.Stoken ("", ";")],
        Gramext.action
          (fun _ (dp : 'expr option) (n : string) _ (loc : int * int) ->
             ([MLast.SgDir (loc, n, dp), loc], true : 'interf))]];
      Grammar.Entry.obj (sig_item_semi : 'sig_item_semi Grammar.Entry.e),
      None,
      [None, None,
       [[Gramext.Snterm
           (Grammar.Entry.obj (sig_item : 'sig_item Grammar.Entry.e));
         Gramext.Stoken ("", ";")],
        Gramext.action
          (fun _ (si : 'sig_item) (loc : int * int) ->
             (si, loc : 'sig_item_semi))]];
      Grammar.Entry.obj (implem : 'implem Grammar.Entry.e), None,
      [None, None,
       [[Gramext.Stoken ("EOI", "")],
        Gramext.action (fun _ (loc : int * int) -> ([], false : 'implem));
        [Gramext.Snterm
           (Grammar.Entry.obj
              (str_item_semi : 'str_item_semi Grammar.Entry.e));
         Gramext.Sself],
        Gramext.action
          (fun (sil, stopped : 'implem) (si : 'str_item_semi)
             (loc : int * int) ->
             (si :: sil, stopped : 'implem));
        [Gramext.Stoken ("", "#"); Gramext.Stoken ("LIDENT", "");
         Gramext.Sopt
           (Gramext.Snterm
              (Grammar.Entry.obj (expr : 'expr Grammar.Entry.e)));
         Gramext.Stoken ("", ";")],
        Gramext.action
          (fun _ (dp : 'expr option) (n : string) _ (loc : int * int) ->
             ([MLast.StDir (loc, n, dp), loc], true : 'implem))]];
      Grammar.Entry.obj (str_item_semi : 'str_item_semi Grammar.Entry.e),
      None,
      [None, None,
       [[Gramext.Snterm
           (Grammar.Entry.obj (str_item : 'str_item Grammar.Entry.e));
         Gramext.Stoken ("", ";")],
        Gramext.action
          (fun _ (si : 'str_item) (loc : int * int) ->
             (si, loc : 'str_item_semi))]];
      Grammar.Entry.obj (top_phrase : 'top_phrase Grammar.Entry.e), None,
      [None, None,
       [[Gramext.Stoken ("EOI", "")],
        Gramext.action (fun _ (loc : int * int) -> (None : 'top_phrase));
        [Gramext.Snterm
           (Grammar.Entry.obj (phrase : 'phrase Grammar.Entry.e))],
        Gramext.action
          (fun (ph : 'phrase) (loc : int * int) -> (Some ph : 'top_phrase))]];
      Grammar.Entry.obj (use_file : 'use_file Grammar.Entry.e), None,
      [None, None,
       [[Gramext.Stoken ("EOI", "")],
        Gramext.action (fun _ (loc : int * int) -> ([], false : 'use_file));
        [Gramext.Snterm
           (Grammar.Entry.obj (str_item : 'str_item Grammar.Entry.e));
         Gramext.Stoken ("", ";"); Gramext.Sself],
        Gramext.action
          (fun (sil, stopped : 'use_file) _ (si : 'str_item)
             (loc : int * int) ->
             (si :: sil, stopped : 'use_file));
        [Gramext.Stoken ("", "#"); Gramext.Stoken ("LIDENT", "");
         Gramext.Sopt
           (Gramext.Snterm
              (Grammar.Entry.obj (expr : 'expr Grammar.Entry.e)));
         Gramext.Stoken ("", ";")],
        Gramext.action
          (fun _ (dp : 'expr option) (n : string) _ (loc : int * int) ->
             ([MLast.StDir (loc, n, dp)], true : 'use_file))]];
      Grammar.Entry.obj (phrase : 'phrase Grammar.Entry.e), None,
      [None, None,
       [[Gramext.Snterm
           (Grammar.Entry.obj (str_item : 'str_item Grammar.Entry.e));
         Gramext.Stoken ("", ";")],
        Gramext.action
          (fun _ (sti : 'str_item) (loc : int * int) -> (sti : 'phrase));
        [Gramext.Stoken ("", "#"); Gramext.Stoken ("LIDENT", "");
         Gramext.Sopt
           (Gramext.Snterm
              (Grammar.Entry.obj (expr : 'expr Grammar.Entry.e)));
         Gramext.Stoken ("", ";")],
        Gramext.action
          (fun _ (dp : 'expr option) (n : string) _ (loc : int * int) ->
             (MLast.StDir (loc, n, dp) : 'phrase))]];
      Grammar.Entry.obj (expr : 'expr Grammar.Entry.e),
      Some (Gramext.Level "simple"),
      [None, None,
       [[Gramext.Stoken ("QUOTATION", "")],
        Gramext.action
          (fun (x : string) (loc : int * int) ->
             (let x =
                try
                  let i = String.index x ':' in
                  String.sub x 0 i,
                  String.sub x (i + 1) (String.length x - i - 1)
                with
                  Not_found -> "", x
              in
              Pcaml.handle_expr_quotation loc x :
              'expr));
        [Gramext.Stoken ("LOCATE", "")],
        Gramext.action
          (fun (x : string) (loc : int * int) ->
             (let x =
                try
                  let i = String.index x ':' in
                  int_of_string (String.sub x 0 i),
                  String.sub x (i + 1) (String.length x - i - 1)
                with
                  Not_found | Failure _ -> 0, x
              in
              Pcaml.handle_expr_locate loc x :
              'expr))]];
      Grammar.Entry.obj (patt : 'patt Grammar.Entry.e),
      Some (Gramext.Level "simple"),
      [None, None,
       [[Gramext.Stoken ("QUOTATION", "")],
        Gramext.action
          (fun (x : string) (loc : int * int) ->
             (let x =
                try
                  let i = String.index x ':' in
                  String.sub x 0 i,
                  String.sub x (i + 1) (String.length x - i - 1)
                with
                  Not_found -> "", x
              in
              Pcaml.handle_patt_quotation loc x :
              'patt));
        [Gramext.Stoken ("LOCATE", "")],
        Gramext.action
          (fun (x : string) (loc : int * int) ->
             (let x =
                try
                  let i = String.index x ':' in
                  int_of_string (String.sub x 0 i),
                  String.sub x (i + 1) (String.length x - i - 1)
                with
                  Not_found | Failure _ -> 0, x
              in
              Pcaml.handle_patt_locate loc x :
              'patt))]]])

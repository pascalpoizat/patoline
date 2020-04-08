(*
  Copyright Florian Hatat, Tom Hirschowitz, Pierre Hyvernat,
  Pierre-Etienne Meunier, Christophe Raffalli, Guillaume Theyssier 2012.

  This file is part of Patoline.

  Patoline is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  Patoline is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with Patoline.  If not, see <http://www.gnu.org/licenses/>.
*)

open Typography
open Typography.Document
open Patfonts
open FTypes
open Patutil
open Extra
open Fonts
open Box
open PatConfig
open Patoraw

let _=Random.self_init ()

module Euler = Euler
module Numerals = Numerals
module TOC = TableOfContents

let findFont = ConfigFindFont.findFont

let sprint_page_number = ref string_of_int
let page_number_vpos   = ref 30.0
let max_iterations     = ref patoConfig.max_iter
let quiet = ref false

let spec =
  [ ( "--extra-fonts-dir"  , Arg.String add_fonts_dir
    , "Adds directories to the font search path")
  ; ( "--extra-hyph-dir"   , Arg.String add_hyphen_dir
    , "Adds directories to the search path for hyphenation dictionaries")
  ; ( "--quiet"            , Arg.Set quiet
    , "Turn off compilation messages")
  ;

("--at-most",Arg.Int (fun x->max_iterations:=x),
 "Compile at most n times");
("--in",Arg.String (fun x->Driver.input_bin := Some x),
 "input a .bin file instead of generating pages");
("--driver",Arg.String (fun x->Driver.driver := Some x),
 "specify a driver to dynlink");
]

module type Output=
  sig
    type output
    val outputParams : output

    val output :
      output ->
      Typography.Document.tree ->
      Typography.Document.environment -> string -> unit
  end

module Format=functor (D:Document.DocumentStructure)->(
  struct

let hyphenate_dict dict = (* Should probably move to Hyphen *)
  try
    let ic = open_in_bin (findHyphen dict) in
    let inp = input_value ic in
    close_in ic;
    (fun str-> Array.of_list (Hyphen.hyphenate inp str))
  with Not_found ->
          Printf.eprintf "Warning: hyphenation dictionary %s not found...\n" dict;
    (fun _ -> [||])



let alegreya=
  [ Regular,
    (Lazy.from_fun
       (fun ()->
          (Fonts.loadFont
            (findFont FontPattern.({family="Alegreya"; slant=Roman; weight=Regular}))
          ),
          (fun x->List.fold_left (fun a f->f a) x
             [make_ligature [168;175] {glyph_utf8="fi";glyph_index=245};
              make_ligature [168;181] {glyph_utf8="fl";glyph_index=246};
              make_ligature [168;177] {glyph_utf8="fj";glyph_index=383};
              make_ligature [175;177] {glyph_utf8="ij";glyph_index=176};
             ]),
          (fun x->x)),
     Lazy.from_fun
       (fun ()->
          (Fonts.loadFont
            (findFont FontPattern.({family="Alegreya"; slant=Italic; weight=Regular}))
          ),
          (fun x->List.fold_left (fun a f->f a) x
             [make_ligature [162;170] {glyph_utf8="fi";glyph_index=477};
              make_ligature [162;175] {glyph_utf8="fl";glyph_index=478};
              make_ligature [162;171] {glyph_utf8="fj";glyph_index=482};
              make_ligature [170;171] {glyph_utf8="ij";glyph_index=476};
             ]),
          (fun x->x)));
    Bold,
    (Lazy.from_fun
       (fun ()->
          (Fonts.loadFont
            (findFont FontPattern.({family="Alegreya"; slant=Roman; weight=Bold}))
          ),
          (fun x->List.fold_left (fun a f->f a) x
             [make_ligature [168;175] {glyph_utf8="fi";glyph_index=245};
              make_ligature [168;181] {glyph_utf8="fl";glyph_index=246};
              make_ligature [168;177] {glyph_utf8="fj";glyph_index=383};
              make_ligature [175;177] {glyph_utf8="ij";glyph_index=176};
             ]),
          (fun x->x)),
     Lazy.from_fun
       (fun ()->
          (Fonts.loadFont
            (findFont FontPattern.({family="Alegreya"; slant=Italic; weight=Bold}))
          ),
          (fun x->List.fold_left (fun a f->f a) x
             [make_ligature [162;170] {glyph_utf8="fi";glyph_index=477};
              make_ligature [162;175] {glyph_utf8="fl";glyph_index=478};
              make_ligature [162;171] {glyph_utf8="fj";glyph_index=482};
              make_ligature [170;171] {glyph_utf8="ij";glyph_index=476};
             ]),
          (fun x->x)));

    Caps,
    (
      simpleFamilyMember (fun ()->Fonts.loadFont (findFont
            FontPattern.({family="Alegreya SC"; slant=Roman; weight=Regular})
      )),
      simpleFamilyMember (fun ()->Fonts.loadFont (findFont
            FontPattern.({family="Alegreya SC"; slant=Italic; weight=Regular})
      ))
    );
  ]

let simpleFont name = [
  Regular,
  (
    simpleFamilyMember (fun ()->Fonts.loadFont (findFont
          FontPattern.({family=name; slant=Roman; weight=Regular})
    )),
    simpleFamilyMember (fun ()->Fonts.loadFont (findFont
          FontPattern.({family=name; slant=Italic; weight=Regular})
    ))
  );

  Bold,
  (
    simpleFamilyMember (fun ()->Fonts.loadFont (findFont
          FontPattern.({family=name; slant=Roman; weight=Bold})
    )),
    simpleFamilyMember (fun ()->Fonts.loadFont (findFont
          FontPattern.({family=name; slant=Italic; weight=Bold})
    ))
  );
]

let philosopher=simpleFont "Philosopher"
let dejaVuSerif=simpleFont "DejaVu Serif"
let dejaVuSans=simpleFont "DejaVu Sans"
let dejaVuSansMono=simpleFont "DejaVu Sans Mono"
let dejaVuSerifCondensed=simpleFont "DejaVu Serif Condensed"
let dejaVuSansCondensed=simpleFont "DejaVu Sans Condensed"
let texgyrecursor=simpleFont "TeX Gyre Cursor"
let bitstreamverasansmono=simpleFont "Bitstream Vera Sans Mono"
let freeSerif=simpleFont "Free Serif"
let freeSans=simpleFont "Free Sans"
let freeMono=simpleFont "Free Mono"


let all_fonts = [alegreya; texgyrecursor] (* trick to force same type *)

let break ()=
  [bB (fun env->[Glue { empty_drawing_box with drawing_min_width=0.;drawing_max_width=env.normalMeasure;drawing_nominal_width=0. };
                 Glue { empty_drawing_box with
                   drawing_min_width=0.;drawing_nominal_width=0.;drawing_max_width=0.;
                   drawing_badness=(fun _->infinity) }])]


let node ?(node_env=(fun env->env)) l=
  Document.Node
    {Document.empty with
      Document.node_env=node_env;
      Document.children=List.fold_left
        (fun m (l,_)->IntMap.add (IntMap.cardinal m) l m) IntMap.empty l},
  []
let paragraph ?(parameters=parameters) ?(par_env=(fun x->x)) cont=
  (Paragraph {par_contents=cont; par_env=par_env;
              par_post_env=(fun env1 env2 -> { env1 with names=env2.names;
                counters=env2.counters;
                user_positions=env2.user_positions });
              par_badness=(badness);
              par_parameters=parameters; par_completeLine=Complete.normal;
              par_states=[];
              par_paragraph=(-1)}, [])

let stackDrawings drs=
  let w=List.fold_left (fun m x->max m x.drawing_nominal_width) 0. drs in
  let cont,_=List.fold_left (fun (cont,y) x->
    (List.map (RawContent.translate ((w-.x.drawing_nominal_width)/.2.) (y-.x.drawing_y0)) (x.drawing_contents x.drawing_nominal_width)
     @cont,
     y+.max 0. (x.drawing_y1-.x.drawing_y0))
  ) ([],0.) drs
  in
  Drawing (drawing cont)

let stackCont drs=
  bB (fun env->[stackDrawings (List.map (fun x->drawing (draw env x)) drs)])

let defaultEnv:environment=
  let f,subst,pos=selectFont alegreya Regular false in
  let fsize=3.7 in
  let feat= [ Opentype.standardLigatures ] in
  let loaded_feat=Fonts.select_features f [ Opentype.standardLigatures ] in
  {
    fontFamily=alegreya;
    fontMonoFamily=bitstreamverasansmono (*texgyrecursor*);
    fontMonoRatio=font_size_ratio alegreya bitstreamverasansmono (*texgyrecursor*);
    fontItalic=false;
    fontAlternative=Regular;
    fontFeatures=feat;
    fontColor=Color.black;
    font=f;
    mathsEnvironment=Euler.default;
    mathStyle=Document.Mathematical.Text;
    substitutions=(fun glyphs->Fonts.apply_features f loaded_feat (subst glyphs));
    positioning=(fun x->pos (positioning f x));
    footnote_y=10.;
    size=fsize;
    lead=13./.10.*.fsize;
    normalMeasure=(fst Util.a4)*.2./.3.;
    normalLead=13./.10.*.fsize;
    normalLeftMargin=0.;
    normalPageFormat=Util.a4;
    par_indent = [Drawing { drawing_min_width= 4.0 *. phi;
                            drawing_max_width= 4.0 *. phi;
                            drawing_width_fixed = true;
                            drawing_adjust_before = false;
                            drawing_y0=0.;drawing_y1=0.;
                            drawing_nominal_width= 4.0 *. phi;
                            drawing_contents=(fun _->[]);
                            drawing_break_badness=0.;
                            drawing_states=[];
                            drawing_badness=fun _-> 0. }];
    hyphenate=hyphenate_dict "hyph-en-us.hdict";
    counters=StrMap.empty;
    last_changed_counter="";
    names=StrMap.empty;
    fixable=ref false;
    user_positions=MarkerMap.empty;
    new_page=PageLayout.default_new_page;
    new_line=(fun env node params nextNode nextParams layout height->
      if node==nextNode && node.layout==layout then (
        let min_height=min height (node.height-.params.min_height_after) in
        let h0=min_height/.env.lead in
        let h1=if (ceil h0-.h0)<=1e-10 then ceil h0 else floor h0 in
        let next_height=env.lead*.h1 in
        let hh=if next_height>=height then next_height-.env.lead else next_height in
              (* Printf.fprintf stderr "cas 1 %f\n" hh;flush stderr; *)
        hh
      ) else
        let d=if node.layout=layout then (
          let min_height=min (nextNode.height-.env.lead) (node.height -. max params.min_height_after nextParams.min_height_before) in
          let h0=min_height/.env.lead in
          let h1=if (ceil h0-.h0)<=1e-10 then ceil h0 else floor h0 in
                (* Printf.fprintf stderr "cas 2.1 %f %f %f \n" min_height h0 h1;flush stderr; *)
          env.lead*.h1
        ) else (
          let min_height=(height-. env.lead) in
          let h0=(floor (min_height/.env.lead)) in
          let h1=if (ceil h0-.h0)<=1e-10 then ceil h0 else floor h0 in
                (* Printf.fprintf stderr "cas 2.2 %f %f %f %f\n" l min_height h0 h1;flush stderr; *)
          env.lead*.h1
        )
        in
        d
    );
    show_boxes=false;
    show_frames=false;
    adjust_optical_alpha=3.1416 /. 4.;
    adjust_optical_beta=0.2; (* kerning between math and text while spacing between word is not kerned requires a small beta *)
    adjust_epsilon=5e-2;
    adjust_min_space=1./.9.;
    math_break_badness = 250.0; (* testé juste sur tests/test_break_badness *)
    stdGlue = (2./.9., 1./.3.,1./.2.);
  }

    let sourcePosition(file,line,column,char) =
      [tT (Printf.sprintf "%s: %d,%d (%d)" file line column char)]

    let parameters=parameters
    let center = do_center parameters
    let ragged_right = do_ragged_right parameters
    let ragged_left = do_ragged_left parameters

    let postprocess_tree tree=
      let has_institute=ref false in
      let has_author=ref false in
      let with_institute=match tree with
          Node n when not (List.mem_assoc "title already typset" n.node_tags)->(try
                     let cont=[tT (List.assoc "Institute" n.node_tags)] in
                     let par=Paragraph {
                       par_contents=cont;
                       par_env=(fun env->{env with par_indent=[]});
                       par_post_env=(fun env1 env2 -> { env1 with names=names env2; counters=env2.counters;
                         user_positions=user_positions env2 });
                       par_parameters=
                         (fun a b c d e f g line->
                           { (center a b c d e f g line) with
                             min_lines_after=if line.lineEnd>=Array.length b.(line.paragraph) then
                                 1 else 0;
                             min_lines_before=if g.lineEnd>=Array.length b.(g.paragraph) then
                                 1 else 0
                           });
                       par_badness=(badness);
                       par_completeLine=Complete.normal;
                       par_states=[];
                       par_paragraph=(-1) }
                     in
                     has_institute:=true;
                     fst (up (newChildBefore (tree,[]) par))
            with
                Not_found->tree)
        | _->tree
      in

      let with_author=match with_institute with
          Node n when not (List.mem_assoc "title already typset" n.node_tags)->(try
                     let cont=[tT (List.assoc "Author" n.node_tags)] in
                     let par=Paragraph {
                       par_contents=cont;
                       par_env=(fun env->{env with par_indent=[]});
                       par_post_env=(fun env1 env2 -> { env1 with names=names env2; counters=env2.counters;
                         user_positions=user_positions env2 });
                       par_parameters=
                         (fun a b c d e f g line->
                           { (center a b c d e f g line) with
                             min_lines_after=
                               if line.lineEnd>=Array.length b.(line.paragraph)then
                                 if !has_institute then
                                   2
                                 else
                                   4
                               else 1;
                             min_height_before=if line.lineEnd>=Array.length b.(line.paragraph) then
                                 2.*.a.normalLead else 0.
                           });
                       par_badness=(badness);
                       par_completeLine=Complete.normal;
                       par_states=[];
                       par_paragraph=(-1) }
                     in
                     has_author:=true;
                     fst (up (newChildBefore (with_institute,[]) par))
            with
                Not_found->with_institute)
        | _->with_institute
      in

      let with_title=match tree with
          Node n when not (List.mem_assoc "title already typeset" n.node_tags)
              && n.displayname<>[]->
            let par=Paragraph {
              par_contents=n.displayname;
              par_env=(fun env-> envScale 2. {env with par_indent=[]; hyphenate=(fun _->[||])});
              par_post_env=(fun env1 env2 -> { env1 with names=names env2; counters=env2.counters;
                user_positions=user_positions env2 });
              par_parameters=
                (fun a b c d e f g line->
                  { (center a b c d e f g line) with
                    min_lines_after=
                      if n.displayname<>[] && line.lineEnd>=Array.length b.(line.paragraph) then
                        if !has_author || !has_institute then
                          3
                        else
                          6
                      else 1;
                    min_height_before=0. });
              par_badness=(badness);
              par_completeLine=Complete.normal;
              par_states=[];
              par_paragraph=(-1)}
            in
            fst (up (newChildBefore (with_author,[]) par))
        | _->with_author
      in

      let rec sectionize path numbered=function
          Node n when List.mem_assoc "structural" n.node_tags ->
          let numbered'=numbered && List.mem_assoc "numbered" n.node_tags in
          let section_name=
            if numbered' then
              [C (fun env->
                  let _,b=try StrMap.find "_structure" env.counters with Not_found -> -1,[0] in
                  bB (fun _->[Marker (Structure path)])
                  ::tT (String.concat "." (List.map (fun x->string_of_int (x+1)) (List.rev (List.drop 1 b))))
                  ::tT " "
                  ::n.displayname
                 )]
            else
              [C (fun _ -> bB (fun _ -> [Marker (Structure path)]) :: n.displayname)]
          in
          let par=Paragraph {
                      par_contents=section_name;
                      par_env=(fun env->
                               let _,b=try StrMap.find "_structure" env.counters with Not_found -> -1,[0] in
                               { (envAlternative ~features:(Opentype.oldStyleFigures::env.fontFeatures) Caps env) with
                                 size=(if List.length b <= 2 then sqrt phi else
                                         sqrt (sqrt phi))*.env.size;
                                 par_indent = []
                               });
                      par_post_env=(fun env1 env2 -> { env1 with names=names env2; counters=env2.counters;
                                                                 user_positions=user_positions env2 });
                      par_parameters=
                        (fun a b c d e f g line->
                         { (parameters a b c d e f g line) with
                           min_height_before=if line.lineStart=0 then a.normalLead else 0.;
                           min_height_after=if line.lineEnd>=Array.length b.(line.paragraph) then a.normalLead else 0.;
                           not_last_line=true });
                      par_badness=(badness);
                      par_completeLine=Complete.normal;
                      par_states=[];
                      par_paragraph=(-1) }
          in
          fst (up (newChildBefore (
                       Node { n with children=IntMap.mapi (fun k a->sectionize (k::path) numbered' a)
                                                          n.children }, []) par
                  ))
        | Node n->
           Node { n with children=IntMap.map (sectionize path numbered) n.children }
        | a->a
      in
      let with_chapters=match with_title with
          Node n->Node { n with children=IntMap.map (sectionize [] true) n.children }
        | _->with_title
      in
      with_chapters




    let defaultEnv=defaultEnv

    let title str ?label:_ ?(extra_tags=[]) displayname =
      let displayname = [C (fun _ -> env_accessed := true; displayname)] in
      try
        let name = string_of_contents displayname in
        let t0',path=
          match top !str with
            Node n,path ->
              if List.mem_assoc "maintitle" n.node_tags then
                raise Exit;
              Node { n with
                name=name;
                node_tags=("maintitle","")::("structural","")::("intoc","")::extra_tags@n.node_tags;
                displayname = displayname},path
          | t,path->
            Node { empty with
              name=name;
              node_tags=["structural","";"intoc",""];
              displayname=displayname;
              children=IntMap.singleton 1 t;
              node_env=(fun x->x);
              node_post_env=(fun x y->{ x with names=y.names; counters=y.counters;
                user_positions=y.user_positions });
              node_states=[]
            },path
        in
        str:=follow (t0',[]) (List.map fst (List.rev path)); true
      with Exit -> D.structure := newStruct !D.structure displayname; false

    module TableOfContents=struct
      let do_begin_env ()=
        let max_depth=2 in
        TableOfContents.these center D.structure D.structure max_depth
      let do_end_env ()=()
    end

    let glue_space n =
      bB(fun env ->
        let font,_,_=selectFont env.fontFamily Regular false in
        let x= Fonts.loadGlyph font
          ({empty_glyph with glyph_index=Fonts.glyph_of_char font ' '})
        in
        let w =  float n *. env.size *. Fonts.glyphWidth x /.1000. in
        [glue w w w])

    (* New parser version of verbatim environment. *)
    let verbs_default fn lines =
      let open Verbatim in
      lines_to_file lines fn;
      let build_line = handle_spaces param_Default (fun s -> [tT s]) in
      line_per_line D.structure build_line lines

    let verbs_Lang param fn lines =
      let open Verbatim in
      lines_to_file lines fn;
      let build_line = handle_spaces param (handle_word param) in
      line_per_line D.structure build_line lines

    let verbs_OCaml  = verbs_Lang Verbatim.param_OCaml
    let verbs_SML    = verbs_Lang Verbatim.param_SML
    let verbs_PML    = verbs_Lang Verbatim.param_PML
    let verbs_Python = verbs_Lang Verbatim.param_Python

    let verbatim    = Verbatim.verb_text (fun s -> [tT s])

    let verb_OCaml  = Verbatim.(verb_text (line_to_contents param_OCaml))
    let verb_SML    = Verbatim.(verb_text (line_to_contents param_SML))
    let verb_PML    = Verbatim.(verb_text (line_to_contents param_PML))
    let verb_Python = Verbatim.(verb_text (line_to_contents param_Python))

    let env_stack=ref []

    module Env_minipage=struct
      let do_begin_env () =
        D.structure:=newChildAfter !D.structure (Node empty);
        env_stack:=(List.map fst (snd !D.structure)) :: !env_stack


      let do_end_env ()=
        D.structure:=follow (top !D.structure) (List.rev (List.hd !env_stack));
        env_stack:=List.tl !env_stack;

        let t,num=match !D.structure with
            t,(h,_)::_->t,h
          | t,[]->t,0
        in
        (match up !D.structure with
            Node n,x->
              D.structure:=(Node { n with children=IntMap.remove num n.children },x);
          | x->D.structure:=x);
        let cont=OutputDrawing.minipage (t,[]) in
        match lastChild !D.structure with
            Paragraph x,y->
              D.structure:=up (Paragraph {x with par_contents=x.par_contents@cont},y);
          | _->(
            D.structure := newPar !D.structure Complete.normal parameters cont;
            (* D.structure:=lastChild !D.structure *)
          )

    end

let animation ?(step=1./.24.) ?(duration=600.) ?(mirror=true) ?(default=0) cycle contents =
  [bB (fun env -> let contents a = draw env (contents a) in
  let tbl = Array.init cycle contents in
  let d = default in
  let r = RawContent.(Animation{
    anim_contents = tbl;
    anim_step = step;
    anim_duration = duration;
    anim_default = d;
    anim_order = Array.fold_left (fun acc c ->
                     List.fold_left (fun acc c -> min acc (drawing_order c))
                                    acc c) max_int tbl;
    anim_mirror = mirror})
  in
  let (x0,y0,x1,y1)=RawContent.bounding_box [r] in
  let w = x1 -. x0 in
  [Drawing {
    drawing_min_width=w;
    drawing_max_width=w;
    drawing_nominal_width=w;
    drawing_width_fixed = true;
    drawing_adjust_before = false;
    drawing_y0=y0;
    drawing_y1=y1;
    drawing_states=[];
    drawing_break_badness=0.;
    drawing_badness=(fun _->0.);
    drawing_contents=(fun _->[r])
  }])]

let dynname =
  let c = ref 0 in
  (fun () -> let x = !c in c := x + 1; "dynamic_" ^ string_of_int x)

let dynamic sample contents =
  let name = dynname () in
  RawContent.([bB (fun env ->
    let contents () = draw env (contents ()) in
    let r = Dynamic{
      dyn_label = name;
      dyn_contents = contents;
      dyn_order = List.fold_left (fun acc c -> min acc (drawing_order c))
                                 max_int (contents ());
      dyn_sample = draw env sample;
    }
  in
  let (x0,y0,x1,y1)=bounding_box [r] in
  let w = x1 -. x0 in
  [Drawing {
    drawing_min_width=w;
    drawing_max_width=w;
    drawing_nominal_width=w;
    drawing_width_fixed = true;
    drawing_adjust_before = true;
    drawing_y0=y0;
    drawing_y1=y1;
    drawing_states=[];
    drawing_break_badness=0.;
    drawing_badness=(fun _->0.);
    drawing_contents=(fun _->[r])
  }])])

module Env_dynamic(X : sig val arg1 : content list
                       end)=struct
  let do_begin_env ()=
    D.structure:=newChildAfter !D.structure (Node { empty with node_env=(fun env->{env with par_indent=[]})});
    env_stack:=(List.map fst (snd !D.structure)) :: !env_stack

  let do_end_env ()=
    let res0, path0=(follow (top !D.structure) (List.rev (List.hd !env_stack))) in
    let cont () = OutputDrawing.minipage
                    ~env_mod:(fun e -> { e with normalLeftMargin=0. }) (res0,[])
    in
    let cont = dynamic X.arg1 cont in
    D.structure := up (Node empty, path0);
    D.structure := newPar ~environment:(fun env->{env with par_indent=[];}) !D.structure
           Complete.normal parameters cont;
    env_stack:=List.tl !env_stack;

end

let figure_drawing ?parameters:(_=center) ?name:(_="") ?(caption=[]) ?(scale=1.) drawing env=
  let dr=drawing env in
  let dr=resize_drawing scale dr in
  let lvl,num=try StrMap.find "figure" env.counters with Not_found -> -1,[] in
  let _,str_counter=try StrMap.find "_structure" env.counters with Not_found -> -1,[] in
  let sect_num=List.drop (List.length str_counter - max 0 lvl+1) str_counter in
  let caption, env, _ (*ms*) = (* FIXME: ms lost !!! no label inside caption will work *)
    OutputDrawing.minipage' {env with normalLeftMargin=0.}
                             (paragraph ((
                                         [ tT "Figure"; tT " ";
                                           tT (String.concat "." (List.map (fun x->string_of_int (x+1)) (List.rev (num@sect_num)))) ]
                                         @(if caption=[] then [] else tT" "::tT"–"::tT" "::caption)
                                       )))
  in
  let caption=try IntMap.find 0 caption with Not_found->empty_drawing_box in
  let fig=if caption.drawing_nominal_width<=dr.drawing_nominal_width then
            drawing_blit dr
                         ((dr.drawing_nominal_width-.caption.drawing_nominal_width)/.2.)
                         (dr.drawing_y0-.2.*.caption.drawing_y1) caption
          else
            drawing_blit caption
                         ((caption.drawing_nominal_width-.dr.drawing_nominal_width)/.2.)
                         (2.*.caption.drawing_y1-.dr.drawing_y0) dr
  in
  { fig with drawing_y0=fig.drawing_y0-.env.lead }



let figure ?(parameters=center) ?(name="") ?(caption=[]) ?(scale=1.) drawing=
  figure ~name:name D.structure center (figure_drawing ~parameters ~name ~caption ~scale drawing)


let figure_here ?(parameters=center) ?(name="") ?(caption=[]) ?(scale=1.) drawing=
  let _=match !D.structure with
      Paragraph _,_->go_up D.structure;
    | _->()
  in
  D.structure := newPar !D.structure ~environment:(fun env->{env with par_indent=[]}) Complete.normal parameters
         (Env (incr_counter "figure")::bB (fun env->[Drawing (figure_drawing ~parameters ~name ~caption ~scale drawing env)])::label name)


    type tableParams={ widths:environment->float array; h_spacing:float; v_spacing:float }

    let table params tab=
      [ bB (fun env->
             let widths0=params.widths env in
             let widths=Array.make (Array.length widths0) 0. in
             let heights=Array.make (Array.length tab) 0. in
             let tab_formatted=Array.mapi
               (fun i x->
                  Array.mapi (fun j y->
                    let minip=try IntMap.find 0
                                    (let d,_,_ = OutputDrawing.minipage'
                                       { env with normalMeasure=widths0.(j) } y in d)
                      with _->empty_drawing_box
                    in
                    widths.(j)<-max widths.(j) (minip.drawing_max_width);
                    heights.(i)<-max heights.(i) (minip.drawing_y1-.minip.drawing_y0);
                    minip
                  ) x
               )
               tab
             in
             for i=0 to Array.length heights-1 do
               heights.(i)<-(ceil (heights.(i)/.env.normalLead))*.env.normalLead
             done;
             let contents=ref [] in
             let x=ref 0. in
             let y=ref 0. in
             let max_x=ref 0. in
             let max_y=ref (-.infinity) in
             let min_y=ref infinity in
             let ymin=ref 0. in
             let ymax=ref 0. in
               for i=0 to Array.length tab_formatted-1 do
                 x:=0.;
                 ymin:=0.;
                 ymax:= -.infinity;
                 let conts=ref [] in
                 for j=0 to Array.length tab_formatted.(i)-1 do
                   let cont=tab_formatted.(i).(j) in
                   conts:=(List.map (RawContent.translate !x 0.)
                             (cont.drawing_contents (widths.(j)))) @ (!conts);
                   ymin := min !ymin cont.drawing_y0;
                   ymax := max !ymax cont.drawing_y1;
                   x:= !x +. widths0.(j) +. params.h_spacing
                 done;
                 max_x:=max !x !max_x;
                 contents:=(List.map (RawContent.translate 0. !y) !conts)@(!contents);
                 max_y:=max !max_y (!y+. !ymax);
                 min_y:=min !min_y (!y+. !ymin);
                 y:=(!y)-. heights.(i)-.params.v_spacing;
               done;

               [Drawing {
                  drawing_min_width= !x;
                  drawing_max_width= !x;
                  drawing_nominal_width= !x;
                  drawing_width_fixed = true;
                  drawing_adjust_before = false;
                  drawing_y0= !min_y;
                  drawing_y1= !max_y;
                  drawing_break_badness=0.;
                  drawing_states=[];
                  drawing_badness=(fun _->0.);
                  drawing_contents=(fun _-> List.map (RawContent.translate 0. 0.) !contents)
                }]
          )]


    module Env_env (M:sig val arg1:Document.environment->Document.environment end)=struct
      let do_begin_env ()=
        env_stack:=(List.map fst (snd !D.structure)) :: !env_stack ;
        D.structure:=newChildAfter !D.structure (Node { empty with node_env=M.arg1 })


      let do_end_env ()=
        D.structure :=follow (top !D.structure) (List.rev (List.hd !env_stack)) ;
        env_stack:=List.tl !env_stack

    end

    module Env_noindent=struct
      let do_begin_env ()=
        env_stack:=(List.map fst (snd !D.structure)) :: !env_stack ;
        D.structure:=newChildAfter !D.structure
          (Node { empty with node_tags=("noindent","")::empty.node_tags;
                             node_env=fun env -> {env with par_indent=[]} })


      let do_end_env ()=
        D.structure :=follow (top !D.structure) (List.rev (List.hd !env_stack)) ;
        env_stack:=List.tl !env_stack
    end

    let noindent = [Env (fun env -> Printf.printf "coucou 2\n%!";{env with par_indent=[] } )]

    let hfill t = [bB (fun env-> let x = env.normalMeasure in
                                  [match glue 0. env.size (x /. t) with
                                    Glue x -> Drawing x
                                  | _ -> assert false
                                  ])]

    let hand = hfill 4. @ hspace 0. @ hfill 4.

    let nothing : content list = []
    let mathNothing : Typography.Maths.math list = []

    module Env_mathpar = struct

      let do_begin_env () =
        D.structure:=newChildAfter !D.structure (Node Document.empty) ;
        env_stack := (List.map fst (snd !D.structure)) :: !env_stack

      let do_end_env () =
        D.structure := follow (top !D.structure) (List.rev (List.hd !env_stack)) ;
        env_stack:=List.tl !env_stack ;
        let rec truc t = match t with
          | Paragraph p -> Paragraph { p with par_contents =
              (hfill 2.) @ p.par_contents @ (hfill 2.) }
          | Node n -> Node ({ n with children = IntMap.map truc n.children })
          | _ -> t
        in
        D.structure := up (truc (fst !D.structure), (snd !D.structure))

    end

    let displayedFormula a b c d e f g line=
      let cent=center a b c d e f g line in
      { cent with
        min_height_before=if line.lineStart<=0 then 3.*.a.lead/.4. else cent.min_height_before;
        min_height_after=
          if line.lineEnd>=Array.length b.(line.paragraph) then
            3.*.a.lead/.4.
          else
            cent.min_height_after;
        not_first_line=true }

    module Env_center = struct

      let do_begin_env ()=
        D.structure:=newChildAfter (!D.structure) (Node { empty with node_env=(fun env->{env with par_indent=[]})});
        env_stack:=(List.map fst (snd !D.structure)) :: !env_stack

      let do_end_env ()=
        let center p = { p with par_parameters=Document.do_center p.par_parameters } in
        let res0, path0=(follow (top !D.structure) (List.rev (List.hd !env_stack))) in
        let res = map_paragraphs center res0 in
          D.structure:=up (res, path0);
          env_stack:=List.tl !env_stack

    end
    module Env_raggedRight = struct

      let do_begin_env ()=
        D.structure:=newChildAfter (!D.structure) (Node empty);
        env_stack:=(List.map fst (snd !D.structure)) :: !env_stack

      let do_end_env ()=
        let rag p = { p with par_parameters=ragged_right } in
        let res0, path0=(follow (top !D.structure) (List.rev (List.hd !env_stack))) in
        let res = map_paragraphs rag res0 in
          D.structure:=up (res, path0);
          env_stack:=List.tl !env_stack

    end
    module Env_raggedLeft = struct

      let do_begin_env ()=
        D.structure:=newChildAfter (!D.structure) (Node empty);
        env_stack:=(List.map fst (snd !D.structure)) :: !env_stack

      let do_end_env ()=
        let rag p = { p with par_parameters=ragged_left } in
        let res0, path0=(follow (top !D.structure) (List.rev (List.hd !env_stack))) in
        let res = map_paragraphs rag res0 in
          D.structure:=up (res, path0);
          env_stack:=List.tl !env_stack

    end

    let tiret_w env=phi*.env.size

    module type Enumeration=sig
      val from_counter:int list->content list
    end
    module Enumerate = functor (M:Enumeration)->struct
      let do_begin_env ()=
        D.structure:=newChildAfter (!D.structure)
          (Node { empty with
            node_env=
              (fun env->
                let lvl,cou=try StrMap.find "enumerate" env.counters with Not_found-> -1,[] in
                { env with
                  normalMeasure=env.normalMeasure-.tiret_w env;
                  normalLeftMargin=env.normalLeftMargin+.tiret_w env;
                  counters=StrMap.add "enumerate" (lvl,(-1)::cou) env.counters }
              );
            node_post_env=
              (fun env0 env1->
                let cou=try
                          let lvl,enum=StrMap.find "enumerate" env1.counters in
                          StrMap.add "enumerate" (lvl,List.drop 1 enum) env1.counters
                  with Not_found-> env1.counters
                in
                { env0 with names=env1.names;user_positions=env1.user_positions;counters=cou });
            node_tags=("structure","")::empty.node_tags;
          });
        env_stack:=(List.map fst (snd !D.structure)) :: !env_stack

      module Item=struct
        let do_begin_env ()=
          (* D.structure:=follow (top !D.structure) (List.rev (List.hd !env_stack)); *)
          while List.mem_assoc "item" (doc_tags (fst !D.structure)) do
            go_up D.structure
          done;
          D.structure:=newChildAfter !D.structure
            (Node { empty with
              node_tags=("item","")::empty.node_tags;
              node_env=(incr_counter "enumerate")
            })
        let do_end_env()=()
      end

      let do_end_env ()=
        let params parameters env a1 a2 a3 a4 a5 a6 line=
          let p=parameters env a1 a2 a3 a4 a5 a6 line in
            if not p.absolute && line.lineStart=0 then (
              let rec findMark w j=
                if j>=line.lineEnd then 0. else
                  if a1.(line.paragraph).(j) = Marker AlignmentMark then w else
                    let (_,ww,_)=box_interval a1.(line.paragraph).(j) in
                      findMark (w+.ww) (j+1)
              in
              let w=findMark 0. 0 in
                { p with
                    left_margin=p.left_margin-.w;
                    measure=p.measure+.w }
            ) else
              p
        in
        let comp complete mes a1 a2 a3 a4 line a6=
          if line.lineStart>0 then complete mes a1 a2 a3 a4 line a6 else (
            let rec findMark w j=
              if j>=Array.length a1.(line.paragraph) then 0. else
                if a1.(line.paragraph).(j) = Marker AlignmentMark then w else
                  let (_,ww,_)=box_interval a1.(line.paragraph).(j) in
                    findMark (w+.ww) (j+1)
            in
              complete { mes with normalMeasure=mes.normalMeasure+.findMark 0. 0 } a1 a2 a3 a4 line a6
          )
        in
        let is_first_par=ref false in
        let rec enumerate do_it t=match t with
            Node n when List.mem_assoc "item" n.node_tags && not do_it ->(
              is_first_par:=true;
              Node { n with children=IntMap.map (enumerate true) n.children }
            )
          | Node n when List.mem_assoc "item" n.node_tags -> Node n
          | Node n->Node { n with children=IntMap.map (enumerate do_it) n.children }
          | Paragraph p when do_it->
            let par_contents=
              if !is_first_par then (
                let item=bB (fun env->
                  let _,enum=try StrMap.find "enumerate" env.counters with Not_found->(-1),[0] in
                  let bb=boxify_scoped env (M.from_counter enum) in
                  let fix g= { g with drawing_min_width=g.drawing_nominal_width;
                    drawing_max_width=g.drawing_nominal_width }
                  in
                  let boxes=List.map (function Glue g->Glue (fix g) | Drawing g->Drawing (fix g) | x->x) bb in
                  boxes@[Marker AlignmentMark])
                in
                is_first_par:=false;
                item::p.par_contents
              ) else p.par_contents
            in
            Paragraph { p with
              par_parameters=params p.par_parameters;
              par_completeLine=comp p.par_completeLine;
              par_contents=par_contents
            }
          | _->t
        in
        D.structure:=follow (top !D.structure) (List.rev (List.hd !env_stack));
        let a,b= !D.structure in
        D.structure:=(enumerate false a,b);
        D.structure:=(up !D.structure);
        env_stack:=List.tl !env_stack
    end

    module Env_itemize =
      Enumerate(struct
                  let from_counter _ =
                    [
                      bB (fun env->[Drawing (
                                     let y=env.size/.4. in
                                     let x0=tiret_w env/.phi in
                                     let x1=tiret_w env-.x0 in
                                       { drawing_min_width=tiret_w env;
                                         drawing_nominal_width=tiret_w env;
                                         drawing_width_fixed = true;
                                         drawing_adjust_before = false;
                                         drawing_max_width=tiret_w env;
                                         drawing_y0=y; drawing_y1=y;
                                         drawing_break_badness=0.;
                                         drawing_states=[];
                                         drawing_badness=(fun _->0.);
                                         drawing_contents=(fun _->
                                                             [RawContent.Path
                                                                 ({RawContent.default_path_param with
                                                                    RawContent.lineWidth=0.3;fillColor=Some env.fontColor; strokingColor=Some env.fontColor},
                                                                 [[|[|x0;x1|],[|y;y;|]|]])
                                                             ]) }
                                   )])
                    ]
                end)

    type number_kind =
      Arabic | AlphaLower | AlphaUpper | RomanLower | RomanUpper

    module type Enumerate_Pattern = sig
      val arg1 : number_kind * (string -> content list)
    end

    module Env_genumerate = functor (Pat:Enumerate_Pattern) ->
      Enumerate(struct
        let c, f = Pat.arg1
        let g = match c with
            Arabic -> string_of_int
          | AlphaLower -> Numerals.alphabetic ~capital:false
          | AlphaUpper -> Numerals.alphabetic ~capital:true
          | RomanLower -> Numerals.roman ~capital:false
          | RomanUpper -> Numerals.roman ~capital:true
        let from_counter x =
          let x = List.hd x + 1 in
          f (g x)
      end)

    module Env_enumerate =
      Enumerate(struct
                  let from_counter x =
                    [ tT(string_of_int (List.hd x + 1));tT".";
                      bB (fun env->let w=env.size/.phi in [glue w w w])]
                end)

    module Env_abstract = struct

      let do_begin_env ()=
        D.structure:=newChildAfter !D.structure (Node empty);
        env_stack:=(List.map fst (snd !D.structure)) :: !env_stack

      let do_end_env ()=

        let stru,path=follow (top !D.structure) (List.rev (List.hd !env_stack)) in
        begin
          try
            let p=find_last is_paragraph stru in
            let a,b=follow (stru,path) p in
            let a'=match a with
                Paragraph p->
                  Paragraph { p with
                    par_parameters=(fun a b c d e f g line->
                      let pp=(p.par_parameters a b c d e f g line) in
                      { pp with
                        min_lines_after=
                          if line.lineEnd>=Array.length b.(line.paragraph) then 2 else pp.min_lines_after;
                      });
                  }
              | _->assert false
            in
            D.structure:=up_n (List.length p) (a',b);

            D.structure:=
              up (change_env !D.structure
                    (fun x->
                      { x with
                        normalLeftMargin=x.normalLeftMargin+.(fst x.normalPageFormat)/.18.;
                        normalMeasure=x.normalMeasure-.2.*.(fst x.normalPageFormat)/.18.}));
          with
            Not_found->()
        end;
        env_stack:=List.tl !env_stack

    end

    module type Theorem=sig
      val refType:string
      val counter:string
      val counterLevel:int
      val display:string->content list
    end
    module Env_gproof(X : sig val arg1 : content list end)=struct
      let do_begin_env ()=
        D.structure:=newChildAfter !D.structure (Node empty);
        env_stack:=(List.map fst (snd !D.structure)) :: !env_stack

      let do_end_env ()=
        let par a b c d e f g line={ (ragged_right a b c d e f g line) with not_first_line=true;
          min_lines_before=0;min_lines_after=2; }
        in
        let bad env a b c d e f g h i j k l m=if d.isFigure then infinity else
          Document.badness env a b c d e f g h i j k l m
        in

        let par_proof a b c d e f g line=
          { (parameters a b c d e f g line) with min_height_before=if line.lineStart=0 then a.lead else 0. }
        in
        let cont=X.arg1 in

        let rec add_proof t=match t with
            Node x->(
              try
                if List.mem_assoc "structure" x.node_tags then raise Not_found;
                let a,b=IntMap.min_binding x.children in
                Node { x with children=IntMap.add a (add_proof b) x.children }
              with
                  Not_found->
                    let a=try fst (IntMap.min_binding x.children) with _->1 in
                    let par,_=(paragraph ~par_env:(fun env->{env with par_indent=[]})
                                 ~parameters:par_proof cont)
                    in
                    Node { x with children=IntMap.add (a-1) par x.children}
            )
          | Paragraph p->
            Paragraph { p with
              par_env=(fun env->{(p.par_env env) with par_indent=[]});
              par_parameters=(fun a b c d e f g h->
                let p=p.par_parameters a b c d e f g h in
                if h.lineStart=0 then {p with min_height_before=a.lead} else p);
              par_contents=cont@p.par_contents
            }
          | _->raise Not_found
        in
        let retag t=match t with
            Node x,y->Node { x with node_tags=("structure","")::x.node_tags },y
          | _->assert false
        in
        D.structure:=(follow (top !D.structure) (List.rev (List.hd !env_stack)));
        D.structure:=up (retag (add_proof (fst !D.structure), snd !D.structure));
        D.structure:=newPar !D.structure ~badness:bad Complete.normal par
          [bB (fun env->
                let w=env.size/.phi in
                  [Drawing (
                     drawing [RawContent.Path ({ RawContent.default_path_param with
                                                     RawContent.close=true;
                                                     RawContent.lineWidth=0.1 },
                                                 [RawContent.rectangle (0.,0.) (w,w)]
                                                )])
                  ]
             )];
        env_stack:=List.tl !env_stack
    end
    module Env_proof = Env_gproof (struct
      let arg1 = italic [tT "Proof.";bB (fun env->let w=env.size in [glue w w w])]
    end)
    module Env_proofOf(X : sig val arg1 : content list end) = Env_gproof (struct
      let arg1 = italic (X.arg1 @ [tT ".";bB (fun env->let w=env.size in [glue w w w])])
    end)

    module Proof = Env_proof (* probably useless, just for compatibility *)

    module Make_theorem=functor (Th:Theorem)->struct

      let reference name=lref ~refType:Th.refType name

      let do_begin_env ()=
        D.structure:=newChildAfter !D.structure (Node empty);
        env_stack:=(List.map fst (snd !D.structure)) :: !env_stack

      let do_end_env ()=
        let rec last_par=function
            Paragraph p->
              Paragraph { p with
                            par_parameters=(fun a b c d e f g line->
                              let pp=(p.par_parameters a b c d e f g line) in
                              { pp with
                                min_lines_after=
                                  if line.lineEnd>=Array.length b.(line.paragraph) then 2 else pp.min_lines_after;
                              });
              }
          | Node n->(try
                       let k0,a0=IntMap.max_binding n.children in
                       Node { n with children=IntMap.add k0 (last_par a0) n.children }
                     with Not_found -> Node n)
          | x -> x
        in
        let stru,path=follow (top !D.structure) (List.rev (List.hd !env_stack)) in



        let cont=
          Env (incr_counter ~level:Th.counterLevel Th.counter)::
            C (fun env->
              let lvl,num=try (StrMap.find Th.counter env.counters) with
                  Not_found -> -1,[0]
              in
              let _,str_counter=try
                                  StrMap.find "_structure" env.counters
                with Not_found -> -1,[0]
              in
              let sect_num=List.drop (max 1 (List.length str_counter - lvl+1))
                str_counter
              in
              Th.display (String.concat "." (List.map (fun x->string_of_int (x+1)) ((List.rev sect_num)@num)))
            )::
            [tT " "]
        in
        let rec add_name t=match t with
            Node x->(
              try
                let a,b=IntMap.min_binding x.children in
                match b with
                    Node y when List.mem_assoc "structure" y.node_tags->raise Not_found
                  | _->Node { x with children=IntMap.add a (add_name b) x.children }
              with
                  Not_found->
                    let a=try fst (IntMap.min_binding x.children) with _->1 in
                    let par,_=paragraph ~par_env:(fun env->{env with par_indent=[]}) cont in
                    Node { x with children=IntMap.add (a-1) par x.children}
            )
          | Paragraph p->
            Paragraph { p with
              par_env=(fun env->{(p.par_env env) with par_indent=[]});
              par_parameters=(fun a b c d e f g h->
                let p=p.par_parameters a b c d e f g h in
                if h.lineStart=0 then {p with min_lines_before=2} else p);
              par_contents=cont@p.par_contents
            }
          | _->raise Not_found
        in
        let retag t=match t with
            Node x,y->Node { x with node_tags=("structure","")::x.node_tags },y
          | _->assert false
        in
        D.structure := up (retag (last_par (add_name stru),path));
        env_stack:=List.tl !env_stack
    end


    module Env_title=struct
      let title ()=
        match fst (top !D.structure) with
            Node n->n.displayname
          | _->[]

      let do_begin_env ()=
        env_stack:=(List.map fst (snd !D.structure)) :: !env_stack


      let do_end_env ()=
        D.structure:=
          (match fst (top !D.structure) with
              Node n->
                Node { n with node_tags=("title already typeset","")::n.node_tags },[]
            | x->x,[]);
        D.structure :=follow (top !D.structure) (List.rev (List.hd !env_stack));
        env_stack:=List.tl !env_stack
    end



    module Output(M:Driver.OutputDriver)=struct
      (** Output routines. An output routine is just a functor taking a driver module *)
      open RawContent
      open Driver
      type output=unit
      (* { *)
      (*   mutable format:Box.box array array->(Document.tree*Document.cxt) array-> *)
      (*                  Box.drawingBox array->(Document.tree*Document.cxt) array-> *)
      (*                  (Layout.parameters*Layout.line) list -> OutputPaper.page; *)
      (*   mutable pageNumbers:OutputPaper.page->environment->int->unit *)
      (* } *)
      let outputParams=()

      let rec resolve tree i env0=
        if not !quiet then Printf.eprintf "Pass number %d\n%!" i;
        pass_number := i;
        let env1, fig_params, params, new_page_list, new_line_list, compl,
          badness, paragraphs, _, figures, _, states = flatten env0 tree in
        if not !quiet then
          Printf.eprintf "Optimization starts: %f s\n%!" (Sys.time ());
        let (logs,opt_pages,figs',user')=TS.typeset
          ~completeLine:compl
          ~figure_parameters:fig_params
          ~figures:figures
          ~parameters:params
          ~new_page:new_page_list
          ~new_line:new_line_list
          ~badness:badness
          ~states
          paragraphs
        in
        if not !quiet then
          Printf.eprintf "Optimization ends: %f s\n%!" (Sys.time ());
        let env, reboot=update_names env1 figs' user' in
        let env=reset_counters env in
        if i < !max_iterations-1 && reboot && !(env.fixable) then (
          resolve tree (i+1) env
        ) else (

          List.iter (fun x->Printf.fprintf stderr "%s\n" (Break.message x)) logs;

          let positions=Array.make (Array.length paragraphs) (0,0.,0.) in
          let par=ref (-1) in
          let crosslinks=ref [] in (* (page, link, destination) *)
          let crosslink_opened=ref false in
          let destinations=ref StrMap.empty in
          let urilinks=ref None in

          let continued_link=ref None in
            (*
              let o=open_out "graph" in
              Printf.fprintf o "digraph{";
              let rec draw_graph g path=
              Printf.fprintf o "%s[label=\"%s, %d\"];\n" path (String.concat "," g.frame_tags) (List.length (g.frame_content));
              IntMap.iter (fun k a->
              let next=Printf.sprintf "%s_%d" path k in
              Printf.fprintf o "%s -> %s;\n" path next;
              draw_graph a next
              ) g.frame_children
              in
              draw_graph opt_pages "r";
              Printf.fprintf o "}";
              close_out o;
            *)

          let draw_page i layout=
            let page={ Driver.size=(layout.frame_x1-.layout.frame_x0,
                                   layout.frame_y1-.layout.frame_y0);
                       Driver.contents=[] }
            in

            let endlink cont=
              continued_link:=None;
              if !crosslink_opened then (
                let rec link_contents u l=match l with
                    []->[]
                  | (Link h)::s when not h.link_closed->(
                    if cont then continued_link:=Some (Link h);
                    let x0,y0,x1,y1=bounding_box u in
                    Link { h with
                      link_x0=x0;link_y0=y0;
                      link_x1=x1;link_y1=y1;
                      link_closed=true;
                      link_contents=List.rev u
                    }
                  )::s
                  | h::s->link_contents (h::u) s
                in
                page.contents<-link_contents [] page.contents;
                crosslink_opened:=false;
              )
            in

            (match !continued_link with
              None->()
            | Some l->(
              page.contents<-l::page.contents;
              crosslink_opened:=true;
              continued_link:=None
            )
            );

            (* Affichage des frames (demouchage) *)
            let h=Hashtbl.create 100 in


            let rec draw_all_frames t=
              if env.show_frames then (
                let r=(t.frame_x0,t.frame_y0,t.frame_x1,t.frame_y1) in
                if not (Hashtbl.mem h r) then (
                  Hashtbl.add h r ();
                  page.contents<-Path (default_path_param,[rectangle (t.frame_x0,t.frame_y0)
                                                       (t.frame_x1,t.frame_y1)])
                  ::page.contents;
                );
              );


              let rec draw_cont last_placed conts=match conts with
                  Placed_line l::s->(
                    if l.line.isFigure then (
                      let fig=figures.(l.line.lastFigure) in
                      let y=
                        match last_placed with
                          None->l.line.height
                        | Some ll->
                          try
                            let nextl =
                              match List.find (function Placed_line _ -> true | _ -> false) s with
                              | Placed_line l -> l
                              | _ -> assert false
                            in
                            let milieu=
                              (ll.line.height+.fst (line_height paragraphs figures ll.line)
                               +.(nextl.line.height+.snd (line_height paragraphs figures nextl.line)))/.2.
                            in
                            milieu-.(fig.drawing_y1+.fig.drawing_y0)/.2.
                          with Not_found->l.line.height
                      in
                      page.contents<- (List.map (translate ((fst l.line.layout).frame_x0+.l.line_params.left_margin) y)
                                             (fig.drawing_contents fig.drawing_nominal_width))
                      @ page.contents;

                    ) else if l.line.paragraph<Array.length paragraphs then (
                      let line=l.line in
                      let param=l.line_params in
                      if line.paragraph<> !par then (
                        par:=line.paragraph;
                        positions.(!par)<-
                          (i,0.,
                           line.height +. phi*.snd (line_height paragraphs figures line))
                      );
                      let comp=compression paragraphs param line in
                      let rec draw_box x y box=
                        let lowy=y+.lower_y box in
                        let uppy=y+.upper_y box in
                        (match !urilinks with
                          None->()
                        | Some h->(
                          h.link_y0<-min h.link_y0 lowy;
                          h.link_y1<-max h.link_y1 uppy
                        ));
                        if !crosslink_opened then
                          (match !crosslinks with
                            []->()
                          | (_,h,_)::_->(
                            h.link_y0<-min h.link_y0 lowy;
                            h.link_y1<-max h.link_y1 uppy
                          ));
                        match box with
                          Kerning kbox ->(
                            let w=draw_box (x+.kbox.kern_x0) (y+.kbox.kern_y0) kbox.kern_contents in
                            w+.kbox.advance_width
                          )
                        | Hyphen h->(
                          (Array.fold_left (fun x' box->
                            let w=draw_box (x+.x') y box in
                            x'+.w) 0. h.hyphen_normal)
                        )
                        | GlyphBox a->(
                          page.contents<-translate x y (Glyph a):: page.contents;
                          let w=a.glyph_size*.Fonts.glyphWidth a.glyph/.1000. in
                          if env.show_boxes then (
                            let y0=lower_y box
                                and y1=upper_y box
                            in
                            page.contents<- Path ({RawContent.default_path_param with close=true;lineWidth=0.1 }, [rectangle (x,y+.y0) (x+.w,y+.y1)]) :: page.contents;
                          );
                          w
                        )
                        | Glue g
                        | Drawing g ->(
                          let w=g.drawing_min_width+.comp*.(g.drawing_max_width-.g.drawing_min_width) in
                          page.contents<- (List.map (translate x y) (g.drawing_contents w)) @ page.contents;
                          if env.show_boxes then
                            page.contents<- Path ({RawContent.default_path_param with close=true;lineWidth=0.1 }, [rectangle (x,y+.g.drawing_y0) (x+.w,y+.g.drawing_y1)]) :: page.contents;
                          w
                        )
                        | Marker (BeginLink l)->(
                          let k = match l with
                              Box.Extern l -> RawContent.Extern l;
                            | Box.Intern l -> RawContent.Intern(l,layout_page line,0.,0.);
                            | Box.Button (t,n) -> RawContent.Button(t,n)
                          in
                          let link={ link_x0=x;link_y0=y;link_x1=x;link_y1=y;link_kind=k;
                                     link_order=0;link_closed=false;
                                     link_contents=[] }
                          in
                          crosslinks:=(i, link, l) :: !crosslinks;
                          crosslink_opened:=true;
                          page.contents<-Link link::page.contents;
                          0.
                        )
                        | Marker EndLink->(
                          endlink false;
                          0.
                        )
                        | Marker (Label l)->(
                          let y0,y1=line_height paragraphs figures line in
                          destinations:=StrMap.add l
                            (i,(fst line.layout).frame_x0+.param.left_margin,
                             y+.y0,y+.y1) !destinations;
                          0.
                        )
                        | b->box_width comp b
                      in
                      if !crosslink_opened then
                        crosslinks:=(match !crosslinks with
                          []->[]
                        | (a,h,c)::s->
                          (a, { h with
                            link_x0=(fst line.layout).frame_x0+.param.left_margin;
                            link_x1=(fst line.layout).frame_x0+.param.left_margin;
                            link_y0=line.height;link_y1=line.height }, c)::(a,h,c)::s);

                      (* Écrire la page *)
                      let _=
                        fold_left_line paragraphs (fun x b->x+.draw_box x line.height b)
                          ((fst line.layout).frame_x0+.param.left_margin) line
                      in

                        (* Fermer les liens, et préparer la continuation sur
                           la prochaine ligne. *)
                      endlink true;
                      (match !continued_link with
                        None->()
                      | Some l->(
                        page.contents<-l::page.contents;
                        crosslink_opened:=true;
                        continued_link:=None
                      )
                      )
                    );
                    draw_cont (Some l) s
                  )
                | Raw r::s->(
                  page.contents<-List.map (translate t.frame_x0 t.frame_y0) r
                  @page.contents;
                  draw_cont last_placed s
                )
                  | []->()
              in
              draw_cont None t.frame_content;
              IntMap.iter (fun _ a->draw_all_frames a) t.frame_children
            in
            draw_all_frames layout;


              (*
                for j=0 to Array.length pp-1 do
                let param=pp.(j).line_params
                and line=pp.(j).line in

                (* Affichage des frames (demouchage) *)
                (* * *)

                if env.show_boxes then
                  page.contents<- Path ({RawContent.default_path_param with close=true;lineWidth=0.1 },
                                            [rectangle (param.left_margin,y+.fig.drawing_y0)
                                                (param.left_margin+.fig.drawing_nominal_width,
                                                 y+.fig.drawing_y1)]) :: page.contents;

                ) else




                  (* Si un lien est commencé sur la ligne précédente,
                     le reprendre *)
              done;
              *)

            endlink true;
            (match !urilinks with
              None->()
            | Some h->page.contents<-Link h::page.contents; urilinks:=None);

              (*
              ignore (
                List.fold_left (
                  fun y footnote->
                    page.contents<- (List.map (translate (env.normalLeftMargin) (y-.footnote.drawing_y1-.env.footnote_y))
                                           (footnote.drawing_contents footnote.drawing_nominal_width)) @ page.contents;
                    y-.(footnote.drawing_y1-.footnote.drawing_y0)
                ) !footnote_y !footnotes
              );
              if !footnotes<>[] then (
                page.contents<- (Path ({RawContent.default_path_param with lineWidth=0.01 }, [ [| [| env.normalLeftMargin;
                                                                                                env.normalLeftMargin+.env.normalMeasure*.(2.-.phi) |],
                                                                                           [| !footnote_y-.env.footnote_y;
                                                                                              !footnote_y-.env.footnote_y |] |] ]))::page.contents
              );
              *)

            let num=boxify_scoped defaultEnv [tT (!sprint_page_number (i+1))] in
            let _,w,_=boxes_interval (Array.of_list num) in
            page.contents<-
                List.map (translate ((fst page.size-.w)/.2.) !page_number_vpos)
              (draw_boxes env num)
            @page.contents;

            page.contents<-List.rev page.contents;
            page
          in

          let rec draw_all_pages g i pages=
            if List.mem "page" g.frame_tags then (
              i+1, draw_page i g::pages
            ) else (
              IntMap.fold (fun _ a (j,ps)->draw_all_pages a j ps) g.frame_children (i,pages)
            )
          in

          let pages=Array.of_list (List.rev (snd (draw_all_pages opt_pages 0 []))) in
          let pages=Array.map (fun p->
              { p with
                contents=List.map (fun a->match a with
                  Link ({link_kind = Intern(label,_,_,_); _} as l)->(
                    try
                      let (p',x,y0,y1)=StrMap.find label !destinations in
                      let dx0,dy0,dx1,dy1=bounding_box l.link_contents in
                      Link { l with link_kind = Intern(label,p',x,y0+.(y1-.y0)*.phi);
                        link_x0=dx0;link_x1=dx1;
                        link_y0=dy0;link_y1=dy1
                           }
                    with
                      Not_found->a
                  )
                | a->a
                ) p.contents
              }
            ) pages
            in
          pages, positions);;

     let basic_output _ tree defaultEnv file=
       let pages, structure =
         match !Driver.input_bin with
           None ->
             let pages, positions = resolve tree 0 defaultEnv in
             let structure = make_struct positions tree in
             pages, structure
         | Some fileName ->
           let ch = open_in fileName in
           let b = input_value ch in
           if b then failwith "Wrong bin for this format";
           let structure = Marshal.from_channel ch in
           let pages = Marshal.from_channel ch in
           close_in ch;
           Printf.fprintf stderr "File %s read.\n" fileName;
           pages, structure
       in

       M.output ~structure pages file

      let output out_params structure defaultEnv file=
        basic_output out_params (postprocess_tree structure) defaultEnv file
    end


  end)

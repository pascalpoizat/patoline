open CamomileLibrary
open Printf
open Fonts.FTypes
open OutputCommon
open Box
open Line
open Document
open Util
module Buf=UTF8.Buf


type page = { mutable pageFormat:float*float; mutable pageContents:contents list }



module type Driver=sig
  val filename:string->string
  val output: ?structure:structure -> page array -> string -> unit
end

(** Output routines. An output routine is just a functor taking a driver module *)

module Output=functor(M:Driver)->struct
  let output structure paragraphs (figures:drawingBox array) env (opt_pages:(parameters*line) list array) file=
    let positions=Array.make (Array.length paragraphs) (0,0.,0.) in
    let par=ref (-1) in
    let draw_page i p=
      let page= { pageFormat=a4 ; pageContents=[] } in
      let footnotes=ref [] in
      let footnote_y=ref (-.infinity) in
      let links=ref None in
        List.iter (
          fun (param,line)->
            let y=270.0-.line.height in

              if line.isFigure then (
                let fig=figures.(line.lastFigure) in
                  page.pageContents<- (List.map (translate param.left_margin (y-.fig.drawing_y1))
                                         (fig.drawing_contents fig.drawing_nominal_width))
                  @ page.pageContents;

              ) else if line.paragraph<Array.length paragraphs then (

                if line.paragraph<> !par then (
                  par:=line.paragraph;
                  positions.(!par)<-(i,0., y +. phi*.snd (line_height paragraphs line))
                );

                let comp=compression paragraphs param line in
                let rec draw_box x y box=
                  (match !links with
                       None->()
                     | Some h->(
                         h.link_y0<-min h.link_y0 (y+.lower_y box 0.);
                         h.link_y1<-max h.link_y1 (y+.upper_y box 0.)
                       ));
                  match box with
                      Kerning kbox ->(
                        let fact=(box_size kbox.kern_contents/.1000.) in
                        let w=draw_box (x+.kbox.kern_x0*.fact) (y+.kbox.kern_y0*.fact) kbox.kern_contents in
                          w+.kbox.advance_width*.fact
                      )
                    | Hyphen h->(
                        (Array.fold_left (fun x' box->
                                            let w=draw_box (x+.x') y box in
                                              x'+.w) 0. h.hyphen_normal)
                      )
                    | GlyphBox a->(
                        page.pageContents<-
                          (OutputCommon.Glyph { a with glyph_x=a.glyph_x+.x;glyph_y=a.glyph_y+.y })
                        :: page.pageContents;
                        a.glyph_size*.Fonts.glyphWidth a.glyph/.1000.
                      )
                    | Glue g
                    | Drawing g ->(
                        let w=g.drawing_min_width+.comp*.(g.drawing_max_width-.g.drawing_min_width) in
                          page.pageContents<- (List.map (translate x y) (g.drawing_contents w)) @ page.pageContents;
                          (* page.pageContents<- Path ({OutputCommon.default with close=true;lineWidth=0.1 }, [rectangle (x,y+.g.drawing_y0) (x+.w,y+.g.drawing_y1)]) :: page.pageContents; *)
                          w
                      )
                    | User (BeginURILink l)->(
                        links:=Some { link_x0=x;link_y0=y;link_x1=x;link_y1=y;uri=l;
                                      dest_page=0;dest_x=0.;dest_y=0. };
                        0.
                      )
                    | User EndLink->(
                        (match !links with
                             None->()
                           | Some h->(
                               h.link_x1<-x;
                               page.pageContents<-Link h::page.pageContents
                             )
                        );
                        links:=None;
                        0.
                      )
                    | User (Footnote (_,g))->(
                        footnotes:= g::(!footnotes);
                        footnote_y:=max !footnote_y (270.-.param.page_height);
                        0.
                      )
                    | b->box_width comp b
                in
                  links:=(match !links with
                              None->None
                            | Some h->
                                page.pageContents<-Link h::page.pageContents;
                                Some { h with link_x0=param.left_margin;link_x1=param.left_margin;
                                         link_y0=y;link_y1=y });
                  let x1=fold_left_line paragraphs (fun x b->x+.draw_box x y b) param.left_margin line in
                    match !links with
                        None->()
                      | Some h->h.link_x1<-x1
              )
        ) p;
        (match !links with
             None->()
           | Some h->page.pageContents<-Link h::page.pageContents; links:=None);
        ignore (
          List.fold_left (
            fun y footnote->
              page.pageContents<- (List.map (translate (env.normalLeftMargin) (y-.footnote.drawing_y1-.env.footnote_y))
                                     (footnote.drawing_contents footnote.drawing_nominal_width)) @ page.pageContents;
              y-.(footnote.drawing_y1-.footnote.drawing_y0)
          ) !footnote_y !footnotes
        );
        if !footnotes<>[] then (
          page.pageContents<- (Path ({OutputCommon.default with lineWidth=0.01 }, [ [| [| env.normalLeftMargin;
                                                                    env.normalLeftMargin+.env.normalMeasure*.(2.-.phi) |],
                                                                 [| !footnote_y-.env.footnote_y;
                                                                    !footnote_y-.env.footnote_y |] |] ]))::page.pageContents
        );
        let pnum=glyph_of_string env.substitutions env.positioning env.font env.size env.fontColor (string_of_int (i+1)) in
        let (_,w,_)=boxes_interval (Array.of_list pnum) in
        let x=(fst page.pageFormat -. w)/.2. in
        let _=List.fold_left (fun x0 b->match b with
                                  (GlyphBox a)->(
                                    let (_,w,_)=box_interval b in
                                      page.pageContents<- (OutputCommon.Glyph { a with glyph_x=x0;glyph_y=20. })
                                      :: page.pageContents;
                                      x0+.w
                                  )
                                | _ -> x0
                             ) x pnum
        in
          { page with pageContents=List.rev page.pageContents }
    in
      M.output ~structure:(make_struct positions structure) (Array.mapi draw_page opt_pages) file
end

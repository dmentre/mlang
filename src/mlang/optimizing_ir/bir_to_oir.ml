(* Copyright (C) 2020 Inria, contributors: Denis Merigoux <denis.merigoux@inria.fr>

   This program is free software: you can redistribute it and/or modify it under the terms of the
   GNU General Public License as published by the Free Software Foundation, either version 3 of the
   License, or (at your option) any later version.

   This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
   even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
   General Public License for more details.

   You should have received a copy of the GNU General Public License along with this program. If
   not, see <https://www.gnu.org/licenses/>. *)

let block_id_counter = ref 0

let fresh_block_id () : Oir.block_id =
  let out = !block_id_counter in
  block_id_counter := out + 1;
  out

let append_to_block (s : Oir.stmt) (bid : Oir.block_id) (blocks : Oir.block Oir.BlockMap.t) :
    Oir.block Oir.BlockMap.t =
  match Oir.BlockMap.find_opt bid blocks with
  | None -> assert false (* should not happen *)
  | Some stmts -> Oir.BlockMap.add bid (s :: stmts) blocks

let initialize_block (bid : Oir.block_id) (blocks : Oir.block Oir.BlockMap.t) :
    Oir.block Oir.BlockMap.t =
  Oir.BlockMap.add bid [] blocks

let rec translate_statement_list (l : Bir.stmt list) (curr_block_id : Oir.block_id)
    (blocks : Oir.block Oir.BlockMap.t) : Oir.block_id * Oir.block Oir.BlockMap.t =
  let blocks, last_block_id =
    List.fold_left
      (fun (blocks, current_block_id) stmt ->
        let new_current_block_id, new_blocks = translate_statement stmt current_block_id blocks in
        (new_blocks, new_current_block_id))
      (blocks, curr_block_id) l
  in
  (last_block_id, blocks)

and translate_statement (s : Bir.stmt) (curr_block_id : Oir.block_id)
    (blocks : Oir.block Oir.BlockMap.t) : Oir.block_id * Oir.block Oir.BlockMap.t =
  match Pos.unmark s with
  | Bir.SAssign (var, data) ->
      ( curr_block_id,
        append_to_block (Pos.same_pos_as (Oir.SAssign (var, data)) s) curr_block_id blocks )
  | Bir.SVerif cond ->
      (curr_block_id, append_to_block (Pos.same_pos_as (Oir.SVerif cond) s) curr_block_id blocks)
  | Bir.SConditional (e, l1, l2) ->
      let b1id = fresh_block_id () in
      let blocks = initialize_block b1id blocks in
      let b2id = fresh_block_id () in
      let blocks = initialize_block b2id blocks in
      let join_block = fresh_block_id () in
      let blocks = initialize_block join_block blocks in
      let blocks =
        append_to_block
          (Pos.same_pos_as (Oir.SConditional (e, b1id, b2id, join_block)) s)
          curr_block_id blocks
      in
      let last_b1id, blocks = translate_statement_list l1 b1id blocks in
      let blocks = append_to_block (Oir.SGoto join_block, Pos.no_pos) last_b1id blocks in
      let last_b2id, blocks = translate_statement_list l2 b2id blocks in
      let blocks = append_to_block (Oir.SGoto join_block, Pos.no_pos) last_b2id blocks in
      (join_block, blocks)

let bir_program_to_oir (p : Bir.program) : Oir.program =
  let entry_block = fresh_block_id () in
  let blocks = initialize_block entry_block Oir.BlockMap.empty in
  let exit_block, blocks = translate_statement_list p.statements entry_block blocks in
  let blocks = Oir.BlockMap.map (fun stmts -> List.rev stmts) blocks in
  {
    blocks;
    entry_block;
    exit_block;
    idmap = p.idmap;
    mir_program = p.mir_program;
    outputs = p.outputs;
  }

let rec re_translate_statement (s : Oir.stmt) (blocks : Oir.block Oir.BlockMap.t) :
    Oir.block_id option * Bir.stmt option =
  match Pos.unmark s with
  | Oir.SAssign (var, data) -> (None, Some (Pos.same_pos_as (Bir.SAssign (var, data)) s))
  | Oir.SVerif cond -> (None, Some (Pos.same_pos_as (Bir.SVerif cond) s))
  | Oir.SConditional (e, b1, b2, join_block) ->
      let b1 = re_translate_blocks_until b1 blocks (Some join_block) in
      let b2 = re_translate_blocks_until b2 blocks (Some join_block) in
      (Some join_block, Some (Pos.same_pos_as (Bir.SConditional (e, b1, b2)) s))
  | Oir.SGoto b -> (Some b, None)

and re_translate_blocks_until (block_id : Oir.block_id) (blocks : Oir.block Oir.BlockMap.t)
    (stop : Oir.block_id option) : Bir.stmt list =
  let next_block, stmts = re_translate_block block_id blocks in
  stmts
  @
  match (next_block, stop) with
  | None, Some _ -> assert false (* should not happen *)
  | None, None -> []
  | Some next_block, None -> re_translate_blocks_until next_block blocks stop
  | Some next_block, Some stop ->
      if next_block = stop then [] else re_translate_blocks_until next_block blocks (Some stop)

and re_translate_block (block_id : Oir.block_id) (blocks : Oir.block Oir.BlockMap.t) :
    Oir.block_id option * Bir.stmt list =
  match Oir.BlockMap.find_opt block_id blocks with
  | None -> assert false (* should not happen *)
  | Some block ->
      let next_block_id, stmts =
        List.fold_left
          (fun (_, acc) s ->
            let next_block, stmt = re_translate_statement s blocks in
            (next_block, match stmt with None -> acc | Some s -> s :: acc))
          (None, []) block
      in
      let stmts = List.rev stmts in
      (next_block_id, stmts)

let oir_program_to_bir (p : Oir.program) : Bir.program =
  let statements = re_translate_blocks_until p.entry_block p.blocks None in
  let p =
    {
      Bir.statements = Bir.remove_empty_conditionals statements;
      idmap = p.idmap;
      mir_program = p.mir_program;
      outputs = p.outputs;
    }
  in
  p

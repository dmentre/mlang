(*
Copyright Inria, contributor: Denis Merigoux <denis.merigoux@inria.fr> (2019)

This software is a computer program whose purpose is to compile and analyze
programs written in the M langage, created by the DGFiP.

This software is governed by the CeCILL-C license under French law and
abiding by the rules of distribution of free software.  You can  use,
modify and/ or redistribute the software under the terms of the CeCILL-C
license as circulated by CEA, CNRS and INRIA at the following URL
http://www.cecill.info.

As a counterpart to the access to the source code and  rights to copy,
modify and redistribute granted by the license, users are provided only
with a limited warranty  and the software's author,  the holder of the
economic rights,  and the successive licensors  have only  limited
liability.

In this respect, the user's attention is drawn to the risks associated
with loading,  using,  modifying and/or developing or reproducing the
software by the user in light of its specific status of free software,
that may mean  that it is complicated to manipulate,  and  that  also
therefore means  that it is reserved for developers  and  experienced
professionals having in-depth computer knowledge. Users are therefore
encouraged to load and test the software's suitability as regards their
requirements in conditions enabling the security of their systems and/or
data to be ensured and,  more generally, to use and operate it in the
same conditions as regards security.

The fact that you are presently reading this means that you have had
knowledge of the CeCILL-C license and that you accept its terms.
*)

type translated_var =
  | Bool of Specifisc.BoolVariable.t
  | Int of Specifisc.IntVariable.t

type ctx = {
  ctx_typ_info: Typechecker.typ_info;
  ctx_var_mapping: translated_var Mvg.VariableMap.t;
  ctx_local_var_mapping: translated_var Mvg.LocalVariableMap.t;
}

let empty_ctx (typing : Typechecker.typ_info): ctx = {
  ctx_typ_info = typing;
  ctx_var_mapping = Mvg.VariableMap.empty;
  ctx_local_var_mapping = Mvg.LocalVariableMap.empty;
}

let mult_precision_factor_int_real = 100

let arr_func_id : Specifisc.ArithmeticFunctionVariable.t =
  Specifisc.ArithmeticFunctionVariable.new_var ("arr", Ast.no_pos) ("", Ast.no_pos)

let inf_func_id : Specifisc.ArithmeticFunctionVariable.t =
  Specifisc.ArithmeticFunctionVariable.new_var ("inf", Ast.no_pos) ("", Ast.no_pos)

let rec translate_logical_expression
    (e: Mvg.expression Ast.marked)
    (ctx: ctx)
  : Specifisc.logical_expression Ast.marked * Specifisc.command list * ctx =
  match Ast.unmark e with
  | Mvg.Unop (Ast.Not, e1) ->
    let se, conds, ctx = translate_logical_expression e1 ctx in
    (Ast.same_pos_as (Specifisc.LogicalNot se) e, conds, ctx)
  | Mvg.Binop ((Ast.And | Ast.Or as op, pos), e1, e2) ->
    let se1, conds1, ctx = translate_logical_expression e1 ctx in
    let se2, conds2, ctx = translate_logical_expression e2 ctx in
    let op = match op with
      | Ast.And -> Specifisc.And
      | Ast.Or -> Specifisc.Or
      | _ -> assert false (* should not happen*)
    in
    (Ast.same_pos_as (Specifisc.LogicalBinop ((op, pos), se1, se2)) e,
     conds2@conds1, ctx)
  | Mvg.Comparison (op, e1, e2) ->
    let se1, conds1, ctx = translate_arithmetic_expression e1 ctx in
    let se2, conds2, ctx = translate_arithmetic_expression e2 ctx in
    let sop = match Ast.unmark op with
      | Ast.Gt -> Specifisc.Gt
      | Ast.Gte -> Specifisc.Gte
      | Ast.Lt -> Specifisc.Lt
      | Ast.Lte -> Specifisc.Lte
      | Ast.Neq -> Specifisc.Neq
      | Ast.Eq -> Specifisc.Eq
    in
    (Ast.same_pos_as (Specifisc.Comparison (Ast.same_pos_as sop op , se1, se2)) e,
     conds2@conds1, ctx)
  | Mvg.Literal (Mvg.Bool b) -> (Ast.same_pos_as (Specifisc.BoolLiteral b) e, [], ctx)
  | Mvg.Var var ->
    begin match Mvg.VariableMap.find var ctx.ctx_var_mapping with
      | Bool bool_var -> (Ast.same_pos_as (Specifisc.BoolVar bool_var) e, [], ctx)
      | _ -> assert false (* should not happen *)
    end
  | Mvg.LocalVar lvar ->
    begin match Mvg.LocalVariableMap.find lvar ctx.ctx_local_var_mapping with
      | Bool bool_var -> (Ast.same_pos_as (Specifisc.BoolVar bool_var) e, [], ctx)
      | _ -> assert false (* should not happen *)
    end
  | Mvg.LocalLet (lvar, e1, e2) ->
    if Mvg.LocalVariableMap.find lvar ctx.ctx_typ_info.typ_info_local_var <> Mvg.Boolean then
      assert false (* should not happen *);
    let se1, conds1, ctx = translate_logical_expression e1 ctx in
    let bool_var = Specifisc.BoolVariable.new_var
        (Ast.same_pos_as ("t" ^ (string_of_int lvar.Mvg.LocalVariable.id)) e)
        (Ast.same_pos_as ("Local variable") e)
    in
    let ctx =
      { ctx with
        ctx_local_var_mapping = Mvg.LocalVariableMap.add lvar (Bool bool_var) ctx.ctx_local_var_mapping;
      } in
    let se2, conds2, ctx = translate_logical_expression e2 ctx in
    (se2, conds2@[Specifisc.BoolDef (bool_var, se1)]@conds1, ctx)
  | _ ->
    raise
      (Errors.UnsupportedBySpecifisc
         (Printf.sprintf "expression %s" (Format_ast.format_position (Ast.get_position e))
         )
      )

and translate_arithmetic_expression
    (e: Mvg.expression Ast.marked)
    (ctx: ctx)
  : Specifisc.arithmetic_expression Ast.marked * Specifisc.command list * ctx =
  match Ast.unmark e with
  | Mvg.Unop (Ast.Minus, e1) ->
    let se, conds, ctx = translate_arithmetic_expression e1 ctx in
    (Ast.same_pos_as (Specifisc.ArithmeticMinus se) e, conds, ctx)
  | Mvg.Binop ((Ast.Add | Ast.Sub | Ast.Div | Ast.Mul as op, pos), e1, e2) ->
    let se1, conds1, ctx = translate_arithmetic_expression e1 ctx in
    let se2, conds2, ctx = translate_arithmetic_expression e2 ctx in
    let op = match op with
      | Ast.Add -> Specifisc.Add
      | Ast.Sub -> Specifisc.Sub
      | Ast.Div -> Specifisc.Div
      | Ast.Mul -> Specifisc.Mul
      | _ -> assert false (* should not happen*)
    in
    (Ast.same_pos_as (Specifisc.ArithmeticBinop ((op, pos), se1, se2)) e,
     conds2@conds1, ctx)
  | Mvg.Conditional (e1, e2, e3) ->
    let se1, conds1, ctx = translate_logical_expression e1 ctx in
    let se2, conds2, ctx = translate_arithmetic_expression e2 ctx in
    let se3, conds3, ctx = translate_arithmetic_expression e3 ctx in
    (Ast.same_pos_as (Specifisc.Conditional (se1 , se2, se3)) e,
     conds3@conds2@conds1, ctx)
  | Mvg.Literal (Mvg.Int i) ->
    (Ast.same_pos_as (
        Specifisc.IntLiteral (Int64.of_int (i * mult_precision_factor_int_real))
      ) e, [], ctx)
  | Mvg.Var var ->
    begin match Mvg.VariableMap.find var ctx.ctx_var_mapping with
      | Int int_var -> (Ast.same_pos_as (Specifisc.IntVar int_var) e, [], ctx)
      | _ -> assert false (* should not happen *)
    end
  | Mvg.LocalVar lvar ->
    begin match Mvg.LocalVariableMap.find lvar ctx.ctx_local_var_mapping with
      | Int int_var -> (Ast.same_pos_as (Specifisc.IntVar int_var) e, [], ctx)
      | _ -> assert false (* should not happen *)
    end
  | Mvg.LocalLet (lvar, e1, e2) ->
    if Mvg.LocalVariableMap.find lvar ctx.ctx_typ_info.typ_info_local_var <> Mvg.Boolean then
      assert false (* should not happen *);
    let se1, conds1, ctx = translate_arithmetic_expression e1 ctx in
    let int_var = Specifisc.IntVariable.new_var
        (Ast.same_pos_as ("t" ^ (string_of_int lvar.Mvg.LocalVariable.id)) e)
        (Ast.same_pos_as ("Local variable") e)
    in
    let ctx =
      { ctx with
        ctx_local_var_mapping = Mvg.LocalVariableMap.add lvar (Int int_var) ctx.ctx_local_var_mapping;
      } in
    let se2, conds2, ctx = translate_arithmetic_expression e2 ctx in
    (se2, conds2@[Specifisc.IntDef (int_var, se1)]@conds1, ctx)
  | Mvg.FunctionCall (Mvg.ArrFunc, [arg]) ->
    let sarg, conds, ctx = translate_arithmetic_expression arg ctx in
    (Ast.same_pos_as (Specifisc.FunctionCall (Ast.same_pos_as arr_func_id e, [sarg])) e, conds, ctx)
  | Mvg.FunctionCall (Mvg.InfFunc, [arg]) ->
    let sarg, conds, ctx = translate_arithmetic_expression arg ctx in
    (Ast.same_pos_as (Specifisc.FunctionCall (Ast.same_pos_as inf_func_id e, [sarg])) e, conds, ctx)
  | _ ->
    raise
      (Errors.UnsupportedBySpecifisc
         (Printf.sprintf "expression %s" (Format_ast.format_position (Ast.get_position e))
         )
      )

let translate_variable_data
    (var: Mvg.Variable.t)
    (data: Mvg.variable_data)
    (ctx: ctx)
  : Specifisc.command list * ctx =
  match data.Mvg.var_definition with
  | InputVar -> [], ctx
  | TableVar (_, def) ->
    raise
      (Errors.UnsupportedBySpecifisc
         (Printf.sprintf "table variable %s" (Format_ast.format_position (match def with
              | IndexGeneric e -> Ast.get_position e
              | IndexTable es -> Ast.get_position (snd (Mvg.IndexMap.choose es))
            ))
         )
      )
  | SimpleVar e ->
    begin match Mvg.VariableMap.find var ctx.ctx_typ_info.Typechecker.typ_info_var with
      | (Mvg.Boolean, _) ->
        let bool_var = Specifisc.BoolVariable.new_var (var.Mvg.Variable.name) (var.Mvg.Variable.descr) in
        let se, conds, ctx = translate_logical_expression e ctx in
        let new_cmds = (Specifisc.BoolDef (bool_var, se))::conds in
        (new_cmds,
         { ctx with
           ctx_var_mapping = Mvg.VariableMap.add var (Bool bool_var) ctx.ctx_var_mapping
         })
      | (Mvg.Integer | Mvg.Real as t, _) ->
        let int_var = Specifisc.IntVariable.new_var (var.Mvg.Variable.name) (var.Mvg.Variable.descr) in
        let se, conds, ctx = translate_arithmetic_expression e ctx in
        let new_cmds = (Specifisc.IntDef (int_var, se))::conds in
        (new_cmds,
         { ctx with
           ctx_var_mapping = Mvg.VariableMap.add var (
               match t with
               | Mvg.Integer -> Int int_var
               | _ -> assert false (*s should not happen *)
             ) ctx.ctx_var_mapping
         })
    end

let translate_cond
    (cond: Mvg.condition_data)
    (ctx: ctx)
  : Specifisc.command list * ctx =
  let se, conds, ctx = translate_logical_expression cond.cond_expr ctx in
  let new_cmds = (Specifisc.Constraint se)::conds in
  (new_cmds, ctx )

let translate_program (program: Mvg.program) (typing : Typechecker.typ_info) : Specifisc.program =
  let exec_order = Execution_order.get_execution_order program in
  let func_body, _ = List.fold_left (fun (cmds, ctx) scc  ->
      if Mvg.VariableMap.cardinal scc > 1 then
        raise (Errors.UnsupportedBySpecifisc
                 (Printf.sprintf "circular variable dependencies (%s)"
                    (String.concat "," (List.map (fun (var, _) ->
                         Ast.unmark var.Mvg.Variable.name) (Mvg.VariableMap.bindings scc)))))
      else
        Mvg.VariableMap.fold (fun var () (cmds, ctx) ->
            try let data = Mvg.VariableMap.find var program.program_vars in
              let new_cmds, ctx = translate_variable_data var data ctx in
              (new_cmds@cmds, ctx)
            with
            | Not_found ->
              try
                let cond = Mvg.VariableMap.find var program.program_conds in
                let new_cmds, ctx = translate_cond cond ctx in
                (new_cmds@cmds, ctx)
              with
              | Not_found -> assert false
          )
          scc (cmds, ctx)) ([], empty_ctx typing) exec_order
  in
  let func_body = List.rev func_body in
  let func_id = Specifisc.FunctionVariable.new_var ("Whole program", Ast.no_pos) ("", Ast.no_pos) in
  {
    Specifisc.program_functions = Specifisc.FunctionVariableMap.singleton func_id {
        Specifisc.body = func_body;
        Specifisc.inputs = assert false;
        Specifisc.outputs = assert false;
      };
    Specifisc.arith_functions = assert false
  }
(*
  Copyright 2018 Denis Merigoux and INRIA

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

      http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
*)

(** Helpers for parsing *)

let current_file: string ref = ref ""

let mk_position sloc = {
  Ast.pos_filename = !current_file;
  Ast.pos_loc = sloc;
}

let parse_variable_name sloc (s: string) : Ast.variable_name =
  if not (String.equal (String.uppercase_ascii s) s) then
    Errors.parser_error sloc "invalid variable name"
  else
    s

let dup_exists l =
  let rec dup_consecutive = function
    | [] | [_] -> false
    | c1::(c2 as h2)::tl -> Char.equal c1 c2 || dup_consecutive (h2::tl)
  in
  let sort_on_third s1 s2 = Char.compare s1 s2 in
  dup_consecutive (List.sort sort_on_third l)

let parse_variable_generic_name sloc (s: string) : Ast.variable_generic_name =
  let parameters = ref [] in
  for i = String.length s - 1 downto 0 do
    let p = String.get s i in
    if p = '_' || Str.string_match (Str.regexp "[0-9]+") (String.make 1 p) 0 ||
       not (Char.equal (Char.lowercase_ascii p) p)
    then
      ()
    else begin
      parameters := p::!parameters;
    end
  done;
  if dup_exists !parameters then
    Errors.parser_error sloc "variable parameters should have distinct names";
  { Ast.parameters = !parameters; Ast.base = s }

let parse_variable sloc (s:string) =
  try Ast.Normal (parse_variable_name sloc s) with
  | Errors.ParsingError _ ->
    try Ast.Generic (parse_variable_generic_name sloc s) with
    | Errors.ParsingError _ ->
      Errors.parser_error sloc "invalid variable name"

type parse_val =
  | ParseVar of Ast.variable
  | ParseInt of int

let parse_variable_or_int sloc (s:string) : parse_val  =
  try ParseInt (int_of_string s) with
  | Failure _ ->
    try ParseVar (Ast.Normal (parse_variable_name sloc s)) with
    | Errors.ParsingError _ ->
      try ParseVar (Ast.Generic (parse_variable_generic_name sloc s)) with
      | Errors.ParsingError _ ->
        Errors.parser_error sloc "invalid variable name"

let parse_table_index sloc (s: string) : Ast.table_index =
  if String.equal s "X" then
    Ast.GenericIndex
  else
    try Ast.LiteralIndex(int_of_string s) with
    | Failure _ ->
      begin try Ast.SymbolIndex (parse_variable sloc s) with
        | Errors.ParsingError _ ->
          Printf.printf "s: %s, %b\n" s (String.equal s "X");
          Errors.parser_error sloc "table index should be an integer"
      end

let parse_literal sloc (s: string) : Ast.literal =
  try Ast.Int (int_of_string s) with
  | Failure _ -> try Ast.Float (float_of_string s) with
    | Failure _ ->
      Ast.Variable (parse_variable sloc s)

let parse_func_name sloc (s: string) : Ast.func_name =
  (s)

let parse_int sloc (s: string) : int =
  try int_of_string s with
  | Failure _ ->
    Errors.parser_error sloc "should be an integer"

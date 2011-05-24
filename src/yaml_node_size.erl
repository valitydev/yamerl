-module(yaml_node_size).

-include("yaml_parser.hrl").
-include("yaml_tokens.hrl").
-include("yaml_repr.hrl").
-include("yaml_nodes.hrl").

%% Public API.
-export([
    tags/0,
    try_represent_token/3,
    represent_token/3,
    node_pres/1
  ]).

-define(TAG, "tag:yakaz.com,2011:size").

-define(REGEX, "([0-9]+)(k|M|G|T)(B?)").

%% -------------------------------------------------------------------
%% Public API.
%% -------------------------------------------------------------------

tags() -> [?TAG].

try_represent_token(Repr, Node,
  #yaml_scalar{tag = #yaml_tag{uri = {non_specific, "?"}}} = Token) ->
    try
        represent_token(Repr, Node, Token)
    catch
        _:#yaml_parser_error{name = not_a_size} ->
            unrecognized
    end;
try_represent_token(_, _, _) ->
    unrecognized.

represent_token(#yaml_repr{simple_structs = true},
  undefined, #yaml_scalar{text = Text} = Token) ->
    case string_to_size(Text) of
        error ->
            exception(Token);
        Int ->
            {finished, Int}
    end;
represent_token(#yaml_repr{simple_structs = false},
  undefined, #yaml_scalar{text = Text} = Token) ->
    Pres = yaml_repr:get_pres_details(Token),
    case string_to_size(Text) of
        error ->
            exception(Token);
        Int ->
            Node = #yaml_int{
              module = ?MODULE,
              tag    = ?TAG,
              pres   = Pres,
              value  = Int
            },
            {finished, Node}
    end;

represent_token(_, _, Token) ->
    exception(Token).

node_pres(Node) ->
    ?NODE_PRES(Node).

%% -------------------------------------------------------------------
%% Internal functions.
%% -------------------------------------------------------------------

string_to_size(Text) ->
    case re:run(Text, ?REGEX, [{capture, all_but_first, list}]) of
        {match, [I, U, B]} ->
            Multiplier = case {U, B} of
                {"k", "B"} -> 1024;
                {"k", _}   -> 1000;
                {"M", "B"} -> 1048576;
                {"M", _}   -> 1000000;
                {"G", "B"} -> 1073741824;
                {"G", _}   -> 1000000000;
                {"T", "B"} -> 1099511627776;
                {"T", _}   -> 1000000000000
            end,
            case yaml_node_int:string_to_integer(I) of
                error ->
                    error;
                Int ->
                    Int * Multiplier
            end;
        nomatch ->
            error
    end.

exception(Token) ->
    Error = #yaml_parser_error{
      name   = not_a_size,
      token  = Token,
      text   = "Invalid size",
      line   = ?TOKEN_LINE(Token),
      column = ?TOKEN_COLUMN(Token)
    },
    throw(Error).

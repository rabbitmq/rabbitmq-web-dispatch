-module(rabbit_mochiweb).

-export([register_handler/4, register_global_handler/1]).
-export([register_context_handler/3, register_static_context/4]).
-export([static_context_selector/1, static_context_handler/3, static_context_handler/2]).
-export([register_authenticated_static_context/5]).

%% Handler Registration

%% @doc Registers a completely dynamic selector and handler combination, with
%% a link to display in the global context.
register_handler(Selector, Handler, LinkPath, LinkDesc) ->
    rabbit_mochiweb_registry:add(Selector, Handler, {LinkPath, LinkDesc}).

%% Utility Methods for standard use cases

%% @spec register_global_handler(HandlerFun) -> ok
%% @doc Sets the fallback handler for the global mochiweb instance.
register_global_handler(Handler) ->
    rabbit_mochiweb_registry:set_fallback(Handler).

%% @spec register_context_handler(Context, Handler, Link) -> ok
%% @doc Registers a dynamic handler under a fixed context path, with
%% link to display in the global context.
register_context_handler(Context, Handler, LinkDesc) ->
    rabbit_mochiweb_registry:add(
      fun(Req) ->
              "/" ++ Path = Req:get(raw_path),
              (Path == Context) or (string:str(Path, Context ++ "/") == 1)
      end,
      Handler,
      {Context, LinkDesc}).

%% @doc Convenience function registering a fully static context to
%% serve content from a module-relative directory, with
%% link to display in the global context.
register_static_context(Context, Module, FSPath, LinkDesc) ->
    register_handler(static_context_selector(Context),
                     static_context_handler(Context, Module, FSPath),
                     Context, LinkDesc).

%% @doc Produces a selector for use with register_handler that
%% responds to GET and HEAD HTTP methods for resources within the
%% given fixed context path.
static_context_selector(Context) ->
    fun(Req) ->
            "/" ++ Path = Req:get(raw_path),
            case Req:get(method) of
                Method when Method =:= 'GET'; Method =:= 'HEAD' ->
                    (Path == Context) or (string:str(Path, Context ++ "/") == 1);
                _ ->
                    false
            end
    end.

%% @doc Produces a handler for use with register_handler that serves
%% up static content from a directory specified relative to the
%% directory containing the ebin directory containing the named
%% module's beam file.
static_context_handler(Context, Module, FSPath) when is_atom(Module) ->
    static_context_handler(Context, [Module], FSPath);

static_context_handler(Context, Modules, FSPath) ->
    static_context_handler(
      Context, [filename:join(module_path(M), FSPath) || M <- Modules]).

module_path(Module) ->
    {file, Here} = code:is_loaded(Module),
    filename:dirname(filename:dirname(Here)).

%% @doc Produces a handler for use with register_handler that serves
%% up static content from a specified directory.
static_context_handler("", LocalPaths) ->
    fun(Req) ->
            "/" ++ Path = Req:get(raw_path),
            serve_file(Req, Path, LocalPaths)
    end;
static_context_handler(Context, LocalPaths) ->
    fun(Req) ->
            "/" ++ Path = Req:get(raw_path),
            case string:substr(Path, length(Context) + 1) of
                ""        -> Req:respond({301, [{"Location", "/" ++ Context ++ "/"}], ""});
                "/" ++ P  -> serve_file(Req, P, LocalPaths)
            end
    end.

serve_file(Req, Path, [LocalPath]) ->
    Req:serve_file(Path, LocalPath);
serve_file(Req, Path, [LocalPath | Others]) ->
    case filelib:is_file(filename:join([LocalPath, Path])) of
        true  -> Req:serve_file(Path, LocalPath);
        false -> serve_file(Req, Path, [Others])
    end.

%% @doc Register a fully static but HTTP-authenticated context to
%% serve content from a module-relative directory, with link to
%% display in the global context.
register_authenticated_static_context(Context, Module, FSPath, LinkDesc,
                                      AuthFun) ->
    RawHandler = static_context_handler(Context, Module, FSPath),
    Unauthorized = {401, [{"WWW-Authenticate",
                           "Basic realm=\"" ++ LinkDesc ++ "\""}], ""},
    Handler =
        fun (Req) ->
                case rabbit_mochiweb_util:parse_auth_header(
                       Req:get_header_value("authorization")) of
                    [Username, Password] ->
                        case AuthFun(Username, Password) of
                            true -> RawHandler(Req);
                            _    -> Req:respond(Unauthorized)
                        end;
                    _ ->
                        Req:respond(Unauthorized)
                end
        end,
    register_handler(static_context_selector(Context),
                     Handler, Context, LinkDesc).

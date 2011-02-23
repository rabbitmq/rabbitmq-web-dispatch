%% This file contains an adapted version of webmachine_mochiweb:loop/1
%% from webmachine (revision 0c4b60ac68b4).

%% All modifications are (C) 2011 VMware, Inc.

-module(rabbit_webmachine).

%% An alternative to webmachine_mochiweb, which places the dispatch
%% table (among other things) into the application env, and thereby
%% makes it impossible to run more than one instance of
%% webmachine. Since rabbit_mochiweb is all about multi-tenanting
%% webapps, clearly this won't do for us.

%% Instead of using webmachine_mochiweb:start/1 or
%% webmachine_mochiweb:loop/1, construct a loop procedure using
%% makeloop/1 and supply it as the argument to
%% rabbit_mochiweb:register_context_handler or to mochiweb_http:start.

%% We hardwire the "error handler" and use a "logging module" if
%% supplied.

-export([makeloop/1, makeloop/2, setup/0]).

setup() ->
    %% Many internal procedures in webmachine check the application
    %% env for the error_handler.
    application:set_env(webmachine, error_handler, webmachine_error_handler).

makeloop(Dispatch) ->
    makeloop(Dispatch, none).

makeloop(Dispatch, LogModule) ->
    fun (MochiReq) ->
            Req = webmachine:new_request(mochiweb, MochiReq),
            {Path, _} = Req:path(),
            %% webmachine_mochiweb:loop/1 uses dispatch/3 here;
            %% however, we don't need to dispatch by the host name.
            case webmachine_dispatcher:dispatch(Path, Dispatch) of
                {no_dispatch_match, _Host, _PathElements} ->
                    {ErrorHTML, ReqState1} =
                        webmachine_error_handler:render_error(
                          404, Req, {none, none, []}),
                    Req1 = {webmachine_request, ReqState1},
                    {ok, ReqState2} = Req1:append_to_response_body(ErrorHTML),
                    Req2 = {webmachine_request,ReqState2},
                    {ok, ReqState3} = Req2:send_response(404),
                    maybe_log_access(LogModule, ReqState3);
                {Mod, ModOpts, HostTokens, Port, PathTokens, Bindings,
                 AppRoot, StringPath} ->
                    BootstrapResource = webmachine_resource:new(x,x,x,x),
                    {ok, Resource} = BootstrapResource:wrap(Mod, ModOpts),
                    {ok,RS1} = Req:load_dispatch_data(Bindings,HostTokens,Port,
                                                      PathTokens,AppRoot,StringPath),
                    XReq1 = {webmachine_request,RS1},
                    {ok,RS2} = XReq1:set_metadata('resource_module', Mod),
                    try
                        webmachine_decision_core:handle_request(Resource, RS2)
                    catch
                        error:_ ->
                            FailReq = {webmachine_request,RS2},
                            {ok,RS3} = FailReq:send_response(500),
                            maybe_log_access(LogModule, RS3)
                    end
            end
    end.

maybe_log_access(none, _) -> ok;
maybe_log_access(Mod, ReqState) ->
    Req = {webmachine_request,ReqState},
    {LogData,_ReqState1} = Req:log_data(),
    Mod:log_access(LogData).

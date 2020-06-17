%% The contents of this file are subject to the Mozilla Public License
%% Version 1.1 (the "License"); you may not use this file except in
%% compliance with the License. You may obtain a copy of the License
%% at https://www.mozilla.org/MPL/
%%
%% Software distributed under the License is distributed on an "AS IS"
%% basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
%% the License for the specific language governing rights and
%% limitations under the License.
%%
%% The Original Code is RabbitMQ.
%%
%% The Initial Developer of the Original Code is GoPivotal, Inc.
%% Copyright (c) 2010-2020 VMware, Inc. or its affiliates.  All rights reserved.
%%

-module(rabbit_cowboy_middleware).
-behavior(cowboy_middleware).

-export([execute/2]).

execute(Req, Env) ->
    %% Find the correct dispatch list for this path.
    Listener = maps:get(rabbit_listener, Env),
    case rabbit_web_dispatch_registry:lookup(Listener, Req) of
        {ok, Dispatch} ->
            {ok, Req, maps:put(dispatch, Dispatch, Env)};
        {error, Reason} ->
            Req2 = cowboy_req:reply(500,
                #{<<"content-type">> => <<"text/plain">>},
                "Registry Error: " ++ io_lib:format("~p", [Reason]), Req),
            {stop, Req2}
    end.

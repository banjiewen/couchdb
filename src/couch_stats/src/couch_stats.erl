% Licensed under the Apache License, Version 2.0 (the "License"); you may not
% use this file except in compliance with the License. You may obtain a copy of
% the License at
%
%   http://www.apache.org/licenses/LICENSE-2.0
%
% Unless required by applicable law or agreed to in writing, software
% distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
% WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
% License for the specific language governing permissions and limitations under
% the License.

-module(couch_stats).

-export([
    start/0,
    stop/0,
    fetch/0,
    reload/0,
    sample/2,
    new/2,
    delete/2,
    list/0,
    increment_counter/1,
    increment_counter/2,
    decrement_counter/1,
    decrement_counter/2,
    update_histogram/2,
    update_gauge/2
]).

-type response() :: ok | {error, unknown_metric}.
-type stat() :: {any(), [{atom(), any()}]}.

start() ->
    application:start(couch_stats).

stop() ->
    application:stop(couch_stats).

fetch() ->
    couch_stats_aggregator:fetch().

reload() ->
    couch_stats_aggregator:reload().

-spec sample(any(), atom()) -> stat().
sample(Name, counter) ->
    moslof_counter:read(Name);
sample(Name, gauge) ->
    moslof_gauge:read(Name);
sample(Name, histogram) ->
    moslof_windowed_histogram:read(Name).

-spec new(atom(), any()) -> ok | {error, atom()}.
new(counter, Name) ->
    moslof_counter:new(Name);
new(gauge, Name) ->
    moslof_gauge:new(Name);
new(histogram, Name) ->
    {ok, Time} = application:get_env(couch_stats, collection_interval),
    %% TODO: expose bounds and clean up
    moslof_windowed_histogram:new(Name, Time * 1000, Time * 100, 1, 1000000, 3);
new(_, _) ->
    {error, unsupported_type}.

delete(Name, counter) ->
    moslof_counter:delete(Name);
delete(Name, gauge) ->
    moslof_gauge:delete(Name);
delete(Name, histogram) ->
    moslof_windowed_histogram:delete(Name);
delete(_, _) ->
    {error, unsupported_type}.

list() ->
    moslof_counter:list() ++ moslof_gauge:list() ++ moslof_windowed_histogram:list().

-spec increment_counter(any()) -> response().
increment_counter(Name) ->
    moslof_counter:inc(Name).

-spec increment_counter(any(), pos_integer()) -> response().
increment_counter(Name, Value) ->
    moslof_counter:inc(Name, Value).

-spec decrement_counter(any()) -> response().
decrement_counter(Name) ->
    moslof_counter:dec(Name).

-spec decrement_counter(any(), pos_integer()) -> response().
decrement_counter(Name, Value) ->
    moslof_counter:dec(Name, Value).

-spec update_gauge(any(), number()) -> response().
update_gauge(Name, Value) ->
    moslof_gauge:update(Name, Value).

-spec update_histogram(any(), number()) -> response();
                      (any(), function()) -> any().
update_histogram(Name, Fun) when is_function(Fun, 0) ->
    Begin = os:timestamp(),
    Result = Fun(),
    Duration = timer:now_diff(os:timestamp(), Begin) div 1000,
    moslof_windowed_histogram:update(Name, Duration),
    Result;
update_histogram(Name, Value) when is_number(Value) ->
    moslof_windowed_histogram:update(Name, Value).

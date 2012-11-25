-module(filter_fir).
-behaviour(gen_server).

%% api
-export([start_link/2, in/2, out/1]).

%% callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
	terminate/2, code_change/3]).

-record(state, {params, destination, queue, out = 0}).


%% api

start_link(Params, Dest) ->
	gen_server:start_link(?MODULE, [Params, Dest], []).

in(Server, Value) ->
	gen_server:cast(Server, {in, Value}),
	ok.

out(Pid) ->
	receive
		{out, Pid, Value} -> Value
	end.

%% callbacks

init([Params, Dest]) ->
	Queue = lists:foldl(fun(_, Q) -> queue:in(0, Q) end, queue:new(),
		lists:seq(1, length(Params))),
	{ok, #state{params = Params, queue = Queue, destination = Dest}}.


handle_cast({in, In}, State) ->
	Out = State#state.out,
	case State#state.destination of
		{iir, Pid} -> filter_iir:in(Pid, Out);
		Pid when is_pid(Pid) -> Pid ! {out, self(), Out}
	end,
	Queue = queue:in(In, queue:drop(State#state.queue)),
	Out1 = run(lists:reverse(queue:to_list(Queue)), State#state.params),
	{noreply, State#state{queue = Queue, out = Out1}}.


handle_call(_Request, _From, State) -> {noreply, State}.
handle_info(_Info, State) -> {noreply, State}.
terminate(_Reason, _State) -> ok.
code_change(_OldVsn, State, _Extra) -> {ok, State}.


%% internal functions

run(Queue, Params) ->
	run(Queue, Params, []).

run([], [], Result) ->
	lists:sum(Result);

run([QueueItem | Queue], [Param | Params], Result) ->
	run(Queue, Params, [QueueItem * Param | Result]).


%%%----------------------------------------------------------------------
%%% File    : transport/xmpp/xmpp_handler.erl
%%% Author  : 0xAX <anotherworldofworld@gmail.com>
%%% Purpose : Xmpp messages handler
%%%----------------------------------------------------------------------
-module(xmpp_handler).

-behavior(gen_server).

-export([start_link/0]).
 
%% gen_server callbacks
-export([init/1,
         handle_call/3,
         handle_cast/2,
         handle_info/2,
         terminate/2,
         code_change/3]).
 
% state
-record(state, {
        % xmpp bot nick
        nick = "",
        % xmpp client pid
        xmpp_client_pid :: pid()
    }).

start_link() ->
    gen_server:start_link(?MODULE, [], []).

init([]) ->
    {ok, #state{}}.
 
handle_call(_Request, _From, State) ->
    {reply, ignored, State}.

handle_cast({xmpp_client, ClientPid, BotNick}, State) ->
    % Get first symbol of bot nick name
    [NickSymb | _] = binary_to_list(BotNick),
    % Check this symbol. If it's '@' this is Hipchat.
    Nick = case NickSymb of
        $@ ->
            % return nick
            binary_to_list(BotNick);
        _ ->
            % get nick part
            [TempNick | _] = string:tokens(binary_to_list(BotNick), "@"),
            % return nick
            TempNick
    end,
    % save xmpp client pid
    {noreply, State#state{xmpp_client_pid = ClientPid, nick = Nick}};

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info({incoming_message, From, IncomingMessage}, #state{nick = Nick} = State) ->
    % Check this is message for Ybot or not
    case string:tokens(IncomingMessage, " \r\n") of
        [Nick] ->
            gen_server:cast(State#state.xmpp_client_pid, {send_message, From, "What?"});
        [Nick, "hi"] ->
            gen_server:cast(State#state.xmpp_client_pid, {send_message, From, "Hello :)"});
        [Nick, "bye"] ->    
            gen_server:cast(State#state.xmpp_client_pid, {send_message, From, "Good bue"});
        [Nick, "history"] ->
            % Get history
            History = gen_server:call(ybot_history, {get_history, State#state.xmpp_client_pid}),
            % Send history
            gen_server:cast(State#state.xmpp_client_pid, {send_message, From, History});
        [Nick, "plugins?"] ->
            % Get plugins
            Plugins = gen_server:call(ybot_manager, get_all_plugins),
            % Send plugins label
            gen_server:cast(State#state.xmpp_client_pid, {send_message, From, "Plugins:"}),
            % Make plugins list
            lists:foreach(fun(Plugin) ->
                              {_, _, Pl, _} = Plugin,
                              gen_server:cast(State#state.xmpp_client_pid, {send_message, From, "Plugin:" ++ Pl ++ "\r\n"})
                          end, 
                          Plugins),
            gen_server:cast(State#state.xmpp_client_pid, {send_message, From, "That's all :)"});
        [Nick, Command | _] ->
                % Get command arguments
                Args = string:tokens(ybot_utils:split_at_end(IncomingMessage, Command), "\r\n"),
                % Start process with supervisor which will be execute plugin and send to pid
                ybot_actor:start_link(State#state.xmpp_client_pid, From, Command, Args);
        _ ->
            % this is not our command
            pass
    end,
    % return
    {noreply, State};

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.
 
%% Internal functions
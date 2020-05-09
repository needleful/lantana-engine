% brain.pl contains predicates for solving problems through actions.

:- module(brain, [fulfill/3]).
:- use_module(desires).
:- use_module(environment).

%-----------------------------------------------------%
%   Fulfill is the most important predicate here.
%   It unifies a starting state, target goal, and
%   a set of actions to achieve that goal (Plan).
%-----------------------------------------------------%
fulfill(Start, Target, (State, Cost, Plan)) :-
	Start = (state(_, _, _, _), D),
	is_dict(D, desires),
	search((Start, [], [], 0, 1.0Inf), Target, (State, RPlan, Cost)),
	reverse(RPlan, Plan).

search(((State, Desires), RunningStates, RunningActions, Count, KnownMin), TargetState, Results) :-
	CountCost is Count*0.2,
	CountCost < KnownMin,
	\+member(State, RunningStates),
	(
		sh_target_met(TargetState, State),
		Cost is Desires.cost() + CountCost,
		Results = (State, RunningActions, Cost),
		!
	);
	(
		NewCount is Count + 1,
		findall((S, A), (successor((State, Desires), S, A), \+member(A, RunningActions)), Successors),
		sh_best_path(
			(State, [], 1.0Inf), 
			((State, Desires), [State|RunningStates], RunningActions, NewCount, KnownMin),
			Successors,
			TargetState,
			Results
		)
	).

% Unifies a previous state, next state, and action linking them
successor((OldState, OldDesires), (NewState, NewDesires), Action) :-
	action(Action, OldState, NewState, Effects),
	NewDesires= OldDesires.apply(Effects).

% Searches over a list of successors for the most optimal path to the target state
sh_best_path(Result, _, [], _, Result).
sh_best_path(KnownBest, Conditions, [S|Successors], TargetState, Result) :-
	sh_apply_successor(Conditions, S, C2),
	search(C2, TargetState, SubResult),
	sh_best_result(KnownBest, SubResult, RNext),
	sh_best_path(RNext, Conditions, Successors, TargetState, Result).

sh_apply_successor((_, RS, RA, C, K), (S2, A), (S2, RS, [A|RA], C, K)).

sh_best_result((S1, A1, C1), (S2, A2, C2), Best) :-
	(C1 < C2, Best = (S1, A1, C1));
	(Best = (S2, A2, C2)).

sh_target_met(T, state(T, _, _, _)).
sh_target_met(T, state(_, T, _, _)).
sh_target_met(T, state(_, _, T, _)).
sh_target_met(T, state(_, _, _, T)).

% environment.pl describes the environment and the actions that can be taken in it

:- module(environment, [
	% Defining needs and their importance
	need/2,
	% Defining available actions
	action/4
	]).

need(energy, 1).
need(food, 1).

food(snack, 1).
food(meal, 3).

item(ingredients).
item(I) :- food(I, _).

object(chair).
object(fridge).
object(oven).

contains(fridge, snack).
contains(fridge, ingredients).

% action(Name, OldState, NewState, StatusEffects).
% OldState and NewState are a term with fixed fields for performance and ease of use.
% state(standing/sitting, at(X), holding(I), gained(n)).
action(	cook,
		state(standing, at(oven), holding(ingredients), G),
		state(standing, at(oven), holding(meal), G),
		[(energy, -1)]).

action(	sit,
		state(standing, at(chair), H, _),
		state(sitting, at(chair), H, gained(energy)),
		[(energy, 2)]).

action( stand,
		state(sitting, A, H, G),
		state(standing, A, H, G),
		[(energy, -0.2)]).

action(	drop(I),
		state(standing, A, holding(I), G),
		state(standing, A, holding(nil), G),
		[]
	) :- item(I).

action(	move(Source, Destination),
		state(standing, at(Source), H, G),
		state(standing, at(Destination), H, G),
		[(energy, -0.1)]
	) :- object(Destination), (Source = nil; object(Source)), Source \= Destination.

action(	eat(F), 
		state(S, A, holding(F), _), 
		state(S, A, holding(nil), gained(food)), 
		[(food, Value), (energy, -0.1)]
	) :- food(F, Value).

action(	get(I),
		state(S, at(O), holding(nil), G),
		state(S, at(O), holding(I), G),
		[(energy, -0.1)]
	) :- item(I), object(O), contains(O, I).

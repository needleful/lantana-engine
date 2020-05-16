% Need to separate dictionaries into their own file

:- module(desires, [
	apply/3, 
	cost/2,
	compound_to_dict/2
]).

:- use_module(actions).

compound_to_dict(desires(Food, Energy), desires{food:Food, energy:Energy}).

% Apply status effects of an action
Desires.apply([]) := Desires.
Desires.apply([(Need, Change)|Effects]) := NewDesires :-
	NewValue is Desires.Need - Change,
	NewDesires = Desires.put(Need, NewValue).apply(Effects).

Desires.cost() := Cost :-
	need(food, F),
	need(energy, E),
	Cost is F*Desires.food**2 + E*Desires.energy**2.
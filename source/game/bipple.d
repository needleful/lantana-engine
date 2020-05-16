// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module game.bipple;

import std.random;
import std.stdio;

import swi.experimental;

import game.actor;

struct Bipple
{
	enum ideal = 100;
	enum sitEnergy = 1.5;
	struct need
	{
		// The actual value of the need from 0 to 100 and beyond
		float value;
		// How quickly it drains per real-time second
		float drain;
		// At what point the Bipple will begin trying to make plans to satisfy this need
		float tolerance;
		// If multiple needs are below tolerance, this decides which will be resolved
		ushort priority;

		this(ushort p_rank, float p_drain, float p_tolerance)
		{
			priority = p_rank;
			drain = p_drain;
			tolerance = p_tolerance;
			value = ideal;
		}
	}

	enum NeedType
	{
		food,
		energy
	}

	static BippleEngine engine;

	Action[] plan;
	Actor* actor;
	need[NeedType.max + 1] needs;

	this(ushort seed)
	{
		needs[] =  [
			need(ushort.max, 0, 90),
			need(100, 1, 85)
		];

		plan = [];
	}

	void update(float delta)
	{
		NeedType needToSatisfy;
		int priority = -1;
		foreach(i, ref n; needs)
		{
			n.value -= n.drain * delta;
			if(n.value <= 0)
			{
				onZero(cast(NeedType) i);
			}
			else if(n.value < n.tolerance && n.priority > priority)
			{
				needToSatisfy = cast(NeedType) i;
				priority = n.priority;
			}
		}

		if(actor !is null && actor.state == Actor.State.inProgress)
		{
			if(actor.currentAction.name == Action.sit)
				needs[NeedType.energy].value += sitEnergy*delta;
		}
		else if(plan.length != 0)
		{
			actor.setAction(plan[0]);
			plan = plan[1..$];
		}
		else if(priority >= 0)
		{
			engine.fulfill(needToSatisfy, this);		
		}
	}

	void onZero(NeedType nType)
	{
		if(nType == NeedType.food)
			writeln("This bipple has starved to death.");
		else if(nType == NeedType.energy)
			writeln("This bipple has passed out.");
	}
}

/// Interface between D and Prolog for bipple AI
final class BippleEngine
{
	Predicate pl_fulfill;

	functor_t state, at, holding, gained, desires;
	atom_t sitting, standing, nil, food, energy;

	this()
	{
		pl_fulfill = Predicate("fulfill", 4);

		state = PL_new_functor(PL_new_atom("state"), 4);
		at = PL_new_functor(PL_new_atom("at"), 1);
		holding = PL_new_functor(PL_new_atom("holding"), 1);
		gained = PL_new_functor(PL_new_atom("gained"), 1);
		desires = PL_new_functor(PL_new_atom("desires"), 2);

		sitting = PL_new_atom("sitting");
		standing = PL_new_atom("standing");
		nil = PL_new_atom("nil");
		food = PL_new_atom("food");
		energy = PL_new_atom("energy");

		Action.loadAtoms();
	}

	bool fulfill(Bipple.NeedType need, ref Bipple b)
	{
		Term a0 = Term.args(4);

		auto res = PL_unify_term(a0, 
			PL_FUNCTOR, state,
				PL_ATOM, standing,
				PL_FUNCTOR, at,
					PL_ATOM, nil,
				PL_FUNCTOR, holding,
					PL_ATOM, nil,
				PL_ATOM, nil			
		);

		if(res != TRUE)
		{
			writeln("Failed to unify state terms in fulfill!");
			return false;
		}

		res = PL_unify_term(a0+1,
			PL_FUNCTOR, desires,
				PL_FLOAT, Bipple.ideal - b.needs[0].value,
				PL_FLOAT, Bipple.ideal - b.needs[1].value
			);

		if(res != TRUE)
		{
			writeln("Failed to unify desires in fulfill!");
			return false;
		}

		atom_t desired;
		if(need == Bipple.NeedType.food)
		{
			desired = food;
		}
		else 
		{
			desired = energy;
		}

		res = PL_unify_term(a0+2,
			PL_FUNCTOR, gained,
			PL_ATOM, desired);
		if(res != TRUE)
		{
			writeln("Failed to unify target state in fulfill!");
			return false;
		}

		PL_put_variable(a0+3);

		if(pl_fulfill(a0) == TRUE)
		{
			Term head = Term.empty();
			Term list = Term.copy(a0+3);

			while(PL_get_list(list, head, list))
			{
				Action a;
				PL_get_name_arity(head, &a.name, &a.arity);

				assert(a.arity <= 2, "No support for actions with more than two arguments");

				Term arg = Term.empty();
				foreach(i; 0..a.arity)
				{
					PL_get_arg(i+1, head, arg);
					if(!PL_is_atom(arg))
					{
						writeln("WARNING: only atoms are supported as arguments for actions!  Found arg type %s",PL_term_type(arg));
						Term.print(arg);
						writeln();
						a.arguments[i] = nil;
					}
					else
						PL_get_atom(arg, &a.arguments[i]);
				}
				b.plan ~= a;
			}
			return true;
		}
		else
		{
			return false;
		}
	}
}
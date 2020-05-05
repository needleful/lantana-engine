// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module game.environment;

struct atom
{
	uint id;
}

struct State
{
	Action[] causes;
	Action[] allowedActions;
}

struct Action
{
	State[] newStates;
	Effect[] effects;
}

struct Effect
{
	enum Type
	{
		Constant,
		Function
	}
	atom status;
	union thunk
	{
		double constant;
		double delegate() func;
	}
	
	thunk value;
}
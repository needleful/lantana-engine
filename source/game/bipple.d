// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module game.bipple;

import swi.prolog: atom_t;

/// An abstract agent with a set of needs and plans
/// The Bipple indirectly affects the world through an Actor
struct Bipple
{
	struct Needs
	{
		float energy = 0, food = 0;
	}
	struct State
	{
		atom_t at;
		atom_t holding;
		bool standing;
	}

	Action[] plan;
	Needs needs;
	State state;
}

struct Action
{
	enum Type
	{
		cook,
		sit,
		stand,
		drop,
		move,
		eat,
		get
	}
	// Currently a maximum of two arguments for each action
	atom_t[2] arguments;
	int arg_count;
	Type type;
}
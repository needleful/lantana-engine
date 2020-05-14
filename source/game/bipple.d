// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module game.bipple;

import std.stdio;

struct Bipple
{
	struct need
	{
		// The actual value of the need from 0 up (but typically no greater than 1)
		float value;
		// How quickly it drains per real-time second
		float drain;
		// At what point the Bipple will begin trying to make plans to satisfy this need
		float tolerance;
		// The higher the rank, the more important the need
		ushort ranking;

		this(ushort p_rank, float p_drain, float p_tolerance)
		{
			ranking = p_rank;
			drain = p_drain;
			tolerance = p_tolerance;
			value = 1;
		}
	}

	enum NeedType
	{
		food,
		energy
	}

	need[NeedType.max + 1] needs;

	this(ushort seed)
	{
		needs[] =  [
			need(ushort.max, 1.0/(24*3600), 0.9),
			need(100, 1.0/(8*3600), 0.6)
		];
	}

	void update(float delta)
	{
		foreach(i, ref n; needs)
		{
			n.value -= n.drain * delta;
			if(n.value <= 0)
			{
				onZero(cast(NeedType) i);
			}
		}
	}

	void onZero(NeedType nType)
	{
		if(nType == NeedType.food)
		{
			writeln("This bipple has starved to death.");
		}
		else if(nType == NeedType.energy)
		{
			writeln("This bipple has passed out.");
		}
	}
}
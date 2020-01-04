// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0


module logic.grid;

import gl3n.linalg;

enum GridDirection
{
	UP,
	DOWN,
	LEFT,
	RIGHT,
}

float getRealRotation(GridDirection p_dir) @nogc @safe nothrow
{
	switch(p_dir)
	{
		case GridDirection.UP:
			return 270;
		case GridDirection.DOWN:
			return 90;
		case GridDirection.RIGHT:
			return 0;
		case GridDirection.LEFT:
			return 180;
		default:
			return 0;
	}
}

struct GridPos
{
	alias vt = Vector!(short, 3);
	vt pos;
	this(short x, short y, short z) @nogc nothrow @safe
	{
		pos = vt(x, y, z);
	}

	public bool opEquals(GridPos rhs) @nogc @safe nothrow
	{
		return rhs.pos == pos;
	}

	ref @property short x() @nogc nothrow @safe
	{
		return pos.x;
	}

	ref @property short y() @nogc nothrow @safe
	{
		return pos.y;
	}

	ref @property short z() @nogc nothrow @safe
	{
		return pos.z;
	}

	const @property short x() @nogc nothrow @safe
	{
		return pos.x;
	}

	const @property short y() @nogc nothrow @safe
	{
		return pos.y;
	}

	const @property short z() @nogc nothrow @safe
	{
		return pos.z;
	}
}

// Pushable block
struct GridBlock
{
	GridPos position;
	GridPos pos_target;
}

struct Grid
{
	// Time to go from one grid point to another
	enum TIME_MOVE = 0.25;

	GridBlock[] blocks;
	//Bounds of grid, inclusive (assumed a 3-dimensional rectangle for now)
	GridPos lowBounds, highBounds;
	// Position of lower bounds corner (-x, -y, -z)
	vec3 position;

	@disable this();

	this(GridPos lowBounds, GridPos highBounds, vec3 position = vec3(0,0,0)) @nogc @safe nothrow
	{
		this.lowBounds = lowBounds;
		this.highBounds = highBounds;
		this.position = position;
	}

	GridPos move(GridPos p_from, GridDirection p_dir) @nogc @safe nothrow
	{
		debug import std.stdio;
		GridPos to = p_from;
		switch(p_dir)
		{
			case GridDirection.UP:
				to.z += 1;
				break;
			case GridDirection.DOWN:
				to.z -= 1;
				break;
			case GridDirection.RIGHT:
				to.x += 1;
				break;
			case GridDirection.LEFT:
				to.x -= 1;
				break;
			default:
				assert(false);
		}
		foreach(ref block; blocks)
		{
			if(block.position == to)
			{
				block.position = move(to, p_dir);
				if(block.position == to)
				{
					return p_from;
				}
				debug printf("GRID >> Moving block (%d, %d, %d) -> (%d, %d, %d)\n",
					to.x, to.y, to.z, block.position.x, block.position.y, block.position.z);
				break;
			}
		}
		if(!inBounds(to))
		{
			return p_from;
		}
		return to;
	}

	bool inBounds(GridPos gp) @nogc @safe nothrow const
	{
		return gp.x >= lowBounds.x && gp.x <= highBounds.x
			&& gp.y >= lowBounds.y && gp.y <= highBounds.y
			&& gp.z >= lowBounds.z && gp.z <= highBounds.z;
	}

	vec3 getRealPosition(GridPos gp) @nogc @safe nothrow const
	{
		assert(inBounds(gp));
		return vec3(gp.x, gp.y, gp.z) + position;
	}
}
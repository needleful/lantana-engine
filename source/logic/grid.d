// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0


module logic.grid;

import gl3n.interpolate;
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

	public this(GridPos p_position)
	{
		position = p_position;
		pos_target = p_position;
	}

	/// Sets position and target position
	public void setPosition(short x, short y, short z)
	{
		position = GridPos(x,y,z);
		pos_target = position;
	}
}

struct Grid
{
	// Time it takes for a move to advance
	enum TIME_MOVE = 0.25;

	// Pushable blocks
	GridBlock[] blocks;
	// Unmovable areas
	GridPos[] unmovable;
	//Bounds of grid, inclusive (assumed a 3-dimensional rectangle for now)
	GridPos lowBounds, highBounds;
	// Position of lower bounds corner (-x, -y, -z)
	vec3 position;
	// Timer for movement
	float timer_move = 0;
	bool active = false;

	public this(GridPos lowBounds, GridPos highBounds, vec3 position = vec3(0,0,0)) @nogc @safe nothrow
	{
		this.lowBounds = lowBounds;
		this.highBounds = highBounds;
		this.position = position;
	}

	public void update(float p_delta) @nogc @safe nothrow
	{
		if(!active) return;

		timer_move += p_delta;
		if(timer_move >= TIME_MOVE)
		{
			timer_move = 0;
			active = false;
			foreach(ref block; blocks)
			{
				block.position = block.pos_target;
			}
		}
	}

	public GridPos move(GridPos p_from, GridDirection p_dir, bool p_can_push, ref bool p_pushed) @nogc @safe nothrow
	{
		active = true;

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
		if(!inBounds(to))
		{
			return p_from;
		}
		foreach(ref u; unmovable)
		{
			// Cannot move to this position
			if(u == to)
			{
				return p_from;
			}
		}
		foreach(ref block; blocks)
		{
			if(block.position == to)
			{
				if(!p_can_push)
				{
					return p_from;
				}
				bool pushed;
				block.pos_target = move(to, p_dir, false, pushed);
				if(block.pos_target == to)
				{
					return p_from;
				}
				p_pushed = true;
				//debug printf("GRID >> Moving block (%d, %d, %d) -> (%d, %d, %d)\n",
				//	to.x, to.y, to.z, block.pos_target.x, block.pos_target.y, block.pos_target.z);
				break;
			}
		}
		return to;
	}

	public bool inBounds(GridPos gp) @nogc @safe nothrow const
	{
		return gp.x >= lowBounds.x && gp.x <= highBounds.x
			&& gp.y >= lowBounds.y && gp.y <= highBounds.y
			&& gp.z >= lowBounds.z && gp.z <= highBounds.z;
	}

	public vec3 getRealPosition(GridPos p_current, GridPos p_target) @nogc @safe nothrow const
	{
		assert(inBounds(p_current));
		assert(inBounds(p_target));

		vec3 cur = vec3(p_current.pos);
		vec3 tar = vec3(p_target.pos);

		return lerp(cur, tar, timer_move/Grid.TIME_MOVE) + position;
	}
}
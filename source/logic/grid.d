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

struct GridPos
{
	alias vt = Vector!(short, 3);
	vt pos;
	this(short x, short y, short z) @nogc nothrow @safe
	{
		pos = vt(x, y, z);
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

struct Grid
{
	//Bounds of grid, inclusive (assumed a 3-dimensional rectangle for now)
	GridPos lowBounds, highBounds;
	// Position of lower bounds corner (-x, -y, -z)
	vec3 position;
	// Abolute distances between grid points (assumed a grid of cubes)
	float gridStep;

	@disable this();

	this(GridPos lowBounds, GridPos highBounds, float gridStep = 1, vec3 position = vec3(0,0,0)) @nogc @safe nothrow
	{
		this.lowBounds = lowBounds;
		this.highBounds = highBounds;
		this.gridStep = gridStep;
		this.position = position;
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
		return vec3(gp.x, gp.y, gp.z)*gridStep + position;
	}
}
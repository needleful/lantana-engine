// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0


module logic.grid;

import lanlib.math.vector;

alias GridPos = Vector!(short, 3);

struct Grid
{
	//Bounds of grid, inclusive (assumed a 3-dimensional rectangle for now)
	GridPos lowBounds, highBounds;
	// Position of lower bounds corner (-x, -y, -z)
	Vec3 position;
	// Abolute distances between grid points (assumed a grid of cubes)
	float gridStep;

	@disable this();

	this(GridPos lowBounds, GridPos highBounds, float gridStep = 1, Vec3 position = Vec3(0,0,0)) @nogc @safe nothrow
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

	Vec3 getRealPosition(GridPos gp) @nogc @safe nothrow const
	{
		assert(inBounds(gp));
		return Vec3(gp.x, gp.y, gp.z)*gridStep + position;
	}
}
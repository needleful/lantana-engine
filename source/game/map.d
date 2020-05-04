// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module game.map;

import gl3n.linalg: vec3;
import lantana.types : RealSize, ivec2, Bitfield;


// Grids are sets of points in an abstract space
struct Grid
{
	enum Dir
	{
		UP,
		DOWN,
		LEFT,
		RIGHT
	}
	// Connections in the node
	struct Node
	{
		Bitfield!Dir con;
	}

	Node[] nodes;

	// Bounds of the grid, inclusive
	ivec2 lowBounds, highBounds;

	this(ivec2 low, ivec2 high)
	{
		lowBounds = low;
		highBounds = high;
		nodes.length = width() * height();
	}

	bool inBounds(ivec2 p_gridPos)
	{
		return p_gridPos.x >= lowBounds.x && p_gridPos.x <= highBounds.x 
		       && p_gridPos.y >= lowBounds.y && p_gridPos.y <= highBounds.y;
	}

	bool navigate(ivec2 p_start, ivec2 p_end, ref ivec2[] p_points)
	{
		if(!inBounds(p_start) || !inBounds(p_end))
		{
			return false;
		}

		p_points.length = 0;

		while(p_start.x < p_end.x)
		{
			p_start.x += 1;
			p_points ~= p_start;
		}
		while(p_start.x > p_end.x)
		{
			p_start.x -= 1;
			p_points ~= p_start;
		}
		while(p_start.y < p_end.y)
		{
			p_start.y += 1;
			p_points ~= p_start;
		}
		while(p_start.y > p_end.y)
		{
			p_start.y -= 1;
			p_points ~= p_start;
		}

		return true;
	}

	Node opIndex(ivec2 position)
	{
		if(!inBounds(position))
		{
			return Node.init;
		}

		ivec2 p2 = position - lowBounds;
		int index = p2.x + width()*p2.y;

		return nodes[index];
	}

	int width() @nogc nothrow const
	{
		return highBounds.x - lowBounds.x; 
	}

	int height() @nogc nothrow const
	{
		return highBounds.y - lowBounds.y;
	}
}

struct Room
{
	// The backing grid
	Grid grid;

	// Position (0,0) of the grid in world space
	vec3 center;

	@disable this();

	this(vec3 p_center, ivec2 lowBounds, ivec2 highBounds)
	{
		grid = Grid(lowBounds, highBounds);
		center = p_center;
	}

	vec3 getWorldPosition(ivec2 p_gridPos)
	{
		return center + vec3(p_gridPos.x, 0, p_gridPos.y); 
	}
}
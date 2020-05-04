// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module game.map;

import std.math: abs;

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
	// Connections in the node (and its search status)
	private enum Cn
	{
		UP = cast(uint)Dir.UP,
		DOWN = cast(uint)Dir.DOWN,
		LEFT = cast(uint)Dir.LEFT,
		RIGHT = cast(uint)Dir.RIGHT,
		S_CLOSED
	}

	struct Node
	{
		// Minimum cost to get from the start (infinity if no path)
		float min_cost;

		// Index of ancestor node in search (-1 if no path)
		int ancestor;

		Bitfield!Cn con;
	}

	Node[] nodes;

	// Bounds of the grid, inclusive
	ivec2 lowBounds, highBounds;

	this(ivec2 low, ivec2 high)
	{
		lowBounds = low;
		highBounds = high;
		nodes.length = width() * height();

		int w = width();
		int h = height();
		foreach(int x; 0..w)
		{
			foreach(int y; 0..h)
			{
				int i = x + y*w;
				nodes[i].con.setAll();
				// Boundary checking
				if(x == 0)
				{
					nodes[i].con[Cn.LEFT] = false;
				}
				else if(x == w-1)
				{
					nodes[i].con[Cn.RIGHT] = false;
				}

				if(y == 0)
				{
					nodes[i].con[Cn.DOWN] = false;
				}
				else if(y == h-1)
				{
					nodes[i].con[Cn.UP] = false;
				}
			}
		}
		clearSearch();
	}

	bool inBounds(ivec2 p_gridPos)
	{
		return p_gridPos.x >= lowBounds.x && p_gridPos.x <= highBounds.x 
		       && p_gridPos.y >= lowBounds.y && p_gridPos.y <= highBounds.y;
	}

	bool navigate(Grid.Dir p_dir, ivec2 p_start, ivec2 p_end, ref ivec2[] p_points)
	{
		if(!inBounds(p_start) || !inBounds(p_end))
		{
			return false;
		}

		p_points.length = 0;

		if(p_start == p_end)
		{
			return true;
		}

		clearSearch();

		this[p_start].ancestor = toIndex(p_start);
		int requiredNodes = search(p_dir, p_start, p_end, 0);
		if(requiredNodes == 0)
		{
			return false;
		}

		p_points.length = requiredNodes;
		int idx = toIndex(p_end);

		for(int i = requiredNodes - 1; i >= 0; i--)
		{
			p_points[i] = fromIndex(idx);

			assert(idx > 0, "Invalid antecedent in search");

			idx = nodes[idx].ancestor;
		}

		return true;
	}

	private void clearSearch()
	{
		foreach(ref Node n; nodes)
		{
			n.ancestor = -1;
			n.min_cost = float.infinity;
			n.con[Cn.S_CLOSED] = false;
		}
	}

	private int search(Grid.Dir dir, ivec2 start, ivec2 target, float runningCost)
	{
		Node* n = &this[start];
		assert(n.ancestor >= 0, "Invalid search order");
		n.con[Cn.S_CLOSED] = true;

		int connected = 0;
		ivec2[4] successors;
		float[4] expectedCost;
		float[4] nodeCost;
		Dir[4] nodeDir;

		static immutable(ivec2[]) dirs = [ivec2(1, 0), ivec2(-1, 0), ivec2(0, 1), ivec2(0, -1)];
		import std.meta : AliasSeq;

		// Get the successors
		static foreach(i, cndir; AliasSeq!(Cn.RIGHT, Cn.LEFT, Cn.UP, Cn.DOWN) )
		{
			if(n.con[cndir])
			{
				ivec2 u = start + dirs[i];
				Node* n2 = &this[u];
				Dir d = cast(Dir) (cndir & 0xF);

				// The cost to get here (increases slightly if we have to turn)
				float cost;

				if(dir == d)
				{
					cost = 1;
				}
				else if(opposingDirs(dir, d))
				{
					cost = 1.15; 
				}
				else
				{
					cost = 1.1;
				}

				if(n2.min_cost > cost + runningCost)
				{
					n2.min_cost = cost + runningCost;
					n2.ancestor = toIndex(start);
					n2.con[Cn.S_CLOSED] = false;
				}

				if(u == target)
				{
					n2.con[Cn.S_CLOSED] = true;
					return 1;
				}

				// The likely future cost
				float evaluation = abs(u.x - target.x) + abs(u.y - target.y) + cost;

				if(!n2.con[Cn.S_CLOSED])
				{
					nodeCost[connected] = cost;
					successors[connected] = u;
					expectedCost[connected] = evaluation;
					nodeDir[connected] = d;
					connected++;
				}
			}
		}

		// Sort the three lists based on expectedCost
		for(int i = 1; i < connected; i++)
		{
			for(int j = i; j > 0 && expectedCost[j] < expectedCost[j-1]; j--)
			{
				float tmp_ec = expectedCost[j];
				expectedCost[j] = expectedCost[j-1];
				expectedCost[j-1] = tmp_ec;

				float tmp_nc = nodeCost[j];
				nodeCost[j] = nodeCost[j-1];
				nodeCost[j-1] = tmp_nc;

				ivec2 tmp_s = successors[j];
				successors[j] = successors[j-1];
				successors[j-1] = tmp_s;


				Dir tmp_d = nodeDir[j];
				nodeDir[j] = nodeDir[j-1];
				nodeDir[j-1] = tmp_d;
			}
		}

		for(int i = 0; i < connected; i++)
		{
			int s = search(nodeDir[i], successors[i], target, runningCost + nodeCost[i]);
			if(s != 0)
			{
				return s + 1;
			}
		}

		return 0;
	}

	ref Node opIndex(ivec2 position)
	{
		return nodes[toIndex(position)];
	}

	int width() @nogc nothrow const
	{
		return (highBounds.x - lowBounds.x) + 1; 
	}

	int height() @nogc nothrow const
	{
		return (highBounds.y - lowBounds.y) + 1;
	}

	bool opposingDirs(Dir d1, Dir d2) @nogc nothrow const pure
	{
		if(d1 > d2)
		{
			Dir t = d1;
			d1 = d2;
			d2 = t;
		}
		return (d1 == Dir.UP && d2 == Dir.DOWN)
		        || (d1 == Dir.LEFT && d2 == Dir.RIGHT);
	}

	private ivec2 fromIndex(int index) @nogc nothrow const
	{
		int w = width();
		ivec2 p = ivec2(index % w, index / w);
		return p + lowBounds;
	}

	private int toIndex(ivec2 position) @nogc nothrow const
	{
		ivec2 p2 = position - lowBounds;
		return p2.x + p2.y*width();
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
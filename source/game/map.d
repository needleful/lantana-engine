// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module game.map;

import std.math: abs;

import gl3n.linalg: vec2, vec3;

import lantana.ai.search;
import lantana.types : RealSize, ivec2, Bitfield;


// Grids are sets of points in an abstract space
struct Grid
{
	enum Dir
	{
		UP,
		DOWN,
		LEFT,
		RIGHT,

		UP_LEFT,
		UP_RIGHT,
		DOWN_LEFT,
		DOWN_RIGHT
	}

	static immutable(Dir[]) dirIter = [
		Dir.UP,
		Dir.DOWN,
		Dir.LEFT,
		Dir.RIGHT,

		Dir.UP_LEFT,
		Dir.UP_RIGHT,
		Dir.DOWN_LEFT,
		Dir.DOWN_RIGHT];

	static immutable(ivec2[]) dirs = [
		ivec2(0, 1),
		ivec2(0, -1),
		ivec2(-1, 0),
		ivec2(1, 0),

		ivec2(-1, 1),
		ivec2(1, 1),
		ivec2(-1, -1),
		ivec2(1, -1)
	];

	static immutable(Dir[]) inverseDirIter = [
		Dir.DOWN,
		Dir.UP,
		Dir.RIGHT,
		Dir.LEFT,

		Dir.DOWN_RIGHT,
		Dir.DOWN_LEFT,
		Dir.UP_RIGHT,
		Dir.UP_LEFT
	];

	static immutable(float[]) dirAngles = [
		180, 0, 90, 270,
		135, 225, 45, 315
	];

	struct Node
	{
		Node* ante;
		float minCost, estimated;
		ivec2 pos;
		Bitfield!Dir con;
		bool open;

		bool closed() @nogc nothrow const
		{
			return !open;
		}

		bool opened() @nogc nothrow const
		{
			return open;
		}

		void clear() @nogc nothrow
		{
			open = false;
			con.clear();
		}

		void activate() @nogc nothrow
		{
			con.setAll();
			assert(con.realValue() == 255);
		}

		struct Successor
		{
			Node* node;
			float cost;

			this(Node* p_node, float p_cost) @nogc nothrow
			{
				node = p_node;
				cost = p_cost;
			}
		}
	}

	private struct ScIterator
	{
		Grid* grid;
		Node* source;

		this(Grid* p_grid, Node* p_source)
		{
			grid = p_grid;
			source = p_source;
		}

		int opApply(scope int delegate(ref Node.Successor) dg)
		{
			int result = 0;

			Node.Successor sc;
			static foreach(i, dir; dirIter)
			{
				if(dir == Dir.DOWN_RIGHT)
				{
					result += 1;
				}
				if(source.con[dir])
				{
					float cost = dirs[i].length();
					sc = Node.Successor(&grid.get(source.pos + dirs[i]), cost);
					result = dg(sc);
					if(result != 0)
						return result;
				}
			}

			return result;
		}
	}

	Node[] nodes;
	Node*[] openNodes;
	Node* knownMin = null;

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
				nodes[i].activate();
				nodes[i].pos = ivec2(x, y) + lowBounds;
				// Boundary checking
				if(x == 0)
				{
					nodes[i].con[Dir.LEFT] = false;
					nodes[i].con[Dir.UP_LEFT] = false;
					nodes[i].con[Dir.DOWN_LEFT] = false;
				}
				else if(x == w-1)
				{
					nodes[i].con[Dir.RIGHT] = false;
					nodes[i].con[Dir.UP_RIGHT] = false;
					nodes[i].con[Dir.DOWN_RIGHT] = false;
				}

				if(y == 0)
				{
					nodes[i].con[Dir.DOWN] = false;
					nodes[i].con[Dir.DOWN_LEFT] = false;
					nodes[i].con[Dir.DOWN_RIGHT] = false;
				}
				else if(y == h-1)
				{
					nodes[i].con[Dir.UP] = false;
					nodes[i].con[Dir.UP_LEFT] = false;
					nodes[i].con[Dir.UP_RIGHT] = false;
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

	bool navigate(Dir p_dir, ivec2 p_start, ivec2 p_end, ref ivec2[] p_points)
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

		bool found = search(this, get(p_start), get(p_end));

		if(!found)
		{
			return false;
		}

		Node* startNode = &get(p_start);
		Node* n = &get(p_end);

		while(n != startNode)
		{
			p_points ~= n.pos;
			assert(n.ante != null, "Point without antecedent!");
			n = n.ante;
		}

		import lantana.types.array : reverse;
		p_points = p_points.reverse();

		return true;
	}

	ref Node get(ivec2 position)
	{
		auto id = toIndex(position);
		assert(nodes[id].pos == position);
		return nodes[id];
	}

	int width() @nogc nothrow const
	{
		return (highBounds.x - lowBounds.x) + 1; 
	}

	int height() @nogc nothrow const
	{
		return (highBounds.y - lowBounds.y) + 1;
	}

	void open(Node* n)
	{
		if(knownMin is null || n.estimated < knownMin.estimated)
		{
			knownMin = n;
		}
		if(n.opened())
		{
			return;
		}
		n.open = true;

		openNodes ~= n;
	}

	void close(Node* n)
	{
		n.open = false;
		if(n is knownMin)
		{
			knownMin = null;
		}
		import lantana.types.array;
		openNodes.removeAt(openNodes.indexOf(n));
	}

	ScIterator successors(Node* n)
	{
		return ScIterator(&this, n);
	}

	float estimate(const ref Node start, const ref Node end)
	{
		ivec2 s = start.pos;
		ivec2 e = end.pos;

		float f = (s - e).length();
		return f;
	}

	void removePoint(ivec2 point)
	{
		Node* n = &get(point);

		static foreach(i, dir; dirIter)
		{
			if(n.con[dir])
			{
				ivec2 u = point + dirs[i];
				Node* n2 = &get(u);
				n2.con[inverseDirIter[i]] = false;
			}
		}

		// Take care of corners
		if(n.con[Dir.LEFT])
		{
			Node* n2 = &get(point + dirs[Dir.LEFT]);
			if(n.con[Dir.UP])
			{
				Node* n3 = &get(point + dirs[Dir.UP]);
				n2.con[Dir.UP_RIGHT] = false;
				n3.con[Dir.DOWN_LEFT] = false;
			}
			if(n.con[Dir.DOWN])
			{
				Node* n3 = &get(point + dirs[Dir.DOWN]);
				n2.con[Dir.DOWN_RIGHT] = false;
				n3.con[Dir.UP_LEFT] = false;
			}
		}
		if(n.con[Dir.RIGHT])
		{
			Node* n2 = &get(point + dirs[Dir.RIGHT]);
			if(n.con[Dir.UP])
			{
				Node* n3 = &get(point + dirs[Dir.UP]);
				n2.con[Dir.UP_LEFT] = false;
				n3.con[Dir.DOWN_RIGHT] = false;
			}
			if(n.con[Dir.DOWN])
			{
				Node* n3 = &get(point + dirs[Dir.DOWN]);
				n2.con[Dir.DOWN_LEFT] = false;
				n3.con[Dir.UP_RIGHT] = false;
			}
		}

		n.clear();
	}

	Node* minimumEstimated(Node* source, Node* target)
	{
		if(openNodes.length == 0)
		{
			return null;
		}
		if(knownMin !is null)
		{
			return knownMin;
		}

		size_t id;
		float newMin = float.infinity;
		foreach(i, n; openNodes)
		{
			if(n.estimated < newMin)
			{
				id = i;
				newMin = n.estimated;
			}
		}

		knownMin = openNodes[id];
		return knownMin;
	}

	private void clearSearch()
	{
		knownMin = null;
		foreach(ref Node n; nodes)
		{
			n.open = false;
			n.minCost = float.infinity;
			n.estimated = float.infinity;
			n.ante = null;
		}
		openNodes.length = 0;
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


static ivec2 fromDir(Grid.Dir d)
{
	static foreach(dir; Grid.dirIter)
	{
		if(dir == d)
		{
			return Grid.dirs[dir];
		}
	}
	assert(false, "bad direction");
}

static Grid.Dir fromVector(ivec2 v)
{
	static foreach(dir; Grid.dirIter)
	{
		if(Grid.dirs[dir] == v)
		{
			return dir;
		}
	}
	assert(false, "bad direction");
}

static bool opposing(Grid.Dir a, Grid.Dir b)
{
	return Grid.inverseDirIter[a] == b;
}
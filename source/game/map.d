// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module game.map;

import std.math: abs;
import std.meta : AliasSeq;
import std.stdio;

import gl3n.linalg: vec3;

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
		RIGHT
	}

	// Connections in the node (and its search status)
	private enum Cn
	{
		UP = cast(uint)Dir.UP,
		DOWN = cast(uint)Dir.DOWN,
		LEFT = cast(uint)Dir.LEFT,
		RIGHT = cast(uint)Dir.RIGHT,
		S_OPEN,
	}
	alias dirIter = AliasSeq!(Cn.RIGHT, Cn.LEFT, Cn.UP, Cn.DOWN);
	alias inverseDirIter = AliasSeq!(Cn.LEFT, Cn.RIGHT, Cn.DOWN, Cn.UP);

	static immutable(ivec2[]) dirs = [ivec2(1, 0), ivec2(-1, 0), ivec2(0, 1), ivec2(0, -1)];

	struct Node
	{
		Node* ante;
		float minCost, estimated;
		ivec2 pos;
		Bitfield!Cn con;

		bool closed() @nogc nothrow const
		{
			return !con[Cn.S_OPEN];
		}

		bool opened() @nogc nothrow const
		{
			return con[Cn.S_OPEN];
		}

		void clear() @nogc nothrow
		{
			con.clear();
		}

		void activate() @nogc nothrow
		{
			con.setAll();
		}

		struct Successor
		{
			enum cost = 1;
			Node* node;

			this(Node* p_node) @nogc nothrow
			{
				node = p_node;
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
			if(source.con[Cn.UP])
			{
				sc = Node.Successor(&grid.get(source.pos + ivec2(0, 1)));
				result = dg(sc);
				if(result)
				{
					return result;
				}
			}
			if(source.con[Cn.LEFT])
			{
				sc = Node.Successor(&grid.get(source.pos + ivec2(-1, 0)),);
				result = dg(sc);
				if(result)
				{
					return result;
				}
			}
			if(source.con[Cn.DOWN])
			{
				sc = Node.Successor(&grid.get(source.pos + ivec2(0, -1)));
				result = dg(sc);
				if(result)
				{
					return result;
				}
			}
			if(source.con[Cn.RIGHT])
			{
				sc = Node.Successor(&grid.get(source.pos + ivec2(1, 0)),);
				result = dg(sc);
				if(result)
				{
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

		writefln("$%.02f", n.minCost);

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
		n.con[Cn.S_OPEN] = true;

		openNodes ~= n;
	}

	void close(Node* n)
	{
		n.con[Cn.S_OPEN] = false;
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

		return abs(s.x - e.x) + abs(s.y - e.y);
	}

	void removePoint(ivec2 point)
	{
		Node* n = &get(point);

		static foreach(i, cndir; dirIter)
		{
			if(n.con[cndir])
			{
				ivec2 u = point + dirs[i];
				Node* n2 = &get(u);
				n2.con[inverseDirIter[i]] = false;
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

		int id;
		float newMin = float.infinity;
		foreach(i, n; openNodes)
		{
			if(n.estimated < newMin)
			{
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
			n.con[Cn.S_OPEN] = false;
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
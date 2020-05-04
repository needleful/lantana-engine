// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module game.map;

import std.math: abs;
import std.meta : AliasSeq;

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
		int id;
		Bitfield!Cn con;

		void close() @nogc nothrow
		{
			con[Cn.S_OPEN] = false;
		}

		bool closed() @nogc nothrow const
		{
			return !con[Cn.S_OPEN];
		}

		void open() @nogc nothrow
		{
			con[Cn.S_OPEN] = true;
		}

		bool opened() @nogc nothrow const
		{
			return con[Cn.S_OPEN];
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

		struct ScIterator
		{
			Grid* grid;
			Node* source;

			this(Grid* p_grid, Node* p_source)
			{
				grid = p_grid;
				source = p_source;
			}

			int opApply(scope int delegate(ref Successor) dg)
			{
				int result = 0;

				Successor sc;
				if(source.con[Cn.UP])
				{
					sc = Successor(&grid.nodes[source.id + grid.width()]);
					result = dg(sc);
					if(result)
					{
						return result;
					}
				}
				if(source.con[Cn.DOWN])
				{
					sc = Successor(&grid.nodes[source.id - grid.width()]);
					result = dg(sc);
					if(result)
					{
						return result;
					}
				}
				if(source.con[Cn.LEFT])
				{
					sc = Successor(&grid.nodes[source.id - 1]);
					result = dg(sc);
					if(result)
					{
						return result;
					}
				}
				if(source.con[Cn.RIGHT])
				{
					sc = Successor(&grid.nodes[source.id + 1]);
					result = dg(sc);
					if(result)
					{
						return result;
					}
				}

				return result;
			}
		}
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
				nodes[i].id = i;
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

	bool navigate(ivec2 p_start, ivec2 p_end, ref ivec2[] p_points)
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

		bool found = search(this, this[p_start], this[p_end]);

		if(!found)
		{
			return false;
		}

		Node* startNode = &this[p_start];
		Node* n = &this[p_end];

		while(n != startNode)
		{
			p_points ~= fromIndex(n.id);
			assert(n.ante != null, "Point without antecedent!");
			n = n.ante;
		}

		import std.algorithm : reverse;
		p_points = p_points.reverse();

		return true;
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

	Node.ScIterator successors(Node* n)
	{
		return Node.ScIterator(&this, n);
	}

	float estimate(const ref Node start, const ref Node end)
	{
		ivec2 s = fromIndex(start.id);
		ivec2 e = fromIndex(end.id);

		return abs(s.x - e.x) + abs(s.y - e.y);
	}

	void removePoint(ivec2 point)
	{
		Node* n = &this[point];

		static foreach(i, cndir; dirIter)
		{
			if(n.con[cndir])
			{
				ivec2 u = point + dirs[i];
				Node* n2 = &this[u];
				n2.con[inverseDirIter[i]] = false;
			}
		}

		n.con.clear();
	}

	Node* minimumEstimated(Node* source, Node* target)
	{
		float min = float.infinity;
		Node* found = null;
		foreach(ref n; nodes)
		{
			if(n.opened())
			{
				if(&n is target)
				{
					return &n;
				}
				if(n.estimated < min)
				{
					min = n.estimated;
					found = &n;
				}
			}
		}
		return found;
	}

	private void clearSearch()
	{
		foreach(ref Node n; nodes)
		{
			n.close();
			n.minCost = float.infinity;
			n.estimated = float.infinity;
			n.ante = null;
		}
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
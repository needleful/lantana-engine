// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module lantana.types.layout;

import std.stdio;

import lantana.math.vectors;
import lantana.types.collections;
import lantana.types.core;

/// Bounds for laying out UI elements
public struct SizeRequest
{
	Bounds width;
	Bounds height;

	/// Indicates no preference for size
	public static enum SizeRequest none = SizeRequest(Bounds.none);
	/// Indicates the element should be totally invisible, not just of zero size
	public static enum SizeRequest hide = SizeRequest(Bounds(-double.infinity, -double.infinity));

	public this(Bounds p_width, Bounds p_height) nothrow
	{
		width = p_width;
		height = p_height;
	}

	public this(Bounds p_bounds) nothrow
	{
		width = p_bounds;
		height = p_bounds;
	}

	public this(RealSize p_size) nothrow
	{
		width.min = p_size.width;
		width.max = p_size.width;

		height.min = p_size.height;
		height.max = p_size.height;
	}

	public SizeRequest constrained(Bounds p_width, Bounds p_height) nothrow
	{
		auto sq = SizeRequest(
			width.apply(p_width),
			height.apply(p_height)
		);

		return sq;
	}

	public bool contains(RealSize p_size) nothrow
	{
		return width.contains(p_size.width) && height.contains(p_size.height);
	}

	const public bool inBounds(int p_width, int p_height)  nothrow
	{
		return width.contains(p_width) && height.contains(p_height);
	}

	void print() @nogc nothrow
	{
		//printT("req{% , %}", width, height);
	}
}

public struct Bounds
{
	double min;
	double max;

	public static enum Bounds none = Bounds(-double.infinity, double.infinity);
	public static enum Bounds init = Bounds.none;

	this(double p_min, double p_max) nothrow
	{
		if(p_max < p_min)
		{
			p_max = p_min;
		}
		min = p_min;
		max = p_max;
	}

	this(double p_size) nothrow
	{
		min = p_size;
		max = p_size;
	}

	this(Bounds p_copy)  nothrow
	{
		min = p_copy.min;
		max = p_copy.max;
	}

	public Bounds apply(Bounds rhs) nothrow
	{
		float newMin = this.min > rhs.min ? this.min : rhs.min;
		float newMax = this.max < rhs.max ? this.max : rhs.max;

		return Bounds(newMin, newMax);
	}

	const public bool contains(double value)  nothrow
	{
		return min <= value && max >= value;
	}

	public void print() nothrow @nogc
	{
		printf("(%.1f to %.1f)", min, max);
	}

	T inRange(T)(T val) const nothrow @nogc
	{
		if(val < min)
		{
			return cast(T) min;
		}
		else if(val > max)
		{
			return cast(T) max;
		}
		else
		{
			return val;
		}
	}
}

/// The actual size, in pixels, of a UI element
public struct RealSize
{
	int width;
	int height;

	public this(int p_size) nothrow @nogc
	{
		width = p_size;
		height = p_size;
	}
	
	public this(int p_width, int p_height)  nothrow
	{
		width = p_width;
		height = p_height;
	}

	public this(iVec2 p_vector)  nothrow
	{
		width = p_vector.x;
		height = p_vector.y;
	}

	public RealSize opBinary(string op)(RealSize rhs)  nothrow
	{
		static if(op == "+")
			return RealSize(width + rhs.width, height + rhs.height);
		static if(op == "-")
			return RealSize(width - rhs.width, height - rhs.height);
		else
			assert(false, "No operator '"~op~"' between RealSize objects");
	}
	
	public RealSize opBinary(string op)(double rhs)  nothrow
	{
		static if(op == "/")
			return RealSize(cast(int)(width / rhs), cast(int)(height / rhs));
		static if(op == "*")
			return RealSize(cast(int)(width * rhs), cast(int)(height * rhs));
		else
			assert(false, "No operator '"~op~"' between RealSize and numbers");
	}

	bool opEquals(RealSize rhs)  nothrow const
	{
		return width == rhs.width && height == rhs.height;
	}

	bool contains(RealSize rhs)  nothrow const
	{
		return width >= rhs.width && height >= rhs.height;
	}

	RealSize constrained(SizeRequest req) nothrow const
	{
		return RealSize(req.width.inRange(width), req.height.inRange(height)); 
	}

	long area() @nogc nothrow const
	{
		return width*height;
	}

	void print() @nogc nothrow const
	{
		printf("rs[%d, %d]", width, height);
	}
}

struct Rect
{
	iVec2 pos;
	RealSize size;

	this(iVec2 p_pos, RealSize p_size) nothrow @nogc
	{
		pos = p_pos;
		size = p_size;
	}

	bool contains(iVec2 p_point) const nothrow @nogc
	{
		iVec2 p = p_point - pos;

		return (p.x >= 0 && p.x <= size.width) && (p.y >= 0 && p.y <= size.height);
	}

	bool intersects(Rect rhs) const nothrow @nogc
	{
		iVec2 topRight = iVec2(pos.x + size.width, pos.y + size.height);
		iVec2 topRightRhs = iVec2(rhs.pos.x + rhs.size.width, rhs.pos.y + rhs.size.height);

		return ( (pos.x >= rhs.pos.x && pos.x <= topRightRhs.x) 
		         || (topRight.x >= rhs.pos.x && topRight.x <= topRightRhs.x))
		       && ( (pos.y >= rhs.pos.y && pos.y <= topRightRhs.y) 
		         || (topRight.y >= rhs.pos.y && topRight.y <= topRightRhs.y));
	}

	void print() const @nogc nothrow
	{
		//printT("REC[ ivec(%, %), %]", pos.x, pos.y, size);
	}
}

public struct Pad
{
	byte top, bottom, left, right;

	this(byte p_top, byte p_bottom, byte p_left, byte p_right) nothrow @nogc
	{
		top = p_top;
		bottom = p_bottom;
		left = p_left;
		right = p_right;
	}

	this(byte p_vertical, byte p_horizontal) nothrow @nogc
	{
		top = p_vertical;
		bottom = p_vertical;
		left = p_horizontal;
		right = p_horizontal;
	}

	this(byte p_pad) nothrow @nogc
	{
		top = p_pad;
		bottom = p_pad;
		left = p_pad;
		right = p_pad;
	}

	void print() @nogc nothrow
	{
		printf("pad[%u, %u, %u, %u]", top, bottom, left, right);
	}
}

enum Alignment
{
	TOP,
	CENTER,
	BOTTOM
}
enum HFlag
{
	Expand,
	Center
}
alias HFlags = Bitfield!HFlag;
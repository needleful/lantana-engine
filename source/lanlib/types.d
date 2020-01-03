// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module lanlib.types;

import gl3n.linalg: Vector;
alias svec2 = Vector!(short, 2);
alias ivec2 = Vector!(int, 2);
alias uvec2 = Vector!(uint, 2);

alias Color = Vector!(ubyte, 3);
alias AlphaColor = Vector!(ubyte, 4);

/// Cannot automatically coerce int literals to shorts in constructor, 
/// so this is a function that does exactly that.
/// Otherwise, svec2 requires casting when constructing, like
/// `svec2(cast(short)0, cast(short)1);`
public svec2 svec(int x, int y) @nogc nothrow
{
	return svec2(cast(short) x, cast(short) y);
}

public svec2 svec(ivec2 v) @nogc nothrow
{
	return svec2(cast(short) v.x, cast(short) v.y);
}

public svec2 add(svec2 lhs, svec2 rhs) @nogc nothrow pure
{
	svec2 ret;
	ret.x = cast(short)(lhs.x + rhs.x);
	ret.y = cast(short)(lhs.y + rhs.y);
	return ret;
}

public auto vmax(L, R)(L lhs, R rhs)
	if(is(L == R) && isTemplateType!(Vector, R))
{
	L ret;
	foreach(v; 0..R.dimension)
	{
		ret.vector[v] = rhs.vector[v] > lhs.vector[v] ? rhs.vector[v] : lhs.vector[v];
	}
	return ret;
}

public auto vmin(L, R)(L lhs, R rhs)
	if(is(L == R) && isTemplateType!(Vector, R))
{
	L ret;
	foreach(v; 0..R.dimension)
	{
		ret.vector[v] = rhs.vector[v] < lhs.vector[v] ? rhs.vector[v] : lhs.vector[v];
	}
	return ret;
}

/// Same problem as svec
public AlphaColor color(uint r, uint g, uint b, uint a)
{
	return AlphaColor(cast(ubyte)r, cast(ubyte)g, cast(ubyte)b, cast(ubyte)a);
}

/**
 A strict alias for a given type.
 To use, initialize a struct like this:

 struct MyAlias
 {
	mixin StrictAlias!Type;
 }
 */
mixin template StrictAlias(T)
{
	/// Internal datatype of the alias struct
	alias dt = T;

	private T _handle;

	@disable this(U)(U u);

	this(T data) @nogc @safe nothrow
	{
		_handle = data;
	}

	T handle() const nothrow @nogc @safe pure
	{
		return _handle;
	}

	T* ptr() nothrow @nogc pure
	{
		return &_handle;
	}

	alias handle this;
}

/// Check if Type is an instantiation of the Template
enum isTemplateType(alias Template, Type) = __traits(
	compiles,
	{
		void f(Specs...)(Template!Specs value){}
		f(Type.init);
	}
);

/// Create a bitfield from an enum
/// IMPORTANT: it assumes the enum is tightly packed, e.g it goes 0, 1, 2, etc
struct Bitfield(Enum)
	if(is(Enum == enum))
{
	static if(Enum.max < 8)
	{
		alias dt = ubyte;
		enum bits = 8;
	}
	else static if(Enum.max < 16)
	{
		alias dt = ushort;
		enum bits = 16;
	}
	else static if(Enum.max < 32)
	{
		alias dt = uint;
		enum bits = 32;
	}
	else static if(Enum.max < 64)
	{
		alias dt = ulong;
		enum bits = 64;
	}
	else
	{
		static assert(false, "enums with values larger than 64 are not supported");
	}

	private dt data;

	public bool opIndex(Enum p_index)
	{
		dt mask = cast(dt)(1 << p_index);
		return (data & mask) != 0;
	}

	public void opIndexAssign(bool p_value, Enum p_index)
	{
		// set the flag to zero
		dt inverseMask = cast(dt)(~(1 << p_index));
		data &= inverseMask;

		// set the bit to 0 or 1
		// bools are 1-bit ints, so this is either 0 or 1<<p_index
		dt mask = cast(dt)(p_value << p_index);
		data |= mask;
	}

	public void setAll()
	{
		data = 0;
		dt newval = dt.max;
		data = cast(dt) (newval >>> (bits - Enum.max));
	}

	public void clear()
	{
		data = 0;
	}
}
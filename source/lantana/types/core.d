// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module lantana.types.core;

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
public svec2 svec(int x, int y)  nothrow
{
	return svec2(cast(short) x, cast(short) y);
}

public svec2 svec(ivec2 v)  nothrow
{
	return svec2(cast(short) v.x, cast(short) v.y);
}

public svec2 add(svec2 lhs, svec2 rhs)  nothrow pure
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
public AlphaColor color(uint r, uint g, uint b, uint a = 255) nothrow @nogc
{
	return AlphaColor(cast(ubyte)r, cast(ubyte)g, cast(ubyte)b, cast(ubyte)a);
}

struct Thunk(Type)
{
	alias func = Type delegate();

	func get;

	this(func p_get)
	{
		get = p_get;
	}

	this(Type value)
	{
		get = (){ return value; };
	}

	this(Type* value)
	{
		get = (){ return *value; };
	}

	Type opCall()
	{
		return get();
	}
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

	this(T data)   nothrow
	{
		_handle = data;
	}

	T handle() const nothrow   pure
	{
		return _handle;
	}

	T* ptr() return nothrow pure
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
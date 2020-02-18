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
public AlphaColor color(uint r, uint g, uint b, uint a) nothrow @nogc
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

	this(T data)  @safe nothrow
	{
		_handle = data;
	}

	T handle() const nothrow  @safe pure
	{
		return _handle;
	}

	T* ptr() nothrow  pure
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
		dt newval = dt.max;
		data = cast(dt) (newval >>> (bits - Enum.max));
	}

	public void clear()
	{
		data = 0;
	}
}

struct BitSet(uint Size)
{
	//static assert(size % 64 == 0, "Bitsets must internally have a size that's a multiple of 64");
	enum longCount = (Size+63)/64;
	enum size = longCount*64;

	private ulong[longCount] longs;

	bool get(uint p_index) @nogc nothrow const
	{
		return opIndex(p_index);
	}

	void set(bool p_value, uint p_index) @nogc nothrow
	{
		opIndexAssign(p_value, p_index);
	}

	bool opIndex(uint p_index) @nogc nothrow const
	{
		assert(p_index < size);

		uint longIndex = p_index/64;
		uint subIndex = p_index % 64;

		ulong tmp = longs[longIndex];
		ulong mask = (1LU << subIndex);

		return(tmp & mask) != 0;
	}

	void opIndexAssign(bool p_value, uint p_index) @nogc nothrow
	{
		assert(p_index < size);

		uint longIndex = p_index/64;
		ubyte subIndex = p_index % 64;

		if(p_value)
		{
			ulong mask = (1LU << subIndex);
			longs[longIndex] |= mask;
		}
		else
		{
			ulong mask = ~(1LU << subIndex);
			longs[longIndex] &= mask;
		}
	}

	long firstSetBit() @nogc nothrow const
	{
		uint longIndex = 0;
		ulong val = 0;
		foreach(uint idx, ulong l; longs)
		{
			if(l != 0)
			{
				longIndex = idx;
				val = l;
				break;
			}
		}
		if(val == 0)
		{
			return -1;
		}

		foreach(bitIndex; 0..64)
		{
			if((val & 1) != 0)
			{
				return bitIndex + 64*longIndex;
			}
			val = val >> 1;
		}

		debug assert(false, "Unreachable code!");
		else return -1;
	}

	long nextSetBit(long p_start) @nogc nothrow const
	{

		p_start += 1;
		uint longStart = cast(uint)p_start/64;
		ubyte bitStart = cast(uint)p_start % 64;

		ulong val = longs[longStart] >> bitStart;
		if(val != 0)
		{
			foreach(bitIndex; bitStart..64)
			{
				if((val & 1) != 0)
				{
					return bitIndex + 64*longStart;
				}
				val = val >> 1;
			}
		}

		uint longIndex;
		foreach(idx; (longStart+1)..longCount)
		{
			if(longs[idx] != 0)
			{
				longIndex = idx;
				val = longs[idx];
				break;
			}
		}
		if(val == 0)
		{
			return -1;
		}

		foreach(bitIndex; 0..64)
		{
			if((val & 1)!= 0)
			{
				return bitIndex + 64*longIndex;
			}
			val = val >> 1;
		}

		return -1;
	}

	void setAll() @nogc nothrow
	{
		foreach(ref l; longs)
		{
			l = ulong.max;
		}
	}

	void clearAll() @nogc nothrow
	{
		foreach(ref l; longs)
		{
			l = 0;
		}
	}
}


import std.conv: emplace;
import std.traits: hasUDA;

enum FreeListCompatible;

struct FLRef
{
	static enum FLRef invalid = FLRef(uint.max);
	uint id;

	this(uint p_id)
	{
		id = p_id;
	}
}

class FreeList(Type, uint Count)
{
	static assert(hasUDA!(Type, FreeListCompatible), 
		"Types must be marked with '@FreeListCompatible' to be used in the FreeList");
	private enum size = Count;
	private Type[Count] data;
	private BitSet!Count free;
	private BitSet!Count initialized;

	public this()
	{
		free.setAll();
		initialized.clearAll();
	}

	/// Get a free resource or create a new one
	/// returns FLRef.invalid in the event of a failure.
	public FLRef getOrCreate(A...)(A args)
	{
		long i = free.firstSetBit();
		if(i == -1)
		{
			debug
				assert(false, "Failed to get GPU resource: " ~ Type.stringof);
			else
				return FLRef.invalid;
		}
		uint idx = cast(uint) i;

		if(initialized[idx])
		{
			data[idx].update(args);
		}
		else
		{
			(&data[idx]).emplace!Type(args);
		}

		initialized[idx] = true;
		free[idx] = false;

		return FLRef(idx);
	}

	/// Check if a resource is still being used
	public bool inUse(FLRef p_ref)
	{
		return !free[p_ref.id];
	}

	/// Release a resource (doesn't delete it from GPU)
	/// Returns false if the object was already released
	public void release(FLRef p_ref)
	{
		free[p_ref.id] = true;
	}

	/// Clean up free resources
	/// returns the number of resources deleted
	public uint clean()
	{
		uint cleaned = 0;
		for(auto i = initialized.firstSetBit(); i != -1; i = initialized.nextSetBit(i))
		{
			uint idx = cast(uint) i;
			if(free[idx])
			{
				cleaned ++;
				data[idx].clean();
			}
		}
		return cleaned;
	}
}
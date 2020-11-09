// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module lantana.types.collections;

import std.conv: emplace;
import std.traits;

public auto first(T)(T collection)
{
	foreach(ref val; collection)
	{
		return val;
	}
	assert(false, "No elements in the collection");
}

struct Stack(T)
{
	T[] list;

	void reserve(size_t size)
	{
		list.reserve(size);
	}

	bool pop(out T value)
	{
		if(list.length == 0)
			return false;

		value = list[$-1];
		list.length -= 1;
		return true;
	}

	bool pop()
	{
		if(list.length == 0)
			return false;
		list.length -= 1;
		return true;
	}

	void push(T value)
	{
		list ~= value;
	}

	T peek()
	{
		return list[$-1];
	}

	T peek(int d)
	{
		return list[$-d];
	}
}

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

	public this(Enum[] flags...)
	{
		set(flags);
	}

	public void set(Enum[] flags...)
	{
		dt mask = 0;
		foreach(flag; flags)
		{
			mask |= cast(dt)(1 << flag);
		}
		data |= mask;
	}

	public bool opIndex(Enum p_index) @nogc nothrow const
	{
		dt mask = cast(dt)(1 << p_index);
		return (data & mask) != 0;
	}

	public void opIndexAssign(bool p_value, Enum p_index) @nogc nothrow
	{
		if(p_value)
		{
			dt mask = cast(dt)(1 << p_index);
			data |= mask;
		}
		else
		{	
			// set the flag to zero
			dt inverseMask = cast(dt)(~(1 << p_index));
			data &= inverseMask;
		}
	}

	public void setAll() @nogc nothrow
	{
		dt newval = dt.max;
		data = cast(dt) (newval >>> (bits - (Enum.max + 1)));
	}

	public void clear() @nogc nothrow
	{
		data = 0;
	}

	public dt realValue() const @nogc nothrow
	{
		return data;
	}
}

struct BitSet(uint Size)
{
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

	void opAssign(ref BitSet!Size rhs) @nogc nothrow
	{
		longs[] = rhs.longs[];
	}
}

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

struct SOA(Type)
	if(is(Type == struct))
{
	import std.format;
	import lantana.types.array;
	import lantana.types.meta;

	private enum fieldNames = FieldNameTuple!Type;

	static foreach(i, type; Fields!Type)
	{
		mixin Import!type;
		mixin(format("%s[] %s;", type.stringof, fieldNames[i]));
	}

	void opDispatch(string func, A...)(A args)
	{
		static foreach(field; fieldNames)
		{
			mixin(format("%s.%s(args);", field, func));
		}
	}

	void clear()
	{
		opDispatch!"clear"();
	}
}
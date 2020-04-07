// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module lantana.types.memory;

import std.conv : emplace;
import std.traits;
import core.memory;

debug
{
	import std.stdio;
}

template AlignT(Type)
{
	static if(Type.sizeof <= ubyte.sizeof)
	{
		enum AlignT = ubyte.sizeof;
	}
	else static if(Type.sizeof <= ushort.sizeof)
	{
		enum AlignT = ushort.sizeof;
	}
	else static if(Type.sizeof <= uint.sizeof)
	{
		enum AlignT = uint.sizeof;
	}
	else
	{
		enum AlignT = size_t.sizeof;
	}
}

T* offset(T)(ref ubyte[] p_bytes, ulong p_offset)
{
	return cast(T*) (&p_bytes[p_offset]);
}

T[] addSpace(T)(ref ubyte[] p_bytes, ulong p_count, ref ulong p_start)
{
	/// Aligns data to size_t
	//ushort shiftAlign = (cast(size_t)p_start) % AlignT!T;
	//ulong size = T.sizeof*p_count+shiftAlign;
	//p_start = p_bytes.length+shiftAlign;
	//p_bytes.length += size+shiftAlign;
	p_start = p_bytes.length;
	p_bytes.length += p_count*T.sizeof;

	return p_bytes.offset!T(p_start)[0..p_count]; 
}

void readData(T, U)(ref T p_dest, ref U p_source)
	if(isArray!T && isArray!U && is(Unqual!(ForeachType!T) == Unqual!(ForeachType!U)))
{
	assert(p_dest.length == p_source.length);

	p_dest[0..p_source.length] = p_source[0..p_source.length];

	//import core.stdc.string: memcpy;
	//memcpy(cast(void*)p_dest.ptr, cast(void*)p_source.ptr, T.sizeof*p_source.length);
}

T[] readArray(T)(ubyte[] p_bytes, ulong p_byteOffset, ulong p_count)
{
	ulong byteEnd = p_byteOffset + p_count*T.sizeof;
	assert(byteEnd <= p_bytes.length);

	return p_bytes.offset!T(p_byteOffset)[0..p_count];
}

struct OwnedList(Type)
{
	private Type* m_ptr;
	private ushort m_length;
	private ushort m_capacity;

	this(Type* p_ptr, ushort p_cap) @nogc nothrow @safe
	{
		m_ptr = p_ptr;
		m_capacity = p_cap;
		m_length = 0;
	}

	~this()
	{
		clear();
		m_ptr = null;
		m_capacity = 0;
	}

	void clear()
	{
		m_length = 0;
		foreach(uint i; 0..m_length)
		{
			destroy(m_ptr[i]);
		}
	}

	void clearNoGC() @nogc nothrow @safe
	{
		m_length = 0;
	}

	@property const(Type*) ptr()  nothrow const @safe
	{
		return m_ptr;
	}

	@property ushort length()  nothrow const @safe
	{
		return m_length;
	}

	@property ushort capacity()  nothrow const @safe
	{
		return m_capacity;
	}

	ref Type opIndex(int p_index) @nogc nothrow
	{
		debug assert(p_index >= 0 && p_index < m_length, "Out of range");

		return m_ptr[p_index];
	}

	int opApply(int delegate(ref Type) p_op)
	{
		int result;
		foreach(int i; 0..m_length)
		{
			result = p_op(m_ptr[i]);
			if(result)
			{
				break;
			}
		}
		return result;
	}

	void opOpAssign(string op)(auto ref Type rhs) @nogc nothrow
		if(op == "~")
	{
		assert(m_length + 1 <= m_capacity, "Capacity exceeded");

		m_ptr[m_length] = rhs;
		m_length += 1;
	}

	void place(A...)(auto ref A args)
	{
		assert(m_length + 1 <= m_capacity, "Capacity exceeded");
		emplace!(Type, A)(&m_ptr[m_length], args);
		m_length += 1;
	}

	@property int opDollar()  const nothrow @safe
	{
		return m_length;
	}

	Type[] borrow() 
	{
		return m_ptr[0..m_length];
	}

	int find(ref Type toFind)
	{
		foreach(i; 0..m_length)
		{
			if(m_ptr[i] == toFind)
			{
				return i;
			}
		}
		return -1;
	}
}

struct BaseRegion
{
	import std.experimental.allocator.mmap_allocator;
	Region region;

	this(size_t p_capacity) @nogc
	{
		ubyte* data = cast(ubyte*) MmapAllocator.instance.allocate(p_capacity).ptr;
		GC.addRange(data, p_capacity);

		assert(data != null, "Failed to get memory for region");
		region = Region(data, p_capacity);
	}

	~this() @nogc
	{
		ulong cap = region.capacity();
		region.disable();

		MmapAllocator.instance.deallocate(cast(void[]) region.data[0..cap]);
		GC.removeRange(region.data);
	}

	SubRegion provideRemainder() 
	{
		size_t spaceRemaining = region.capacity() - region.spaceUsed();
		return SubRegion(spaceRemaining, this);
	}

	alias region this;

	Region* ptr() @nogc nothrow
	{
		return &region;
	}
}

struct SubRegion
{
	Region region;

	this(size_t p_capacity, ref BaseRegion p_parent) @nogc
	{
		ubyte* data = p_parent.makeList!ubyte(p_capacity).ptr;
		assert(data != null, "Failed to get memory for region");
		region = Region(data, p_capacity);
	}

	~this()
	{
		region.disable();
	}

	alias region this;

	Region* ptr() @nogc nothrow
	{
		return &region;
	}
}

/++ A Region of memory for dumb data with quick allocation and clearing.
   note: when Region space is freed, it does not call any destructors.
   It is the responsibility of the calling code to call destroy()
   on any objects that manage other resources.
+/
struct Region
{
	enum minimumSize = size_t.sizeof*2;

	ubyte* data;

	this(ubyte* p_data, size_t p_capacity) @nogc
	{
		assert(p_capacity > minimumSize);
		data = p_data;
		setCapacity(p_capacity);
		setSpaceUsed(2*size_t.sizeof);

		debug printf("Creating Region with %u bytes\n", capacity());
	}

	void disable() @nogc
	{
		debug printf("Deleting Region with %u/%u bytes allocated\n", spaceUsed(), capacity());
		setCapacity(0);
		setSpaceUsed(0);
		data = null;
	}

	/+
	 +  User-friendly methods for allocation 
	 +/
	T[] makeList(T)(size_t count)
	{
		//debug printf("MEM: Creating %s[%u]\n", T.stringof.ptr, count);
		//return (cast(T*)allocAligned!(AlignT!T)(T.sizeof * count))[0..count];
		return (cast(T*)alloc(T.sizeof*count))[0..count];
	}

	OwnedList!T makeOwnedList(T)(ushort p_size)
	{
		//return OwnedList!T((cast(T*)allocAligned!(AlignT!T)(T.sizeof * p_size)), p_size);
		return OwnedList!T((cast(T*)alloc(T.sizeof * p_size)), p_size);
	}

	auto make(T, A...)(auto ref A args)
	{
		//debug printf("MEM: Creating instance of %s\n", T.stringof.ptr);
		static if(is(T == class))
		{
			//void[] buffer = allocAligned!(AlignT!T)(T.sizeof)[0..T.sizeof];
			void[] buffer = cast(void[]) alloc(T.sizeof)[0..T.sizeof];
			assert(buffer.ptr != null, "Failed to allocate memory");
			return emplace!(T, A)(buffer, args);
		}
		else
		{
			//T *ptr = cast(T*) allocAligned!(AlignT!T)(T.sizeof);
			T *ptr = cast(T*) alloc(T.sizeof);
			assert(ptr != null, "Failed to allocate memory");
			return emplace!(T, A)(ptr, args);
		}
	}

	T copy(T)(T p_string)
		if(isSomeString!T)
	{
		return cast(T) copyList(p_string);
	}

	private T[] copyList(T)(immutable(T)[] p_list)
	{
		auto newList = makeList!T(p_list.length);
		newList.readData(p_list);
		return newList;
	}

	/// Wipe all data from the stack
	void wipe() @nogc nothrow
	{
		setSpaceUsed(minimumSize);
	}

	private void* alloc(size_t bytes) @nogc
	{
		if((bytes + spaceUsed()) > capacity())
		{
			import std.stdio;
			printf("Exceeded memory limits: %u > %u\n", bytes + spaceUsed(), capacity());
			debug
				assert(false, "Out of memory");
			else
				return null;
		}
		void* result = cast(void*)(&data[spaceUsed]);
		setSpaceUsed(spaceUsed + bytes);

		return result;
	}

	private void* allocAligned(uint alignment)(size_t bytes) @nogc
	{
		ulong address = ((cast(ulong)data)+spaceUsed());
		auto alignShift = address % alignment;
		alignShift = (alignment - alignShift) % alignment;

		assert((address + alignShift) % alignment == 0);
		assert(alignShift <= alignment);

		void* ptr = alloc(bytes + alignShift);

		return &ptr[alignShift];
	}

	private bool remove(void* data) @nogc nothrow
	{
		// Regions don't remove things
		return false;
	}

	size_t capacity() @nogc const nothrow
	{
		return (cast(size_t*)data)[0];
	}

	size_t spaceUsed() @nogc const nothrow
	{
		return (cast(size_t*)data)[1];
	}

	private void setCapacity(size_t val) @nogc nothrow
	{
		(cast(size_t*)data)[0] = val;
	}

	private void setSpaceUsed(size_t val) @nogc nothrow
	{
		(cast(size_t *) data)[1] = val;
	}
}
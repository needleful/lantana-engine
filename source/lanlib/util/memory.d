// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module lanlib.util.memory;

import std.conv : emplace;
import std.traits : hasUDA;
import core.memory;

debug
{
	import std.stdio;
}

struct OwnedRef(Type)
{
	Type* data;

	this(Type* p_data) 
	{
		data = p_data;
	}

	~this() 
	{
		if(data)
			destroy(data);
	}

	void opAssign(Type* p_val)
	{
		destroy(data);
		data = p_val;
	}

	Type* borrow()
	{
		return data;
	}

	alias data this;
}

struct OwnedList(Type)
{
	private Type* m_ptr;
	private ushort m_length;
	private ushort m_capacity;

	this(Type* p_ptr, ushort p_cap) 
	{
		m_ptr = p_ptr;
		m_capacity = p_cap;
		m_length = 0;
	}

	~this()
	{
		foreach(uint i; 0..m_length)
		{
			destroy!false(m_ptr[i]);
		}
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

	ref Type opIndex(int p_index) 
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

	void opOpAssign(string op)(auto ref Type rhs)
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
		size_t used = region.spaceUsed();
		size_t cap = region.capacity();
		region.disable();

		MmapAllocator.instance.deallocate(cast(void[]) region.data[0..cap]);
		GC.removeRange(region.data);
		debug printf("Deleted Region with %u/%u bytes allocated\n", used, cap);
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
		return (cast(T*)alloc(T.sizeof * count))[0..count];
	}

	OwnedList!T makeOwnedList(T)(ushort p_size) 
	{
		return OwnedList!T((cast(T*)alloc(T.sizeof * p_size)), p_size);
	}

	auto make(T, A...)(auto ref A args)
	{
		//debug printf("MEM: Creating instnace of %s\n", T.stringof.ptr);
		static if(is(T == class))
		{
			void[] buffer = alloc(T.sizeof)[0..T.sizeof];
			assert(buffer.ptr != null, "Failed to allocate memory");
			return emplace!(T, A)(buffer, args);
		}
		else
		{
			T *ptr = cast(T*) alloc(T.sizeof);
			assert(ptr != null, "Failed to allocate memory");
			return emplace!(T, A)(ptr, args);
		}
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

//class LanGCAllocator: ref Region
//{
//	void* make(ulong bytes)
//	{
//		import std.experimental.allocator.gc_allocator;
//		return GCAllocator.instance.allocate(bytes).ptr;
//	}

//	bool remove (void* data)
//	{
//		// Automatic
//		return false;
//	}
//}
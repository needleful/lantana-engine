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

/++
  Anything with the @GpuResource attribute must have its destructor called
  once its no longer valid.  As a result, no GpuResource types can be put on 
  a Region.  They must be managed through some other method.
 +/
enum GpuResource;

/++
  An interface for allocating data.
+/
interface ILanAllocator
{
	void* make(ulong bytes) @nogc;

	bool remove(void* data) @nogc;
}

/+
 +  User-friendly methods for allocators 
 +/

T[] makeList(T)(ILanAllocator alloc, ulong count) @nogc
{
	//debug printf("MEM: Creating %s[%u]\n", T.stringof.ptr, count);
	return (cast(T*)alloc.make(T.sizeof * count))[0..count];
}

T *create(T, A...)(ILanAllocator alloc, auto ref A args) @nogc 
{
	//debug printf("MEM: Creating instnace of %s\n", T.stringof.ptr);
	T *ptr = cast(T*) alloc.make(T.sizeof);
	assert(ptr != null, "Failed to allocate memory");
	emplace!(T, A)(ptr, args);
	return ptr;
}

bool remove_list(T)(ILanAllocator alloc, T[] data) @nogc
{
	return alloc.remove(cast(void*) data.ptr);
}

/++
 Manager for system memory.  Wraps malloc() and free()
 +/
class SysMemManager : ILanAllocator
{

	import core.stdc.stdlib : malloc, free;

	override void* make(ulong bytes) @nogc
	{
		void* res = malloc(bytes);
		GC.addRange(cast(ubyte*)res, bytes);
		return res;
	}
	override bool remove(void* data) @nogc
	{
		free(data);
		GC.removeRange(cast(ubyte*)data);
		return true;
	}
}

/++ A Region of memory for dumb data with quick allocation and clearing.
   note: when Region space is freed, it does not call any destructors.
   It is the responsibility of the calling code to call destroy()
   on any objects that manage other resources.
+/
class Region : ILanAllocator
{
	enum minimumSize = ulong.sizeof*2;

	ILanAllocator parent;
	ubyte *data;

	this(ulong p_capacity, ILanAllocator p_parent) @nogc
	{
		parent = p_parent;
		assert(p_capacity > minimumSize);
		data = parent.makeList!ubyte(p_capacity).ptr;

		assert(data != null, "Failed to get memory for region");

		setCapacity(p_capacity);
		setSpaceUsed(2*ulong.sizeof);

		debug printf("Creating Region with %u bytes\n", p_capacity);
	}

	~this() @nogc
	{
		ulong used = spaceUsed();
		ulong cap = capacity();
		setCapacity(0);
		setSpaceUsed(0);
		data = null;
		parent.remove(cast(void*)data);
		debug printf("Deleted Region with %u/%u bytes allocated\n", used, cap);
	}

	override void* make(ulong bytes) @nogc 
	{
		if(bytes + spaceUsed > capacity)
		{
			debug
				assert(false, "Out of memory");
			else
				return null;
		}
		void* result = cast(void*)(&data[spaceUsed]);
		setSpaceUsed(spaceUsed + bytes);

		//debug printf("MEM: Allocating %u bytes, total: %u\n", bytes, spaceUsed);

		return result;
	}

	override bool remove(void* data)
	{
		// Regions don't remove things
		return false;
	}

	/// Wipe all data from the stack
	void wipe() @nogc nothrow
	{
		setSpaceUsed(minimumSize);
	}

	@property ulong capacity() @nogc const nothrow
	{
		return (cast(ulong*)data)[0];
	}

	@property ulong spaceUsed() @nogc const nothrow
	{
		return (cast(ulong*)data)[1];
	}

	private void setCapacity(ulong val) @nogc nothrow
	{
		(cast(ulong*)data)[0] = val;
	}

	private void setSpaceUsed(ulong val) @nogc nothrow
	{
		(cast(ulong *) data)[1] = val;
		assert(spaceUsed() == val);
	}
}
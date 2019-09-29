// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module lanlib.sys.memory;

import std.conv : emplace;
import std.traits : hasUDA;

debug
{
	import std.stdio;
}

/++
  Anything with the @GpuResource attribute must have its destructor called
  once its no longer valid.  As a result, no GpuResource types can be put on 
  the MemoryStack.  They must be managed through some other method.
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


/++
 Manager for system memory.  Wraps malloc() and free()
 +/
class SysMemManager : ILanAllocator
{

	import core.stdc.stdlib : malloc, free;

	override void* make(ulong bytes) @nogc
	{
		return malloc(bytes);
	}

	T[] make_list(T)(ulong count) @nogc
	{
		return (cast(T*)make(T.sizeof * count))[0..count];
	}

	override bool remove(void* data) @nogc
	{
		free(data);
		return true;
	}

	bool remove_list(T)(T[] data) @nogc
	{
		free(cast(void*) data.ptr);
		return true;
	}
}

/++ A stack of non-GCd memory
   note: when stack space is freed, it does not call any destructors.
   It is the responsibility of the calling code to call destroy()
   on any objects that manage other resources.
+/
class LanRegion : ILanAllocator
{
	enum minimum_size = ulong.sizeof*2;

	ILanAllocator parent;
	ubyte *data;

	this(ulong capacity, ILanAllocator parent) @nogc
	{
		this.parent = parent;
		assert(capacity > minimum_size);
		data = cast(ubyte*)parent.make(capacity);

		assert(data != null, "Failed to get memory for region");

		set_capacity(capacity);
		set_space_used(2*ulong.sizeof);
		debug
		{
			printf("Creating Region with %u bytes\n", capacity);
		}
	}

	~this() @nogc
	{
		ulong used = space_used();
		ulong cap = capacity();
		set_capacity(0);
		set_space_used(0);
		parent.remove(cast(void*)data);
		data = null;
		debug
		{
			printf("Deleted Region with %u/%u bytes allocated\n", used, cap);
		}
	}

	override void* make(ulong bytes) @nogc 
	{
		if(bytes + space_used > capacity)
		{
			debug {
				assert(false, "Out of memory");
			}
			else return null;
		}
		void* result = cast(void*)(&data[space_used]);
		set_space_used(space_used + bytes);

		return result;
	}

	T[] make_list(T)(ulong count) @nogc
	{
		return (cast(T*)make(T.sizeof * count))[0..count];
	}

	T *create(T, A...)(auto ref A args) @nogc 
	{
		T *ptr = cast(T*) make(T.sizeof);
		assert(ptr != null, "Failed to allocate memory");
		emplace!(T, A)(ptr, args);
		return ptr;
	}

	override bool remove(void* data)
	{
		// Regions don't remove things
		return false;
	}

	/// Wipe the stack with some memory preserved.
	/// So you can allocate long-lived data here, then get the used space, 
	/// then later call wipe_with_preserved using that value
	void wipe_with_preserved(ulong preserved_bytes) @nogc
	{
		assert(preserved_bytes > minimum_size);
		assert(preserved_bytes <= space_used);
		set_space_used(preserved_bytes);
	}

	/// Wipe all data from the stack
	void wipe() @nogc nothrow
	{
		set_space_used(minimum_size);
	}

	@property ulong capacity() @nogc const nothrow
	{
		return (cast(ulong*)data)[0];
	}

	@property ulong space_used() @nogc const nothrow
	{
		return (cast(ulong*)data)[1];
	}

	private void set_capacity(ulong val) @nogc nothrow
	{
		(cast(ulong*)data)[0] = val;
	}

	private void set_space_used(ulong val) @nogc nothrow
	{
		(cast(ulong *) data)[1] = val;
	}
}
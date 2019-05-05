// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module lanlib.sys.memory;

import core.stdc.stdlib : malloc, free;
import std.conv : emplace;
import std.traits : hasUDA;

debug
{
	import std.stdio;
}

/**
  Anything with the @GpuResource attribute must have its destructor called
  once its no longer valid.  As a result, no GpuResource types can be put on 
  the MemoryStack.  They must be managed through some other method.
 */
enum GpuResource;

/** A stack of non-GCd memory
   note: when stack space is freed, it does not call any destructors.
   It is the responsibility of the calling code to call destroy()
   on any objects that manage other resources.
*/
struct MemoryStack
{
	enum minimum_size = ulong.sizeof*2;
	ubyte *data;

	this(ulong capacity) @nogc
	{
		assert(capacity > minimum_size);
		data = cast(ubyte*) malloc(capacity);

		assert(data != null, "Out of memory");

		set_capacity(capacity);
		set_space_used(2*ulong.sizeof);
		debug
		{
			printf("Creating MemoryStack with %u bytes\n", capacity);
		}
	}

	~this() @nogc
	{
		set_capacity(0);
		set_space_used(0);
		free(data);
		data = null;
		debug
		{
			printf("Deleted MemoryStack\n");
		}
	}

	T *reserve(T)(uint count = 1) @nogc 
	{
		static assert(!hasUDA!(T, GpuResource), 
			"Cannot allocate GpuResource type `"~T.stringof ~
			"` using MemoryStack, as its destructor will never be called");
		assert(count > 0);
		assert(T.sizeof*count + space_used <= capacity, "Out of memory");
		T* result = cast(T*)(&data[space_used]);
		set_space_used(space_used + T.sizeof*count);

		return result;
	}

	T[] reserve_list(T)(uint count) @nogc
	{
		return reserve!T(count)[0..count];
	}

	T *create(T, A...)(auto ref A args) @nogc 
	{
		T *ptr = reserve!T(1);
		assert(ptr != null, "Failed to allocate memory");
		emplace!(T, A)(ptr, args);
		return ptr;
	}


	// Wipe the stack with some memory preserved.
	// So you can allocate long-lived data here, then get the used space, 
	// then later call wipe_with_preserved using that value
	void wipe_with_preserved(ulong preserved_bytes) @nogc
	{
		assert(preserved_bytes > minimum_size);
		assert(preserved_bytes <= space_used);
		set_space_used(preserved_bytes);
	}

	// Wipe all data from the stack
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
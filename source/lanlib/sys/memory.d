// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module lanlib.sys.memory;

import core.stdc.stdlib : malloc, free;
import std.conv : emplace;

debug
{
	import std.stdio;
}

/** A stack of non-GCd memory
   note: when stack space is freed, it does not call any destructors.
   It is the responsibility of the calling code to call destroy()
   on any objects that manage other resources.
*/
struct MemoryStack
{
	ubyte *data;

	@nogc this(uint capacity)
	{
		assert(capacity > ulong.sizeof*2);
		data = cast(ubyte*) malloc(capacity);

		assert(data != null, "Out of memory");

		set_capacity(capacity);
		set_space_used(2*ulong.sizeof);
		debug
		{
			printf("Creating MemoryStack with %u bytes\n", capacity);
		}
	}

	@nogc ~this()
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

	@nogc T *reserve(T)(uint count = 1)
	{
		assert(count > 0);
		assert(T.sizeof*count + space_used <= capacity, "Out of memory");
		T* result = cast(T*)(&data[space_used]);
		set_space_used(space_used + T.sizeof*count);

		return result;
	}

	@nogc T[] reserve_list(T)(uint count)
	{
		return reserve!T(count)[0..count];
	}

	@nogc T *create(T, A...)(auto ref A args)
	{
		T *ptr = reserve!T(1);
		assert(ptr != null, "Failed to allocate memory");
		emplace!(T, A)(ptr, args);
		return ptr;
	}

	@property @nogc const ulong capacity()
	{
		return (cast(ulong*)data)[0];
	}

	@property @nogc const ulong space_used()
	{
		return (cast(ulong*)data)[1];
	}

	private @nogc void set_capacity(ulong val)
	{
		(cast(ulong*)data)[0] = val;
	}

	private @nogc void set_space_used(ulong val)
	{
		(cast(ulong *) data)[1] = val;
	}
}
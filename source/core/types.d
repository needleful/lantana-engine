// Lantana
// types.d
// Licensed under GPL v3.0

/// Module of generic types and templates
module lantana.core.types;

import std.traits;

struct Flags(E)
	if(is(E == enum))
{
	static if(EnumMembers!E.length <= 8)
	{
		alias DT = ubyte;
	}
	else static if(EnumMembers!E.length <= 16)
	{
		alias DT = ushort;
	}
	else static if(EnumMembers!E.length <= 32)
	{
		alias DT = uint;
	}
	else static if(EnumMembers!E.length <= 64)
	{
		alias DT = ulong;
	}
	else
	{
		static assert(false, "BitField does not support enums with more than 64 bits");
	}

	DT data;

	void clear()
	{
		data = 0;
	}

	bool opIndex(E key)
	{
		DT i = cast(DT)key;

		return cast(bool)( (1<<i) & data);
	}

	void opIndexAssign(bool value, E key)
	{
		DT i = cast(DT)key;

		DT flag = cast(DT)(value << key);
		DT nflag = ~flag;

		// TODO implement
	}
}
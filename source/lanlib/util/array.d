// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module lanlib.util.array;
import std.conv : emplace;

/// Linearly search a list for an item
/// return the index or -1 if the item wasn't in the list
long indexOf(Type)(Type[] list, auto ref Type toFind) @nogc nothrow @safe
{
	foreach(i, ref val; list)
	{
		if(val == toFind)
		{
			return i;
		}
	}
	return -1;
}

void place(Type, A...)(Type[] list, ulong index, auto ref A args)
{
	emplace!(Type, A)(&list[index], args);
}

void clear(Type)(Type[] list) nothrow @safe
{
	list.length = 0;
}
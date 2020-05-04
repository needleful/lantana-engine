// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module lantana.types.array;
import std.conv : emplace;

/// Linearly search a list for an item
/// return the index or -1 if the item wasn't in the list
long indexOf(Type)(Type[] list, auto ref Type toFind) @nogc nothrow @safe
{
	foreach(i, ref val; list)
	{
		if(val is toFind)
		{
			return i;
		}
	}
	return -1;
}

void removeAt(Type)(ref Type[] list, ulong index)
{
	if(index == 0)
	{
		list = list[1..$];
	}
	else if(index == list.length - 1)
	{
		list = list[0..$-1];
	}
	else
	{
		auto tail = list[index+1..$];
		list.length -= 1;
		for(int i = 0; i < tail.length; i++)
		{
			list[index + i] = tail[i];
		}
	}
}

// Insert before the provided index
void insert(Type)(ref Type[] list, ulong index, Type value)
{
	list.length += 1;

	for(size_t i = list.length - 1; i > index; i--)
	{
		list[i] = list[i-1];
	}
	list[index] = value;
}

void place(Type, A...)(Type[] list, ulong index, auto ref A args)
{
	emplace!(Type, A)(&list[index], args);
}

void clear(Type)(ref Type[] list) nothrow @safe
{
	list.length = 0;
}

// In-place reversal
T[] reverse(T)(T[] input)
{
	if(input.length <= 1)
	{
		return input;
	}

	ulong end = input.length - 1;
	foreach(ulong i; 0..input.length/2)
	{
		ulong opp = end-i;

		auto temp = input[i];
		input[i] = input[opp];
		input[opp] = temp;
	}

	return input;
}

/// Add object, double size if length exceeds capacity
T* append(T)(ref T[] list, T object)
{
	if(list.length == 0)
	{
		list.reserve(2);
	}
	else if(list.length == list.capacity)
	{
		list.reserve(list.length * 2);
	}

	list ~= object;
	return &list[$-1];
}

// Returns true if we had to reserve more space, false otherwise
bool addSpace(T)(ref T[] list, uint space)
{
	bool realloc_required = false;
	if((list.length + space) > list.capacity)
	{
		list.reserve((list.length * 2));
		realloc_required = true;
	}
	list.length += space;
	return realloc_required;
}
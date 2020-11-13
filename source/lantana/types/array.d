// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module lantana.types.array;
import std.conv : emplace;

/// Linearly search a list for an item
/// return the index or -1 if the item wasn't in the list
long indexOf(Type)(Type[] list, auto ref Type toFind) @nogc nothrow 
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

void removeAt(Type)(ref Type[] list, size_t index)
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
void insert(Type)(ref Type[] list, size_t index, Type value)
{
	list.length += 1;

	for(uint i = list.length - 1; i > index; i--)
	{
		list[i] = list[i-1];
	}
	list[index] = value;
}

enum Compare
{
	LT,
	GT,
	EQ
}

// Binary search
// If returns true, index is the index of the value
// if returns false, index is a place to insert the item to be sorted
bool binarySearch(alias fn, T, U)(T list, U value, out size_t index)
	if(is( typeof(fn(value, list[0])) == Compare ))
{
	auto search = list;
	size_t start = 0;
	while(search.length > 4)
	{
		size_t pivot = search.length/2;
		auto c = fn(value, search[pivot]);

		if(c == Compare.EQ)
		{
			index = start + pivot;
			return true;
		}
		else if(c == Compare.LT)
		{
			search = search[0..pivot];
		}
		else
		{
			start += pivot + 1;
			search = search[pivot + 1..$];
		}
	}

	foreach(id, ref v2; search)
	{
		auto c = fn(value, v2);

		if(c == Compare.LT)
		{
			index = id + start;
			return false;
		}
		else if(c == Compare.EQ)
		{
			index = id + start;
			return true;
		}
	}
	index = list.length;
	return false;
}

void place(Type, A...)(Type[] list, size_t index, auto ref A args)
{
	emplace!(Type, A)(&list[index], args);
}

void clear(Type)(ref Type[] list) nothrow 
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

	size_t end = input.length - 1;
	foreach(size_t i; 0..input.length/2)
	{
		size_t opp = end-i;

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
bool addSpace(T)(ref T[] list, size_t space)
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
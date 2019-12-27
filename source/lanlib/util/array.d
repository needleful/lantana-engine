// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module lanlib.util.array;

/// Linearly search a list for an item
/// return the index or -1 if the item wasn't in the list
long indexOf(Type)(Type[] list, auto ref Type toFind)
{
	foreach(i; 0..list.length)
	{
		if(list[i] == toFind)
		{
			return i;
		}
	}
	return -1;
}
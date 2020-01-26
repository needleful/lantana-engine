// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module test.meta;

import std.traits;


template Declare(string type, string name)
{
	enum Declare = type~" "~name~";\n";
}

struct Duplicate(Type)
	if(is(Type == struct))
{
	enum fieldNames = FieldNameTuple!Type;

	static foreach(i, type; Fields!Type)
	{
		mixin(Declare!(Type.stringof, fieldNames[i].stringof[1..$-1]));
	}
}

struct Test
{
	string name;
	int a,b,c;
	ushort x, y, z;
}

//void testTypes()
//{
//	pragma(msg, "Original: ", FieldNameTuple!Test);
//	pragma(msg, "Duplicate: ", FieldNameTuple!(Duplicate!Test));
//}
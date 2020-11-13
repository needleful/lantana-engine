// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module lantana.types.meta;

import std.meta;
import std.traits;

enum isSimpleType(Type) = isBasicType!Type || isStaticArray!Type;
enum isSimpleStruct(Type) = isSimpleType!Type || allSatisfy!(isSimpleType, Fields!Type);
enum isDumbData(Type) = isSimpleStruct!Type || allSatisfy!(isSimpleStruct, Fields!Type);

template StripType(T)
{
	static if(isArray!T)
	{
		alias subType = ForeachType!T;
	}
	else static if(isPointer!T)
	{
		alias subType = PointerTarget!T;
	}
	else
	{
		alias subType = T;
	}
	alias StripType = Unqual!subType;
}

mixin template Import(Type)
{
	alias absType = StripType!Type;

	static if(__traits(compiles, moduleName!absType))
	{
		import std.array : split;
		alias templateName = TemplateOf!absType;
		static if(is(templateName == void))
		{
			alias toImport = absType;
		}
		else
		{
			alias toImport = templateName;
		}
		alias pkg = moduleName!toImport;
		mixin("import "~pkg~": "~split(toImport.stringof, '(')[0] ~ ";\n");
	}
}
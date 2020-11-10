// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module lantana.ecs.core;

import std.format;
import std.meta;
import std.traits;

import lantana.types.meta;
import lantana.types.memory : Region;

struct EntityRef
{
	uint id;
}

/// Attribute for marking systems
struct System
{
	string[] components;

	this(string[] p_components...)
	{
		components = p_components;
	}
}

final class Manager(Systems...)
{
	static foreach (i, SysType; Systems)
	{
		mixin Import!SysType;
		mixin(format("private %s system_%s;", SysType.stringof, i));
	}

	private template typeToIndex(System)
	{
		static foreach(i, S; Systems)
		{
			static if(is(System == S))
			{
				enum typeToIndex = i;
			}
		}
	}

	public ref System get(System)()
	{
		enum i = typeToIndex!System;

		return mixin(format("system_%s", i));
	}

	this()
	{
		clear();
	}

	this(Systems systems)
	{
		static foreach(i, SysType; Systems)
		{
			mixin(format("system_%s",i)) = systems[i];
		}
	}

	public void update(float p_delta)
	{
		static foreach(S; Systems)
		{{
			auto s = &get!S();

			static if(__traits(compiles, s.update(p_delta)))
			{
				s.update(p_delta);
			}
			else static if(__traits(compiles, s.update()))
			{
				s.update();
			}
		}}
	}

	public void clear()
	{
		import lantana.types.array;
		static foreach(S; Systems)
		{{
			auto s = &get!S();
			static if(__traits(compiles, s.clear()))
			{
				s.clear();
			}
		}}
	}

	public void reserve(System)(Region p_alloc, uint count)
	{
		get!System().components.reserve(count);
	}
}
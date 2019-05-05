// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module ecs.core;

alias EntityID=uint;

struct Entity
{
	EntityID id;
}

abstract class System(C)
{
	abstract void process() @nogc;
}

struct Component
{
	EntityID entity;
}
// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module ecs.core;

alias EntityID=uint;

struct Entity
{
	EntityID id;
}

struct System(C: Component)
{
	void process(C[] components);
}

struct Component
{
	EntityID entity;
}
// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module game.systems;

import lantana.ecs.core;
import lantana.math: Transform;
import lantana.types.array;
import lantana.types.memory : OwnedList;
import lantana.render.mesh.animation : AnimationSequence;
import game.actor;


mixin template OwnerSystem(Component)
{
	alias component = Component;
	Component[] components;
	void update(float delta)
	{
		foreach(ref c; components)
		{
			c.update(delta);
		}
	}

	Component* add(Component c)
	{
		components ~= c;
		return &components[$-1];
	}

	void clear()
	{
		components.clear();
	}
}

@System(Actor.stringof)
struct Actors
{
	mixin OwnerSystem!Actor;
}

@System(AnimationSequence.stringof)
struct Animations
{
	mixin OwnerSystem!AnimationSequence;
}

@System(Actor.stringof, Transform.stringof)
struct ActorTransforms
{
	struct TransformUpdate
	{
		Actor* actor;
		Transform* actorTransform;

		this(Actor* a, Transform* t)
		{
			actor = a;
			actorTransform = t;
		}
	}

	alias component = TransformUpdate;

	TransformUpdate[] components;
	void update()
	{
		foreach(ref c; components)
		{
			c.actorTransform._rotation.y = c.actor.facingAngle();
			c.actorTransform._position = c.actor.worldPos();
		}
	}

	void add(Actor* a, Transform* t)
	{
		components ~= TransformUpdate(a,t);
	}

	void clear()
	{
		components.clear();
	}
}
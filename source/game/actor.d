// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module game.actor;

import std.math : abs;

import gl3n.linalg : vec3;
import lantana.types : ivec2;

import game.map;

struct Actor
{
	// Walking speed in meters per second
	enum speed = 2.5;

	// Where the actor wants to go
	ivec2[] plan;

	// The actor's current room
	Room* room;

	// The actor's position on the room grid
	ivec2 gridPos;

	// The actor's world position
	private vec3 realPos;

	// Distance covered to the next point on the plan
	private float coveredDistance;

	// Current direction
	Grid.Dir direction;

	this(Room* p_room)
	{
		coveredDistance = 0;
		room = p_room;
		realPos = room.getWorldPosition(gridPos);
	}

	bool approach(ivec2 target)
	{
		if(gridPos == target)
		{
			return true;
		}

		return room.grid.navigate(gridPos, target, plan);
	}

	void update(float delta)
	{
		if(plan.length == 0)
		{
			coveredDistance = 0;
			return;
		}

		ivec2 dir = plan[0]-gridPos;

		assert(dir.length_squared() == 1, "Cannot navigate more than one tile at a time!");

		if(dir.x > 0)
		{
			direction = Grid.Dir.RIGHT;
		}
		else if(dir.x < 0)
		{
			direction = Grid.Dir.LEFT;
		}
		else if(dir.y > 0)
		{
			direction = Grid.Dir.UP;
		}
		else if(dir.y < 0)
		{
			direction = Grid.Dir.DOWN;
		}

		vec3 move = vec3(dir.x, 0, dir.y)*speed*delta;

		// We know it's either all X or all Z
		coveredDistance += abs(move.x) + abs(move.z);
		// Movement between 1x1 grid points
		if(coveredDistance >= 1)
		{
			gridPos = plan[0];
			realPos = room.getWorldPosition(gridPos);
			coveredDistance = 0;
			plan = plan[1..$];
		}
		else
		{
			realPos += move;
		}
	}

	vec3 worldPos()
	{
		return realPos;
	}
}
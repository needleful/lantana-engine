// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module logic.player;

import gl3n.interpolate;
import gl3n.linalg;

import logic.grid;
import logic.input;


struct Player
{
	// Time to go from one grid point to another
	enum TIME_MOVE = 0.25;
	// Time to rotate from direction to direction
	enum TIME_ROTATE = 0.01;

	enum State
	{
		IDLE,
		MOVE,
	}
	enum Mode
	{
		ALONE,
		WITH_AXE,
	}

	Grid* grid;
	GridPos pos, pos_target;
	float timer_move = 0;
	float rotation;

	GridDirection dir;
	State state;
	Mode mode;


	@disable this();
	this(Grid* p_grid, GridPos p_gridPos, GridDirection p_dir = GridDirection.UP, State p_state = State.IDLE) @nogc @safe nothrow
	{
		grid = p_grid;
		pos = p_gridPos;
		state = p_state;
		pos_target = pos;

		dir = p_dir;
		rotation = getRealRotation(dir);
	}

	void frame(const ref Input input, const float delta)  @nogc @safe nothrow
	{

		if(state == State.MOVE)
		{
			timer_move += delta;
			if(timer_move >= TIME_MOVE)
			{
				state = State.IDLE;
			}
		}

		if(state == State.IDLE)
		{
			State next_state = State.IDLE;
			pos = pos_target;
			timer_move = 0;
			// Can only move one grid space at a time
			if(input.is_pressed(Input.Action.FORWARD))
			{
				dir = GridDirection.UP;
				next_state = State.MOVE;
				pos_target.z += 1;
			}
			else if(input.is_pressed(Input.Action.BACK))
			{
				dir = GridDirection.DOWN;
				next_state = State.MOVE;
				pos_target.z -= 1;
			}
			else if(input.is_pressed(Input.Action.RIGHT))
			{
				dir = GridDirection.RIGHT;
				next_state = State.MOVE;
				pos_target.x += 1;
			}
			else if(input.is_pressed(Input.Action.LEFT))
			{
				dir = GridDirection.LEFT;
				next_state = State.MOVE;
				pos_target.x -= 1;
			}

			if(!grid.inBounds(pos_target))
			{
				pos_target = pos;
				state = State.IDLE;
			}
			state = next_state;
		}

	}

	vec3 realPosition() @nogc @safe nothrow
	{
		return lerp(
			grid.getRealPosition(pos),
			grid.getRealPosition(pos_target), 
			timer_move/TIME_MOVE);
	}

	float realRotation() @nogc @safe nothrow
	{
		return getRealRotation(dir);
	}

	private static float getRealRotation(GridDirection p_dir) @nogc @safe nothrow
	{
		switch(p_dir)
		{
			case GridDirection.UP:
				return 270;
			case GridDirection.DOWN:
				return 90;
			case GridDirection.RIGHT:
				return 0;
			case GridDirection.LEFT:
				return 180;
			default:
				return 0;
		}
	}

}
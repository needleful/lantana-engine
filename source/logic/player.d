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
	enum State
	{
		IDLE,
		MOVE,
		BLOCKED,
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
		rotation = dir.getRealRotation();
	}

	void frame(const ref Input input, const float delta)  @nogc @safe nothrow
	{
		// Calculate new state
		if(state == State.MOVE)
		{
			timer_move += delta;
			if(timer_move >= Grid.TIME_MOVE)
			{
				state = State.IDLE;
				timer_move = 0;
			}
		}
		if(state == State.IDLE)
		{
			State next_state = State.IDLE;
			pos = pos_target;
			// Can only move one grid space at a time
			if(input.is_pressed(Input.Action.FORWARD))
			{
				dir = GridDirection.UP;
				next_state = State.MOVE;
			}
			else if(input.is_pressed(Input.Action.BACK))
			{
				dir = GridDirection.DOWN;
				next_state = State.MOVE;
			}
			else if(input.is_pressed(Input.Action.RIGHT))
			{
				dir = GridDirection.RIGHT;
				next_state = State.MOVE;
			}
			else if(input.is_pressed(Input.Action.LEFT))
			{
				dir = GridDirection.LEFT;
				next_state = State.MOVE;
			}

			// Could not move
			if(next_state == State.MOVE)
			{
				pos_target = grid.move(pos, dir);
				if(pos == pos_target)
				{
					state = State.BLOCKED;
				}
			}
			state = next_state;
		}
	}

	vec3 realPosition() @nogc @safe nothrow
	{
		return lerp(
			grid.getRealPosition(pos),
			grid.getRealPosition(pos_target), 
			timer_move/Grid.TIME_MOVE);
	}

	float realRotation() @nogc @safe nothrow
	{
		return dir.getRealRotation();
	}
}
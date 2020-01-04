// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module logic.player;

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
	}

	void update(const ref Input input, const float delta)  @nogc @safe nothrow
	{
		grid.update(delta);

		// Calculate new state

		// !grid.active means the current move has ended
		if(!grid.active)
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

			if(next_state == State.MOVE)
			{
				pos_target = grid.move(pos, dir, true);
				if(pos == pos_target)
				{
					next_state = State.BLOCKED;
				}
			}
			state = next_state;
		}
	}

	vec3 realPosition() @nogc @safe nothrow
	{
		return grid.getRealPosition(pos, pos_target);
	}

	float realRotation() @nogc @safe nothrow
	{
		return dir.getRealRotation();
	}
}
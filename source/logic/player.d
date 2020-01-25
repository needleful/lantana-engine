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
		PUSHING,
		MOVE_BACKWARD,
		TURN90_RIGHT,
		TURN90_LEFT,
		TURN180_RIGHT,
		TURN180_LEFT
	}
	enum Mode
	{
		FREE,
		WITH_AXE,
	}

	Grid* grid;
	GridPos pos, pos_target;

	GridDirection dir;
	State state;
	State previousState;
	// For visual appeal, the character turns in one direction
	State previousTurnState;
	Mode mode;

	this(Grid* p_grid, GridPos p_gridPos, GridDirection p_dir = GridDirection.UP, State p_state = State.IDLE)  @safe nothrow
	{
		grid = p_grid;
		pos = p_gridPos;
		state = p_state;
		pos_target = pos;

		dir = p_dir;
	}

	void update(const(Input*) input, const float delta)   @safe nothrow
	{
		grid.update(delta);

		// Calculate new state

		// While free, turning only lasts for one frame
		// We're assigning 'state' here to bypass the queueAnimation/playAnimation logic
		if(state == State.TURN90_LEFT 
			|| state == State.TURN90_RIGHT 
			|| state == State.TURN180_LEFT 
			|| state == State.TURN180_RIGHT)
		{
			state = State.MOVE;
		}
		previousState = state;
		// !grid.active means the current move has ended
		if(!grid.active)
		{
			State nextState = State.IDLE;
			pos = pos_target;

			GridDirection previousDir = dir;
			// Can only move one grid space at a time
			if(input.is_pressed(Input.Action.FORWARD))
			{
				dir = GridDirection.UP;
				nextState = State.MOVE;
			}
			else if(input.is_pressed(Input.Action.BACK))
			{
				dir = GridDirection.DOWN;
				nextState = State.MOVE;
			}
			else if(input.is_pressed(Input.Action.RIGHT))
			{
				dir = GridDirection.RIGHT;
				nextState = State.MOVE;
			}
			else if(input.is_pressed(Input.Action.LEFT))
			{
				dir = GridDirection.LEFT;
				nextState = State.MOVE;
			}

			if(nextState == State.MOVE)
			{
				bool blockPushed;
				pos_target = grid.move(pos, dir, true, blockPushed);
				if(pos == pos_target)
				{
					nextState = State.BLOCKED;
				}
				else if(blockPushed)
				{
					nextState = State.PUSHING;
				}
			}

			float diff = dir.getRealRotation() - previousDir.getRealRotation();
			if(diff == -270 || diff == 90)
			{
				nextState = State.TURN90_RIGHT;
				previousTurnState = nextState;
			}
			else if(diff == 270 || diff == -90)
			{
				nextState = State.TURN90_LEFT;
				previousTurnState = nextState;
			}
			else if(diff == 180 || diff == -180)
			{
				if(previousTurnState == State.TURN180_LEFT || previousTurnState == State.TURN90_LEFT)
				{
					nextState = State.TURN180_LEFT;
				}
				else if(previousTurnState == State.TURN180_RIGHT || previousTurnState == State.TURN90_RIGHT)
				{
					nextState = State.TURN180_RIGHT;
				}
			}

			state = nextState;
		}
	}

	string getAnimation()  @safe nothrow
	{
		switch(state)
		{
			case State.MOVE:
				return "FreeWalk";

			case State.TURN90_RIGHT:
				return "FreeTurn90Right";
			case State.TURN90_LEFT:
				return "FreeTurn90Left";

			case State.TURN180_RIGHT:
				return "FreeTurn180Right";
			case State.TURN180_LEFT:
				return "FreeTurn180Left";

			case State.IDLE:
				goto default;
			default:
				return "FreeIdle";
		}
	}

	vec3 realPosition()  @safe nothrow
	{
		return grid.getRealPosition(pos, pos_target);
	}

	float realRotation()  @safe nothrow
	{
		return dir.getRealRotation();
	}
}
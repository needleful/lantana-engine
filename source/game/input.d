// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module game.input;

import core.types;

struct Input
{
	enum Action
	{
		UP,
		DOWN,
		LEFT,
		RIGHT,
		PAUSE,
		ACTION_COUNT
	}
	enum Status
	{
		UP,
		DOWN,
		JUST_PRESSED,
		JUST_RELEASED,
	}
	// Currently held position of sticks
	Vec2 analog_left, analog_right;
	// Relative mouse movement since last frame
	Vec2 mouse_movement;
	// Status of all buttons
	Status[Action.ACTION_COUNT] status;

	void press(Action a)
	{
		if(status[a] == Status.JUST_PRESSED || status[a] == Status.DOWN)
		{
			status[a] = Status.DOWN;
		}
		else
		{
			status[a] = Status.JUST_PRESSED;
		}
	}

	void release(Action a)
	{
		if(status[a] == Status.JUST_RELEASED || status[a] == Status.UP)
		{
			status[a] = Status.UP;
		}
		else
		{
			status[a] = Status.JUST_RELEASED;
		}
	}

	// Reset input, for example when re-entering the window
	void clear()
	{
		analog_left = Vec2(0,0);
		analog_right = Vec2(0,0);
		mouse_movement = Vec2(0,0);
		foreach(ref Status s; status)
		{
			s = Status.UP;
		}
	}

	const bool is_pressed(Action a)
	{
		return status[a] == Status.DOWN || Status.JUST_PRESSED;
	}
	const bool is_just_pressed(Action a)
	{
		return status[a] == Status.JUST_PRESSED;
	}
	const bool is_just_released(Action a)
	{
		return status[a] == Status.JUST_RELEASED;
	}
}


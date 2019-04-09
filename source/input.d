// Part of the Kitty3D System (k3ds)
// developed by needleful
// Licensed under GPL v3.0

module input;

import core_types;
import derelict.sdl2.sdl;

const int CONCURRENT_INPUTS_LIMIT = 16;

struct InputData
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
	Status[Action.ACTION_COUNT] pressed;
}


// Part of the Kitty3D System (k3ds)
// developed by needleful
// Licensed under GPL v3.0

module input;

import core_types;
import derelict.sdl2.sdl;

const int CONCURRENT_INPUTS_LIMIT = 16;

struct InputData
{
	// Currently held position of sticks
	Vec2 analog_left, analog_right;
	// Relative mouse movement since last frame
	Vec2 mouse_movement;
	// Buttons pressed this frame
	int[CONCURRENT_INPUTS_LIMIT] pressed;
	// Buttons pressed on a previous frame
	int[CONCURRENT_INPUTS_LIMIT] held;
	// Buttons released this frame
	int[CONCURRENT_INPUTS_LIMIT] released;
	ubyte pressed_count, held_count, released_count;
}


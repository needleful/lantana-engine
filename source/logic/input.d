// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module logic.input;

debug import std.stdio;

import bindbc.sdl;
import gl3n.linalg;

import lanlib.types;
import logic.keyboard;

struct Input
{
	KeyboardInput keyboard;
	// Currently held position of sticks
	vec2 analog_left, analog_right;
	// Relative mouse movement since last frame
	vec2 mouse_movement;
	// Absolute position of the mouse
	ivec2 mouse_position;

	// Reset input, for example when re-entering the window
	void clear() @safe nothrow
	{
		analog_left = vec2(0,0);
		analog_right = vec2(0,0);
		mouse_movement = vec2(0,0);
		keyboard.pressed.clearAll();
		keyboard.text.length = 0;
	}
}
// Lantana
// input.d
// Licensed under GPL v3.0

/// Module for handling input logic
module lantana.logic.input;

import derelict.sdl2.sdl;

import lantana.core.types;

struct SInput
{
	/// Input actions
	enum Action
	{
		MoveUp,
		MoveDown,
		MoveLeft,
		MoveRight,
	}

	/// Inputs held this frame
	Flags!Action pressed;
	/// Inputs pressed earlier
	Flags!Action held;
	/// Inputs released this frame
	Flags!Action released;
}
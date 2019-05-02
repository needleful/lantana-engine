// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

import std.math;
import std.stdio;

import lanlib.types.matrix;
import lanlib.types.vector;
import lanlib.types.transform;

import lanlib.sys.input;
import lanlib.sys.sdl;

int main()
{
	debug {
		writeln("Running Lantana2D in debug mode!");
	}
	SDLWindow ww = SDLWindow(720, 512, "Lantana2D");
	Input ii = Input();

	

	
	while(ww.should_run)
	{
		ww.poll_events(ii);

		ww.begin_frame();

		ww.end_frame();
	}

	return 0;
}

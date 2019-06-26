// Lantana
// main.d
// Licensed under GPL v3.0

/// The main module for running the game
module lantana.main;

import std.stdio;

void main()
{
	run();
}

/// The main method of the game,
/// everything that can be made nogc should be here
void run() @nogc nothrow
{
	puts("Howdy!");
}
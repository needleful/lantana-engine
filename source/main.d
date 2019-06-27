// Lantana
// main.d
// Licensed under GPL v3.0

/// The main module for running the game
module lantana.main;

import derelict.sdl2.sdl;
import std.stdio;

int main()
{
	DerelictSDL2.load();

	if(SDL_Init(SDL_INIT_VIDEO | SDL_INIT_EVENTS) != 0)
	{
		printf("Failed to initialize SDL: %s\n", SDL_GetError());
		return 1;
	}
	scope(exit)
	{
		SDL_Quit();
		puts("SDL terminated");
	}

	SDL_Window* window = SDL_CreateWindow(
		"Lantana 0.0.0", 
		SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED,
		512, 512, SDL_WINDOW_OPENGL);

	if(window == null)
	{
		printf("Failed to open SDL window: %s\n", SDL_GetError());
		return 2;
	}
	scope(exit) 
	{
		SDL_DestroyWindow(window);
		puts("Window destroyed");
	}
	
	return run();
}

/// The main method of the game,
/// everything that can be made nogc should be here
int run() @nogc nothrow
{
	string text = "Howdy!  I'm Devin Hastings";

	SDL_Delay(1000);

	return 0;
}
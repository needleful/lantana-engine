// Part of the Kitty3D System (k3ds)
// developed by needleful
// Licensed under GPL v3.0

import derelict.sdl2.sdl;
import derelict.opengl;
import std.stdio;
mixin glFreeFuncs!(GLVersion.gl33);

import input;

int main()
{
	DerelictSDL2.load();
	DerelictGL3.load();

	int return_code = run();

	printf("Returned with %d\n", return_code);
	return return_code;
}

@nogc nothrow int run()
{
	import core.memory;
	bool should_exit = false;
	float usec_delta = 1;

	if(SDL_Init(SDL_INIT_VIDEO) < 0){
		return 1;
	}
	SDL_Window* window = SDL_CreateWindow(
		cast(const char*)"Kitty Development Kit", 
		cast(int)SDL_WINDOWPOS_CENTERED, cast(int)SDL_WINDOWPOS_CENTERED, 
		720, 512, SDL_WINDOW_OPENGL);
	if(window == null)
	{
		return 2;
	}

	SDL_GLContext glContext = SDL_GL_CreateContext(window);
	if(glContext == null)
	{
		return 3;
	}

	InputData* data = cast(InputData*) pureMalloc(InputData.sizeof*2);
	InputData* oldInput = data[0];
	InputData* newInput = data[1];
	
	SDL_Event event;
	while(!should_exit)
	{

		while(SDL_PollEvent(&event))
		{

		}
		glClearColor(0.5, 0.5, 1, 1);
		glClear(GL_COLOR_BUFFER_BIT);
		SDL_GL_SwapWindow(window);
		SDL_Delay(3000);
		should_exit = 1;	
	}

	scope(exit)
	{
		if(window != null)
		{
			SDL_DestroyWindow(window);
		}
		if(glContext != null)
		{
			SDL_GL_DeleteContext(glContext);
		}
		if(inData != null)
		{
			pureFree(inData);
		}
		SDL_Quit();
	}

	return 0;
}
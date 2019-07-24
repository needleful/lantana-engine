// Lantana
// gl.d
// Licensed under GPL v3.0

/// Application metasystem
module lantana.core.app;

import derelict.sdl2.image;
import derelict.sdl2.sdl;

import lantana.core.ecs;
import lantana.core.enums;
import lantana.render.gl;

import std.stdio: printf, puts;

@Metasystem
struct MApplication
{
	string name;
	SDL_Window* window;
	SDL_GLContext gl;

	Result init(string name)
	{
		DerelictSDL2.load();
		DerelictSDL2Image.load();
		DerelictGL3.load();

		this.name = name;

		if(SDL_Init(SDL_INIT_VIDEO | SDL_INIT_EVENTS) != 0)
		{
			printf("Failed to initialize SDL: %s\n", SDL_GetError());
			return Result.Failure;
		}
		int img_flags = IMG_INIT_PNG;
		int img_result = IMG_Init(img_flags);

		if((img_result&img_flags) != img_flags)
		{
			printf("Failed to initialize SDL2_Image: %s\n", IMG_GetError());
			return Result.Failure;
		}

		window = SDL_CreateWindow(
			name.ptr, 
			SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED,
			512, 512, SDL_WINDOW_OPENGL);

		if(window == null)
		{
			printf("Failed to open SDL window: %s\n", SDL_GetError());
			return Result.Failure;
		}

		SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 4);
		SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 3);
		SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_CORE);
		debug
		{
			SDL_GL_SetAttribute(SDL_GL_CONTEXT_FLAGS, SDL_GL_CONTEXT_DEBUG_FLAG);
		}
		
		int success = SDL_GL_SetSwapInterval(-1);
		if(!success)
		{
			puts("Could not enable adaptive swap interval");
			success = SDL_GL_SetSwapInterval(1);
			if(!success)
			{
				puts("WARNING: Could not enable synced swapping");
			}
			else{
				puts("Successfully set synced swap interval");
			}
		}
		gl = SDL_GL_CreateContext(window);

		SDL_GL_MakeCurrent(window, gl);

		auto loadedVersion = DerelictGL3.reload();
		if(loadedVersion < GLVersion.gl43)
		{
			printf("Failed to load OpenGL 4.3: %s\n", SDL_GetError());
			return Result.Failure;
		}
		debug
		{
			GLint flags;
			glGetIntegerv(GL_CONTEXT_FLAGS, &flags);

			if ((flags & GL_CONTEXT_FLAG_DEBUG_BIT) == 0)
			{
				puts("Warning: debug context creation failed!");
			}
			glDebugMessageCallback(&logMessage, cast (void*) null);
		}
		return Result.Success;
	}

	void cleanup() @nogc nothrow
	{
		SDL_GL_DeleteContext(gl);
		SDL_DestroyWindow(window);
		IMG_Quit();
		SDL_Quit();
		puts("Application terminated");
	}
}
// Lantana
// main.d
// Licensed under GPL v3.0

/// The main module for running the game
module lantana.main;

// TODO: render animated sprite

import derelict.sdl2.image;
import derelict.sdl2.sdl;

import lantana.core.app;
import lantana.core.enums: Result;
import lantana.render.gl;
import lantana.render.shaders;
import lantana.render.sprites;

import std.datetime.stopwatch;

MApplication app;

int main()
{
	Result r = app.init("Lantana 0.0.0-dev");
	scope(exit) app.cleanup();

	if(r == Result.Failure)
	{
		return 1;
	}
	return run();
}

/// The main method of the game,
/// everything that can be made nogc should be here
int run() @nogc
{
	import std.stdio;

	auto spriteSystem = SAnimatedSprite("data/shaders/sprite_animated.vert", "data/shaders/sprite.frag");
	int[2] size = [128, 128];
	CAnimatedSprite sprite = spriteSystem.create_sprite("data/sprites/kitty.ss.png", size);
	scope(exit) spriteSystem.delete_sprite(sprite);

	CAnimatedSprite violentSprite = spriteSystem.create_sprite("data/sprites/kitty.ss.png", size);

	sprite.translate = [128, 128];
	violentSprite.translate = [256, 256];

	// Render text

	uint[2] screen_size = [512, 512];

	SDL_Event event;
	bool should_quit = false;
	glClearColor(0.8, 0.3, 0.0, 1.0);


	FILE* framelogs = fopen("logs/frames.tsv", "w");
	if(!framelogs)
	{
		puts("Failed to open frame logs");
		return -1;
	}
	scope(exit) fclose(framelogs);

	fputs("Frame Time\t Render time\n", framelogs);
	auto frametime = StopWatch(AutoStart.no);
	auto rendertime = StopWatch(AutoStart.no);
	
	while(!should_quit)
	{
		frametime.reset();
		rendertime.reset();

		frametime.start();
		rendertime.start();

		bool should_inc = false;

		while(SDL_PollEvent(&event))
		{
			switch(event.type)
			{
			case SDL_WINDOWEVENT:
				switch(event.window.event)
				{
				case SDL_WINDOWEVENT_CLOSE:
					should_quit = true;
					break;
				default:
					break;
				}
				break;
			case SDL_KEYDOWN:
				if(event.key.keysym.sym == SDLK_SPACE)
				{
					should_inc = true;
				}
				break;
			default: break;
			}
		}

		glClear(GL_COLOR_BUFFER_BIT);

		violentSprite.frame = (violentSprite.frame + 1) % violentSprite.frame_count;

		if(should_inc)
		{
			sprite.frame = (sprite.frame + 1) % sprite.frame_count;
		}
		spriteSystem.render(sprite, screen_size);
		spriteSystem.render(violentSprite, screen_size);

		rendertime.stop();

		SDL_GL_SwapWindow(app.window);

		frametime.stop();

		fprintf(framelogs, "%u\t%u\n", frametime.peek().total!"usecs", rendertime.peek().total!"usecs");
	}

	return 0;
}
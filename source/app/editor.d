// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

import std.stdio;

import derelict.sdl2.image;
import derelict.sdl2.sdl;
import lanlib.sys.gl;

import lanlib.sys.sdl;
import logic.input;

// Currently used to test random things
int main()
{
	SDLWindow ww = SDLWindow(720, 512, "Lantana Editor");
	ww.grab_mouse(false);

	Input ii = Input();

	DerelictSDL2Image.load();
	IMG_Init(IMG_INIT_PNG);
	scope(exit) IMG_Quit();

	SDL_Surface* tx_surface;

	tx_surface = IMG_Load("data/test/needleful.png");

	if(!tx_surface)
	{
		printf("Failed to load image: %d\n", IMG_GetError());
		return 1;
	}
	scope(exit) SDL_FreeSurface(tx_surface);

	GLuint texture;
	glGenTextures(1, &texture);

	glBindTexture(GL_TEXTURE_2D, texture);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

	glTexImage2D (GL_TEXTURE_2D, 0, GL_RGB, tx_surface.w, tx_surface.h, 0, GL_RGB, GL_FLOAT, tx_surface.pixels);
	
	while(!(ww.state & WindowState.CLOSED))
	{
		ww.poll_events(ii);

		ww.begin_frame();

		

		ww.end_frame();
	}
	return 0;
}
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
	// Initialize renderer
	GLuint pixelProgram;
	{
		import core.stdc.stdio;
		import core.stdc.stdlib;

		FILE* vertfile = fopen("data/shaders/sprite.vert", "r");
		FILE* fragfile = fopen("data/shaders/sprite.frag", "r");
		scope(exit)
		{
			fclose(vertfile);
			fclose(fragfile);
		}

		fseek(vertfile, 0L, SEEK_END);
		fseek(fragfile, 0L, SEEK_END);

		auto vertShaderSize = ftell(vertfile);
		auto fragShaderSize = ftell(fragfile);
		rewind(vertfile);
		rewind(fragfile);

		auto v = vertShaderSize + 1;
		auto f = fragShaderSize + 1;
		char[] vertShader_source = (cast(char*)malloc(char.sizeof * v))[0..v];
		char[] fragShader_source = (cast(char*)malloc(char.sizeof * f))[0..f];

		vertShader_source[$-1] = '\0';
		fragShader_source[$-1] = '\0';

		fread(vertShader_source.ptr, char.sizeof, vertShaderSize, vertfile);
		fread(fragShader_source.ptr, char.sizeof, fragShaderSize, fragfile);

		scope(exit) 
		{
			free(vertShader_source.ptr);
			free(fragShader_source.ptr);
		}

		GLuint[2] shaders = 
		[
			MakeShader(GL_VERTEX_SHADER, vertShader_source.ptr),
			MakeShader(GL_FRAGMENT_SHADER, fragShader_source.ptr)
		];

		if(shaders[0] == 0)
		{
			puts("Failed to load required vertex shader");
			return -1;
		}

		if(shaders[1] == 0)
		{
			puts("Failed to load required fragment shader");
			return -1;
		}
		pixelProgram = LinkShaders(shaders);
		if(pixelProgram == 0)
		{
			puts("Failed to link text shader program");
			return -1;
		}
	}
	scope(exit) glDeleteProgram(pixelProgram);

	int[2][4] quad = 
	[
		[20, 492],
		[492, 492],
		[492, 20],
		[20, 20]
	];

	float[2][4] uv = 
	[
		[0, 0],
		[1, 0],
		[1, 1],
		[0, 1]
	];

	uint[6] elements =
	[
		0, 1, 2,
		0, 2, 3
	];

	GLuint vao_text, ebo_text, vbo_pos, vbo_uv;
	{
		glGenVertexArrays(1, &vao_text);
		glBindVertexArray(vao_text);
		glCheck();

		glGenBuffers(1, &vbo_pos);
		glGenBuffers(1, &vbo_uv);
		glGenBuffers(1, &ebo_text);

		glBindBuffer(GL_ARRAY_BUFFER, vbo_pos);
		glBufferData(GL_ARRAY_BUFFER, int.sizeof*2*quad.length, quad.ptr, GL_STATIC_DRAW);
		glEnableVertexAttribArray(0);
		glVertexAttribIPointer(0, 2, GL_INT, 0, cast(const(GLvoid*)) 0);

		glBindBuffer(GL_ARRAY_BUFFER, vbo_uv);
		glBufferData(GL_ARRAY_BUFFER, float.sizeof*2*uv.length, uv.ptr, GL_STATIC_DRAW);
		glEnableVertexAttribArray(1);
		glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 0, cast(const(GLvoid*)) 0);

		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ebo_text);
		glBufferData(GL_ELEMENT_ARRAY_BUFFER, uint.sizeof*elements.length, elements.ptr, GL_STATIC_DRAW);

		glBindVertexArray(0);
		glCheck();
	}
	scope(exit)
	{
		glDeleteBuffers(1, &vbo_pos);
		glDeleteBuffers(1, &vbo_uv);
		glDeleteVertexArrays(1, &vao_text);
	}

	GLuint tx_sprite;
	SDL_Surface* tx_sprite_image;
	{
		glGenTextures(1, &tx_sprite);
		tx_sprite_image = IMG_Load("data/sprites/idle1.png");
		if(!tx_sprite_image)
		{
			printf("Could not load sprite: %s\n", IMG_GetError());
		}

		if(tx_sprite_image.format.BytesPerPixel != 3)
		{
			printf("Only RGB images are supported, no transparency");
		}
		else
		{
			glBindTexture(GL_TEXTURE_2D, tx_sprite);
			glTexImage2D(
				GL_TEXTURE_2D, 0, GL_RGB, 
				tx_sprite_image.w, tx_sprite_image.h,
				0, GL_RGB, GL_UNSIGNED_BYTE, tx_sprite_image.pixels);


			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
		}
		glCheck();
		puts("Loaded sprite");
	}
	scope(exit)
	{
		glDeleteTextures(1, &tx_sprite);
		SDL_FreeSurface(tx_sprite_image);
	}
	
	// Render text

	uint[2] screen_size = [512, 512];
	int[2] translate = [0,0];
	glClearColor(0.8, 0.3, 0.0, 1.0);

	auto uTranslate = glGetUniformLocation(pixelProgram, "translation");
	auto uScreen    = glGetUniformLocation(pixelProgram, "screen_size");
	auto uColor     = glGetUniformLocation(pixelProgram, "color");
	auto uSprite    = glGetUniformLocation(pixelProgram, "sprite");

	assert(uTranslate >= 0);
	assert(uScreen    >= 0);
	assert(uSprite    >= 0);

	glCheck();

	glUseProgram(pixelProgram);
	{
		glActiveTexture(GL_TEXTURE0);
		glBindTexture(GL_TEXTURE_2D, tx_sprite);

		glUniform2iv(uTranslate, 1, &translate[0]);
		glUniform2uiv(uScreen, 1, &screen_size[0]);
		glUniform1i(uSprite, 0);

		glBindVertexArray(vao_text);
		glDrawElements(GL_TRIANGLES, elements.length, GL_UNSIGNED_INT, cast(GLvoid*) 0);
		glBindVertexArray(0);
	}

	SDL_GL_SwapWindow(app.window);

	SDL_Event event;
	bool should_quit = false;
	while(!should_quit)
	{
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
			default: break;
			}
		}
	}

	return 0;
}
// Lantana
// sprites.d
// Licensed under GPL v3.0

module lantana.render.sprites;

import core.stdc.stdio;
import derelict.sdl2.image;
import derelict.sdl2.sdl;

import lantana.core.ecs;
import lantana.render.gl;
import lantana.render.shaders;

import std.typecons: Tuple;


@Component
struct CAnimatedSprite
{
	// The texture data itself, encoded in an SDL_Surface due to laziness
	SDL_Surface* surface;
	// texture
	GLuint texture;
	// Dimensions of a single frame (spritesheet size is in surface)
	int[2] size;
	// Translation of sprite in pixel space
	int[2] translate;
	// The frame number itself
	ushort frame, frame_count;
}

@System
struct SSprites
{
	static immutable int[2][4] quad = 
	[
		[0, 1],
		[1, 1],
		[1, 0],
		[0, 0]
	];

	static immutable float[2][4] uv = 
	[
		[0, 0],
		[1, 0],
		[1, 1],
		[0, 1]
	];

	static immutable uint[6] elements =
	[
		0, 1, 2,
		0, 2, 3
	];

	// The VBO_pos, VBO_uv, and EBO of the sprite quad
	GLuint[3] vbo;

	// Shader and VAO for all sprites
	GLuint vao;
	GLuint shader_anim, shader_static;

	// Shader Uniforms
	Tuple!(
		GLuint, "sprite", 
	    GLuint, "translation",
		GLuint, "screenSize",
	    GLuint, "frameSize",
	    GLuint, "frameScale",
	    GLuint, "frameOffset",
	) uAnim;

	@disable this();

	this(const(char*) vertShaderSource, const(char*) fragShaderSource) @nogc
	{
		// Create VAO and VBOs
		glGenVertexArrays(1, &vao);
		glBindVertexArray(vao);
		glCheck();

		glGenBuffers(3, vbo.ptr);
		glBindBuffer(GL_ARRAY_BUFFER, vbo_pos());
		glBufferData(GL_ARRAY_BUFFER, int.sizeof*2*quad.length, quad.ptr, GL_STATIC_DRAW);
		glEnableVertexAttribArray(0);
		glVertexAttribIPointer(0, 2, GL_INT, 0, cast(const(GLvoid*)) 0);

		glBindBuffer(GL_ARRAY_BUFFER, vbo_uv());
		glBufferData(GL_ARRAY_BUFFER, float.sizeof*2*uv.length, uv.ptr, GL_STATIC_DRAW);
		glEnableVertexAttribArray(1);
		glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 0, cast(const(GLvoid*)) 0);

		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ebo());
		glBufferData(GL_ELEMENT_ARRAY_BUFFER, uint.sizeof*elements.length, elements.ptr, GL_STATIC_DRAW);

		glBindVertexArray(0);
		glCheck();

		GLuint[2] shaders = 
		[
			CompileShader(GL_VERTEX_SHADER, vertShaderSource),
			CompileShader(GL_FRAGMENT_SHADER, fragShaderSource)
		];

		scope(exit)
		{
			glDeleteShader(shaders[0]);
			glDeleteShader(shaders[1]);
		}

		if(shaders[0] == 0)
		{
			puts("Failed to load required vertex shader");
		}

		if(shaders[1] == 0)
		{
			puts("Failed to load required fragment shader");
		}

		shader_anim = LinkShaders(shaders);
		if(shader_anim == 0)
		{
			puts("Failed to link text shader_anim program");
		}

		uAnim.sprite      = glGetUniformLocation(shader_anim, "sprite");
		uAnim.translation = glGetUniformLocation(shader_anim, "translation");
		uAnim.screenSize  = glGetUniformLocation(shader_anim, "screen_size");
		uAnim.frameSize   = glGetUniformLocation(shader_anim, "frame_size");
		uAnim.frameScale  = glGetUniformLocation(shader_anim, "frame_scale");
		uAnim.frameOffset = glGetUniformLocation(shader_anim, "frame_offset");
	}

	~this() @nogc
	{
		glDeleteProgram(shader_anim);
		glDeleteBuffers(3, vbo.ptr);
		glDeleteVertexArrays(1, &vao);

		glCheck();
		puts("Sprite System shut down");
	}

	ref GLuint vbo_pos() @nogc nothrow
	{
		return vbo[0];
	}

	ref GLuint vbo_uv() @nogc nothrow
	{
		return vbo[1];
	}

	ref GLuint ebo() @nogc nothrow
	{
		return vbo[2];
	}

	CAnimatedSprite create_sprite(const(char*) filename, const ref int[2] frame_size) @nogc
	{
		import core.stdc.stdio;
		CAnimatedSprite sprite;

		glGenTextures(1, &sprite.texture);
		sprite.surface = IMG_Load(filename);
		if(!sprite.surface)
		{
			printf("Could not load sprite: %s\n", IMG_GetError());
		}

		if(sprite.surface.format.BytesPerPixel != 3)
		{
			printf("Only RGB surfaces are supported, no transparency");
		}
		glBindTexture(GL_TEXTURE_2D, sprite.texture);
		glTexImage2D(
			GL_TEXTURE_2D, 0, GL_RGB, 
			sprite.surface.w, sprite.surface.h,
			0, GL_RGB, GL_UNSIGNED_BYTE, sprite.surface.pixels);


		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
	
		printf("Loaded sprite: %s\n", filename);

		sprite.size = frame_size;
		sprite.frame = 0;

		//TODO: non-linear spritesheets?
		sprite.frame_count = cast(ushort) sprite.surface.w/sprite.size[0];

		return sprite;
	}

	void delete_sprite(ref CAnimatedSprite sprite) @nogc
	{
		glDeleteTextures(1, &sprite.texture);
		SDL_FreeSurface(sprite.surface);
	}

	void render(const ref CAnimatedSprite sprite, const ref uint[2] screen_size) @nogc
	{
		glCheck();

		glUseProgram(shader_anim);
		glActiveTexture(GL_TEXTURE0);
		glBindTexture(GL_TEXTURE_2D, sprite.texture);

		uAnim.sprite.glUniform1i(0);
		uAnim.translation.glUniform2iv(1, sprite.translate.ptr);
		uAnim.screenSize.glUniform2uiv(1, screen_size.ptr);
		uAnim.frameSize.glUniform2iv(1, sprite.size.ptr);
		//calculate uFrameOffset from the sprite frame and dimensions of the image
		// TODO: currently it just assumes the sprites are linearly packed

		float frameScale = (cast(double) sprite.size[0])/(cast(double) sprite.surface.w);
		float[2] frameOffset = [frameScale*sprite.frame, 0];
		uAnim.frameOffset.glUniform2fv(1, frameOffset.ptr);
		uAnim.frameScale.glUniform1f(frameScale);

		glBindVertexArray(vao);
		glDrawElements(GL_TRIANGLES, elements.length, GL_UNSIGNED_INT, cast(GLvoid*) 0);
		glBindVertexArray(0);
	}
}

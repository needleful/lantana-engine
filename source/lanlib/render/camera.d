// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module lanlib.render.camera;

import lanlib.types.vector;

alias Res = Vector!(int, 2);

struct Camera2D{
	Vec2 position;
	Res resolution;

	this(Res resolution)
	{
		this.resolution = resolution;
		position = Vec2(0,0);
	}

	this(Vec2 position, Res resolution)
	{
		this.position = position;
		this.resolution = resolution;
	}

	void translate(Vec2 translation)
	{
		position += translation;
	}
}
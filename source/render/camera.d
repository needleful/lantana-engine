// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0


module render.camera;

import lanlib.math.func;
import lanlib.math.projection;

import gl3n.linalg;

enum DEFAULT_NEAR_PLANE = 0.01;
enum DEFAULT_FAR_PLANE = 500;

struct Camera
{
	mat4 projection;
	vec3 pos;
	vec2 rot;

	this(vec3 position, float aspect, float fov) @safe @nogc nothrow
	{
		projection = Projection(aspect, fov, DEFAULT_NEAR_PLANE, DEFAULT_FAR_PLANE).matrix;
		pos = position;
		rot = vec2(0,0);
	}

	void set_projection(Projection p) @safe @nogc nothrow
	{
		projection = p.matrix;
	}

	mat4 calculate_view() @safe @nogc nothrow
	{
		vec3 f = forward();
		vec3 r = right();
		vec3 u = cross(r, f);

		auto eye = pos + f;

		auto view =  mat4(
			vec4( r.x,  r.y,  r.z, 0f),
			vec4( u.x,  u.y,  u.z, 0f),
			vec4( f.x,  f.y,  f.z, 0f),
			vec4(0.0f, 0.0f, 0.0f, 1f)
		);

		view *= mat4(
			vec4(1, 0, 0, -pos.x),
			vec4(0, 1, 0, -pos.y),
			vec4(0, 0, 1, -pos.z),
			vec4(0, 0, 0, 1f)
		);
		return view;
	}

	@property mat4 vp() @safe @nogc nothrow
	{
		mat4 res = projection;
		res *= calculate_view();
		return res;
	}

	@property vec3 forward() @safe @nogc nothrow
	{
		float rx = radians(rot.x);
		float ry = radians(rot.y);
		return vec3(
			cos(ry)*sin(rx),
			sin(ry),
			cos(ry)*cos(rx));
	}

	@property vec3 up()
	{
		return right().cross(forward());
	}

	@property vec3 right() @safe @nogc nothrow
	{
		double rx = radians(rot.x);
		double ry = radians(rot.y);
		return vec3(
			cos(rx),
			0,
			-sin(rx));
	}
}
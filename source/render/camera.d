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

	this(vec3 position, float aspect, float fov) @safe  nothrow
	{
		projection = Projection(aspect, fov, DEFAULT_NEAR_PLANE, DEFAULT_FAR_PLANE).matrix;
		pos = position;
		rot = vec2(0,0);
	}

	void set_projection(Projection p) @safe  nothrow
	{
		projection = p.matrix;
	}

	mat4 calculate_view() @safe  nothrow
	{
		auto f = forward();
		auto r = right();
		auto u = cross(r, f);

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

	@property mat4 vp() @safe  nothrow
	{
		mat4 res = projection;
		res *= calculate_view();
		return res;
	}

	@property vec3 forward() @safe  nothrow
	{
		double rx = radians(rot.x);
		double ry = radians(rot.y);
		return vec3(
			cos(ry)*sin(rx),
			sin(ry),
			cos(ry)*cos(rx));
	}

	@property vec3 up()
	{
		return right().cross(forward());
	}

	@property vec3 right() @safe  nothrow
	{
		double rx = radians(rot.x);
		double ry = radians(rot.y);
		return vec3(
			cos(rx),
			0,
			-sin(rx));
	}
}

struct OrbitalCamera
{
	mat4 projection;
	vec3 target;
	vec2 angle;
	// From the origin, facing it
	float distance;

	this(vec3 p_target, float aspect, float fov, vec2 p_angle = vec2(0)) @safe  nothrow
	{
		projection = Projection(aspect, fov, DEFAULT_NEAR_PLANE, DEFAULT_FAR_PLANE).matrix;
		target = p_target;
		angle = p_angle;
	}

	void set_projection(Projection p) @safe  nothrow
	{
		projection = p.matrix;
	}

	mat4 calculate_view() @safe  nothrow
	{
		auto f = forward();
		auto r = right();
		auto u = cross(r, f);

		auto offset = -f*distance + target;

		auto view =  mat4(
			vec4( r.x,  r.y,  r.z, 0f),
			vec4( u.x,  u.y,  u.z, 0f),
			vec4( f.x,  f.y,  f.z, 0f),
			vec4(0.0f, 0.0f, 0.0f, 1f)
		);

		view *= mat4(
			vec4(1, 0, 0, -offset.x),
			vec4(0, 1, 0, -offset.y),
			vec4(0, 0, 1, -offset.z),
			vec4(0, 0, 0, 1f)
		);
		return view;
	}

	void rotateDegrees(vec2 degrees)
	{
		angle += degrees;
		angle.x = angle.x % 360;
		angle.y = angle.y % 360;
	}

	@property mat4 vp() @safe  nothrow
	{
		mat4 res = projection;
		res *= calculate_view();
		return res;
	}

	@property vec3 forward() @safe  nothrow
	{
		double rx = radians(angle.x);
		double ry = radians(angle.y);
		return vec3(
			cos(ry)*sin(rx),
			sin(ry),
			cos(ry)*cos(rx));
	}

	@property vec3 up()
	{
		return right().cross(forward());
	}

	@property vec3 right() @safe  nothrow
	{
		double rx = radians(angle.x);
		double ry = radians(angle.y);
		return vec3(
			cos(rx),
			0,
			-sin(rx));
	}
}
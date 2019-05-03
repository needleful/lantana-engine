// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0


module render.camera;

import lanlib.math.func;
import lanlib.math.matrix;
import lanlib.math.projection;
import lanlib.math.vector;

enum DEFAULT_NEAR_PLANE = 0.01;
enum DEFAULT_FAR_PLANE = 1000;

struct Camera
{
	Mat4 projection;
	Vec3 pos;
	Vec2 rot;

	this(Vec3 position, float aspect, float fov) @safe @nogc nothrow
	{
		projection = Projection(aspect, fov, DEFAULT_NEAR_PLANE, DEFAULT_FAR_PLANE).matrix;
		pos = position;
		rot = Vec2(0,0);
	}

	void set_projection(Projection p) @safe @nogc nothrow
	{
		projection = p.matrix;
	}

	Mat4 calculate_view() @safe @nogc nothrow
	{
		Vec3 f = forward();
		Vec3 r = right();
		Vec3 u = r.cross(f);

		auto eye = pos + f;

		auto view =  Mat4([
			[ r.x,  r.y,  r.z, 0f],
			[ u.x,  u.y,  u.z, 0f],
			[ f.x,  f.y,  f.z, 0f],
			[0.0f, 0.0f, 0.0f, 1f]
		]);

		view *= Mat4([
			[1, 0, 0, -pos.x],
			[0, 1, 0, -pos.y],
			[0, 0, 1, -pos.z],
			[0, 0, 0, 1f]
		]);
		return view;
	}

	@property Mat4 vp() @safe @nogc nothrow
	{
		Mat4 res = projection;
		res *= calculate_view();
		return res;
	}

	@property Vec3 forward() @safe @nogc nothrow
	{
		float rx = radians(rot.x);
		float ry = radians(rot.y);
		return Vec3(
			cos(ry)*sin(rx),
			sin(ry),
			cos(ry)*cos(rx));
	}

	@property Vec3 up()
	{
		return right().cross(forward());
	}

	@property Vec3 right() @safe @nogc nothrow
	{
		double rx = radians(rot.x);
		double ry = radians(rot.y);
		return Vec3(
			cos(rx),
			0,
			-sin(rx));
	}
}
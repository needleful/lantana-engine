// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0


module render.camera;

import lanlib.math.func;
import lanlib.math.matrix;
import lanlib.math.projection;
import lanlib.math.vector;

struct Camera
{
	Mat4 projection;
	Vec3 pos;
	Vec2 rot;

	this(Vec3 position, float aspect, float fov) @safe @nogc nothrow
	{
		projection = Projection(aspect, fov, 0.0001, 8000).matrix;
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
		Vec3 u = f.cross(r);

		auto eye = pos + f;

		return Mat4([
			[r.x, r.y, r.z, 0f],
			[u.x, u.y, u.z, 0f],
			[f.x, f.y, f.z, 0f],
			[-eye.dot(r), -eye.dot(u), -eye.dot(f), 1f]
		]);
	}

	@property Mat4 vp() @safe @nogc nothrow
	{
		Mat4 res = calculate_view();
		res *= projection;
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
// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0


module components.render.camera;

import lanlib.math.func;
import lanlib.math.matrix;
import lanlib.math.projection;
import lanlib.math.vector;

struct Camera
{
	Projection projection;
	Vec3 pos;
	Vec2 rot;

	this(Vec3 position, float aspect, float fov) @safe @nogc
	{
		projection = Projection(aspect, fov, 0.0001, 8000);
		pos = position;
		rot = Vec2(0,0);
	}

	Mat4 vp() @safe @nogc @property
	{
		Vec3 f = forward();
		Vec3 r = right();
		Vec3 u = f.cross(r);

		Mat4 res = Mat4([
			[r.x, r.y, r.z, 0f],
			[u.x, u.y, u.z, 0f],
			[f.x, f.y, f.z, 0f],
			[pos.dot(r), pos.dot(u), pos.dot(f), 1f]
		]);

		res *= projection.matrix;


		return res;
	}

	Vec3 forward()  @safe @nogc @property
	{
		float rx = radians(rot.x);
		float ry = radians(rot.y);
		return Vec3(
			cos(ry)*sin(rx),
			sin(ry),
			cos(ry)*cos(rx));
	}

	Vec3 right()  @safe @nogc @property
	{
		double rx = radians(rot.x);
		double ry = radians(rot.y);
		return Vec3(
			sin(rx - 3.14f / 2.0f),
			0,
			cos(rx - 3.14f / 2.0f));
	}
}
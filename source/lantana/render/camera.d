// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0


module lantana.render.camera;

import lantana.math;

enum DEFAULT_NEAR_PLANE = 0.1;
enum DEFAULT_FAR_PLANE = 1000;

struct Camera
{
	Mat4 projection;
	Vec3 pos;
	Vec2 rot;

	this(Vec3 position, float aspect, float fov)  nothrow
	{
		projection = Projection(aspect, fov, DEFAULT_NEAR_PLANE, DEFAULT_FAR_PLANE).matrix;
		pos = position;
		rot = Vec2(0,0);
	}

	void setProjection(Projection p)  nothrow
	{
		projection = p.matrix;
	}

	Mat4 calculateView()  nothrow
	{
		Vec3 f = forward();
		Vec3 r = right();
		Vec3 u = r.cross(f);

		Vec3 eye = pos + f;

		Mat4 view =  Mat4([
			[ r.x,  r.y,  r.z, 0f],
			[ u.x,  u.y,  u.z, 0f],
			[ f.x,  f.y,  f.z, 0f],
			[0.0f, 0.0f, 0.0f, 1]
		]);

		view *= Mat4([
			[1f, 0, 0, -pos.x],
			[0f, 1, 0, -pos.y],
			[0f, 0, 1, -pos.z],
			[0f, 0, 0, 1f],
		]);
		return view;
	}

	@property Mat4 vp()  nothrow
	{
		Mat4 res = projection;
		res *= calculateView();
		return res;
	}

	@property Vec3 forward()  nothrow
	{
		double rx = radians(rot.x);
		double ry = radians(rot.y);
		return Vec3(
			cos(ry)*sin(rx),
			sin(ry),
			cos(ry)*cos(rx));
	}

	@property Vec3 up()
	{
		return right().cross(forward());
	}

	@property Vec3 right()  nothrow
	{
		double rx = radians(rot.x);
		double ry = radians(rot.y);
		return Vec3(
			cos(rx),
			0,
			-sin(rx));
	}
}

struct OrbitalCamera
{
	Mat4 projection;
	Vec3 target;
	Vec2 angle;
	// From the origin, facing it
	float distance;
	float nearPlane = 0.0001;
	float farPlane = 150000;

	this(Vec3 p_target, float aspect, float fov, Vec2 p_angle = Vec2(0))  nothrow
	{
		setProjection(aspect, fov);
		target = p_target;
		angle = p_angle;
	}

	void setProjection(float aspect, float fov)  nothrow
	{
		projection = Projection(aspect, fov, nearPlane, farPlane).matrix;
	}

	Mat4 calculate_view()  nothrow
	{
		Vec3 f = forward();
		Vec3 r = right();
		Vec3 u = r.cross(f);

		Vec3 offset = -f*distance + target;

		Mat4 view =  Mat4([
			[ r.x,  r.y,  r.z, 0f],
			[ u.x,  u.y,  u.z, 0f],
			[ f.x,  f.y,  f.z, 0f],
			[0.0f, 0.0f, 0.0f, 1]
		]);

		view *= Mat4([
			[1f, 0, 0, -offset.x],
			[0f, 1, 0, -offset.y],
			[0f, 0, 1, -offset.z],
			[0f, 0, 0, 1f]
		]);
		return view;
	}

	void rotateDegrees(Vec2 degrees)
	{
		angle += degrees;
		angle.x = angle.x % 360;
		angle.y = angle.y % 360;
	}

	Mat4 vp()  nothrow
	{
		Mat4 res = projection;
		res *= calculate_view();
		return res;
	}
	
	@property Vec3 forward()  nothrow
	{
		double rx = radians(angle.x);
		double ry = radians(angle.y);
		return Vec3(
			cos(ry)*sin(rx),
			sin(ry),
			cos(ry)*cos(rx));
	}

	@property Vec3 up()
	{
		return right().cross(forward());
	}

	@property Vec3 right()  nothrow
	{
		double rx = radians(angle.x);
		return Vec3(
			cos(rx),
			0,
			-sin(rx));
	}
}
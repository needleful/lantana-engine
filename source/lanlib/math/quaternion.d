// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module math.quaternion;

import std.math;

import lanlib.math.matrix;
import lanlib.math.vector;

struct Quat
{
	float w, x, y, z;

	this(float w, float x, float y, float z) @nogc @safe nothrow
	{
		this.w = w;
		this.x = x;
		this.y = y;
		this.z = z;
	}

	this(float angle, const Vec3 v) @nogc @safe nothrow
	{
		float s = sin(angle);
		w = cos(angle);
		x = v.x*s;
		y = v.y*s;
		z = v.z*s;
	}

	void normalize() @nogc @safe nothrow
	{
		float len = sqrt(x*x + y*y + z*z);
		x /= len;
		y /= len;
		z /= len;
	}

	// Returns a row-major transformation matrix
	const Mat4 to_matrix() @nogc @safe nothrow
	{
		return Mat4([
			[1.0f - 2*y*y - 2*z*z,        2*x*y - 2*w*z,        2*x*z + 2*w*y, 0.0f],
			[       2*x*y + 2*w*z, 1.0f - 2*x*x - 2*z*z,        2*y*z - 2*w*x, 0.0f],
			[       2*x*z - 2*w*y,        2*y*z + 2*w*x, 1.0f - 2*x*x - 2*y*y, 0.0f],
			[                0.0f,                 0.0f,                 0.0f, 1.0f]
		]);
	}
}
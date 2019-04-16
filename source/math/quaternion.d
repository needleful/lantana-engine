// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module math.quaternion;

import std.math;

import math.matrix;
import math.vector;

struct Quat
{
	float w, x, y, z;

	this(float w, float x, float y, float z)
	{
		this.w = w;
		this.x = x;
		this.y = y;
		this.z = z;
	}

	this(float angle, Vec3 v)
	{
		float s = sin(angle);
		w = cos(angle);
		x = v.x*s;
		y = v.y*s;
		z = v.z*s;
	}

	void normalize()
	{
		float len = sqrt(x*x + y*y + z*z);
		x /= len;
		y /= len;
		z /= len;
	}

	// Returns a row-major transformation matrix
	Mat4 to_matrix()
	{
		return Mat4([
			[1.0f - 2*y*y - 2*z*z,        2*x*y - 2*w*z,        2*x*z + 2*w*y, 0.0f],
			[       2*x*y + 2*w*z, 1.0f - 2*x*x - 2*z*z,        2*y*z - 2*w*x, 0.0f],
			[       2*x*z - 2*w*y,        2*y*z + 2*w*x, 1.0f - 2*x*x - 2*y*y, 0.0f],
			[                0.0f,                 0.0f,                 0.0f, 1.0f]
		]);
	}
}
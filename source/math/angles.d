// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module math.angles;

import std.math;

import math.matrix;
import math.vector;

struct Angles
{
	Vec3 axis;
	float angle;

	this(Vec3 axis, float angle)
	{
		this.axis = axis;
		axis.normalize();
		this.angle = angle;
		normalize_angle();
	}

	void normalize_angle()
	{
		while(angle > 2*PI)
		{
			angle -= 2*PI;
		}
		while(angle < -2*PI)
		{
			angle += 2*PI;
		}
	}

	void rotate(float f)
	{
		angle += f;
		normalize_angle();
	}

	const Mat4 to_matrix()
	{
		float c = cos(angle);
		float s = sin(angle);
		float x = axis.x;
		float y = axis.y;
		float z = axis.z;

		return Mat4([
			[  c + (1-c)*x*x, (1-c)*x*y - s*z, (1-c)*x*z + s*y, 0.0f],
			[(1-c)*x*y + s*z,   c + (1-c)*y*y, (1-c)*y*z - s*x, 0.0f],
			[(1-c)*x*z - s*y, (1-c)*y*z + s*x,   c + (1-c)*z*z, 0.0f],
			[           0.0f,            0.0f,            0.0f, 1.0f]
		]);
	}
}
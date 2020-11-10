// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module lantana.math.angles;

import std.math;

import gl3n.linalg;

struct Angles
{
	vec3 axis;
	float angle;

	this(vec3 axis, float angle)   nothrow
	{
		this.axis = axis;
		this.axis.normalize();

		this.angle = angle;
		normalize();
	}

	void normalize()   nothrow
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

	void rotate(float f)   nothrow
	{
		angle += f;
		normalize();
	}

	const mat4 to_matrix()   nothrow
	{
		float c = cos(angle);
		float s = sin(angle);
		float x = axis.x;
		float y = axis.y;
		float z = axis.z;

		return mat4(
			vec4(  c + (1-c)*x*x, (1-c)*x*y - s*z, (1-c)*x*z + s*y, 0.0f),
			vec4((1-c)*x*y + s*z,   c + (1-c)*y*y, (1-c)*y*z - s*x, 0.0f),
			vec4((1-c)*x*z - s*y, (1-c)*y*z + s*x,   c + (1-c)*z*z, 0.0f),
			vec4(           0.0f,            0.0f,            0.0f, 1.0f)
		);
	}
}
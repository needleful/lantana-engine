// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module lanlib.math.angles;

import std.math;

import gl3n.linalg;

struct Angles
{
	vec3 axis;
	float angle;

	this(vec3 axis, float angle) @nogc @safe nothrow
	{
		this.axis = axis;
		this.axis.normalize();

		this.angle = angle;
		normalize_angle();
	}

	void normalize_angle() @nogc @safe nothrow
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

	void rotate(float f) @nogc @safe nothrow
	{
		angle += f;
		normalize_angle();
	}

	const mat4 to_matrix() @nogc @safe nothrow
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
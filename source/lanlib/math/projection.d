// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module lanlib.math.projection;

import std.math: tan, PI;

import gl3n.linalg;

import lanlib.math.func;

struct Projection
{
	private mat4 _matrix;
	float aspectRatio;
	float fov;
	float nearPlane;
	float farPlane;

	this(float p_aspectRatio, float p_fov, float p_nearPlane, float p_farPlane)  @safe nothrow
	{
		aspectRatio = p_aspectRatio;
		fov = p_fov;
		nearPlane = p_nearPlane;
		farPlane = p_farPlane;

		compute_matrix();
	}

	void compute_matrix()  @safe nothrow
	{
		float t = tan(radians(fov)/2);
		float ar = aspectRatio;

		float z1 = (-nearPlane - farPlane)/(nearPlane - farPlane);
		float z2 = (2*nearPlane*farPlane)/(nearPlane - farPlane); 

		_matrix = mat4(
			vec4(1/(ar*t),   0,  0, 0f),
			vec4(       0, 1/t,  0, 0f),
			vec4(       0,   0, z1, z2),
			vec4(       0,   0, 1f, 0f)
		);
	}

	@property ref mat4 matrix()  @safe nothrow
	{
		compute_matrix();
		return _matrix;
	}
}
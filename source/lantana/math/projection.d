// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module lantana.math.projection;

import std.math: tan, PI;

import gl3n.linalg;

import lantana.math.func;

struct Projection
{
	private mat4 _matrix;
	float aspectRatio;
	float fov;
	float nearPlane;
	float farPlane;

	this(float p_aspectRatio, float p_fov, float p_nearPlane, float p_farPlane)   nothrow
	{
		aspectRatio = p_aspectRatio;
		fov = p_fov;
		nearPlane = p_nearPlane;
		farPlane = p_farPlane;

		compute_matrix();
	}

	void compute_matrix() nothrow
	{
		double t = tan(radians(fov)/2);
		double ar = aspectRatio;

		double z1 = (farPlane + nearPlane)/(farPlane - nearPlane);
		double z2 = -nearPlane - nearPlane*z1;

		_matrix = mat4(
			vec4(1/(ar*t),   0,  0, 0f),
			vec4(       0, 1/t,  0, 0f),
			vec4(       0,   0, z1, z2),
			vec4(       0,   0, 1f, 0f)
		);
	}

	@property ref mat4 matrix() return nothrow
	{
		compute_matrix();
		return _matrix;
	}
}
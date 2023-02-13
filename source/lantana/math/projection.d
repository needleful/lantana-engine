// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module lantana.math.projection;

import std.math: tan, PI;

import lantana.math;

struct Projection
{
	private Mat4 _matrix;
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
		float t = tan(radians(fov)/2);
		float ar = aspectRatio;

		float z1 = (-nearPlane)/(nearPlane - farPlane);
		float z2 = (nearPlane*farPlane)/(nearPlane - farPlane); 

		_matrix = Mat4([
			[1f/(ar*t),   0,  0, 0f],
			[       0f, 1/t,  0, 0f],
			[       0f,   0f, z1, z2],
			[       0f,   0f, 1f, 0f]
		]);
	}

	@property ref Mat4 matrix() return nothrow
	{
		compute_matrix();
		return _matrix;
	}
}
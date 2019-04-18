// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module lanlib.math.projection;

import std.math: tan, PI;

import lanlib.math.func;
import lanlib.math.matrix;

struct Projection
{
	private Mat4 _matrix;
	float aspect_ratio;
	float fov;
	float near_plane;
	float far_plane;

	this(float aspect_ratio, float fov, float near_plane, float far_plane) @nogc @safe nothrow
	{
		this.aspect_ratio = aspect_ratio;
		this.fov = fov;
		this.near_plane = near_plane;
		this.far_plane = far_plane;

		compute_matrix();
	}

	void compute_matrix() @nogc @safe nothrow
	{
		float t = tan(radians(fov)/2);
		float ar = aspect_ratio;

		float z1 = (-near_plane - far_plane)/(near_plane - far_plane);
		float z2 = (2*near_plane*far_plane)/(near_plane - far_plane); 

		_matrix.set([
			[1/(ar*t),   0,  0, 0f],
			[       0, 1/t,  0, 0f],
			[       0,   0, z1, 1f],
			[       0,   0, z2, 0f]
		]);
	}

	@property ref Mat4 matrix() @nogc @safe nothrow
	{
		compute_matrix();
		return _matrix;
	}
}
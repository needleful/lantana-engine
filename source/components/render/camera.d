// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0


module components.render.camera;

import lanlib.math.matrix;
import lanlib.math.projection;
import lanlib.math.transform;
import lanlib.math.vector;

struct Camera
{
	Projection projection;
	Transform transform;

	@safe @nogc this(Vec3 position, float aspect, float fov)
	{
		projection = Projection(aspect, fov, 0.0001, 8000);
		transform = Transform(1, -position);
	}

	@safe @nogc @property Mat4 vp()
	{
		Mat4 mat = projection.matrix;
		mat *= transform.matrix;
		return mat;
	}
}
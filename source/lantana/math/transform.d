// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module lantana.math.transform;

import std.math: sin, cos;

import gl3n.linalg;

import lantana.math.func;

struct Transform
{
	private mat4 m_matrix;
	// X Y and Z rotations in degrees
	private vec3 m_rotation;
	private vec3 m_position;
	private vec3 m_scale;
	private bool m_changed;

	this(const float scale, const vec3 position = vec3(0), const vec3 rotation = vec3(180, 0, 0))  @safe nothrow
	{
		m_scale = vec3(scale);
		m_position = position;
		m_rotation = rotation;
		m_changed = true;
	}

	mat4 computeMatrix()  @safe nothrow
	{
		if(m_changed)
		{	
			m_matrix = mat4(
				vec4(m_scale.x, 0.0f,     0.0f,     0),
				vec4(0.0f,     m_scale.y, 0.0f,     0),
				vec4(0.0f,     0.0f,     m_scale.z, 0),
				vec4(0.0f,     0.0f,     0.0f,  1.0f)
			);
			m_matrix *= rotation_matrix();
			m_matrix[0][3] = m_position.x;
			m_matrix[1][3] = m_position.y;
			m_matrix[2][3] = m_position.z;
			m_changed = false;
		}

		return m_matrix;
	}

	void scale(const float s)  @safe nothrow
	{
		m_scale.x = s;
		m_scale.y = s;
		m_scale.z = s;
		m_changed = true;
	}

	void scale(const vec3 scale)  @safe nothrow
	{
		m_scale = scale;
		m_changed = true;
	}

	void translate(const vec3 v)  @safe nothrow
	{
		m_position.x += v.x;
		m_position.y += v.y;
		m_position.z += v.z;
		m_changed = true;
	}

	void rotateDegrees(vec3 v) @safe nothrow
	{
		rotateDegrees(v.x, v.y, v.z);
		m_changed = true;
	}

	void rotateDegrees(float x, float y, float z)  @safe nothrow
	{
		m_rotation.x += x;
		m_rotation.y += y;
		m_rotation.z += z;

		foreach(ref float angle; m_rotation.vector)
		{
			while(angle >= 360)
			{
				angle -= 360;
			}
			while(angle <= -360)
			{
				angle += 360;
			}
		}
		m_changed = true;
	}

	void setPosition(vec3 pos) @safe nothrow
	{
		m_position = pos;
		m_changed = true;
	}

	void setMatrix(mat4 mat) @safe nothrow
	{
		m_matrix = mat;
		m_changed = false;
	}

	void setRotation(vec3 rot) @safe nothrow
	{
		m_rotation = rot;
		m_changed = true;
	}

	const vec3 rotation() @safe nothrow
	{
		return m_rotation;
	}

	mat4 rotation_matrix()  @safe nothrow
	{
		float sx, sy, sz;
		float cx, cy, cz;
		sincos(radians(m_rotation.x), sx, cx);
		sincos(radians(m_rotation.y), sy, cy);
		sincos(radians(m_rotation.z), sz, cz);

		return mat4(
			vec4(           cy*cz,            cy*sz,   -sy, 0f),
			vec4(sx*sy*cz - cx*sz, cx*cz + sx*sy*sz, sx*cy, 0f),
			vec4(sx*sz + cx*sy*cz, cx*sy*sz - sx*cz, cx*cy, 0f),
			vec4(0,0,0,1f)
		);
	}
}
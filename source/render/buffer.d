// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module render.buffer;

import gl3n.linalg: vec2, vec3, Vector;

import render.gl;
import render.material;
import render.mesh.attributes;
import ui.layout;

struct FrameBuffer
{
	private struct Vert
	{
		float uv;
		int position;
	}
	Material mat;
	private UniformId uTex, uDepth, uResolution;
	private GLuint buffer;
	// 0: color
	// 1: depth
	private GLuint[2] tex;
	private Attr!Vert attrib;
	/// 0: triangle
	/// 1: verts
	/// 2: uvs
	private GLuint[3] vbo;
	private GLuint vao;

	// The triangle for rendering
	private static immutable(ubyte[3]) s_triangle = [
	        0, 1, 2
	];
	private static immutable(vec2[3]) s_verts = [
	        vec2(-1,-2),
	        vec2( 3, 0),
	        vec2(-1, 2)
	];
	private static immutable(vec2[3]) s_uvs = [
	        vec2(0, -0.5),
	        vec2(2, 0.5),
	        vec2(0, 1.5)
	];

	private RealSize size;

	@disable this();

	public this(const string p_vert, const string p_frag, RealSize p_size)
	{
		glGenFramebuffers(1, &buffer);
		glGenTextures(tex.length, tex.ptr);

		glBindFramebuffer(GL_FRAMEBUFFER, buffer);

		glBindTexture(GL_TEXTURE_2D, tex[0]);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, cast(int)(p_size.width*1.25), cast(int)(p_size.height*1.25), 0, GL_RGBA, GL_UNSIGNED_BYTE, null);
		glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, tex[0], 0);
		glcheck();

		glBindTexture(GL_TEXTURE_2D, tex[1]);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexImage2D(GL_TEXTURE_2D, 0, GL_DEPTH_COMPONENT24, cast(int)(p_size.width*1.25), cast(int)(p_size.height*1.25), 0, GL_DEPTH_COMPONENT, GL_FLOAT, null);
		glFramebufferTexture2D(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_TEXTURE_2D, tex[1], 0);
		glcheck();

		glcheck();
		glDrawBuffer(GL_COLOR_ATTACHMENT0);
		glcheck();

		size = p_size;
		assert(glCheckFramebufferStatus(GL_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE);
		glBindFramebuffer(GL_FRAMEBUFFER, 0);

		mat = loadMaterial(p_vert, p_frag);
		attrib = Attr!Vert(mat);

		uTex = mat.getUniformId("in_tex");
		uDepth = mat.getUniformId("in_depth");
		uResolution = mat.getUniformId("resolution");
		assert(mat.canRender());

		// Create VBO
		glGenBuffers(vbo.length, vbo.ptr);
		glGenVertexArrays(1, &vao);
		glBindVertexArray(vao);

		attrib.enable();

		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, vbo[0]);
		glBufferData(
			GL_ELEMENT_ARRAY_BUFFER,
			s_triangle.length*ubyte.sizeof,
			s_triangle.ptr,
			GL_STATIC_DRAW);

		glBindBuffer(GL_ARRAY_BUFFER, vbo[1]);
		glBufferData(
			GL_ARRAY_BUFFER,
			s_verts.length*vec2.sizeof,
			s_verts.ptr,
			GL_STATIC_DRAW);
		glVertexAttribPointer(
			attrib.position,
			2, GL_FLOAT,
			GL_FALSE,
			0,
			cast(void*) 0);

		glBindBuffer(GL_ARRAY_BUFFER, vbo[2]);
		glBufferData(
			GL_ARRAY_BUFFER,
			s_uvs.length*vec2.sizeof,
			s_uvs.ptr,
			GL_STATIC_DRAW);
		glVertexAttribPointer(
			attrib.uv,
			2, GL_FLOAT,
			GL_FALSE,
			0,
			cast(void*) 0);

		glBindVertexArray(0);

		attrib.disable();
	}

	public ~this()
	{
		glDeleteBuffers(vbo.length, vbo.ptr);
		glDeleteVertexArrays(1, &vao);
		glDeleteTextures(tex.length, tex.ptr);
		glDeleteFramebuffers(1, &buffer);
	}

	public void bind()
	{
		glBindFramebuffer(GL_FRAMEBUFFER, buffer);
		glDepthMask(GL_TRUE);
		glClear(GL_DEPTH_BUFFER_BIT);
		glViewport(0, 0, cast(int)(size.width*1.25), cast(int)(size.height*1.25));
	}

	public void render()
	{
		mat.enable();

		glDisable(GL_DEPTH_TEST);
		glDepthMask(GL_FALSE);
		glDisable(GL_BLEND);

		glBindVertexArray(vao);
		glActiveTexture(GL_TEXTURE0);
		glBindTexture(GL_TEXTURE_2D, tex[0]);
		mat.setUniform(uTex, 0);

		glActiveTexture(GL_TEXTURE1);
		glBindTexture(GL_TEXTURE_2D, tex[1]);
		mat.setUniform(uDepth, 1);
		mat.setUniform(uResolution, vec2(size.width, size.height));

		glDrawElements(
			GL_TRIANGLES, 
			cast(int) s_triangle.length,
			GL_UNSIGNED_BYTE,
			cast(void*) 0);

		glBindVertexArray(0);
	}

	public void unbind()
	{
		glBindFramebuffer(GL_FRAMEBUFFER, 0);
		glViewport(0, 0, size.width, size.height);
	}

	public void resize(RealSize p_size)
	{
		glBindTexture(GL_TEXTURE_2D, tex[0]);
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, cast(int)(p_size.width*1.25), cast(int)(p_size.height*1.25), 0, GL_RGBA, GL_UNSIGNED_BYTE, null);
		glBindTexture(GL_TEXTURE_2D, tex[1]);
		glTexImage2D(GL_TEXTURE_2D, 0, GL_DEPTH_COMPONENT24, cast(int)(p_size.width*1.25), cast(int)(p_size.height*1.25), 0, GL_DEPTH_COMPONENT, GL_FLOAT, null);
		size = p_size;
	}
}
// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module ui.render;

debug import std.stdio;

import deimos.freeimage;

import gl3n.linalg: vec2, vec3, Vector;
import lanlib.types;
import lanlib.util.gl;
import render.material;

import ui.layout;
import ui.textures;

struct SpriteId
{
	mixin StrictAlias!ushort;
}

/// The Grand Poobah of UI.
/// It handles all the logic for rendering UI layouts and updating them responsibly.
/// There should be exactly one UIRenderer
public class UIRenderer
{
	/++++++++++++++++++++++++++++++++++++++
		UI Objects and State
	+++++++++++++++++++++++++++++++++++++++/

	/// What UI data was invalidated by a recent change
	/// Invalidation means that data has to be refreshed (expensive)
	enum UIData
	{
		Layout,
		TextEBO,
		SpriteEBO,
		PositionBuffer,
		UVBuffer,
		TextAtlas,
		SpriteAtlas,
	}
	private Bitfield!UIData invalidated;

	/// The base widget of the UI
	private Widget root;

	/// The size of the UI window
	private RealSize size;

	/++++++++++++++++++++++++++++++++++++++
		OpenGL data
	+++++++++++++++++++++++++++++++++++++++/

	struct VertAttributes
	{
		AttribId uv;
		AttribId position;
	}
	
	struct TextUniforms
	{
		/// uvec2
		UniformId cam_resolution;
		/// ivec2
		UniformId translation;
		/// uint
		UniformId in_tex;
		/// vec3
		UniformId color;
	}

	struct SpriteUniforms
	{
		/// uvec2
		UniformId cam_resolution;
		/// ivec2
		UniformId translation;
		/// uint
		UniformId in_tex;
	}

	/// 0: text elements
	/// 1: sprite elements
	/// 2: vertex positions, in pixels (all)
	/// 3: UV coordinates (all)
	private GLuint[4] vbo;

	/// 0: text VAO
	/// 1: sprite VAO
	private GLuint[2] vao;

	private ushort[] elemText;
	private ushort[] elemSprite;
	private svec2[] vertpos;
	private vec2[] uvs;

	private Material matText, matSprite;
	private VertAttributes atrText, atrSprite;
	private TextUniforms uniText;
	private SpriteUniforms uniSprite;

	private TextureAtlas!(dchar, ubyte) atlasText;
	private TextureAtlas!(SpriteId, AlphaColor) atlasSprite;

	private ushort spriteCount;

	/++++++++++++++++++++++++++++++++++++++
		public methods -- basic
	+++++++++++++++++++++++++++++++++++++++/

	public this(RealSize p_windowSize)
	{
		size = p_windowSize;

		initMaterials();
		initAtlases();
		initBuffers();
		invalidated.setAll();
	}

	public ~this()
	{
		glDeleteVertexArrays(vao.length, vao.ptr);
		glDeleteBuffers(vbo.length, vbo.ptr);
	}

	public void update(float delta)
	{
		if(invalidated[UIData.Layout])
		{
			IntrinsicSize intrinsics = IntrinsicSize(Bounds(size.width), Bounds(size.height)); 
			root.layout(this, intrinsics);
			root.prepareRender(this, root.position);
		}

		if(invalidated[UIData.SpriteAtlas])
		{
			atlasSprite.reload();
		}
		if(invalidated[UIData.TextAtlas])
		{
			atlasText.reload();
		}

		if(invalidated[UIData.TextEBO])
		{
			updateTextEBO();
		}
		if(invalidated[UIData.SpriteEBO])
		{
			updateSpriteEBO();
		}
		if(invalidated[UIData.PositionBuffer])
		{
			updatePositionBuffer();
		}
		if(invalidated[UIData.UVBuffer])
		{
			updateUVBuffer();
		}

		invalidated.clear();
	}

	public void render() @nogc
	{
		// Render sprites
		matSprite.enable();
		glBindVertexArray(vao[1]);

		glBindTexture(GL_TEXTURE_2D, atlasSprite.textureId);
		glActiveTexture(GL_TEXTURE0);

		matSprite.set_uniform(uniSprite.in_tex, 0);
		matSprite.set_uniform(uniSprite.translation, ivec2(0,0));
		matSprite.set_uniform(uniSprite.cam_resolution, uvec2(size.width, size.height));
		
		glDrawElements(
			GL_TRIANGLES,
			cast(int) elemSprite.length,
			GL_UNSIGNED_SHORT,
			cast(void*) 0);

		glcheck();

		// Render text
		matText.enable();
		glBindVertexArray(vao[0]);

		glBindTexture(GL_TEXTURE_2D, atlasText.textureId);
		glActiveTexture(GL_TEXTURE0);

		matText.set_uniform(uniText.in_tex, 0);
		matText.set_uniform(uniText.translation, ivec2(0,0));
		matText.set_uniform(uniText.cam_resolution, uvec2(size.width, size.height));
		// TODO: text color should be configurable
		matText.set_uniform(uniText.color, vec3(1, 1, 1));
		
		glDrawElements(
			GL_TRIANGLES,
			cast(int) elemText.length,
			GL_UNSIGNED_SHORT,
			cast(void*) 0);

		glBindVertexArray(0);

		glcheck();
	}

	public void setRootWidget(Widget p_root)
	{
		root = p_root;
		invalidated[UIData.Layout] = true;
	}

	public void setSize(RealSize p_size)
	{
		size = p_size;
		invalidated[UIData.Layout] = true;
	}

	/++++++++++++++++++++++++++++++++++++++
		public methods -- sprites
	+++++++++++++++++++++++++++++++++++++++/

	/// Add a sprite to be rendered
	public SpriteId addSprite(Texture!AlphaColor p_texture)
	{
		spriteCount += 1;
		SpriteId id = SpriteId(spriteCount);

		auto node = atlasSprite.getAtlasSpot(id, p_texture.size);
		if(node == null)
		{
			debug writeln("Failed to get atlas spot");
			return SpriteId(0);
		}

		bool success = atlasSprite.blit(node, p_texture.buffer);
		if(!success)
		{
			debug writeln("Failed to blit sprite");
			return SpriteId(0);
		}

		invalidated[UIData.SpriteAtlas] = true;

		return id;
	}

	/// Load a sprite from a file and add it
	/// filename: the path to the image
	public SpriteId loadSprite(const string filename)
	{
		Texture!AlphaColor image;
		auto format = FreeImage_GetFileType(filename.ptr);
		FIBITMAP* bitmap = FreeImage_Load(format, filename.ptr);
		image.size = RealSize(FreeImage_GetWidth(bitmap), FreeImage_GetHeight(bitmap));
		image.buffer = cast(AlphaColor*)FreeImage_GetBits(bitmap);

		auto result = addSprite(image);
		FreeImage_Unload(bitmap);

		return result;
	}

	public RealSize getSpriteSize(SpriteId p_id)
	{
		assert(p_id in atlasSprite.map);
		return atlasSprite.map[p_id].size;
	}

	/// Add a quad for a sprite (not sized yet)
	public ushort[] addSpriteQuad(SpriteId p_sprite)
	{
		assert(p_sprite in atlasSprite.map);

		// The uv positions are set by other functions, 
		// so they can stay (0,0) right now
		ushort vertStart = cast(ushort)vertpos.length;
		vertpos.length += 4;

		// The UVs must be set, though
		ushort uvstart = cast(ushort)uvs.length;
		assert(uvstart == vertStart);
		uvs.length += 4;

		TextureNode* node = atlasSprite.map[p_sprite];

		// UV start, normalized
		vec2 uv_pos = vec2(node.position.x, node.position.y);
		uv_pos.x /= atlasSprite.width;
		uv_pos.y /= atlasSprite.height;

		// UV offset, normalized
		vec2 uv_off = vec2(node.size.width, node.size.height);

		uv_off.x /= atlasSprite.width;
		uv_off.y /= atlasSprite.height;

		// Quads are laid out in space like so:
		// 1-------3   /\ +y
		// |       |   |
		// |       |   |
		// 0-------2   |
		// -------------> +x
		// With vertex indeces in this order:
		// 		{0, 2, 1}
		// 		{1, 2, 3}
		// This applies to both texture UV and screen position.
		uvs[uvstart..uvstart+4] = [
			uv_pos,
			uv_pos + vec2(0, uv_off.y),
			uv_pos + vec2(uv_off.x, 0),
			uv_pos + uv_off
		];

		ulong elemStart = elemSprite.length;
		elemSprite.length += 6;

		elemSprite[elemStart..elemStart+6]= [
			cast(ushort)(vertStart+0), 
			cast(ushort)(vertStart+2), 
			cast(ushort)(vertStart+1),

			cast(ushort)(vertStart+1), 
			cast(ushort)(vertStart+2), 
			cast(ushort)(vertStart+3)
		];

		invalidated[UIData.UVBuffer] = true;
		invalidated[UIData.SpriteEBO] = true;

		return elemSprite[elemStart..elemStart+6];
	}

	/// Set the size of the quad (while removing translation)
	public void setQuadSize(ushort[] p_vertices, RealSize p_size) @nogc nothrow
	{
		assert(p_vertices.length == 6);

		// Consult the diagram in addSpriteQuad for explanation
		ushort quadStart = p_vertices[0];
		vertpos[quadStart] = svec(0,0);
		vertpos[quadStart + 1] = svec(0, p_size.height);
		vertpos[quadStart + 2] = svec(p_size.width, 0);
		vertpos[quadStart + 3] = svec(p_size.width, p_size.height);

		invalidated[UIData.PositionBuffer] = true;
	}

	public void translateQuad(ushort[] p_vertices, svec2 p_translation) @nogc nothrow
	{
		assert(p_vertices.length == 6);
		ushort quadStart = p_vertices[0];

		vertpos[quadStart] += p_translation;
		vertpos[quadStart + 1] += p_translation;
		vertpos[quadStart + 2] += p_translation;
		vertpos[quadStart + 3] += p_translation;

		invalidated[UIData.PositionBuffer] = true;
	}

	/++++++++++++++++++++++++++++++++++++++
		public methods -- debug
	+++++++++++++++++++++++++++++++++++++++/

	/// Renders the sprite and text atlases.
	/// It also puts the renderer in an invalid state,
	/// so only render this once.
	debug public void debugRender()
	{
		glEnable(GL_BLEND);
		glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

		glcheck();
		// We'll just render the atlases as quads
		uvs.length = 7;
		vertpos.length = 7;

		uvs[0..$] = [
			vec2(0,0),
			vec2(0,1),
			vec2(1,0),
			vec2(1,1),

			vec2(0,1),
			vec2(1,0),
			vec2(1,1)
		];

		vertpos[0..$] = [
			svec(0, 0),
			svec(0, 256),
			svec(256, 0),
			svec(256, 256),

			svec(0, 1024),
			svec(1024, 0),
			svec(1024, 1024)
		];

		elemText.length = 6;
		elemSprite.length = 6;

		elemText[0..$] = [
			0, 2, 1,
			1, 2, 3
		];

		elemSprite[0..$] = [
			0, 5, 4,
			4, 5, 6
		];

		updateUVBuffer();
		updatePositionBuffer();
		updateTextEBO();
		updateSpriteEBO();

		glcheck();

		/// Render the text atlas with the camera at (0,0)

		matText.enable();

		glBindTexture(GL_TEXTURE_2D, atlasText.textureId);
		glActiveTexture(GL_TEXTURE0);

		matText.set_uniform(uniText.in_tex, 0);
		matText.set_uniform(uniText.translation, ivec2(0));
		matText.set_uniform(uniText.cam_resolution, uvec2(size.width, size.height));
		matText.set_uniform(uniText.color, vec3(1, 0, 1));

		glEnableVertexAttribArray(atrText.uv);
		glEnableVertexAttribArray(atrText.position);

		glBindBuffer(GL_ARRAY_BUFFER, vbo[2]);
		glVertexAttribIPointer(
			atrText.position,
			2, GL_SHORT,
			0, 
			cast(void*) 0);

		glBindBuffer(GL_ARRAY_BUFFER, vbo[3]);
		glVertexAttribPointer(
			atrText.uv,
			2, GL_FLOAT,
			GL_FALSE,
			0,
			cast(void*) 0);

		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, vbo[0]);
		glDrawElements(
			GL_TRIANGLES,
			cast(int) elemText.length,
			GL_UNSIGNED_SHORT,
			cast(void*) 0);

		glDisableVertexAttribArray(atrText.uv);
		glDisableVertexAttribArray(atrText.position);

		glcheck();

		// Render the Sprite atlas at (256, 256)

		matSprite.enable();

		glBindTexture(GL_TEXTURE_2D, atlasSprite.textureId);
		glActiveTexture(GL_TEXTURE0);

		matSprite.set_uniform(uniSprite.in_tex, 0);
		matSprite.set_uniform(uniSprite.translation, ivec2(256));
		matSprite.set_uniform(uniSprite.cam_resolution, uvec2(size.width, size.height));

		glEnableVertexAttribArray(atrSprite.uv);
		glEnableVertexAttribArray(atrSprite.position);

		glBindBuffer(GL_ARRAY_BUFFER, vbo[2]);
		glVertexAttribIPointer(
			atrSprite.position,
			2, GL_SHORT,
			0, 
			cast(void*) 0);

		glBindBuffer(GL_ARRAY_BUFFER, vbo[3]);
		glVertexAttribPointer(
			atrSprite.uv,
			2, GL_FLOAT,
			GL_FALSE,
			0,
			cast(void*) 0);

		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, vbo[1]);
		glDrawElements(
			GL_TRIANGLES,
			cast(int) elemSprite.length,
			GL_UNSIGNED_SHORT,
			cast(void*) 0);

		glDisableVertexAttribArray(atrSprite.uv);
		glDisableVertexAttribArray(atrSprite.position);

		glcheck();
	}

	/++++++++++++++++++++++++++++++++++++++
		private methods
	+++++++++++++++++++++++++++++++++++++++/

	private void initMaterials()
	{
		VertAttributes _build(Material* p_mat, GLuint p_vert, GLuint p_frag)
		{
			MaterialId prog = MaterialId(glCreateProgram());
			prog.glAttachShader(p_vert);
			prog.glAttachShader(p_frag);
			prog.link_shader();

			*p_mat = Material(prog);
			assert(p_mat.can_render());

			VertAttributes atr;
			atr.uv = p_mat.get_attrib_id("uv");
			atr.position = p_mat.get_attrib_id("position");

			return atr;
		} 

		GLuint vert2d = 
			compile_shader("data/shaders/screenspace2d.vert", GL_VERTEX_SHADER);
		GLuint fragText = 
			compile_shader("data/shaders/text2d.frag", GL_FRAGMENT_SHADER);
		GLuint fragSprite = 
			compile_shader("data/shaders/sprite2d.frag", GL_FRAGMENT_SHADER);

		atrText = _build(&matText, vert2d, fragText);
		uniText.cam_resolution = matText.get_uniform_id("cam_resolution");
		uniText.translation = matText.get_uniform_id("translation");
		uniText.in_tex = matText.get_uniform_id("in_tex");
		uniText.color = matText.get_uniform_id("color");

		atrSprite = _build(&matSprite, vert2d, fragSprite);
		uniSprite.cam_resolution = matSprite.get_uniform_id("cam_resolution");
		uniSprite.translation = matSprite.get_uniform_id("translation");
		uniSprite.in_tex = matSprite.get_uniform_id("in_tex");

		glDisable(GL_BLEND);
		glcheck();
	}

	private void initAtlases()
	{
		atlasSprite = TextureAtlas!(SpriteId, AlphaColor)(1024, 1024);
		atlasText   = TextureAtlas!(dchar, ubyte)(256, 256);
		debug
		{
			atlasSprite.blitgrid(color(255,255,0,255));
			atlasText.blitgrid(255);
		}
	}

	private void initBuffers()
	{
		glcheck();
		glGenBuffers(vbo.length, vbo.ptr);
		glGenVertexArrays(vao.length, vao.ptr);

		// Text EBO
		glBindVertexArray(vao[0]);

		glEnableVertexAttribArray(atrText.uv);
		glEnableVertexAttribArray(atrText.position);

		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, vbo[0]);

		glBindBuffer(GL_ARRAY_BUFFER, vbo[2]);
		glVertexAttribIPointer(
			atrText.position,
			2, GL_SHORT,
			0, 
			cast(void*) 0);

		glBindBuffer(GL_ARRAY_BUFFER, vbo[3]);
		glVertexAttribPointer(
			atrText.uv,
			2, GL_FLOAT,
			GL_FALSE,
			0,
			cast(void*) 0);

		glcheck();

		// Sprite EBO
		glBindVertexArray(vao[1]);

		glDisableVertexAttribArray(atrText.uv);
		glDisableVertexAttribArray(atrText.position);

		glEnableVertexAttribArray(atrSprite.uv);
		glEnableVertexAttribArray(atrSprite.position);

		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, vbo[1]);

		glBindBuffer(GL_ARRAY_BUFFER, vbo[2]);
		glVertexAttribIPointer(
			atrSprite.position,
			2, GL_SHORT,
			0, 
			cast(void*) 0);

		glBindBuffer(GL_ARRAY_BUFFER, vbo[3]);
		glVertexAttribPointer(
			atrSprite.uv,
			2, GL_FLOAT,
			GL_FALSE,
			0,
			cast(void*) 0);

		glBindVertexArray(0);

		glDisableVertexAttribArray(atrSprite.uv);
		glDisableVertexAttribArray(atrSprite.position);
	}

	/// Updates UV buffer
	private void updateUVBuffer()
	{
		glBindBuffer(GL_ARRAY_BUFFER, vbo[3]);
		glBufferData(GL_ARRAY_BUFFER,
			uvs.length*vec3.sizeof, uvs.ptr,
			GL_STATIC_DRAW);

		debug puts("Updated vertices");
	}

	private void updatePositionBuffer()
	{
		// Vertex positions
		glBindBuffer(GL_ARRAY_BUFFER, vbo[2]);
		glBufferData(GL_ARRAY_BUFFER,
			vertpos.length*svec2.sizeof, vertpos.ptr,
			GL_STATIC_DRAW);
	}

	private void updateTextEBO()
	{
		// Text EBO
		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, vbo[0]);
		glBufferData(GL_ELEMENT_ARRAY_BUFFER, 
			elemText.length*ushort.sizeof, elemText.ptr, 
			GL_STATIC_DRAW);

		debug puts("Updated text EBO");
	}

	private void updateSpriteEBO()
	{
		// Sprite EBO
		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, vbo[1]);
		glBufferData(GL_ELEMENT_ARRAY_BUFFER,
			elemSprite.length*ushort.sizeof, elemSprite.ptr,
			GL_STATIC_DRAW);

		debug puts("Updated sprite EBO");
	}
}
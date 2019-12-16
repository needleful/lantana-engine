// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module ui.render;

debug import std.stdio;

import gl3n.linalg: vec2, vec3, Vector;
import lanlib.types;
import lanlib.util.gl;
import render.material;
import ui.layout;

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
		TextMesh,
		SpriteMesh,
		TextAtlas,
		SpriteAtlas,
	}
	private Bitfield!UIData invalidated;

	/// The base widget of the UI
	public Widget root;
	/// The size of the UI window
	public RealSize size;

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
		UniformId cam_position;
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
		UniformId cam_position;
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
	private TextureAtlas!(ushort, AlphaColor) atlasSprite;

	private ushort spriteCount;

	/++++++++++++++++++++++++++++++++++++++
		public methods
	+++++++++++++++++++++++++++++++++++++++/

	public this(RealSize p_windowSize)
	{
		size = p_windowSize;

		initMaterials();
		initAtlases();
		initBuffers();
		invalidated.setAll();
	}

	public void update(float delta) @nogc nothrow
	{
		if(invalidated[UIData.Layout])
		{
			IntrinsicSize intrinsics = IntrinsicSize(Bounds(size.width), Bounds(size.height)); 
			root.layout(this, intrinsics);
			root.prepareRender(this, root.position);
		}

		invalidated.clear();
	}

	public void render() @nogc nothrow
	{
		// Render sprites
		matSprite.enable();

		// Render text
		matText.enable();

	}

	public ~this()
	{
		glDeleteVertexArrays(vao.length, vao.ptr);
		glDeleteBuffers(vbo.length, vbo.ptr);
	}

	/// Should not be called every frame
	debug public void debugRender()
	{
		glEnable(GL_BLEND);
		glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

		glcheck();
		// We'll just render the atlases as quads
		uvs.length = 4;
		vertpos.length = 4;

		uvs[0..4] = [
			vec2(0,0),
			vec2(0,1),
			vec2(1,0),
			vec2(1,1)
		];

		vertpos[0..4] = [
			svec(0, 0),
			svec(0, 256),
			svec(256, 0),
			svec(256, 256)
		];

		elemText.length = 6;
		elemSprite.length = 6;

		elemText[0..6] = [
			0, 2, 1,
			1, 2, 3
		];

		elemSprite[0..6] = [
			0, 2, 1,
			1, 2, 3
		];

		updateVertices();
		updateTextEBO();
		updateSpriteEBO();

		glcheck();


		/+++++++++
			Render the Sprite atlas at (0, 0)
		+++++++++/

		matSprite.enable();

		glBindTexture(GL_TEXTURE_2D, atlasSprite.textureId);
		glActiveTexture(GL_TEXTURE0);

		matSprite.set_uniform(uniSprite.in_tex, 0);
		matSprite.set_uniform(uniSprite.cam_position, ivec2(0,0));
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

		/+++++++++
			Render the text atlas with the camera at (-256, -256)
		+++++++++/

		matText.enable();

		glBindTexture(GL_TEXTURE_2D, atlasText.textureId);
		glActiveTexture(GL_TEXTURE0);

		matText.set_uniform(uniText.in_tex, 0);
		matText.set_uniform(uniText.cam_position, ivec2(-256, -256));
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

		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, vbo[1]);
		glDrawElements(
			GL_TRIANGLES,
			cast(int) elemText.length,
			GL_UNSIGNED_SHORT,
			cast(void*) 0);

		glDisableVertexAttribArray(atrText.uv);
		glDisableVertexAttribArray(atrText.position);

		glcheck();
	}

	public ushort getSpriteId()
	{
		ushort ret = spriteCount;
		spriteCount ++;
		return ret;
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

		atrText   = _build(&matText, vert2d, fragText);

		uniText.cam_resolution = matText.get_uniform_id("cam_resolution");
		uniText.cam_position = matText.get_uniform_id("cam_position");
		uniText.in_tex = matText.get_uniform_id("in_tex");
		uniText.color = matText.get_uniform_id("color");

		atrSprite = _build(&matSprite, vert2d, fragSprite);
		uniSprite.cam_resolution = matSprite.get_uniform_id("cam_resolution");
		uniSprite.cam_position = matSprite.get_uniform_id("cam_position");
		uniSprite.in_tex = matSprite.get_uniform_id("in_tex");

		glDisable(GL_BLEND);
		glcheck();
	}

	private void initAtlases()
	{
		atlasSprite = TextureAtlas!(ushort, AlphaColor)(256, 256);
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
	}

	/// Updates both the vertpos and UV
	private void updateVertices()
	{
		// Vertex positions
		glBindBuffer(GL_ARRAY_BUFFER, vbo[2]);
		glBufferData(GL_ARRAY_BUFFER,
			vertpos.length*svec2.sizeof, vertpos.ptr,
			GL_STATIC_DRAW);

		// Vertex UVs
		glBindBuffer(GL_ARRAY_BUFFER, vbo[3]);
		glBufferData(GL_ARRAY_BUFFER,
			uvs.length*vec3.sizeof, uvs.ptr,
			GL_STATIC_DRAW);
	}

	private void updateSpriteEBO()
	{
		// Sprite EBO
		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, vbo[1]);
		glBufferData(GL_ELEMENT_ARRAY_BUFFER,
			elemText.length*ushort.sizeof, elemText.ptr,
			GL_STATIC_DRAW);
	}

	private void updateTextEBO()
	{
		// Text EBO
		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, vbo[0]);
		glBufferData(GL_ELEMENT_ARRAY_BUFFER, 
			elemText.length*ushort.sizeof, elemText.ptr, 
			GL_STATIC_DRAW);
	}

	private void updateSpriteAtlas()
	{

	}

	private void updateTextAtlas()
	{

	}
}

/// A reference to vertices in a UIRenderer buffer
public struct UIMesh
{
	ushort[] elements;
}

struct Texture(TextureDataType)
{
	RealSize size;
	TextureDataType* buffer;
}

struct TextureAtlas(IdType, TextureDataType)
{
	struct Node
	{
		Node* left, right;
		ivec2 position;
		RealSize size;

		this(ivec2 p_position, RealSize p_size)
		{
			position = p_position;
			size = p_size;
		}

		bool isLeaf()
		{
			return left == null && right == null;
		}

		bool isEmpty()
		{
			return size.width == 0 && size.height == 0;
		}
	}

	alias tex = TextureDataType;

	static if(is(tex == ubyte))
	{
		enum internalFormat = GL_R8;
		enum textureFormat = GL_RED;
	}
	else static if(is(tex == Color))
	{
		enum internalFormat = GL_RGB8;
		enum textureFormat = GL_RGB;
	}
	else static if(is(tex == AlphaColor))
	{
		enum internalFormat = GL_RGBA8;
		enum textureFormat = GL_RGBA;
	}
	else
	{
		static assert(false, "Unsupported texture type: "~TextureDataType.stringof);
	}

	/// Map of IDs to nodes
	Node[IdType] map;

	/// The binary tree of nodes for texture packing
	Node tree;

	/// The texture data
	TextureDataType[] data;

	/// The OpenGL id of the texture
	GLuint textureId;

	/// The dimensions of the texture data
	ushort width, height;

	public this(ushort p_width, ushort p_height)
	{
		width = p_width;
		height = p_height;
		data.length = width*height;

		tree = Node(ivec2(0,0), RealSize(width, height));

		glGenTextures(1, &textureId);
		glBindTexture(GL_TEXTURE_2D, textureId);

		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);

	}

	public ~this()
	{
		glDeleteTextures(1, &textureId);
	}

	///TODO implement
	/// new_value indicates the atlas texture was changed
	public Node* getAtlasSpot(IdType p_id, RealSize p_size, bool* new_value = null)
	{
		Node* _getSpot(Node* p_node, IdType p_id, RealSize p_size)
		{
			if(p_node.isLeaf())
			{
				RealSize space = p_node.size - p_size;
			}
			return null;
		}

		if(p_id in map)
		{
			*new_value = false;
			return &map[p_id];
		}

		*new_value = true;
		return _getSpot(&tree, p_id, p_size);
	}

	public bool blit(Node* p_node, TextureDataType[] p_data)
	{
		debug import std.format;
		// Return false if the texture can't be blit
		ivec2 end = ivec2(p_node.position.x + p_node.size.width, p_node.position.y + p_node.size.height);
		if(end.x > width || end.y > height)
		{
			return false;
		}

		for(uint row = 0; row < p_node.size.height; row++)
		{
			uint sourceRowOffset = row*p_node.size.width;
			uint targetRowOffset = (p_node.position.y + row)*width;

			for(uint col = 0; col < p_node.size.width; col++)
			{
				uint source = sourceRowOffset + col;
				uint target = targetRowOffset + (p_node.position.x + col);

				assert(target >= 0 && target < data.length, 
					format("Invalid index %d [valid: 0 to %u]", target, data.length));

				data[target] = p_data[source];
			}
		}
		return true;
	}

	void blitgrid(tex p_color)
	{
		data[0..$] = tex.init;

		for(uint row = 0; row < height; row++)
		{
			for(uint col = 0; col < width; col += 32)
			{
				data[row*width + col] = p_color;
			}
		}

		for(uint row = 0; row < height; row += 32)
		{
			for(uint col = 0; col < width; col++)
			{
				data[row*width + col] = p_color;
			}
		}

		reload();
	}

	public void clearColor(TextureDataType p_color)
	{
		data[0..$] = p_color;
		reload();
	}

	public void reload()
	{
		glBindTexture(GL_TEXTURE_2D, textureId);
		glTexImage2D(
			GL_TEXTURE_2D,
			0, internalFormat,
			width, height,
			0, textureFormat,
			GL_UNSIGNED_BYTE, 
			data.ptr);
		glcheck();
	}
}

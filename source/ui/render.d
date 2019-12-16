// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module ui.render;

import gl3n.linalg: vec2, vec3, Vector;
import lanlib.types;
import lanlib.util.gl;
import render.material;
import ui.layout;


alias svec2 = Vector!(short, 2);
alias Color = Vector!(ubyte, 3);
alias AlphaColor = Vector!(ubyte, 4);

/// The Grand Poobah of UI.
/// It handles all the logic for rendering UI layouts and updating them responsibly.
/// There should be exactly one UIRenderer
public class UIRenderer
{
	enum UIData
	{
		Layout,
		Vertices,
		SpriteEBO,
		TextEBO,
		SpriteAtlas,
		TextAtlas
	}
	/// The base widget that this system updates and renders
	public Widget root;
	/// The size of the UI window
	public RealSize size;

	/// If this UI data was invalidated
	private Bitfield!UIData invalidated;

	/// 0: sprite elements
	/// 1: text elements
	/// 2: vertpos (all)
	/// 3: uv elements (all)
	private GLuint[4] vbo;

	/// 0: text VAO
	/// 1: sprite VAO
	private GLuint[2] vao;

	private ushort[] spriteElems;
	private ushort[] textElems;
	private svec2[] vertpos;
	private svec2[] uvs;

	private Material textMaterial;
	private Material spriteMaterial;

	private TextureAtlas!(ushort, Color) spriteAtlas;
	private TextureAtlas!(dchar, ubyte) textAtlas;

	public this()
	{
		initMaterials();
		initAtlases();
		initBuffers();
	}

	public void update(float delta) @nogc nothrow
	{
		if(invalidated[UIData.Layout])
		{
			IntrinsicSize intrinsics = IntrinsicSize(Bounds(size.width), Bounds(size.height)); 
			root.layout(this, intrinsics);
			root.prepareRender(this, root.position);
		}
	}

	public void render() @nogc nothrow
	{

	}

	/// Called by constructor
	private void initMaterials()
	{
		GLuint vert2d = 
			compile_shader("data/shaders/screenspace2d.vert", GL_VERTEX_SHADER);
		GLuint fragText = 
			compile_shader("data/shaders/text2d.frag", GL_FRAGMENT_SHADER);
		GLuint fragSprite = 
			compile_shader("data/shaders/sprite2d.frag", GL_FRAGMENT_SHADER);

		MaterialId spriteMat = MaterialId(glCreateProgram());
		MaterialId textMat = MaterialId(glCreateProgram());

		spriteMat.glAttachShader(vert2d);
		spriteMat.glAttachShader(fragSprite);

		textMat.glAttachShader(vert2d);
		textMat.glAttachShader(fragText);

		spriteMat.link_shader();
		textMat.link_shader();

		textMaterial = Material(textMat);
		spriteMaterial = Material(spriteMat);

		assert(textMaterial.can_render());
		assert(spriteMaterial.can_render());
		glcheck();
	}

	private void initAtlases()
	{
		spriteAtlas = TextureAtlas!(ushort, Color)(1024, 1024);
		textAtlas = TextureAtlas!(dchar, ubyte)(256, 256);
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

	}
	private void updateSpriteEBO()
	{

	}
	private void updateTextEBO()
	{

	}
}

/// A reference to a mesh for 
public struct UIMesh
{
	/// Index of first vertex in UIRenderer's buffer
	ushort start;
	/// Number of triangles for this mesh
	ushort tricount;

	public this(ushort p_start, ushort p_tricount)
	{
		start = p_start;
		tricount = p_tricount;
	}
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

		// These have no default values and the texture will just be black if they aren't set
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
	}

	public ~this()
	{
		glDeleteTextures(1, &textureId);
	}

	///TODO implement
	public Node* getAtlasSpot(IdType p_id, RealSize p_size)
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
			return &map[p_id];
		}
		else
		{
			return null;
		}
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
}

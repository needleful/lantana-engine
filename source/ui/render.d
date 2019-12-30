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
		Vertices,
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
	private TextureAtlas!(SpriteId, AlphaColor) atlasSprite;

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
		if(invalidated[UIData.Vertices])
		{
			updateVertices();
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
		matSprite.set_uniform(uniSprite.cam_position, ivec2(0,0));
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
		matText.set_uniform(uniText.cam_position, ivec2(0,0));
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

	// Sprite methods

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

		debug
		{
			puts("Quad UVs:");
			foreach(vert; elemSprite[elemStart..elemStart+6])
			{
				vec2 uv = uvs[vert];
				printf("\tv%d: [%f, %f]\n", vert, uv.x, uv.y);
			}
		}

		invalidated[UIData.Vertices] = true;
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

		debug
		{
			puts("Quad Size:");
			foreach(vert; p_vertices)
			{
				svec2 p = vertpos[vert];
				printf("\tv%d: [%d, %d]\n", vert, p.x, p.y);
			}
		}

		invalidated[UIData.Vertices] = true;
	}

	public void translateQuad(ushort[] p_vertices, svec2 p_translation) @nogc nothrow
	{
		assert(p_vertices.length == 6);
		ushort quadStart = p_vertices[0];

		vertpos[quadStart] += p_translation;
		vertpos[quadStart + 1] += p_translation;
		vertpos[quadStart + 2] += p_translation;
		vertpos[quadStart + 3] += p_translation;

		debug
		{
			puts("Translated Quad:");
			foreach(vert; p_vertices)
			{
				svec2 p = vertpos[vert];
				printf("\tv%d: [%d, %d]\n", vert, p.x, p.y);
			}
		}

		invalidated[UIData.Vertices] = true;
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

		// Render the Sprite atlas at (0, 0)

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

		/// Render the text atlas with the camera at (-256, -256)
		// I'm moving the camera because UI elements have no translation property

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

		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, vbo[0]);
		glDrawElements(
			GL_TRIANGLES,
			cast(int) elemText.length,
			GL_UNSIGNED_SHORT,
			cast(void*) 0);

		glDisableVertexAttribArray(atrText.uv);
		glDisableVertexAttribArray(atrText.position);

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

		glDisableVertexAttribArray(atrText.uv);
		glDisableVertexAttribArray(atrText.position);

		glcheck();

		// Sprite EBO
		glBindVertexArray(vao[1]);

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

		glDisableVertexAttribArray(atrSprite.uv);
		glDisableVertexAttribArray(atrSprite.position);

		glBindVertexArray(0);
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

		debug puts("Updated vertices");
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

struct TextureNode
{
	TextureNode* left, right;
	ivec2 position;
	RealSize size;
	bool occupied;

	this(ivec2 p_position, RealSize p_size)
	{
		position = p_position;
		size = p_size;
	}

	~this()
	{
		debug writefln("Deleting %s atlas node", occupied? "occupied" : (isLeaf?"empty": "joining") );
	}

	bool isLeaf()
	{
		return left == null && right == null;
	}
}

struct TextureAtlas(IdType, TextureDataType)
{
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
	TextureNode*[IdType] map;

	/// The binary tree of nodes for texture packing
	TextureNode tree;

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

		tree = TextureNode(ivec2(0,0), RealSize(width, height));

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
	public TextureNode* getAtlasSpot(IdType p_id, RealSize p_size, bool* new_value = null)
	{
		TextureNode* _getSpot(TextureNode* p_node, IdType p_id, RealSize p_size)
		{
			// Occupied or too small
			if(p_node.occupied || !p_node.size.contains(p_size))
			{
				return null;
			}
			if(p_node.isLeaf())
			{
				// Perfect size
				if(p_node.size == p_size)
				{
					p_node.occupied = true;
					map[p_id] = p_node;
					return p_node;
				}

				// Too big, requires splitting
				// When splitting, we only create the left node.
				// the right is created only when needed
				RealSize space = p_node.size - p_size;
				if(space.height >= space.width)
				{
					p_node.left = new TextureNode(
						p_node.position, 
						RealSize(p_node.size.width, p_size.height));

					return _getSpot(p_node.left, p_id, p_size);
				}
				else
				{
					p_node.left = new TextureNode(
						p_node.position,
						RealSize(p_size.width, p_node.size.height));

					return _getSpot(p_node.left, p_id, p_size);
				}
			}
			else // Not a leaf
			{
				TextureNode* result = _getSpot(p_node.left, p_id, p_size);
				if(result != null)
				{
					return result;
				}
				if(p_node.right != null)
				{
					return _getSpot(p_node.right, p_id, p_size);
				}

				// Create a right node if it can contain this texture
				RealSize space = p_node.size - p_node.left.size;
				RealSize newSize;
				ivec2 newPos;
				// It was split vertically if the heights are the same
				if(space.height == 0)
				{
					newSize = RealSize(space.width, p_node.size.height);
					newPos = ivec2(p_node.position.x + p_node.left.size.width, p_node.position.y);
					// Making sure my assumption is correct
					// Laying the left and right nodes side-by-side should equal the parent node
					assert(p_node.size == 
						RealSize(newSize.width + p_node.left.size.width, newSize.height));
				}
				else
				{
					newSize = RealSize(p_node.size.width, space.height);
					newPos = ivec2(p_node.position.x, p_node.position.y + p_node.left.size.height);

					assert(p_node.size == 
						RealSize(newSize.width, newSize.height + p_node.left.size.height));
				}

				if(newSize.contains(p_size)) // big enough for the image
				{
					p_node.right = new TextureNode(newPos, newSize);
					return _getSpot(p_node.right, p_id, p_size);
				}
				else
				{
					return null;
				}
			}
		}

		if(p_id in map)
		{
			if(new_value) *new_value = false;
			return map[p_id];
		}

		if(new_value) *new_value = true;
		return _getSpot(&tree, p_id, p_size);
	}

	public bool blit(TextureNode* p_node, TextureDataType* p_data)
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

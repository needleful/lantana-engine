// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module render.textures;

debug import std.stdio;
import deimos.freeimage;
import gl3n.linalg: vec2, vec3, Vector;

import lanlib.types;
import lanlib.util.gl;
import lanlib.util.memory;
import render.material;
import ui.layout;

struct Bitmap(TextureDataType)
{
	private FIBITMAP* _bits;
	RealSize size;
	TextureDataType* buffer;

	public this(string p_filename)
	{
		auto format = FreeImage_GetFileType(p_filename.ptr);
		_bits = FreeImage_Load(format, p_filename.ptr);

		assert(_bits != null, "Failed to load image: "~p_filename);

		size = RealSize(FreeImage_GetWidth(_bits), FreeImage_GetHeight(_bits));
		buffer = cast(TextureDataType*)FreeImage_GetBits(_bits);
	}

	public ~this()
	{
		FreeImage_Unload(_bits);
	}
}

struct Texture(TextureDataType)
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

	tex* buffer;
	GLuint id;
	RealSize size;

	this(string p_filename, bool p_filter, ILanAllocator p_alloc)
	{
		Bitmap!tex b = Bitmap!tex(p_filename);
		size = b.size;
		// Copy loaded bitmap
		uint length = size.width*size.height;
		buffer = p_alloc.make_list!tex(length).ptr;
		buffer[0..length] = b.buffer[0..length];

		glGenTextures(1, &id);
		glBindTexture(GL_TEXTURE_2D, id);

		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, p_filter? GL_LINEAR : GL_NEAREST);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);

		// Swap blue and red channels for FreeImage bitmaps
		static if(is(tex == Color))
		{
			GLint[4] swizzle = [GL_BLUE, GL_GREEN, GL_RED, GL_ONE];
			glTexParameteriv(GL_TEXTURE_2D, GL_TEXTURE_SWIZZLE_RGBA, swizzle.ptr);
		}
		else static if(is(tex == AlphaColor))
		{
			GLint[4] swizzle = [GL_BLUE, GL_GREEN, GL_RED, GL_ALPHA];
			glTexParameteriv(GL_TEXTURE_2D, GL_TEXTURE_SWIZZLE_RGBA, swizzle.ptr);
		}

		reload();
	}

	this(RealSize p_size, bool p_filter, tex* p_buffer)
	{
		size - p_size;
		buffer = p_buffer;

		init(p_filter);
	}

	public this(RealSize p_size, bool p_filter, ILanAllocator p_alloc)
	{
		size = p_size;
		buffer = p_alloc.make_list!tex(size.width*size.height).ptr;

		init(p_filter);
	}

	private void init(bool p_filter)
	{
		glGenTextures(1, &id);
		glBindTexture(GL_TEXTURE_2D, id);

		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, p_filter? GL_LINEAR : GL_NEAREST);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);

		reload();
	}

	public ~this()
	{
		glDeleteTextures(1, &id);
	}

	public bool blit(RealSize p_size, ivec2 p_position, tex* p_data, bool p_swap_red_blue = false)
	{
		debug import std.format;
		// Return false if the texture can't be blit
		ivec2 end = ivec2(p_position.x + p_size.width, p_position.y + p_size.height);
		if(end.x > size.width || end.y > size.height)
		{
			return false;
		}

		for(uint row = 0; row < p_size.height; row++)
		{
			uint sourceRowOffset = row*p_size.width;
			uint targetRowOffset = (p_position.y + row)*size.width;

			for(uint col = 0; col < p_size.width; col++)
			{
				uint source = sourceRowOffset + col;
				uint target = targetRowOffset + (p_position.x + col);

				if(p_swap_red_blue && !is(tex == ubyte))
				{
					static if(is(tex == AlphaColor))
					{
						buffer[target] = p_data[source].bgra;
					}
					else static if(is(tex == Color))
					{
						buffer[target] = p_data[source].bgr;
					}
				}
				else 
				{	
					buffer[target] = p_data[source];
				}
			}
		}
		return true;
	}

	void blitgrid(tex p_color)
	{
		buffer[0..size.width*size.height] = tex.init;

		for(uint row = 0; row < size.height; row++)
		{
			for(uint col = 0; col < size.width; col += 32)
			{
				buffer[row*size.width + col] = p_color;
			}
		}

		for(uint row = 0; row < size.height; row += 32)
		{
			for(uint col = 0; col < size.width; col++)
			{
				buffer[row*size.width + col] = p_color;
			}
		}

		reload();
	}

	public void clearColor(TextureDataType p_color)
	{
		buffer[0..size.width*size.height] = p_color;
		reload();
	}

	public void reload()
	{
		glBindTexture(GL_TEXTURE_2D, id);
		glTexImage2D(
			GL_TEXTURE_2D,
			0, internalFormat,
			size.width, size.height,
			0, textureFormat,
			GL_UNSIGNED_BYTE, 
			buffer);
		glcheck();
	}
}

struct TextureNode
{
	TextureNode* left, right;
	ivec2 position;
	RealSize size;
	bool occupied;

	this(ivec2 p_position, RealSize p_size) nothrow
	{
		position = p_position;
		size = p_size;
	}

	~this() nothrow
	{
		// I want to minimize the number of empty nodes
		// Occupied nodes point to a specific image, and joining nodes are necessary for splitting the atlas 
		// debug printf("Deleting %s atlas node\n", occupied? "occupied".ptr : (isLeaf?"empty".ptr: "joining".ptr) );
	}

	bool isLeaf() nothrow
	{
		return left == null && right == null;
	}
}

struct TextureAtlas(IdType, TextureDataType)
{
	/// Map of IDs to nodes
	TextureNode*[IdType] map;

	/// The binary tree of nodes for texture packing
	TextureNode tree;

	Texture!TextureDataType texture;

	public this(RealSize p_size, ILanAllocator p_alloc)
	{
		tree = TextureNode(ivec2(0,0), p_size);

		texture = Texture!TextureDataType(p_size, false, p_alloc);
	}

	///TODO implement
	/// new_value indicates the atlas texture was changed
	public TextureNode* getAtlasSpot(IdType p_id, RealSize p_size, bool* new_value = null) nothrow
	{
		TextureNode* _getSpot(TextureNode* p_node, IdType p_id, RealSize p_size) nothrow
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

	void reload()
	{
		return texture.reload();
	}
}
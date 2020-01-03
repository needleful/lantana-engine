// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module ui.textures;

debug import std.stdio;

import gl3n.linalg: vec2, vec3, Vector;

import lanlib.types;
import lanlib.util.gl;
import render.material;
import ui.layout;

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

	this(ivec2 p_position, RealSize p_size) nothrow
	{
		position = p_position;
		size = p_size;
	}

	~this() nothrow
	{
		// I want to minimize the number of empty nodes
		// Occupied nodes point to a specific image, and joining nodes are necessary for splitting the atlas 
		debug printf("Deleting %s atlas node\n", occupied? "occupied".ptr : (isLeaf?"empty".ptr: "joining".ptr) );
	}

	bool isLeaf() nothrow
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
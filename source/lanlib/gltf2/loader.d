// Part of the Lantana Engine
// developed by needleful
// Licensed under GPL v3.0

module lanlib.gltf2.loaded;

import lanlib.gltf2.types;

struct StaticMeshView
{
	/// Views for vertex attributes
	GLBBufferView positions, uvs, normals;

	/// View for EBO
	GLBBufferView elements;

	/// View for texture (in the same buffer)
	GLBImage texAlbedo;
}

struct AnimatedMeshView
{
	/// Views for base vertex attributes
	GLBBufferView positions, uvs, normals;

	/// Views for animation-specific vertex attributes
	GLBBufferView jointWeights, jointIndices;

	/// View for EBO
	GLBBufferView elements;

	/// View for texture (in the same buffer)
	GLBImage texAlbedo;
}

struct PlayerMeshView
{

}

struct MeshSetView
{
	GLBBufferView[] subElements;
	GLBBufferView positions, uvs, normals;
	GLBImage atlasAlbedo;
}
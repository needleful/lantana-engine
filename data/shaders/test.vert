#version 130

in vec3 position;

uniform float scale;

void main()
{
	gl_Position = vec4(position.x*scale, position.y*scale, position.z, 1);
}
#version 330
uniform mat4 MVP;
layout (location=0) in vec3 position;
layout (location=1) in vec4 color;
out vec4 vColor;
layout (location=2) in vec2 texCoord;
out vec2 vTexCoord;

void main(void)
 {
   gl_Position = MVP*vec4(position,1.0);
   vColor = color;
   vTexCoord = texCoord;
}
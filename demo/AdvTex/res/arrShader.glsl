#version 330

[VERTEX]

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

[FRAGMENT]

uniform sampler2DArray tex0;
in vec4 vColor;
in vec2 vTexCoord;
out vec4 fragColor;

void main(void)
{
  vec3 c = vColor.bgr;
  vec4 col = texture(tex0, vec3(vTexCoord, vTexCoord.x+vTexCoord.y*2));
  fragColor = col;
}
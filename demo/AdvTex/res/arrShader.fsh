#version 330
uniform sampler2DArray tex0;
in vec4 vColor;
in vec2 vTexCoord;
out vec4 fragColor;

void main(void)
{
  vec3 c = vColor.bgr;
  vec4 col = texture(tex0, vec3(vTexCoord, vTexCoord.x+vTexCoord.y));
  //fragColor = col+vec4(vTexCoord/2.0, 0.0, 1.0);
  fragColor = col;
}
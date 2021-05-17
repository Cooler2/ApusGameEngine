#version 330
uniform sampler2D tex0;
uniform float uFactor;
uniform vec3 ambientColor;
uniform vec3 lightDir;
uniform vec3 lightColor;
uniform float lightPower;
in vec3 vNormal;
in vec4 vColor;
in vec2 vTexCoord;
out vec4 fragColor;

void main(void)
{
  vec3 c = vec3(vColor.b,vColor.g,vColor.r);
  float a = vColor.a;
  vec3 normal = normalize(vNormal);
  float diff = lightPower*max(dot(normal,lightDir),0.0);
  c = c*lightColor*diff+ambientColor;
  fragColor = vec4(c.r, c.g, c.b, a);
}
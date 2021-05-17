#version 330
// Shader for drawing regular primitives (without normals)
uniform sampler2D tex0; // reserved for engine's use
uniform sampler2D tex1; // shadow map
uniform mat4 LightMatrix;

in vec4 vColor;
in vec2 vTexCoord;
in vec4 vLightPos;
out vec4 fragColor;

void main(void)
{
  vec3 c = vColor.bgr;
  //vec4 lPos = 0.5*vLightPos+vec4(0.5, 0.12, 0.0,0.0);
  vec4 lPos = 0.5*vLightPos + vec4(0.5, 0.5, 0.5, 0.0);
  float depth = texture(tex1, lPos.xy).r;
  //fragColor = vec4(texture(tex1, lPos.xy).bgr, 1.0);
  //fragColor = vec4(depth,depth,depth, 1.0);
  //fragColor = vec4(depth, lPos.z, 0.0, vColor.a);
  if (depth < lPos.z*0.999) { c = c*0.5; } // shadow
  fragColor = vec4(c, vColor.a);
}
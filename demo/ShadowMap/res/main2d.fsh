#version 330
// Shader for drawing regular primitives (without normals)
uniform sampler2D tex0; // reserved for engine's use
uniform sampler2DShadow tex1; // shadow map
uniform mat4 LightMatrix;

in vec4 vColor;
in vec2 vTexCoord;
in vec4 vLightPos;
out vec4 fragColor;

void main(void)
{
  vec3 c = vColor.bgr;
  float shadow = texture(tex1, vLightPos.xyz);
  c = c*(0.7+0.3*shadow); // 30% shading
  //fragColor = vec4(vLightPos.xy, 0.0, 1.0);  // debug: view light space position
  //fragColor = vec4(depth,depth,depth, 1.0);  // debug: view shadowmap depth
  //fragColor = vec4(depth, vLightPos.z, 0.0, vColor.a);
  //if (depth < vLightPos.z-0.001) { c = c*0.5; } // shadow
  fragColor = vec4(c, vColor.a);
}
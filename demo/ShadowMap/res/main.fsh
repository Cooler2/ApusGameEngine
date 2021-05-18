#version 330
// Shader for drawing meshes (with normals)
uniform sampler2D tex0; // main texture
uniform sampler2D tex1; // shadow map
uniform float uFactor;
uniform vec3 ambientColor;
uniform vec3 lightDir;
uniform vec3 lightColor;
uniform float lightPower;
in vec3 vNormal;
in vec4 vColor;
in vec2 vTexCoord;
in vec4 vLightPos;
out vec4 fragColor;

void main(void)
{
  vec3 c = vColor.bgr;
  float a = vColor.a;
  float depth = texture(tex1, vLightPos.xy).r;
  //fragColor = vec4(vLightPos.xy, 0.0, 1.0);  // debug: view light space position
  //fragColor = vec4(depth,depth,depth, 1.0);  // debug: view shadowmap depth
  //fragColor = vec4(depth, vLightPos.z, 0.0, vColor.a);
  
  float diff = 0.0;
  if (depth > vLightPos.z-0.001) {
   vec3 normal = normalize(vNormal);
   diff = lightPower*max(dot(normal,lightDir),0.0);
  }
  c = c*(lightColor*diff+ambientColor);
  fragColor = vec4(c.r, c.g, c.b, a);
}
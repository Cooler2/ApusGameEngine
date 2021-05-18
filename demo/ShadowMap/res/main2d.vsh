#version 330
// Shader for regular primitives (without normals)
uniform mat4 MVP;
uniform mat4 ModelMatrix;
uniform mat4 LightMatrix;
layout (location=0) in vec3 position;
layout (location=1) in vec4 color;
out vec4 vColor;
layout (location=2) in vec2 texCoord;
out vec2 vTexCoord;
out vec4 vLightPos;

void main(void)
 {
   gl_Position = MVP * vec4(position,1.0);
   vColor = color;
   vTexCoord = texCoord;
   vLightPos = LightMatrix * ModelMatrix * vec4(position,1.0); // this is MVP in the light space
   //vLightPos = 0.5*vLightPos+0.5;
}
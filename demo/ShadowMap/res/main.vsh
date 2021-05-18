#version 330
// Shader for drawing meshes (with normals)
uniform mat4 MVP;
uniform mat4 ModelMatrix;
uniform mat4 LightMatrix;
layout (location=0) in vec3 position;
layout (location=1) in vec3 normal;
out vec3 vNormal;
layout (location=2) in vec4 color;
out vec4 vColor;
layout (location=3) in vec2 texCoord;
out vec2 vTexCoord;
out vec3 vLightPos;

void main(void)
 {
   gl_Position = MVP*vec4(position,1.0);
   vNormal = mat3(ModelMatrix)*normal;
   vColor = color;
   vTexCoord = texCoord;
   vLightPos = vec3(LightMatrix * ModelMatrix * vec4(position,1.0)); // this is MVP in the light space
}
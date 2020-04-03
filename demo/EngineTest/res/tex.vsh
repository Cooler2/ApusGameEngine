#version 330

uniform mat4 uMVP;
uniform mat4 uModel;
layout (location=0) in vec3 position;
layout (location=1) in vec3 normal;
layout (location=2) in vec2 texCoord;
out vec3 vNormal;
out vec2 vTexCoord;

void main(void)
{
   gl_Position = uMVP * vec4(position, 1.0);
   //vFragPos = vec3(uModel * vec4(position, 1.0f));
   //vNormal = normal;
   vNormal = normalize(mat3(uModel) * normal);
   vTexCoord = texCoord;
}
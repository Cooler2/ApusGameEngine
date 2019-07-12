#version 330
in vec3 vNormal;
out vec4 fragColor;

float ambient = 0.2;
vec3 objColor = vec3(1.0, 0.8, 0.7);

void main(void)
{
  vec3 lightDir = normalize(vec3(0.8, -1.0, 1.0));
  
  float light = ambient + max(dot(vNormal, lightDir), 0.0);
  fragColor = vec4(objColor * light, 1.0);  
}

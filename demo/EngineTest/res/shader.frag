#version 110
uniform sampler2D TextureUnit0;
uniform sampler2D TextureUnit1;

void main(void)
{
  float v1 = 2.0 / 6.0;
  float v2 = 1.0 / 6.0;

  vec4 value0 = texture2D(TextureUnit0, vec2(gl_TexCoord[0]));
  vec4 value1 = texture2D(TextureUnit1, vec2(gl_TexCoord[1]));
  vec4 value2 = texture2D(TextureUnit1, vec2(gl_TexCoord[2]));
  vec4 value3 = texture2D(TextureUnit1, vec2(gl_TexCoord[3]));
  vec4 value4 = texture2D(TextureUnit1, vec2(gl_TexCoord[4]));

        gl_FragColor = (value0*v1 + value1*v2 + value2*v2 + value3*v2 + value4*v2);
//        gl_FragColor = value0*v1;
}

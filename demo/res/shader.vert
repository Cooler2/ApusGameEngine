#version 110
uniform float offset;

void main(void)
{
        gl_TexCoord[0] = gl_MultiTexCoord0;
        gl_TexCoord[1] = gl_MultiTexCoord0+vec4(offset,offset,0,0);
        gl_TexCoord[2] = gl_MultiTexCoord0+vec4(-offset,offset,0,0);
        gl_TexCoord[3] = gl_MultiTexCoord0+vec4(offset,-offset,0,0);
        gl_TexCoord[4] = gl_MultiTexCoord0+vec4(-offset,-offset,0,0);

        gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
}
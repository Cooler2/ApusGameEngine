// Shared GLSL source headers. Include in a const section after defines.inc.
{$IFDEF GLES}
  GLSL_VERTEX_HEADER='#version 300 es'#13#10;
  GLSL_FRAGMENT_HEADER=GLSL_VERTEX_HEADER+'precision highp float;'#13#10;
{$ELSE}
  GLSL_VERTEX_HEADER='#version 330'#13#10;
  GLSL_FRAGMENT_HEADER=GLSL_VERTEX_HEADER;
{$ENDIF}

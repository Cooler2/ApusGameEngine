// Clear daylight sky, rendered from world-space directions without a dome mesh.
//
// Copyright (C) 2026 Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (https://github.com/Cooler2/ApusGameEngine)
unit Apus.Engine.Sky;
{$I defines.inc}
interface
uses Apus.Geom3D, Apus.Engine.Resources;

type
  TSkyParameters=record
    zenithColor,horizonColor,sunColor:cardinal; // RGB, in the scene's output color space
    upDirection:TVec3; // world up; nonzero, normalized by Draw
    sunDirection:TVec3; // towards the sun; nonzero, normalized by Draw
    horizonPower:single; // positive; smaller values narrow the pale horizon band
    sunRadius:single; // angular radius in radians; zero hides the disk
    sunGlow:single; // nonnegative intensity of the broad sun halo
    class function ClearDay:TSkyParameters; static;
  end;

  TSky=class
    parameters:TSkyParameters;
    constructor Create;
    destructor Destroy; override;
    // Render thread / current GL context only. Set perspective and camera first;
    // draw before opaque geometry. Uses the current target, viewport and clipping.
    // Preserves transforms, depth contents/state and blend mode; selects DrawAll
    // culling and resets the shader. Set culling/materials for subsequent geometry.
    // A sky background does not provide scene reflections or environment lighting.
    procedure Draw;
  private
    skyShader:TShader; // compiled lazily on the first Draw
  end;

implementation
uses Apus.Core, Apus.VertexLayout, Apus.Engine.API, Apus.Engine.Types, Apus.Engine.Graphics;

const
  {$IFDEF GLES}
  SHADER_HEADER:String8='#version 300 es'#10+'precision highp float;'#10;
  {$ELSE}
  SHADER_HEADER:String8='#version 330'#10;
  {$ENDIF}

  SKY_VERTEX:String8=
    'layout(location=0) in vec2 position;'#10+
    'uniform mat4 skyInvProjection,skyInvView;'#10+
    'out vec3 skyDirection;'#10+
    'void main(){'#10+
    '  gl_Position=vec4(position,1.0,1.0);'#10+
    '  vec4 p=skyInvProjection*vec4(position,1.0,1.0);'#10+
    '  skyDirection=(skyInvView*vec4(p.xyz/p.w,0.0)).xyz;'#10+
    '}';

  SKY_FRAGMENT:String8=
    'in vec3 skyDirection; out vec4 fragColor;'#10+
    'uniform vec3 skyUp,skySunDir,skyZenith,skyHorizon,skySunColor;'#10+
    'uniform float skyHorizonPower,skySunRadius,skySunGlow;'#10+
    'void main(){'#10+
    '  vec3 d=normalize(skyDirection);'#10+
    '  float height=clamp(dot(d,skyUp),0.0,1.0);'#10+
    // Finite slope at the horizon avoids the sharp band of pow(height,p<1).
    '  float gradient=1.0-pow(1.0-height,1.0/skyHorizonPower);'#10+
    '  vec3 color=mix(skyHorizon,skyZenith,gradient);'#10+
    '  float mu=clamp(dot(d,skySunDir),-1.0,1.0);'#10+
    '  float facing=max(mu,0.0);'#10+
    // Broad forward scattering, kept separate from the small solar disk.
    '  float halo=(0.25*pow(facing,4.0)+0.75*pow(facing,32.0))*skySunGlow;'#10+
    '  color=mix(color,skySunColor,clamp(halo,0.0,1.0));'#10+
    '  float angle=acos(mu);'#10+
    '  float edge=max(fwidth(angle),0.00001);'#10+
    '  float disk=1.0-smoothstep(skySunRadius-edge,skySunRadius+edge,angle);'#10+
    '  if(skySunRadius<=0.0 || dot(skySunDir,skyUp)<0.0) disk=0.0;'#10+
    '  color=mix(color,skySunColor,disk);'#10+
    '  fragColor=vec4(color,1.0);'#10+
    '}';

  // Oversized triangle covers the viewport without a diagonal interpolation seam.
  SKY_TRIANGLE:array[0..2] of TVec2=((x:-1;y:-1),(x:3;y:-1),(x:-1;y:3));

class function TSkyParameters.ClearDay:TSkyParameters;
  begin
    result.zenithColor:=$FF397FC5;
    result.horizonColor:=$FFD5E3EC;
    result.sunColor:=$FFFFF4DF;
    result.upDirection:=Vec3(0,0,1);
    result.sunDirection:=Vec3(0.4,0.3,1);
    result.horizonPower:=0.45;
    result.sunRadius:=0.00465; // approximately 0.53 degrees across
    result.sunGlow:=0.25;
  end;

constructor TSky.Create;
  begin
    inherited;
    parameters:=TSkyParameters.ClearDay;
  end;

destructor TSky.Destroy;
  begin
    skyShader.Free;
    inherited;
  end;

procedure TSky.Draw;
  var
    depth:TDepthMode;
    blend:TBlendingMode;
    up,sun:TVec3;
    projection,view:TMat4d;
  begin
    ASSERT(parameters.upDirection.Length>0,'Sky: up direction must be nonzero');
    ASSERT(parameters.sunDirection.Length>0,'Sky: sun direction must be nonzero');
    ASSERT(parameters.horizonPower>0,'Sky: horizon power must be positive');
    ASSERT(parameters.sunRadius>=0,'Sky: sun radius must be nonnegative');
    ASSERT(parameters.sunGlow>=0,'Sky: sun glow must be nonnegative');
    projection:=transform.ProjMatrix;
    ASSERT(abs(projection[2,3])>0,'Sky.Draw needs a perspective projection');
    projection.Invert;
    view:=transform.ViewMatrix;
    view.Invert;
    up:=parameters.upDirection; up.Normalize;
    sun:=parameters.sunDirection; sun.Normalize;
    if skyShader=nil then skyShader:=shader.Build(SHADER_HEADER+SKY_VERTEX,SHADER_HEADER+SKY_FRAGMENT);
    depth:=gfx.target.DepthMode;
    blend:=renderTargetAPI.CurrentBlendMode;
    try
      gfx.target.SetDepthMode(TDepthTest.Disabled,TDepthWrite.Off);
      gfx.target.BlendMode(blNone);
      gfx.SetCullMode(TCullMode.DrawAll);
      clippingAPI.Prepare;
      shader.UseCustom(skyShader);
      shader.SetUniform('skyInvProjection',projection);
      shader.SetUniform('skyInvView',view);
      shader.SetUniform('skyUp',up);
      shader.SetUniform('skySunDir',sun);
      shader.SetUniform('skyZenith',TShader.VectorFromColor3(parameters.zenithColor));
      shader.SetUniform('skyHorizon',TShader.VectorFromColor3(parameters.horizonColor));
      shader.SetUniform('skySunColor',TShader.VectorFromColor3(parameters.sunColor));
      shader.SetUniform('skyHorizonPower',parameters.horizonPower);
      shader.SetUniform('skySunRadius',parameters.sunRadius);
      shader.SetUniform('skySunGlow',parameters.sunGlow);
      renderDevice.Draw(TRG_LIST,1,@SKY_TRIANGLE,TVertexLayout.Create([vcPosition2d]));
    finally
      shader.Reset;
      gfx.target.SetDepthMode(depth.test,depth.write);
      gfx.target.BlendMode(blend);
    end;
  end;

end.

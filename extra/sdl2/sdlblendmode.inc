//from "sdl_blendmode.h"

{**
 *  The blend mode used in SDL_RenderCopy() and drawing operations.
 *}

type
  PSDL_BlendMode = ^TSDL_BlendMode;
  TSDL_BlendMode = type DWord;

const
  SDL_BLENDMODE_NONE  = TSDL_BlendMode($00000000);    {**< No blending *}
  SDL_BLENDMODE_BLEND = TSDL_BlendMode($00000001);    {**< dst = (src * A) + (dst * (1-A)) *}
  SDL_BLENDMODE_ADD   = TSDL_BlendMode($00000002);    {**< dst = (src * A) + dst *}
  SDL_BLENDMODE_MOD   = TSDL_BlendMode($00000004);    {**< dst = src * dst *}

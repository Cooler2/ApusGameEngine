from pathlib import Path
import subprocess
from PIL import Image

out=Path(__file__).parent/'r32_png'
out.mkdir(exist_ok=True)
img=Image.new('RGBA',(1024,1024))
img.putdata([((x*17+y*3)&255,(x*5+y*11)&255,(x^y)&255,(x*13+y*7)&255)
             for y in range(1024) for x in range(1024)])
img.save(out/'rgba_large.png')
img=Image.new('RGBA',(128,128))
img.putdata([((x*2)&255,(y*2)&255,160,255 if (x//8+y//8)%2 else 96)
             for y in range(128) for x in range(128)])
img.save(out/'ui_small.png')
img=Image.new('P',(512,512))
img.putpalette([v for i in range(256) for v in (i,(i*3)&255,255-i)])
img.putdata([(x//4+y//4)&255 for y in range(512) for x in range(512)])
img.save(out/'palette.png')
img=Image.new('L',(512,512))
img.putdata([(x*3+y*5)&255 for y in range(512) for x in range(512)])
img.save(out/'gray.png')

subprocess.run(['magick',str(out/'rgba_large.png'),'-interlace','PNG',
                str(out/'interlaced.png')],check=True)

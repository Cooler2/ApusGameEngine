unit scene3D;
interface
 uses Geom2d,Geom3D;
 type
  ColorRGBA=packed record
   r,g,b,a:single;
  end;
  ColorRGB=packed record
   r,g,b:single;
  end;

  // Ёлемент иерархии сцены
  TFrame=class
   parent,next,firstChild,lastChild:TFrame;
   id:integer; // уникальный ID объекта
   name:string; // им€ фрейма (уникальное среди объектов этого уровн€)
   transform:TMatrix43; // трансформаци€ фрейма
   data:TObject; // объект, который содержит фрейм
  end;

  // базовый класс материала
  TMaterial=class
   name:string;
  end;

  // базовый класс блендера
  TBlender=class
   name:string;
  end;

  // базовый класс текстуры
  TTexture=class
   name:string;
  end;

  // эта запись определ€ет режим рисовани€ примитивов
  TShader=record
   material:TMaterial; // определ€ет алгоритм вычислени€ цветов вершин (это может быть и вершинный шейдер)
   blender:TBlender; // определ€ет алгоритм растеризации (это может быть пиксел-шейдер)
   textures:array[1..4] of TTexture; // набор текстур
  end;

  // часть меша, состо€ща€ из примитивов одного типа и использующа€ один шейдер
  TPart=record
   primtype:integer;
   material:TMaterial;
   blender:TBlender;
   textures:array[1..4] of TTexture;
   primcount:integer;
   indices:array of integer; // индекс-буфер
  end;

  // Ѕазовый меш-класс
  TMesh=class
   vertices:array of TPoint3s; // вершины (и прочие точки)
   normals:array of TVector3s; // нормали вершин
   colors:array of ColorRGBA; // цвета вершин
   tex1,tex2,tex3:array of TPoint2s; // текстурные к-ты
   parts:array of TPart; // части меша
   options:cardinal; // доп. параметры
  end;

  // —цена
  TScene=class
   name:string;
   rootframe:TFrame;
   meshes:array of TMesh;
   textures:array of TTexture;
   materials:array of TMaterial;
   blenders:array of TBlender;
   shaders:array of TShader;
   cameras:array of TCamera;
   lights:array of TLight;
  end;


implementation

end.

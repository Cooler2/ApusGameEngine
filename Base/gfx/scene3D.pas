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

  // ������� �������� �����
  TFrame=class
   parent,next,firstChild,lastChild:TFrame;
   id:integer; // ���������� ID �������
   name:string; // ��� ������ (���������� ����� �������� ����� ������)
   transform:TMatrix43; // ������������� ������
   data:TObject; // ������, ������� �������� �����
  end;

  // ������� ����� ���������
  TMaterial=class
   name:string;
  end;

  // ������� ����� ��������
  TBlender=class
   name:string;
  end;

  // ������� ����� ��������
  TTexture=class
   name:string;
  end;

  // ��� ������ ���������� ����� ��������� ����������
  TShader=record
   material:TMaterial; // ���������� �������� ���������� ������ ������ (��� ����� ���� � ��������� ������)
   blender:TBlender; // ���������� �������� ������������ (��� ����� ���� ������-������)
   textures:array[1..4] of TTexture; // ����� �������
  end;

  // ����� ����, ��������� �� ���������� ������ ���� � ������������ ���� ������
  TPart=record
   primtype:integer;
   material:TMaterial;
   blender:TBlender;
   textures:array[1..4] of TTexture;
   primcount:integer;
   indices:array of integer; // ������-�����
  end;

  // ������� ���-�����
  TMesh=class
   vertices:array of TPoint3s; // ������� (� ������ �����)
   normals:array of TVector3s; // ������� ������
   colors:array of ColorRGBA; // ����� ������
   tex1,tex2,tex3:array of TPoint2s; // ���������� �-��
   parts:array of TPart; // ����� ����
   options:cardinal; // ���. ���������
  end;

  // �����
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

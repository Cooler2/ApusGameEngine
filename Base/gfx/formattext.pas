// ������ ��� ��������� ���������������� ����������� (���������� ������ HTML)
//
//
// Copyright (C) 2004 Apus Software (www.games4win.com)
// Author: Ivan Polyacov (ivan@apus-software.com)
unit formattext;
interface
 const
  // ��������� ����������� ������
  sfLowered   = 1;  // ����������
  sfRaised    = 2;  // ��������
  sfShadow    = 3;  // � �����
  sfUnderline = 16; // � ��������������

 type
  // ��� ��������, ��������� ���� - ��� ���������, � �� ��� �������� ���������!
  // ������� ��������� ���������������� ������
  TBaseItem=class
   id:integer;
   x,y,width,height:integer; // ��������� ��������
   link:string; // ���� ������ �������� - ������� �������� �������
   style:TObject; // reserved: ��� ����� ����� ��������, ������������ ��� ������� �� �������
  end;
  // �������-�������
  TTextItem=class(TBaseItem)
   font:integer;
   color:cardinal;
   text:string;
   styleFlags:cardinal; // ���. ����� ��� �����������
  end;
  // �������-��������
  TImageItem=class(TBaseItem)
   name:string;
  end;

  // ������� ����� ��� ������ � ��������������� �������
  // ��� ������������� ����� �������������� ������ ����������� ������ ������ � ���������
  TTextFormatter=class
   width,height:integer; // ������ ������ ����� ���������

   constructor Create;
   // �������� ������
   // ------------
   // ���������� �����, ������� ������ ��������� ��� ���������
   procedure Parse(text:string;canvasWidth:integer); virtual;
   // ���������� �������� ������� (��������� ������������ ���� ���������� ��-��)
   procedure Draw(x,y,w,h:integer); virtual;

   // ������ ��� ��������������� ���������
   // ------------
   // ���������� ������ �������, ���������� �������� �������
   function GetTextWidth(t:string;font:integer):integer; virtual; abstract;
   // ���������� ����� �� ����������� ��� ������
   function GetCharOffset(c1,c2:string;font:integer):integer; virtual; abstract;
   // ���������� �������� �������
   procedure DrawItem(item:TBaseItem); virtual; abstract;
  protected
   count:integer;
   items:array of TBaseItem;
  end;

implementation

{ TTextFormatter }

constructor TTextFormatter.Create;
begin
 count:=0;
end;

procedure TTextFormatter.Draw(x, y, w, h: integer);
begin

end;

procedure TTextFormatter.Parse(text: string; canvasWidth: integer);
begin

end;

end.

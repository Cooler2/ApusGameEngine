// Модуль для обработки форматированного гипертекста (упрощенный аналог HTML)
//
//
// Copyright (C) 2004 Apus Software (www.games4win.com)
// Author: Ivan Polyacov (ivan@apus-software.com)
unit formattext;
interface
 const
  // Константы отображения текста
  sfLowered   = 1;  // вдавленный
  sfRaised    = 2;  // выпуклый
  sfShadow    = 3;  // с тенью
  sfUnderline = 16; // с подчеркиванием

 type
  // ВСЕ ЭЛЕМЕНТЫ, ОПИСАННЫЕ НИЖЕ - ДЛЯ ОТРИСОВКИ, А НЕ ДЛЯ ОПИСАНИЯ СТРУКТУРЫ!
  // Элемент отрисовки форматированного текста
  TBaseItem=class
   id:integer;
   x,y,width,height:integer; // положение элемента
   link:string; // если строка непустая - элемент является ссылкой
   style:TObject; // reserved: это будет стиль элемента, определяющий его реакцию на события
  end;
  // Элемент-надпись
  TTextItem=class(TBaseItem)
   font:integer;
   color:cardinal;
   text:string;
   styleFlags:cardinal; // доп. флаги для отображения
  end;
  // Элемент-картинка
  TImageItem=class(TBaseItem)
   name:string;
  end;

  // Базовый класс для работы с форматированным текстом
  // Для использования нужно переопределить методы определения ширины текста и отрисовку
  TTextFormatter=class
   width,height:integer; // размер текста после обработки

   constructor Create;
   // Основные методы
   // ------------
   // обработать текст, создать список элементов для отрисовки
   procedure Parse(text:string;canvasWidth:integer); virtual;
   // Нарисовать заданную область (используя определенный ниже отрисовщик эл-та)
   procedure Draw(x,y,w,h:integer); virtual;

   // Методы для переопределения потомками
   // ------------
   // определить ширину надписи, выведенную заданным шрифтом
   function GetTextWidth(t:string;font:integer):integer; virtual; abstract;
   // определить сдвиг по горизонтали для вывода
   function GetCharOffset(c1,c2:string;font:integer):integer; virtual; abstract;
   // Нарисовать заданный элемент
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

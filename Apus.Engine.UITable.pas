// -----------------------------------------------------
// Table: rows of cells under a header with columns, sorting and single selection
//
// Author: Ivan Polyacov, Apus Software (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (http://apus-software.com/engine/)
// ------------------------------------------------------

unit Apus.Engine.UITable;
interface
 uses Apus.Core, Apus.Lib, Apus.Engine.API, Apus.Engine.Types, Apus.Engine.UITypes,
  Apus.Engine.UIWidgets;

 type
  TTableSort=(tsText,   // by the text: case-insensitive, digit runs compared as numbers
              tsKey,    // by the cell key: sizes, times
              tsNone);  // the column does not sort

  TTableColumn=record
   caption:String8;
   width:single;         // UI units; 0 - a share of the room the fixed columns leave
   align:TTextAlignment;
   sort:TTableSort;
  end;

  TTableCell=record
   text:String8;  // shown
   key:double;    // sort key for tsKey columns
  end;
  PTableCell=^TTableCell;

  TTableRow=record
   cells:array of TTableCell;
   tag:NativeInt;
   group:integer;
  end;

  TUITable=class;
  TTableEvent=procedure(table:TUITable;row:integer) of object;

  // Rows of cells under a header. A header click sorts by the column, the second click reverses.
  // Rows keep their group first: a lower group goes above in either direction (folders first).
  // Equal rows keep the order they were added. Selection follows the row, not its place,
  // when the rows are sorted again.
  // Keys (Up, Down, PgUp, PgDn, Home, End, Enter) work while the table has the focus, and
  // while the focus is anywhere inside keyScope - an edit box above the table, for instance.
  TUITable=class(TUIScrollable)
   columns:array of TTableColumn;
   rowHeight,headerHeight:single;
   onSelect:TTableEvent;   // the selected row changed, row -1 - none
   onActivate:TTableEvent; // double click or Enter on a row
   constructor Create(width,height:single;parent:TUIElement;name:String8='');
   function AddColumn(const caption:String8;width:single;align:TTextAlignment=taLeft;
     sort:TTableSort=tsText):integer;
   procedure ClearRows;
   // A row at the end, its cells empty; tag - the app's id of the row
   function AddRow(tag:NativeInt=0;group:integer=0):integer;
   procedure SetCell(row,col:integer;const text:String8;key:double=0);
   procedure SortBy(col:integer;descending:boolean=false); // col -1 - the order the rows were added
   function RowCount:integer;
   function RowTag(row:integer):NativeInt;
   function CellText(row,col:integer):String8;
   function RowAt(place:integer):integer;  // the row shown at a place (0 - the top one)
   function PlaceOf(row:integer):integer;  // the place of a row, -1 - no such row
   procedure ScrollToRow(row:integer);     // scroll the least to show the row whole
   // Geometry in the client space of the table
   function ColumnLeft(col:integer):single;
   function ColumnWidth(col:integer):single;
   function RowsWidth:single;              // the client width without the scrollbar
   function ScrollPos:single;              // how far the rows are scrolled up
   function ColumnAt(x:single):integer;    // -1 - no column there
   function RowAtPoint(x,y:single):integer; // -1 - the header or below the last row

   procedure onMouseMove; override;
   procedure onMouseButtons(button:byte;state:boolean); override;
   function onKey(keycode:byte;pressed:boolean;shiftstate:byte):boolean; override;
   function onHotKey(keycode:byte;shiftstate:byte):boolean; override;
   procedure SetupScrollers; override; // the range from the row count, not children
  private
   rows:array of TTableRow;
   order:IntArray;      // places -> rows
   needSort:boolean;    // order is outdated
   fSortColumn:integer;
   fSortDescending:boolean;
   fSelected:integer;
   fKeyScope:TUIElement;
   fHoverRow,fHoverColumn:integer;
   lastClickRow:integer;
   lastClickTime:int64;
   procedure Arrange;
   procedure UpdateScroller;
   procedure SetSelected(row:integer);
   procedure SetKeyScope(scope:TUIElement);
   function HandleKey(keycode:byte):boolean;
   procedure Activate(row:integer);
  public
   property sortColumn:integer read fSortColumn;
   property sortDescending:boolean read fSortDescending;
   property selected:integer read fSelected write SetSelected; // row index, -1 - none; setting it scrolls it into view
   property hoverRow:integer read fHoverRow;       // the row under the mouse, -1 - none
   property hoverColumn:integer read fHoverColumn; // the header column under the mouse, -1 - none
   property keyScope:TUIElement read fKeyScope write SetKeyScope; // nil - keys only with the focus on the table
  end;

 // Text order of the sort: digit runs compare as numbers, the rest by bytes. Case folding
 // is the caller's: the table compares lowercased texts
 function NaturalCompare(const a,b:String8):integer;

implementation
 uses Apus.EventMan, Apus.Geom2D, Apus.Strings, Apus.Engine.Keys, Apus.Engine.UIShapes;

 const
  SCROLLBAR_WIDTH=8;
  DOUBLE_CLICK_TIME=400; // ms between the clicks of a double click on the same row
  MIN_FILL_WIDTH=20;     // the least width of a column that takes the free room

 function IsDigit(c:AnsiChar):boolean; inline;
  begin
   result:=(c>='0') and (c<='9');
  end;

 function NaturalCompare(const a,b:String8):integer;
  var
   i,j,la,lb,si,sj,k:integer;
  begin
   i:=1; j:=1;
   la:=length(a); lb:=length(b);
   while (i<=la) and (j<=lb) do begin
    if IsDigit(a[i]) and IsDigit(b[j]) then begin
     // leading zeros don't count: '007' = '7'
     while (i<la) and (a[i]='0') and IsDigit(a[i+1]) do inc(i);
     while (j<lb) and (b[j]='0') and IsDigit(b[j+1]) do inc(j);
     si:=i; sj:=j;
     while (i<=la) and IsDigit(a[i]) do inc(i);
     while (j<=lb) and IsDigit(b[j]) do inc(j);
     if i-si<>j-sj then exit((i-si)-(j-sj)); // a longer run is a larger number
     for k:=0 to i-si-1 do
      if a[si+k]<>b[sj+k] then exit(ord(a[si+k])-ord(b[sj+k]));
    end else begin
     if a[i]<>b[j] then exit(ord(a[i])-ord(b[j]));
     inc(i); inc(j);
    end;
   end;
   result:=(la-i)-(lb-j); // the rest: a prefix goes first
  end;

{ TUITable }

 constructor TUITable.Create(width,height:single;parent:TUIElement;name:String8);
  var
   bar:TUIScrollBar;
  begin
   inherited Create(width,height,parent,name);
   shape:=shapeFull;
   flags.canHaveFocus:=true;
   sendSignals:=ssMajor;
   SetPadding(1); // inside the border
   rowHeight:=20;
   headerHeight:=22;
   fSortColumn:=-1;
   fSelected:=-1;
   fHoverRow:=-1;
   fHoverColumn:=-1;
   lastClickRow:=-1;
   bar:=TUIScrollBar.CreateV(SCROLLBAR_WIDTH,clientHeight-headerHeight,self,name+'_scroll');
   bar.SetPos(clientWidth,headerHeight,pivotTopRight).SetAnchors(1,0,1,1);
   bar.flags.noParentClip:=true;
   scrollerV:=bar.GetScroller;
   UpdateScroller;
  end;

 function TUITable.AddColumn(const caption:String8;width:single;align:TTextAlignment;
   sort:TTableSort):integer;
  begin
   result:=length(columns);
   SetLength(columns,result+1);
   columns[result].caption:=caption;
   columns[result].width:=width;
   columns[result].align:=align;
   columns[result].sort:=sort;
  end;

 procedure TUITable.ClearRows;
  begin
   SetLength(rows,0);
   SetLength(order,0);
   needSort:=false;
   fSelected:=-1;
   fHoverRow:=-1;
   lastClickRow:=-1;
   UpdateScroller;
   scrollerV.SetValue(0);
  end;

 function TUITable.AddRow(tag:NativeInt;group:integer):integer;
  begin
   result:=length(rows);
   SetLength(rows,result+1);
   rows[result].tag:=tag;
   rows[result].group:=group;
   SetLength(order,result+1);
   order[result]:=result;
   needSort:=true;
   UpdateScroller;
  end;

 procedure TUITable.SetCell(row,col:integer;const text:String8;key:double);
  begin
   ASSERT((row>=0) and (row<length(rows)) and (col>=0));
   with rows[row] do begin
    if col>=length(cells) then SetLength(cells,col+1);
    cells[col].text:=text;
    cells[col].key:=key;
   end;
   needSort:=true;
  end;

 procedure TUITable.SortBy(col:integer;descending:boolean);
  begin
   if (col<0) or (col>=length(columns)) then col:=-1;
   fSortColumn:=col;
   fSortDescending:=descending and (col>=0);
   needSort:=true;
   if fSelected>=0 then ScrollToRow(fSelected);
  end;

 // Sort the places: group, then the sort column, then the order of adding
 procedure TUITable.Arrange;
  var
   keys:Strings8;
   temp:IntArray;
   sort:TTableSort;
   c:PTableCell;
   i,n:integer;

  function Cell(row:integer):PTableCell; // nil - the row has no such cell
   begin
    if fSortColumn<length(rows[row].cells) then result:=@rows[row].cells[fSortColumn]
     else result:=nil;
   end;

  function Compare(a,b:integer):integer;
   var
    ca,cb:PTableCell;
    ka,kb:double;
   begin
    result:=rows[a].group-rows[b].group;
    if result<>0 then exit;
    if sort=tsText then
     result:=NaturalCompare(keys[a],keys[b])
    else
    if sort=tsKey then begin
     ca:=Cell(a); cb:=Cell(b);
     if ca<>nil then ka:=ca.key else ka:=0;
     if cb<>nil then kb:=cb.key else kb:=0;
     if ka<kb then result:=-1
      else if ka>kb then result:=1;
    end;
    if fSortDescending then result:=-result;
    if result=0 then result:=a-b;
   end;

  // merge sort of order[lo..hi-1]
  procedure MergeSort(lo,hi:integer);
   var
    mid,i,j,k:integer;
   begin
    if hi-lo<2 then exit;
    mid:=(lo+hi) div 2;
    MergeSort(lo,mid);
    MergeSort(mid,hi);
    i:=lo; j:=mid; k:=lo;
    while (i<mid) and (j<hi) do begin
     if Compare(order[i],order[j])<=0 then begin
      temp[k]:=order[i]; inc(i);
     end else begin
      temp[k]:=order[j]; inc(j);
     end;
     inc(k);
    end;
    while i<mid do begin temp[k]:=order[i]; inc(i); inc(k); end;
    while j<hi do begin temp[k]:=order[j]; inc(j); inc(k); end;
    for k:=lo to hi-1 do order[k]:=temp[k];
   end;

  begin
   needSort:=false;
   n:=length(rows);
   if fSortColumn>=0 then sort:=columns[fSortColumn].sort
    else sort:=tsNone;
   if sort=tsText then begin
    SetLength(keys,n);
    for i:=0 to n-1 do begin
     c:=Cell(i);
     if c<>nil then keys[i]:=UTF8.ToLower(c.text);
    end;
   end;
   SetLength(order,n);
   for i:=0 to n-1 do order[i]:=i;
   SetLength(temp,n);
   MergeSort(0,n);
  end;

 function TUITable.RowCount:integer;
  begin
   result:=length(rows);
  end;

 function TUITable.RowTag(row:integer):NativeInt;
  begin
   if (row>=0) and (row<length(rows)) then result:=rows[row].tag
    else result:=-1;
  end;

 function TUITable.CellText(row,col:integer):String8;
  begin
   result:='';
   if (row<0) or (row>=length(rows)) or (col<0) then exit;
   if col<length(rows[row].cells) then result:=rows[row].cells[col].text;
  end;

 function TUITable.RowAt(place:integer):integer;
  begin
   if needSort then Arrange;
   if (place>=0) and (place<length(order)) then result:=order[place]
    else result:=-1;
  end;

 function TUITable.PlaceOf(row:integer):integer;
  var
   i:integer;
  begin
   if needSort then Arrange;
   for i:=0 to high(order) do
    if order[i]=row then exit(i);
   result:=-1;
  end;

 procedure TUITable.ScrollToRow(row:integer);
  var
   place:integer;
   top,view,pos:single;
  begin
   place:=PlaceOf(row);
   if place<0 then exit;
   top:=place*rowHeight;
   view:=clientHeight-headerHeight;
   pos:=ScrollPos;
   if top<pos then scrollerV.SetValue(top)
    else if top+rowHeight>pos+view then scrollerV.SetValue(top+rowHeight-view);
  end;

 function TUITable.RowsWidth:single;
  begin
   result:=clientWidth;
   if scrollerV.GetElement.flags.visible then result:=result-scrollerV.GetElement.width;
  end;

 function TUITable.ColumnWidth(col:integer):single;
  var
   i,fills:integer;
   fixed:single;
  begin
   if (col<0) or (col>=length(columns)) then exit(0);
   if columns[col].width>0 then exit(columns[col].width);
   fixed:=0; fills:=0;
   for i:=0 to high(columns) do
    if columns[i].width>0 then fixed:=fixed+columns[i].width
     else inc(fills);
   result:=Max(MIN_FILL_WIDTH,(RowsWidth-fixed)/fills);
  end;

 function TUITable.ColumnLeft(col:integer):single;
  var
   i:integer;
  begin
   result:=0;
   for i:=0 to col-1 do result:=result+ColumnWidth(i);
  end;

 function TUITable.ScrollPos:single;
  begin
   result:=scrollerV.GetValue;
  end;

 function TUITable.ColumnAt(x:single):integer;
  var
   i:integer;
   left,w:single;
  begin
   left:=0;
   if x>=0 then
    for i:=0 to high(columns) do begin
     w:=ColumnWidth(i);
     if x<left+w then exit(i);
     left:=left+w;
    end;
   result:=-1;
  end;

 function TUITable.RowAtPoint(x,y:single):integer;
  begin
   if (y<headerHeight) or (y>=clientHeight) or (x<0) or (x>=RowsWidth) then exit(-1);
   result:=RowAt(trunc((y-headerHeight+ScrollPos)/rowHeight));
  end;

 procedure TUITable.UpdateScroller;
  var
   bar:TUIElement;
   view,total:single;
  begin
   view:=Max(0,clientHeight-headerHeight);
   total:=length(rows)*rowHeight;
   scrollerV.SetRange(0,total);
   scrollerV.SetPageSize(view);
   scrollerV.SetStep(rowHeight*Max(1,round(view/rowHeight) div 2));
   bar:=scrollerV.GetElement;
   bar.SetPos(clientWidth,headerHeight,pivotTopRight);
   bar.size.y:=view;
   bar.flags.visible:=total>view;
  end;

 procedure TUITable.SetupScrollers;
  begin
   if scrollerV<>nil then UpdateScroller; // nil during the construction
  end;

 procedure TUITable.SetSelected(row:integer);
  var
   tag:NativeInt;
  begin
   if (row<0) or (row>=length(rows)) then row:=-1;
   if row>=0 then ScrollToRow(row);
   if row=fSelected then exit;
   fSelected:=row;
   if Assigned(onSelect) then onSelect(self,row);
   if (sendSignals<>ssNone) and (name<>'') then begin
    if row>=0 then tag:=rows[row].tag else tag:=-1;
    Signal('UI\'+name+'\Selected',tag);
   end;
  end;

 procedure TUITable.Activate(row:integer);
  begin
   if (row<0) or (row>=length(rows)) then exit;
   if Assigned(onActivate) then onActivate(self,row);
   if (sendSignals<>ssNone) and (name<>'') then Signal('UI\'+name+'\Activated',rows[row].tag);
  end;

 procedure TUITable.SetKeyScope(scope:TUIElement);
  const
   KEYS:array[0..6] of TKey=(TKey.Up,TKey.Down,TKey.PageUp,TKey.PageDown,TKey.Home,TKey.EndKey,TKey.Enter);
  var
   k:TKey;
  begin
   if scope=fKeyScope then exit;
   for k in KEYS do
    if scope=nil then RemoveHotKey(ord(k))
     else if fKeyScope=nil then SetHotKey(ord(k));
   fKeyScope:=scope;
  end;

 function TUITable.HandleKey(keycode:byte):boolean;
  var
   n,place,page:integer;
  begin
   result:=true;
   n:=length(rows);
   place:=PlaceOf(fSelected);
   page:=Max(1,trunc((clientHeight-headerHeight)/rowHeight)-1);
   case TKey(keycode) of
    TKey.Up:if place<0 then place:=n-1 else dec(place);
    TKey.Down:inc(place);
    TKey.PageUp:dec(place,page);
    TKey.PageDown:if place<0 then place:=page else inc(place,page);
    TKey.Home:place:=0;
    TKey.EndKey:place:=n-1;
    TKey.Enter:begin
     if fSelected<0 then exit(false); // nothing to activate: the key goes on
     Activate(fSelected);
     exit;
    end;
    else exit(false);
   end;
   if n>0 then SetSelected(RowAt(Clamp(place,0,n-1)));
  end;

 function TUITable.onKey(keycode:byte;pressed:boolean;shiftstate:byte):boolean;
  begin
   if pressed and (shiftstate=0) and HandleKey(keycode) then exit(false);
   result:=inherited onKey(keycode,pressed,shiftstate);
  end;

 // The focus is not on the table (onKey takes the keys then) but inside the key scope
 function TUITable.onHotKey(keycode:byte;shiftstate:byte):boolean;
  var
   f:TUIElement;
  begin
   f:=FocusedElement;
   if (fKeyScope=nil) or (f=nil) or (f=self) then exit(false);
   if (f<>fKeyScope) and not f.HasParent(fKeyScope) then exit(false);
   result:=HandleKey(keycode);
  end;

 procedure TUITable.onMouseMove;
  var
   p:TVec2;
  begin
   inherited;
   fHoverRow:=-1;
   fHoverColumn:=-1;
   if underMouse<>self then exit;
   p:=TransformFromScreen(Vec2(curMouseX,curMouseY));
   if (p.y>=0) and (p.y<headerHeight) then fHoverColumn:=ColumnAt(p.x)
    else fHoverRow:=RowAtPoint(p.x,p.y);
  end;

 procedure TUITable.onMouseButtons(button:byte;state:boolean);
  var
   p:TVec2;
   col,row:integer;
   isDouble:boolean;
  begin
   inherited;
   if (button<>1) or not state then exit;
   p:=TransformFromScreen(Vec2(curMouseX,curMouseY));
   if p.y<headerHeight then begin
    col:=ColumnAt(p.x);
    if (col<0) or (columns[col].sort=tsNone) then exit;
    SortBy(col,(col=fSortColumn) and not fSortDescending);
    exit;
   end;
   row:=RowAtPoint(p.x,p.y);
   if row<0 then exit;
   isDouble:=(row=lastClickRow) and (CoreTime.Ticks<lastClickTime+DOUBLE_CLICK_TIME);
   SetSelected(row);
   if isDouble then begin
    lastClickRow:=-1;
    Activate(row);
   end else begin
    lastClickRow:=row;
    lastClickTime:=CoreTime.Ticks;
   end;
  end;

end.

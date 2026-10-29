// -----------------------------------------------------
// Table: rows of cells under a header with columns, sorting and selection of one or several rows
//
// Author: Ivan Polyacov (ivan@apus-software.com)
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Game Engine (https://github.com/Cooler2/ApusGameEngine)
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
   flexible:boolean;     // added with width 0: keeps taking the table's width changes after a resize
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
  // With multiSelect the selected row is the focused one, the cursor of the keyboard; the set
  // of selected rows is separate: Ctrl+click toggles a row, Shift+click and Shift+arrows select
  // the range from the anchor, Ctrl+A (with the focus on the table) selects all rows.
  // A plain click, a plain key or setting 'selected' leaves the one row selected.
  TUITable=class(TUIScrollable)
   columns:array of TTableColumn;
   rowHeight,headerHeight:single;
   resizeColumns:boolean; // drag a header separator; columns to its right move without changing width
   multiSelect:boolean;
   onSelect:TTableEvent;   // the selected (focused) row changed, row -1 - none
   onSelectionChanged:TTableEvent; // the set of selected rows changed, row - the focused one
   onActivate:TTableEvent; // double click or Enter on a row
   constructor Create(width,height:single;parent:TUIElement;name:String8='');
   function AddColumn(const caption:String8;width:single;align:TTextAlignment=taLeft;
     sort:TTableSort=tsText):integer;
   procedure ClearRows;
   // A row at the end, its cells empty; tag - the app's id of the row
   function AddRow(tag:NativeInt=0;group:integer=0):integer;
   procedure SetCell(row,col:integer;const text:String8;key:double=0);
   procedure SortBy(col:integer;descending:boolean=false); // col -1 - the order the rows were added
   // A fixed width in UI units; a flexible column with width 0 takes the free room again
   procedure SetColumnWidth(col:integer;width:single);
   // Selection of several rows; without multiSelect the selected row is the set
   function IsSelected(row:integer):boolean;
   function SelectedCount:integer;
   function SelectedRows:IntArray;          // in the shown order
   procedure SetRowSelected(row:integer;value:boolean); // the focus stays where it is
   procedure SelectAll;
   procedure ClearSelection;
   procedure FocusRow(row:integer);          // move the focus, keeping the set; scrolls it into view
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
   function RowsHeight:single;             // visible rows below the header, above the horizontal bar
   function ScrollX:single;
   function ScrollPos:single;              // how far the rows are scrolled up
   function ColumnAt(x:single):integer;    // -1 - no column there
   function RowAtPoint(x,y:single):integer; // -1 - the header or below the last row

   procedure onMouseMove; override;
   procedure onMouseButtons(button:byte;state:boolean); override;
   procedure onLostFocus; override;
   function onKey(keycode:byte;pressed:boolean;shiftstate:byte):boolean; override;
   function onHotKey(keycode:byte;shiftstate:byte):boolean; override;
   procedure SetupScrollers; override; // the range from the row count, not children
  private
   rows:array of TTableRow; // the first fRowCount are used, the rest is spare capacity
   fRowCount:integer;
   order:IntArray;      // places -> rows
   fitWidth:single;     // RowsWidth when the flexible columns got fixed widths, 0 - they share the room
   needSort:boolean;    // order is outdated
   fSortColumn:integer;
   fSortDescending:boolean;
   fSelected:integer;
   marks:array of boolean; // multiSelect: the selected rows, as long as rows
   markCount:integer;
   anchor:integer;         // the row a Shift range starts from, -1 - the focused one
   rowsRevision:cardinal; // a callback may replace the listing during selection/activation
   fKeyScope:TUIElement;
   fHoverRow,fHoverColumn:integer;
   lastClickRow:integer;
   lastClickTime:int64;
   resizeColumn:integer;
   resizeStartX:single;
   resizeWidths:array of single;
   function SeparatorAt(x,y:single):integer;
   procedure StopResize;
   procedure Arrange;
   procedure UpdateScroller;
   procedure SetSelected(row:integer);
   procedure MoveFocus(row:integer);
   procedure SelectRange(fromRow,toRow:integer;add:boolean);
   procedure SelectionChanged;
   procedure SetKeyScope(scope:TUIElement);
   function HandleKey(keycode,shiftstate:byte):boolean;
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
   resizeColumns:=true;
   resizeColumn:=-1;
   fSortColumn:=-1;
   fSelected:=-1;
   anchor:=-1;
   fHoverRow:=-1;
   fHoverColumn:=-1;
   lastClickRow:=-1;
   bar:=TUIScrollBar.CreateV(SCROLLBAR_WIDTH,clientHeight-headerHeight,self,name+'_scroll');
   bar.SetPos(clientWidth,headerHeight,pivotTopRight).SetAnchors(1,0,1,1);
   bar.flags.noParentClip:=true;
   scrollerV:=bar.GetScroller;
   bar:=TUIScrollBar.CreateH(clientWidth,SCROLLBAR_WIDTH,self,name+'_scrollH');
   bar.flags.noParentClip:=true;
   scrollerH:=bar.GetScroller;
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
   columns[result].flexible:=width<=0;
  end;

 procedure TUITable.ClearRows;
  begin
   inc(rowsRevision);
   SetLength(rows,0);
   SetLength(order,0);
   marks:=nil;
   markCount:=0;
   anchor:=-1;
   fRowCount:=0;
   needSort:=false;
   fSelected:=-1;
   fHoverRow:=-1;
   lastClickRow:=-1;
   UpdateScroller;
   scrollerV.SetValue(0);
  end;

 function TUITable.AddRow(tag:NativeInt;group:integer):integer;
  begin
   result:=fRowCount;
   if result>=length(rows) then begin
    SetLength(rows,Max(16,result*2));
    SetLength(order,length(rows));
    SetLength(marks,length(rows));
   end;
   inc(fRowCount);
   marks[result]:=false;
   rows[result].cells:=nil;
   rows[result].tag:=tag;
   rows[result].group:=group;
   order[result]:=result;
   needSort:=true;
   UpdateScroller;
  end;

 procedure TUITable.SetCell(row,col:integer;const text:String8;key:double);
  begin
   ASSERT((row>=0) and (row<fRowCount) and (col>=0));
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

 procedure TUITable.SetColumnWidth(col:integer;width:single);
  var
   i:integer;
   shared:boolean;
  begin
   if (col<0) or (col>=length(columns)) then exit;
   if columns[col].flexible and (width<=0) then columns[col].width:=0
    else columns[col].width:=Max(MIN_FILL_WIDTH,width);
   // the room is shared again when no flexible column keeps a width of its own
   shared:=true;
   for i:=0 to high(columns) do
    if columns[i].flexible and (columns[i].width>0) then shared:=false;
   if shared then fitWidth:=0;
   UpdateScroller;
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
   n:=fRowCount;
   if fSortColumn>=0 then sort:=columns[fSortColumn].sort
    else sort:=tsNone;
   if sort=tsText then begin
    SetLength(keys,n);
    for i:=0 to n-1 do begin
     c:=Cell(i);
     if c<>nil then keys[i]:=UTF8.ToLower(c.text);
    end;
   end;
   for i:=0 to n-1 do order[i]:=i;
   SetLength(temp,n);
   MergeSort(0,n);
  end;

 function TUITable.RowCount:integer;
  begin
   result:=fRowCount;
  end;

 function TUITable.RowTag(row:integer):NativeInt;
  begin
   if (row>=0) and (row<fRowCount) then result:=rows[row].tag
    else result:=-1;
  end;

 function TUITable.CellText(row,col:integer):String8;
  begin
   result:='';
   if (row<0) or (row>=fRowCount) or (col<0) then exit;
   if col<length(rows[row].cells) then result:=rows[row].cells[col].text;
  end;

 function TUITable.RowAt(place:integer):integer;
  begin
   if needSort then Arrange;
   if (place>=0) and (place<fRowCount) then result:=order[place]
    else result:=-1;
  end;

 function TUITable.PlaceOf(row:integer):integer;
  var
   i:integer;
  begin
   if needSort then Arrange;
   for i:=0 to fRowCount-1 do
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
   view:=RowsHeight;
   pos:=ScrollPos;
   if top<pos then scrollerV.SetValue(top)
    else if top+rowHeight>pos+view then scrollerV.SetValue(top+rowHeight-view);
  end;

 function TUITable.RowsWidth:single;
  begin
   result:=clientWidth;
   if scrollerV.GetElement.flags.visible then result:=result-scrollerV.GetElement.width;
  end;

 function TUITable.RowsHeight:single;
  begin
   result:=Max(0,clientHeight-headerHeight);
   if (scrollerH<>nil) and scrollerH.GetElement.flags.visible then
    result:=Max(0,result-SCROLLBAR_WIDTH);
  end;

 function TUITable.ScrollX:single;
  begin
   result:=0;
   if scrollerH<>nil then result:=scrollerH.GetValue;
  end;

 function TUITable.ColumnWidth(col:integer):single;
  var
   i,fills:integer;
   fixed:single;
  begin
   if (col<0) or (col>=length(columns)) then exit(0);
   if columns[col].width>0 then begin
    result:=columns[col].width;
    // a flexible column follows the table width from the size it was given
    if columns[col].flexible and (fitWidth>0) then
     result:=Max(MIN_FILL_WIDTH,result+RowsWidth-fitWidth);
    exit;
   end;
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
   if (x<0) or (x>=RowsWidth) then exit(-1);
   x:=x+ScrollX;
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
   if (y<headerHeight) or (y>=headerHeight+RowsHeight) or (x<0) or (x>=RowsWidth) then exit(-1);
   result:=RowAt(trunc((y-headerHeight+ScrollPos)/rowHeight));
  end;

 procedure TUITable.UpdateScroller;
  var
   bar,hbar:TUIElement;
   view,total,totalWidth:single;
   i,pass:integer;
  begin
   if (scrollerV=nil) or (scrollerH=nil) then exit;
   bar:=scrollerV.GetElement; hbar:=scrollerH.GetElement;
   total:=fRowCount*rowHeight;
   bar.flags.visible:=false; hbar.flags.visible:=false;
   // Either bar may make the other necessary. Starting without bars converges
   // in at most three passes; flexible columns use the resulting viewport width.
   for pass:=0 to 2 do begin
    totalWidth:=0;
    for i:=0 to high(columns) do totalWidth:=totalWidth+ColumnWidth(i);
    hbar.flags.visible:=totalWidth>RowsWidth+0.01;
    bar.flags.visible:=total>RowsHeight;
   end;
   view:=RowsHeight;
   scrollerV.SetRange(0,total);
   scrollerV.SetPageSize(view);
   scrollerV.SetStep(rowHeight*Max(1,round(view/rowHeight) div 2));
   bar.SetPos(clientWidth,headerHeight,pivotTopRight);
   bar.size.y:=view;
   scrollerH.SetRange(0,totalWidth);
   scrollerH.SetPageSize(RowsWidth);
   scrollerH.SetStep(Max(20,RowsWidth/3));
   hbar.SetPos(0,clientHeight,pivotBottomLeft);
   hbar.size.x:=RowsWidth;
  end;

 procedure TUITable.SetupScrollers;
  begin
   if scrollerV<>nil then UpdateScroller; // nil during the construction
  end;

 procedure TUITable.MoveFocus(row:integer);
  var
   tag:NativeInt;
  begin
   if (row<0) or (row>=fRowCount) then row:=-1;
   if row>=0 then ScrollToRow(row);
   if row=fSelected then exit;
   fSelected:=row;
   if row>=0 then tag:=rows[row].tag else tag:=-1;
   if Assigned(onSelect) then onSelect(self,row);
   if (sendSignals<>ssNone) and (name<>'') then begin
    Signal('UI\'+name+'\Selected',tag);
   end;
  end;

 procedure TUITable.SelectionChanged;
  begin
   if Assigned(onSelectionChanged) then onSelectionChanged(self,fSelected);
  end;

 // The one row selected and focused
 procedure TUITable.SetSelected(row:integer);
  var
   i:integer;
   changed:boolean;
   revision:cardinal;
  begin
   if (row<0) or (row>=fRowCount) then row:=-1;
   changed:=row<>fSelected;
   if multiSelect then begin
    for i:=0 to fRowCount-1 do
     if marks[i]<>(i=row) then begin
      marks[i]:=i=row;
      changed:=true;
     end;
    markCount:=ord(row>=0);
    anchor:=row;
   end;
   revision:=rowsRevision;
   MoveFocus(row);
   if changed and (revision=rowsRevision) then SelectionChanged;
  end;

 procedure TUITable.FocusRow(row:integer);
  begin
   if multiSelect then MoveFocus(row) else SetSelected(row);
  end;

 function TUITable.IsSelected(row:integer):boolean;
  begin
   if (row<0) or (row>=fRowCount) then exit(false);
   if multiSelect then result:=marks[row] else result:=row=fSelected;
  end;

 function TUITable.SelectedCount:integer;
  begin
   if multiSelect then result:=markCount else result:=ord(fSelected>=0);
  end;

 function TUITable.SelectedRows:IntArray;
  var
   place,row,n:integer;
  begin
   result:=nil;
   SetLength(result,SelectedCount);
   n:=0;
   for place:=0 to fRowCount-1 do begin
    if n>=length(result) then break;
    row:=RowAt(place);
    if IsSelected(row) then begin
     result[n]:=row;
     inc(n);
    end;
   end;
   SetLength(result,n);
  end;

 procedure TUITable.SetRowSelected(row:integer;value:boolean);
  begin
   if (row<0) or (row>=fRowCount) then exit;
   if not multiSelect then begin
    if value then SetSelected(row)
     else if row=fSelected then SetSelected(-1);
    exit;
   end;
   if marks[row]=value then exit;
   marks[row]:=value;
   if value then inc(markCount) else dec(markCount);
   SelectionChanged;
  end;

 procedure TUITable.SelectAll;
  var
   i:integer;
  begin
   if not multiSelect or (markCount=fRowCount) then exit;
   for i:=0 to fRowCount-1 do marks[i]:=true;
   markCount:=fRowCount;
   SelectionChanged;
  end;

 procedure TUITable.ClearSelection;
  var
   i:integer;
  begin
   if not multiSelect then begin
    SetSelected(-1);
    exit;
   end;
   if markCount=0 then exit;
   for i:=0 to fRowCount-1 do marks[i]:=false;
   markCount:=0;
   SelectionChanged;
  end;

 // The rows shown from one to the other, both included; the event is the caller's
 procedure TUITable.SelectRange(fromRow,toRow:integer;add:boolean);
  var
   i,a,b:integer;
  begin
   a:=PlaceOf(fromRow); b:=PlaceOf(toRow);
   if a<0 then a:=b;
   if b<0 then exit;
   if a>b then begin
    i:=a; a:=b; b:=i;
   end;
   if not add then
    for i:=0 to fRowCount-1 do marks[i]:=false;
   for i:=a to b do marks[order[i]]:=true;
   markCount:=0;
   for i:=0 to fRowCount-1 do
    if marks[i] then inc(markCount);
  end;

 procedure TUITable.Activate(row:integer);
  var
   tag:NativeInt;
  begin
   if (row<0) or (row>=fRowCount) then exit;
   tag:=rows[row].tag;
   if Assigned(onActivate) then onActivate(self,row);
   if (sendSignals<>ssNone) and (name<>'') then Signal('UI\'+name+'\Activated',tag);
  end;

 procedure TUITable.SetKeyScope(scope:TUIElement);
  const
   KEYS:array[0..6] of TKey=(TKey.Up,TKey.Down,TKey.PageUp,TKey.PageDown,TKey.Home,TKey.EndKey,TKey.Enter);
   // Shift+Home and the rest select text in an edit box of the scope
   SHIFT_KEYS:array[0..1] of TKey=(TKey.Up,TKey.Down);
  var
   k:TKey;
  begin
   if scope=fKeyScope then exit;
   for k in KEYS do
    if scope=nil then RemoveHotKey(ord(k))
     else if fKeyScope=nil then SetHotKey(ord(k));
   for k in SHIFT_KEYS do
    if scope=nil then RemoveHotKey(ord(k),sscShift)
     else if fKeyScope=nil then SetHotKey(ord(k),sscShift);
   fKeyScope:=scope;
  end;

 function TUITable.HandleKey(keycode,shiftstate:byte):boolean;
  var
   n,place,page,row:integer;
   range:boolean;
   revision:cardinal;
  begin
   result:=true;
   range:=multiSelect and (shiftstate=sscShift);
   if (shiftstate<>0) and not range then exit(false);
   n:=fRowCount;
   place:=PlaceOf(fSelected);
   page:=Max(1,trunc(RowsHeight/rowHeight)-1);
   case TKey(keycode) of
    TKey.Up:if place<0 then place:=n-1 else dec(place);
    TKey.Down:inc(place);
    TKey.PageUp:dec(place,page);
    TKey.PageDown:if place<0 then place:=page else inc(place,page);
    TKey.Home:place:=0;
    TKey.EndKey:place:=n-1;
    TKey.Enter:begin
     if range or (fSelected<0) then exit(false); // nothing to activate: the key goes on
     Activate(fSelected);
     exit;
    end;
    else exit(false);
   end;
   if n=0 then exit;
   row:=RowAt(Clamp(place,0,n-1));
   if not range then begin
    SetSelected(row);
    exit;
   end;
   if anchor<0 then anchor:=fSelected;
   SelectRange(anchor,row,false);
   revision:=rowsRevision;
   MoveFocus(row);
   if revision=rowsRevision then SelectionChanged;
  end;

 function TUITable.onKey(keycode:byte;pressed:boolean;shiftstate:byte):boolean;
  begin
   if pressed and multiSelect and (shiftstate=sscCtrl) and (TKey(keycode)=TKey.A) then begin
    SelectAll;
    exit(false);
   end;
   if pressed and HandleKey(keycode,shiftstate) then exit(false);
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
   result:=HandleKey(keycode,shiftstate);
  end;

 function TUITable.SeparatorAt(x,y:single):integer;
 var
  i:integer;
  edge:single;
 begin
  result:=-1;
  if not resizeColumns or (y<0) or (y>=headerHeight) then exit;
  edge:=-ScrollX;
  for i:=0 to high(columns)-1 do begin
   edge:=edge+ColumnWidth(i);
   if (edge>0) and (edge<RowsWidth) and (Abs(x-edge)<=4) then exit(i);
  end;
 end;

 procedure TUITable.StopResize;
 begin
  resizeColumn:=-1;
  resizeWidths:=nil;
  if hooked=self then hooked:=nil;
  cursor:=0;
 end;

 procedure TUITable.onLostFocus;
 begin
  StopResize;
  inherited;
 end;

 procedure TUITable.onMouseMove;
  var
   p:TVec2;
   delta:single;
   i:integer;
  begin
   inherited;
   fHoverRow:=-1;
   fHoverColumn:=-1;
   if resizeColumn>=0 then begin
    cursor:=CursorID.ResizeW;
    if (hooked<>self) or (length(resizeWidths)<>length(columns)) then begin
     StopResize;
     exit;
    end;
    delta:=(curMouseX-resizeStartX)/globalScale;
    for i:=0 to high(columns) do columns[i].width:=resizeWidths[i];
    columns[resizeColumn].width:=Max(40,resizeWidths[resizeColumn]+delta);
    UpdateScroller;
    exit;
   end;
   cursor:=0;
   if underMouse<>self then exit;
   p:=TransformFromScreen(Vec2(curMouseX,curMouseY));
   if SeparatorAt(p.x,p.y)>=0 then cursor:=CursorID.ResizeW
   else if (p.y>=0) and (p.y<headerHeight) then fHoverColumn:=ColumnAt(p.x)
    else fHoverRow:=RowAtPoint(p.x,p.y);
  end;

 procedure TUITable.onMouseButtons(button:byte;state:boolean);
  var
   p:TVec2;
   col,row,i:integer;
   shift:byte;
   isDouble:boolean;
   revision:cardinal;
  begin
   inherited;
   if (button=1) and (resizeColumn>=0) then begin
    if not state then StopResize;
    exit;
   end;
   if (button<>1) or not state then exit;
   p:=TransformFromScreen(Vec2(curMouseX,curMouseY));
   col:=SeparatorAt(p.x,p.y);
   if col>=0 then begin
    resizeColumn:=col;
    resizeStartX:=curMouseX;
    SetLength(resizeWidths,length(columns));
    for i:=0 to high(columns) do resizeWidths[i]:=ColumnWidth(i);
    fitWidth:=RowsWidth;
    hooked:=self;
    cursor:=CursorID.ResizeW;
    lastClickRow:=-1;
    exit;
   end;
   if p.y<headerHeight then begin
    col:=ColumnAt(p.x);
    if (col<0) or (columns[col].sort=tsNone) then exit;
    SortBy(col,(col=fSortColumn) and not fSortDescending);
    exit;
   end;
   row:=RowAtPoint(p.x,p.y);
   if row<0 then exit;
   shift:=GetWindow.shiftState and (sscCtrl or sscShift);
   if multiSelect and (shift<>0) then begin
    // Shift - the range from the anchor (Ctrl+Shift adds it), Ctrl - one row in or out
    if shift and sscShift<>0 then begin
     if anchor<0 then anchor:=fSelected;
     SelectRange(anchor,row,shift and sscCtrl<>0);
    end else begin
     marks[row]:=not marks[row];
     if marks[row] then inc(markCount) else dec(markCount);
     anchor:=row;
    end;
    lastClickRow:=-1;
    revision:=rowsRevision;
    MoveFocus(row);
    if revision=rowsRevision then SelectionChanged;
    exit;
   end;
   isDouble:=(row=lastClickRow) and (CoreTime.Ticks<lastClickTime+DOUBLE_CLICK_TIME);
   revision:=rowsRevision;
   SetSelected(row);
   if revision<>rowsRevision then exit; // the click belonged to the old listing
   if isDouble then begin
    lastClickRow:=-1;
    Activate(row);
   end else begin
    lastClickRow:=row;
    lastClickTime:=CoreTime.Ticks;
   end;
  end;

end.

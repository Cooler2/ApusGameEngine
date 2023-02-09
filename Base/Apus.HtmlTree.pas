// Simple HTML parser
// Reference: https://www.w3.org/TR/2016/REC-html51-20161101/syntax.html

// Copyright (C) 2023 Ivan Polyacov, ivan@apus-software.com
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Base Library (http://apus-software.com/engine/#base)
unit Apus.HtmlTree;
interface
uses Apus.Types, Apus.Structs;

type
 THtmlNode=class;
 THtmlElement=class;

 THtmlNodeVisitor=procedure(node:THtmlNode;context:pointer);
 THtmlElementVisitor=procedure(element:THtmlElement;context:pointer);

 // Base node class
 THtmlNode=class
   parent:THtmlElement;
   text:string;
   constructor Create(parent:THtmlElement;text:string='');
   destructor Destroy; override;
   function Depth:integer; // how many parents the node has
 end;

 // Regular text node
 THtmlText=class(THtmlNode)
 end;

 // Content of foreign elements differs from regular text nodes and is not included in the InnerText
 THtmlForeignContent=class(THtmlNode)
 end;

 // Comment node class
 THtmlComment=class(THtmlNode)
 end;

 // Element node class. Only nodes of this type can have child nodes
 THtmlElement=class(THtmlNode)
   tag:string;
   attributes:TNameValueList;
   children:TArray<THtmlNode>;
   constructor Create(parent:THtmlElement;text:string='');
   destructor Destroy; override;
   procedure AddChild(node:THtmlNode);
   procedure RemoveChild(node:THtmlNode); // remove node from children, but don't delete it
   function InnerText:string;  // return concatenated text of all the children text nodes (recursively)
   procedure Visit(visitor:THtmlNodeVisitor;context:pointer); // call visitor for each child node (recursively)
   procedure VisitElements(visitor:THtmlElementVisitor;context:pointer;tag:string=''); // call visitor for each child element matching criteria
   // Find an element with given tag name, having specified attribute containing spefified text
   function GetElement(tag:string;attribute:string='';contains:string=''):THtmlElement;
   function PrintTree:string; // for debug
   function HasAttribute(aName:string):boolean;
   function AttributeContains(aName,substr:string):boolean;
 protected
   function IsVoid:boolean;
   function IsRawtext:boolean;
   function IsForeign:boolean;
   function CanContain(childTag:string):boolean; // can this element contain a 'childTag' element as a child?
 end;

 // Returns a HTML tree with an empty root element
 function ParseHTML(st:string):THtmlElement;

implementation
uses SysUtils, Apus.Common;

const
 VOID_ELEMENTS = '|!doctype|area|base|br|col|embed|hr|img|input|keygen|link|menuitem|meta|param|source|track|wbr|';
 RAWTEXT_ELEMENTS = '|script|style|textarea|title|';
 FOREIGN_ELEMENTS = '|svg|';

var
 whiteList:TVarHash; // contains list of allowed elements
 blackList:TVarHash; // contains list of forbidden elements

// Find the next unquoted '>' character
function FindTagEnd(const st:string;startPos:integer):integer;
var
 i:integer;
 quote:char;
begin
 quote:=#0;
 i:=startPos;
 while i<=length(st) do begin
   if quote=#0 then begin
    if st[i]='>' then exit(i);
    if st[i] in ['"',''''] then quote:=st[i];
   end else begin
    if (st[i]=quote) and (st[i-1]<>'\') then quote:=#0;
   end;
   inc(i);
 end;
end;

function ParseHTML(st:string):THtmlElement;
type
 TState=(stateText,stateComment,stateTag);
var
 root:THtmlElement;
 stack:TArray<THtmlElement>;
 i,p:integer;
 node:THtmlNode;
 element:THtmlElement;
 tag:string;
begin
 root:=THtmlElement.Create(nil);
 stack.Add(root);
 i:=1; // current position
 repeat
   // loop always starts in the "text" state
   p:=pos('<',st,i); // EOF or '<' symbol
   if p=0 then p:=length(st)+1;
   if p>i then begin
     // create text node
     node:=THtmlText.Create(stack.Last,copy(st,i,p-i));
     i:=p;
   end;
   if i>length(st) then break;
   if (i+3<length(st)) and (st[i+1]='!') and (st[i+2]='-') and (st[i+3]='-') then begin
     // comment node
     p:=pos('-->',st,i+4);
     if i=0 then p:=length(st)+1;
     node:=THtmlComment.Create(stack.Last,copy(st,i,p-i));
     i:=p+3;
     continue;
   end;
   // html close tag?
   if (i<length(st)) and (st[i+1]='/') then begin
     // closing tag
     p:=pos('>',st,i+1);
     tag:=copy(st,i+2,p-i-2);
     tag:=Lowercase(Chop(tag));
     i:=p+1;
     // Close tags
     for p:=stack.count-1 downto 1 do
      if tag=THtmlElement(stack.items[p]).tag then begin
        SetLength(stack.items,p); // trim the stack to this element
        break;
      end;
     continue;
   end;
   // Regular HTML tag
   p:=FindTagEnd(st,i+1);
   if p=0 then p:=length(st)+1;
   element:=THtmlElement.Create(nil,copy(st,i,p-i+1));
   i:=p+1;
   // Autoclose some elements?
   while stack.Count>1 do
     if THtmlElement(stack.Last).CanContain(element.tag) then break
       else stack.Pop;
   // Append element to the tree
   stack.Last.AddChild(element);
   // Process element
   if element.IsForeign or element.IsRawtext then begin
     // find end tag and create a text node for the whole content
     p:=PosFrom('</'+element.tag+'>',st,i,true); // To be accurate, space chars are allowed before '>'
     if p=0 then p:=length(st)+1;
     if element.IsForeign then
       THtmlForeignContent.Create(element,copy(st,i,p-i))
     else
       THtmlText.Create(element,copy(st,i,p-i));
     i:=pos('>',st,p)+1;
     continue;
   end else
   if not element.IsVoid then
     stack.Add(element); // push element to the stack
 until false;

 result:=root;
end;

{ THtmlNode }

constructor THtmlNode.Create(parent:THtmlElement;text:string);
begin
 self.parent:=parent;
 self.text:=text;
 if parent<>nil then parent.AddChild(self);
end;

function THtmlNode.Depth:integer;
var
 node:THtmlNode;
begin
 result:=0;
 node:=self;
 while node.parent<>nil do begin
  inc(result);
  node:=node.parent;
 end;
end;

destructor THtmlNode.Destroy;
begin
 if parent<>nil then parent.RemoveChild(self);
 inherited;
end;

{ THtmlElement }

constructor THtmlElement.Create(parent:THtmlElement; text:string);
var
 i,p:integer;
 name,value:string;
begin
 inherited;
 if text='' then exit;
 ASSERT(text.StartsWith('<') and text.EndsWith('>'),'Malformed tag: '+text);
 i:=2;
 // Extract tagname
 while (i<=length(text)) and not (text[i] in [' ',#9,#10,#13,'>']) do inc(i);
 tag:=Lowercase(copy(text,2,i-2));
 // Extract attributes
 while i<length(text) do begin
  // skip whitespace
  while (i<=length(text)) and (text[i] in [' ',#9,#10,#13]) do inc(i);
  // get attribute name
  p:=i;
  while (p<=length(text)) and not (text[p] in [' ','=',#9,#10,#13,'>']) do inc(p);
  name:=copy(text,i,p-i); // can be empty
  i:=p;
  // Skip whitespace before '='
  while (i<=length(text)) and (text[i] in [' ',#9,#10,#13]) do inc(i);
  if text[i]<>'=' then begin
    // no value
    if name<>'' then attributes.Item[name]:=''; // add attribute without value
    continue;
  end;
  inc(i); // next char after '=' - skip whitespace
  while (i<=length(text)) and (text[i] in [' ',#9,#10,#13]) do inc(i);
  // Extract value
  if (text[i]='''') or (text[i]='"') then begin
    // quoted value
    p:=i;
    repeat
     p:=PosFrom(text[i],text,p+1);
     if p=0 then begin
      // no end quote
      p:=length(text)-1;
      break;
     end;
     if text[p-1]<>'\' then break; // found first unescaped end quote
    until false;
    value:=copy(text,i+1,p-i-1);
    i:=p+1;
  end else begin
    // unquoted value - grab all up to the nearest space/terminator char
    p:=i;
    while (p<=length(text)) and not (text[p] in [' ',#9,#10,#13,'>']) do inc(p);
    value:=copy(text,i,p-i);
    i:=p;
  end;
  if name<>'' then attributes.Item[name]:=value;
 end;
end;

destructor THtmlElement.Destroy;
begin
 while children.Count>0 do children.Pop.Free; // delete children
 inherited;
end;

function THtmlElement.GetElement(tag,attribute,contains:string):THtmlElement;
var
 i:integer;
 aIdx:integer;
begin
 result:=nil;
 // Check if this element meets the search criteria
 if (tag='') or SameText(tag,self.tag) then begin
  result:=self;
  if attribute<>'' then begin // element must have specified attribute
   aIdx:=attributes.Find(attribute);
   if aIdx<0 then result:=nil
   else begin
    if (contains<>'') and (PosFrom(contains,attributes.items[aIdx].value,1,true)=0) then result:=nil;
   end;
  end;
 end;
 if result<>nil then exit;
 for i:=0 to children.Count-1 do
  if children.items[i] is THtmlElement then
   with children.items[i] as THtmlElement do begin
    result:=GetElement(tag,attribute,contains);
    if result<>nil then exit;
   end;
end;

function THtmlElement.HasAttribute(aName:string):boolean;
begin
 result:=attributes.HasName(aName);
end;

function THtmlElement.AttributeContains(aName,substr:string):boolean;
var
 idx:integer;
begin
 result:=false;
 idx:=attributes.Find(aName);
 if idx<0 then exit;
 result:=PosFrom(substr,attributes.items[idx].value,1,true)>0;
end;

function THtmlElement.InnerText:string;
var
 i:integer;
begin
 result:='';
 for i:=0 to children.count-1 do begin
  if children.items[i] is THtmlText then
   result:=result+THtmlText(children.items[i]).text;
  if children.items[i] is THtmlElement then
   result:=result+THtmlElement(children.items[i]).InnerText;
 end;
end;

procedure THtmlElement.AddChild(node:THtmlNode);
begin
 children.Add(node);
 node.parent:=self;
end;

procedure THtmlElement.RemoveChild(node:THtmlNode);
begin
 children.Remove(node,true);
 node.parent:=nil;
end;

function THtmlElement.CanContain(childTag:string):boolean;
var
 st:string;
begin
 result:=true;
 childTag:='|'+childTag+'|';
 st:=whiteList.Get(tag);
 if (st<>'') and (pos(childTag,st)=0) then exit(false);
 st:=blackList.Get(tag);
 if pos(childTag,st)>0 then exit(false);
end;

procedure THtmlElement.Visit(visitor:THtmlNodeVisitor;context:pointer);
var
 i:integer;
begin
 for i:=0 to children.count-1 do begin
  visitor(children.items[i],context);
  if children.items[i] is THtmlElement then
   THtmlElement(children.items[i]).Visit(visitor,context);
 end;
end;

procedure THtmlElement.VisitElements(visitor:THtmlElementVisitor;context:pointer;tag:string);
var
 i:integer;
begin
 if (tag='') or (SameText(tag,self.tag)) then
  visitor(self,context);
 for i:=0 to children.count-1 do
  if children.items[i] is THtmlElement then
   THtmlElement(children.items[i]).VisitElements(visitor,context,tag);
end;

procedure PrintVisitor(node:THtmlNode;context:pointer);
var
 st:PString;
 txt:string;
 depth:integer;
begin
 depth:=node.Depth;
 if depth=0 then exit;
 txt:=StringOfChar(#9,depth-1);
 txt:=txt+StringReplace(node.text,#13#10,'',[rfReplaceAll]);
 st:=context;
 st^:=st^+txt+#13#10;
end;

function THtmlElement.PrintTree:string;
var
 str:string;
begin
 str:='';
 Visit(PrintVisitor,@str);
 result:=str;
end;

function THtmlElement.IsForeign:boolean;
begin
 result:=pos('|'+tag+'|',FOREIGN_ELEMENTS)>0;
end;

function THtmlElement.IsRawtext:boolean;
begin
 result:=pos('|'+tag+'|',RAWTEXT_ELEMENTS)>0;
end;

function THtmlElement.IsVoid:boolean;
begin
 result:=pos('|'+tag+'|',VOID_ELEMENTS)>0;
end;

var
 node:THtmlElement;
 st:string;
 t:int64;

initialization
 with whiteList do begin
  Put('table','|caption|col|colgroup|thead|tfoot|tbody|tr|');
  Put('tr','|td|th|');
  Put('colgroup','|col|');
  Put('thead','|tr|');
  Put('tfoot','|tr|');
  Put('tbody','|tr|');
  Put('tr','|td|th|');
  Put('dl','|dt|dd|');
  Put('ol','|li|');
  Put('ul','|li|');
  Put('select','|optgroup|option|');
  Put('optgroup','|option|');
 end;
 with blackList do begin
  Put('head','|body|');
 end;

{ // Debug test
 st:=LoadFileAsString('test.htm');
 st:=LoadFileAsString('content.htm');
 t:=MyTickCount;
 node:=ParseHTML(st);
 t:=MyTickCount-t;
 st:=node.PrintTree;
 SaveFile('tree.txt',Utf8String(st));
 writeln(t,node.tag);  }
end.

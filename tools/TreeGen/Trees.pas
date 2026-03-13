unit Trees;
interface
uses Apus.Engine.Api, Apus.Engine.Model3D;

type
 TTreeType=(
   treeGeneric,
   treeOak);

 TTreeGenerator=class
   // input parameters
   age:single; // age in years (1..300)
   seed:integer;
   // output
   skeleton:TMesh;
   tree:TModel3D;
   // misc
   tex:TTexture;
   constructor Create(path:string);
   destructor Destroy; override;
   procedure Build; virtual;
 end;

 TOakTreeGenerator=class(TTreeGenerator)

 end;

 function TreeGenerator(treeType:TTreeType):TTreeGenerator;

implementation
 uses Apus.Common, Apus.Geom3D, Apus.VertexLayout, Apus.Colors;

function TreeGenerator(treeType:TTreeType):TTreeGenerator;
 begin

 end;

{ TTreeGenerator }

procedure TTreeGenerator.Build;
 type
  TSkeletonNode=record
   pos:TVec3;
   parent:integer;
   depth:integer;
   weight:single;
  end;
 var
  rand:TRandom;
  sNodes:array[0..250] of TSkeletonNode;
  sCount:integer;

 procedure BuildSkeleton;
  // Рекурсивное построение скелета дерева
  procedure ExtendNode(node:integer);
   var
    i,branches,par:integer;
    w:array[0..2] of single;
    s,factor,weight:single;
    vec,bVec:TVec3;
   begin
    // Ветвление? Сколько веток [1..3]
    branches:=Clamp(round(1.9+rand.Sum),1,3);
    // веса веток
    s:=0;
    for i:=0 to branches-1 do begin
     w[i]:=rand.Float;
     s:=s+w[i];
    end;
    // нормализация
    for i:=0 to branches-1 do
     w[i]:=w[i]/s;
    // направление
    par:=sNodes[node].parent;
    if par>=0 then begin
     vec:=Vector3s(sNodes[par].pos,sNodes[node].pos);
     vec.Normalize;
    end else
     vec:=Vector3s(0,0,1);
    // развитие новых ветвей
    for i:=0 to branches-1 do begin
     inc(sCount);
     weight:=sNodes[node].weight*w[i];
     sNodes[sCount].weight:=weight;
     sNodes[sCount].parent:=node;
     sNodes[sCount].depth:=sNodes[node].depth+1;

     bVec:=vec;
     factor:=0.25/(weight+0.05);
     VectAdd(bVec,Vector3s(rand.Sum*factor,rand.Sum*factor,rand.Sum*factor));
     bVec.Normalize;
     sNodes[sCount].pos:=PointAdd(sNodes[node].pos,bVec,2+rand.Sum);

     if (sNodes[sCount].weight>0.04) and (sNodes[node].depth<5) then
      ExtendNode(sCount);
    end;
   end;

  begin
   sCount:=0;
   // root
   sNodes[0].pos:=Point3s(0,0,0.1+0.07*sqrt(age));
   sNodes[0].parent:=-1;
   sNodes[0].depth:=0;
   sNodes[0].weight:=1;
   // Extend
   ExtendNode(0);
  end;

 procedure BuildSkeletonMesh;
  var
   i,par:integer;
   r:single;
   color:cardinal;
  begin
   if skeleton<>nil then skeleton.Free;
   skeleton:=TMesh.Create(TVertexLayout.Create([vcPosition3d,vcNormal,vcColor]),0,0);
   for i:=1 to sCount do begin
    par:=sNodes[i].parent;
    r:=0.01+0.1*sqrt(sNodes[i].weight);
    color:=MyColor(150,200-sNodes[i].depth*30,100);
    skeleton.AddCylinder(sNodes[par].pos,sNodes[i].pos,r,r,8,color);
   end;
   skeleton.Finish;
  end;

 begin
  rand.Init(seed);
  BuildSkeleton;
  BuildSkeletonMesh;
 end;

constructor TTreeGenerator.Create(path:string);
 begin

 end;

destructor TTreeGenerator.Destroy;
 begin

  inherited;
 end;

end.

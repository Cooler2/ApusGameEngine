// Producer-Consumer classes

// Copyright (C) 2022 Ivan Polyacov, ivan@apus-software.com
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Base Library (http://apus-software.com/engine/#base)
unit Apus.ProdCons;
interface
uses Classes, Apus.Classes, Apus.Structs;

type
 TDataItem=record
  data:integer;
  value:single; // used as priority for priorited queue
  ptr:pointer;
 end;

 TProducerConsumer=class
  // bufferSize - max number of items to queue for processing
  constructor Create(bufferSize:integer;numThreads:integer=0);
  destructor Destroy; override;
  // Add an item to process. Wait up to waitMS ms if there is no room for a new item right now.
  // Returns true if item was successfully added.
  function Produce(const item:TDataItem;waitMS:integer):boolean; virtual;
  function Consume(out item:TDataItem):boolean; virtual; abstract;
  procedure Process(const item:TDataItem); virtual; abstract; // override this
 protected
  threads:array of TThread;
  function InternalProduce(const item:TDataItem):boolean; virtual; abstract;
 end;

 TProducerConsumerPriority=class(TProducerConsumer)
  constructor Create(bufferSize:integer;numThreads:integer=0);
  function Consume(out item:TDataItem):boolean; override;
 protected
  queue:TPriorityQueue;
  function InternalProduce(const item:TDataItem):boolean; override;
 end;

implementation
 uses Apus.CrossPlatform, Apus.MyServis;

const
 DEFAULT_NUM_THREADS = 4;

var
 objList:TObjectList;

type
 TConsumerThread=class(TThread)
  consumer:TProducerConsumer;
  threadIdx,sleepTime:integer;
  constructor Create(consumer:TProducerConsumer;idx:integer);
  procedure Execute; override;
 end;

{ TProducerConsumer }
constructor TProducerConsumer.Create(bufferSize:integer;numThreads:integer);
 var
  i:integer;
 begin
  if numThreads=0 then numThreads:=DEFAULT_NUM_THREADS;
  SetLength(threads,numThreads);
  for i:=0 to high(threads) do
   threads[i]:=TConsumerThread.Create(self,i);
  objList.Add(self);
 end;

destructor TProducerConsumer.Destroy;
 var
  i:integer;
 begin
  objList.Remove(self);
  for i:=0 to high(threads) do
   threads[i].Terminate;
  for i:=0 to high(threads) do
   threads[i].Free;
  inherited;
 end;

function TProducerConsumer.Produce(const item:TDataItem;waitMS:integer):boolean;
 var
  time:int64;
 begin
  if InternalProduce(item) then exit(true);
  if waitMS<=0 then exit(false);
  time:=MyTickCount+waitMS;
  repeat
    Sleep(0);
    if InternalProduce(item) then exit(true);
  until MyTickCount>time;
  result:=false;
 end;

procedure TerminateAll;
 var
  obj:TObject;
 begin
  repeat
   obj:=objList.Get;
   if obj=nil then exit;
   obj.Free;
  until false;
 end;

{ TConsumerThread }

constructor TConsumerThread.Create(consumer:TProducerConsumer;idx:integer);
 begin
  self.consumer:=consumer;
  self.threadIdx:=idx;
  sleepTime:=0;
  inherited Create(false);
 end;

procedure TConsumerThread.Execute;
 var
  item:TDataItem;
 begin
  repeat
   if consumer.Consume(item) then begin
    consumer.Process(item);
    sleepTime:=0;
   end else begin
    Sleep(sleepTime+threadIdx);
    if sleepTime=0 then inc(sleepTime);
   end;
  until terminated;
 end;

{ TProducerConsumerPriority }

constructor TProducerConsumerPriority.Create(bufferSize,numThreads:integer);
 begin
  queue.Init(bufferSize);
  inherited Create(bufferSize,numThreads);
 end;


function TProducerConsumerPriority.Consume(out item:TDataItem):boolean;
 var
  v:TPriorityItem;
 begin
  result:=queue.Get(v);
  item.data:=v.data;
  item.value:=v.priority;
  item.ptr:=v.ptr;
 end;

function TProducerConsumerPriority.InternalProduce(const item:TDataItem):boolean;
 var
  v:TPriorityItem;
 begin
  v.data:=item.data;
  v.priority:=item.value;
  v.ptr:=item.ptr;
  result:=queue.Add(v);
 end;

initialization
finalization
 TerminateAll; // clean up any objects that were not explicitly destroyed
end.

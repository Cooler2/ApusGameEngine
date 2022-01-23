// Producer-Consumer classes

// Copyright (C) 2022 Ivan Polyacov, ivan@apus-software.com
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Base Library (http://apus-software.com/engine/#base)
unit Apus.ProdCons;
interface
uses Classes, SyncObjs, Apus.Classes, Apus.Structs;

const
 // You can use this magic number to specify number of threads like (NUM_CPU_CORES-1) or (NUM_CPU_CORES div 2)
 // when you can't use CPUcount variable
 NUM_CPU_CORES = $1000;

type
 TDataItem = Apus.Structs.TDataItem; // type alias

 TProducerConsumer=class
  // bufferSize - max number of items to queue for processing
  constructor Create(bufferSize:integer;numThreads:integer=NUM_CPU_CORES);
  destructor Destroy; override;
  // Add an item to process. Wait up to waitMS ms if there is no room for a new item right now.
  // Returns true if item was successfully added.
  function Produce(const item:TDataItem;waitMS:integer=0):boolean; virtual;
 protected
  syncEvent:TEvent; // event is in signalled state when queue is not empty
  threads:array of TThread;
  function Consume(out item:TDataItem):boolean; virtual; abstract;
  function InternalProduce(const item:TDataItem):boolean; virtual; abstract; // just queue an item
  function ItemsToConsume:integer; virtual; abstract;
  procedure Process(const item:TDataItem); virtual; abstract; // override this: process an item
 end;

 // Use a FIFO queue (item.value can hold any data)
 TProducerConsumerFIFO=class(TProducerConsumer)
  constructor Create(bufferSize:integer;numThreads:integer=0);
 protected
  queue:TQueue;
  function Consume(out item:TDataItem):boolean; override;
  function InternalProduce(const item:TDataItem):boolean; override;
  function ItemsToConsume:integer; override;
 end;

 // Use a priorited queue (item.value is priority)
 TProducerConsumerPriority=class(TProducerConsumer)
  constructor Create(bufferSize:integer;numThreads:integer=0);
 protected
  queue:TPriorityQueue;
  function Consume(out item:TDataItem):boolean; override;
  function InternalProduce(const item:TDataItem):boolean; override;
  function ItemsToConsume:integer; override;
 end;

implementation
 uses Apus.CrossPlatform, Apus.MyServis, SysUtils;

var
 objList:TObjectList;

type
 TConsumerThread=class(TThread)
  consumer:TProducerConsumer;
  threadIdx:integer;
  constructor Create(consumer:TProducerConsumer;idx:integer);
  procedure Execute; override;
 end;

{ TProducerConsumer }
constructor TProducerConsumer.Create(bufferSize:integer;numThreads:integer);
 var
  i:integer;
 begin
  syncEvent:=TEvent.Create(nil,false,false,ClassName+'_Event');
  if numThreads>256 then begin
   i:=numThreads-NUM_CPU_CORES;
   if abs(i)<10 then numThreads:=CPUcount+i
    else numThreads:=round(CPUcount*(numThreads/NUM_CPU_CORES));
  end;
  numThreads:=Clamp(numThreads,1,32); // max 32 threads allowed
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
  syncEvent.Free;
  inherited;
 end;

function TProducerConsumer.Produce(const item:TDataItem;waitMS:integer=0):boolean;
 var
  time:int64;
  needEvent:boolean;
 begin
  needEvent:=ItemsToConsume=0;
  if InternalProduce(item) then begin
   if needEvent then
    syncEvent.SetEvent;
   exit(true);
  end;
  if waitMS<=0 then exit(false);
  // queue is full - wait
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
  inherited Create(false);
 end;

procedure TConsumerThread.Execute;
 var
  item:TDataItem;
 begin
  RegisterThread(className+'_'+IntToStr(threadIDX));
  repeat
   if consumer.Consume(item) then begin
    consumer.Process(item);
   end else begin
    // No items available
    consumer.syncEvent.WaitFor(10);
   end;
  until terminated;
  UnregisterThread;
 end;

{ TProducerConsumerPriority }

constructor TProducerConsumerPriority.Create(bufferSize,numThreads:integer);
 begin
  queue.Init(bufferSize);
  inherited Create(bufferSize,numThreads);
 end;

// Try to get an item from queue
function TProducerConsumerPriority.Consume(out item:TDataItem):boolean;
 begin
  result:=queue.Get(item);
  if not result then syncEvent.ResetEvent;
 end;

// Put item into the priorited queue
function TProducerConsumerPriority.InternalProduce(const item:TDataItem):boolean;
 begin
  result:=queue.Add(item);
 end;

function TProducerConsumerPriority.ItemsToConsume:integer;
 begin
  result:=queue.count;
 end;

{ TProducerConsumerFIFO }
constructor TProducerConsumerFIFO.Create(bufferSize,numThreads:integer);
 begin
  queue.Init(bufferSize);
  inherited Create(bufferSize,numThreads);
 end;

function TProducerConsumerFIFO.Consume(out item:TDataItem): boolean;
 begin
  result:=queue.Get(item);
  if not result then syncEvent.ResetEvent;
 end;

function TProducerConsumerFIFO.InternalProduce(const item:TDataItem):boolean;
 begin
  result:=queue.Add(item);
 end;

function TProducerConsumerFIFO.ItemsToConsume: integer;
 begin
  result:=queue.Count;
 end;

initialization
finalization
 TerminateAll; // clean up any objects that were not explicitly destroyed
end.

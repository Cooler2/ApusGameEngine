// Convenience re-export module - single import for commonly used Apus Base functionality
//
// SCOPE: Aggregates foundation modules for convenience.
// Reduces boilerplate when you need multiple base modules. Use when building applications
// that need general utilities without caring about fine-grained imports.
//
// Usage: uses Apus.Core, Apus.Lib;  // Core must be imported explicitly
//
// ADD HERE: Re-exports of stable, commonly used modules.
// DON'T ADD: Platform-specific code, high-level subsystems, experimental APIs.
//
// Note: Record helpers (String8Helper, String32Helper) can't be re-exported - import Apus.Strings directly.
//
// Copyright (C) Ivan Polyacov, ivan@apus-software.com
// This file is licensed under the terms of BSD-3 license (see license.txt)
// This file is a part of the Apus Base Library (http://apus-software.com/engine/#base)
{$I defines.inc}
unit Apus.Lib;
interface
uses
  SysUtils,
  Apus.Types,
  Apus.Log,
  Apus.Threads,
  Apus.Classes,
  Apus.Conv,
  Apus.HashMaps,
  Apus.Strings,
  Apus.Structs,
  Apus.Files,
  Apus.Utils,
  Apus.Geom2D,
  Apus.Geom3D,
  Apus.AnimatedValues;

type
  // --- SysUtils ---
  Exception = SysUtils.Exception;

  // --- Apus.Types ---
  TIntRange = Apus.Types.TIntRange;
  TFloatRange = Apus.Types.TFloatRange;
  TNameValue = Apus.Types.TNameValue;
  TNameValueList = Apus.Types.TNameValueList;
  TBuffer = Apus.Types.TBuffer;
  TWriteBuffer = Apus.Types.TWriteBuffer;

  // --- Apus.Threads ---
  TLock = Apus.Threads.TLock;
  TRWLock = Apus.Threads.TRWLock;   // cross-platform lean RW-lock
  TRWLockD = Apus.Threads.TRWLockD; // debug RW-lock with name and assertions
  TLightweightEvent = Apus.Threads.TLightweightEvent;
  {$IFDEF DELPHI}
  TScopedLock = Apus.Threads.TScopedLock;
  {$ENDIF}
  Thread = Apus.Threads.Thread;

  // --- Apus.Log ---
  Log = Apus.Log.Log;

  // --- Apus.Classes ---
  TObjectEx = Apus.Classes.TObjectEx;
  TNamedObject = Apus.Classes.TNamedObject;
  TNamedObjectClass = Apus.Classes.TNamedObjectClass;
  TNamedObjects = Apus.Classes.TNamedObjects;

  // --- Apus.Conv ---
  Conv = Apus.Conv.Conv;

  // --- Apus.Strings ---
  UTF8 = Apus.Strings.UTF8;

  // --- Apus.Files ---
  Files = Apus.Files.Files;
  Folder = Apus.Files.Folder;

  // --- Apus.Structs ---
  TObjectHash = Apus.Structs.TObjectHash;

  // --- Apus.HashMaps ---
  TObjectMap = Apus.HashMaps.THashMap<TObject>;

  // --- Apus.Utils ---
  TSplineFunc = Apus.Utils.TSplineFunc;

  // --- Apus.AnimatedValues ---
  PAnimatedValue = Apus.AnimatedValues.PAnimatedValue;
  TAnimatedValue = Apus.AnimatedValues.TAnimatedValue;

  // Geom2D
  TPoint2s = Apus.Geom2D.TPoint2s;
  TVector2s = Apus.Geom2D.TVector2s;

  // Geom3D
  TPoint3s = Apus.Geom3D.TPoint3s;
  TVector3s = Apus.Geom3D.TVector3s;
  TQuaternionS = Apus.Geom3D.TQuaternionS;


implementation
end.

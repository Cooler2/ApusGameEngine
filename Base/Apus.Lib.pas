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
  Apus.Core,
  Apus.Types,
  Apus.Threads,
  Apus.Classes,
  Apus.Conv,
  Apus.HashMaps,
  Apus.Strings,
  Apus.Utils;

type
  // --- Apus.Core ---
  Char8 = Apus.Core.Char8;
  String8 = Apus.Core.String8;
  PString8 = Apus.Core.PString8;
  Char16 = Apus.Core.Char16;
  String16 = Apus.Core.String16;
  PString16 = Apus.Core.PString16;
  String32 = Apus.Core.String32;
  PString32 = Apus.Core.PString32;
  Strings8 = Apus.Core.Strings8;
  Strings16 = Apus.Core.Strings16;
  Strings32 = Apus.Core.Strings32;
  Strings = Apus.Core.Strings;
  ByteArray = Apus.Core.ByteArray;
  WordArray = Apus.Core.WordArray;
  IntArray = Apus.Core.IntArray;
  UIntArray = Apus.Core.UIntArray;
  SingleArray = Apus.Core.SingleArray;
  FloatArray = Apus.Core.FloatArray;
  PointerArray = Apus.Core.PointerArray;
  VariantArray = Apus.Core.VariantArray;
  TProcedure = Apus.Core.TProcedure;
  TObjProcedure = Apus.Core.TObjProcedure;
  TBaseException = Apus.Core.EBaseException;
  EBaseException = Apus.Core.EBaseException;
  EWarning = Apus.Core.EWarning;
  EError = Apus.Core.EError;
  EFatalError = Apus.Core.EFatalError;

  // --- Apus.Types ---
  TPoint = Apus.Types.TPoint;
  TRect = Apus.Types.TRect;
  TArray<T> = Apus.Types.TArray<T>;
  TIntRange = Apus.Types.TIntRange;
  TFloatRange = Apus.Types.TFloatRange;
  TNameValue = Apus.Types.TNameValue;
  TNameValueList = Apus.Types.TNameValueList;
  TBuffer = Apus.Types.TBuffer;
  TWriteBuffer = Apus.Types.TWriteBuffer;

  // --- Apus.Threads ---
  TLock = Apus.Threads.TLock;
  TMyCriticalSection = Apus.Threads.TMyCriticalSection;
  TCriticalSection = Apus.Threads.TCriticalSection;
  TSRWLock = Apus.Threads.TSRWLock;
  TLightweightEvent = Apus.Threads.TLightweightEvent;
  TScopedLock = Apus.Threads.TScopedLock;
  Thread = Apus.Threads.Thread;

  // --- Apus.Classes ---
  TObjectEx = Apus.Classes.TObjectEx;
  TNamedObject = Apus.Classes.TNamedObject;
  TNamedObjectClass = Apus.Classes.TNamedObjectClass;
  TNamedObjects = Apus.Classes.TNamedObjects;

  // --- Apus.Conv ---
  Conv = Apus.Conv.Conv;

  // --- Apus.Strings ---
  UTF8 = Apus.Strings.UTF8;

  // --- Apus.Utils ---
  TSplineFunc = Apus.Utils.TSplineFunc;

implementation
end.

// Convenience re-export module - single import for commonly used Apus Base functionality
//
// SCOPE: Aggregates frequently used modules (Conv, HashMaps, Log) for convenience.
// Reduces boilerplate when you need multiple base modules. Use when building applications
// that need general utilities without caring about fine-grained imports.
//
// Usage: uses Apus.Core, Apus.Lib;  // Core must be imported explicitly
//
// ADD HERE: Re-exports of stable, commonly used modules.
// DON'T ADD: Specialized modules (Threads, Files), platform-specific code, experimental APIs.
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
  Apus.Classes,
  Apus.Conv,
  Apus.HashMaps,
  Apus.Strings;

type
  // --- Apus.Types ---
  TSplineFunc = Apus.Types.TSplineFunc;
  TIntRange = Apus.Types.TIntRange;
  TFloatRange = Apus.Types.TFloatRange;
  TNameValue = Apus.Types.TNameValue;
  TNameValueList = Apus.Types.TNameValueList;
  TBuffer = Apus.Types.TBuffer;
  TWriteBuffer = Apus.Types.TWriteBuffer;

  // --- Apus.Classes ---
  TObjectEx = Apus.Classes.TObjectEx;
  TNamedObject = Apus.Classes.TNamedObject;
  TNamedObjectClass = Apus.Classes.TNamedObjectClass;
  TNamedObjects = Apus.Classes.TNamedObjects;
  TBaseException = Apus.Core.EBaseException;
  EWarning = Apus.Core.EWarning;
  EError = Apus.Core.EError;
  EFatalError = Apus.Core.EFatalError;

  // --- Apus.Conv ---
  Conv = Apus.Conv.Conv;

  // --- Apus.Strings ---
  UTF8 = Apus.Strings.UTF8;

implementation
end.

{**
 *  \file SDL_guid.h
 *
 *  Include file for handling ::SDL_GUID values.
 *}

{**
 * An SDL_GUID is a 128-bit identifier for an input device that
 *   identifies that device across runs of SDL programs on the same
 *   platform.  If the device is detached and then re-attached to a
 *   different port, or if the base system is rebooted, the device
 *   should still report the same GUID.
 *
 * GUIDs are as precise as possible but are not guaranteed to
 *   distinguish physically distinct but equivalent devices.  For
 *   example, two game controllers from the same vendor with the same
 *   product ID and revision may have the same GUID.
 *
 * GUIDs may be platform-dependent (i.e., the same device may report
 *   different GUIDs on different operating systems).
 *}
type
  PPSDL_GUID = ^PSDL_GUID;
  PSDL_GUID = ^TSDL_GUID;
  TSDL_GUID = record
    data: array[0..15] of cuint8;
  end;

  {**
 * Get an ASCII string representation for a given ::SDL_GUID.
 *
 * You should supply at least 33 bytes for pszGUID.
 *
 * \param guid the ::SDL_GUID you wish to convert to string
 * \param pszGUID buffer in which to write the ASCII string
 * \param cbGUID the size of pszGUID
 *
 * \since This function is available since SDL 2.24.0.
 *
 * \sa SDL_GUIDFromString
 *}
procedure SDL_GUIDToString(guid: TSDL_GUID; pszGUID: PAnsiChar; cbGUID: cint); cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GUIDToString' {$ENDIF} {$ENDIF};

{**
 * Convert a GUID string into a ::SDL_GUID structure.
 *
 * Performs no error checking. If this function is given a string containing
 * an invalid GUID, the function will silently succeed, but the GUID generated
 * will not be useful.
 *
 * \param pchGUID string containing an ASCII representation of a GUID
 * \returns a ::SDL_GUID structure.
 *
 * \since This function is available since SDL 2.24.0.
 *
 * \sa SDL_GUIDToString
 *}
function SDL_GUIDFromString(const pchGUID: PAnsiChar): TSDL_GUID; cdecl;
  external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GUIDFromString' {$ENDIF} {$ENDIF};

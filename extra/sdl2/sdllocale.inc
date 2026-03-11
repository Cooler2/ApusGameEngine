// based on SDL_locale.h

type
	PPSDL_Locale = ^PSDL_Locale;
	PSDL_Locale = ^TSDL_Locale;
	TSDL_Locale = record
		// A language name, like 'en' for English.
		language: PAnsiChar;
		// A country, like 'US' for America. Can be NIL.
		country: PAnsiChar;
	end;

{**
 *  \brief Report the user's preferred locale.
 *
 *  This returns an array of SDL_Locale structs, the final item zeroed out.
 *  When the caller is done with this array, it should call SDL_free() on
 *  the returned value; all the memory involved is allocated in a single
 *  block, so a single SDL_free() will suffice.
 *
 *  Returned language strings are in the format xx, where 'xx' is an ISO-639
 *  language specifier (such as 'en' for English, 'de' for German, etc).
 *  Country strings are in the format YY, where 'YY' is an ISO-3166 country
 *  code (such as "US" for the United States, 'CA' for Canada, etc). Country
 *  might be NULL if there's no specific guidance on them (so you might get
 *  ( 'en', 'US' ) for American English, but ( 'en', NIL ) means "English
 *  language, generically"). Language strings are never NIL, except to
 *  terminate the array.
 *
 *  Please note that not all of these strings are 2 characters; some are
 *  three or more.
 *
 *  The returned list of locales are in the order of the user's preference.
 *  For example, a German citizen that is fluent in US English and knows
 *  enough Japanese to navigate around Tokyo might have a list like:
 *  [ 'de', 'en_US', 'jp', NIL ]. Someone from England might prefer British
 *  English (where "color" is spelled "colour", etc), but will settle for
 *  anything like it: [ 'en_GB', 'en', NIL ].
 *
 *  This function returns NIL on error, including when the platform does not
 *  supply this information at all.
 *
 *  This might be a "slow" call that has to query the operating system. It's
 *  best to ask for this once and save the results. However, this list can
 *  change, usually because the user has changed a system preference outside
 *  of your program; SDL will send an SDL_LOCALECHANGED event in this case,
 *  if possible, and you can call this function again to get an updated copy
 *  of preferred locales.
 *
 *   \return array of locales, terminated with a locale with a NIL language
 *           field. Will return NIL on error.
 *}
function SDL_GetPreferredLocales(): PSDL_Locale; cdecl;
	external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GetPreferredLocales' {$ENDIF} {$ENDIF};

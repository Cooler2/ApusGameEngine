{  -----------------------------------------------------------------------------------------------

                      MySQL Client API for Borland Delphi (version 4 and above)

                             Pascal Interface Unit for libmySQL.dll, the
                          Client Library for MySQL AB's SQL Database Server

                    This is a literal translation of relevant parts of MySQL AB's
                      C header files, mysql.h, mysql_com.h, and mysql_version.h

   -----------------------------------------------------------------------------------------------
                         See mysql.h for MySQL AB's copyright and GPL notice
   -----------------------------------------------------------------------------------------------

       17-Aug-1999  mf  Translated mysql.h                             MySQL 3.22.24
       19-Aug-1999  mf  Corrected some type definitions                MySQL 3.22.24
       20-Aug-1999  mf  Finished debugging the unit                    MySQL 3.22.24
       18-Sep-1999  mf  Code maintenance for release 3.22.26a          MySQL 3.22.26a
       22-Oct-1999  mf  Code maintenance for release 3.22.28           MySQL 3.22.28
       02-Jan-2000  mf  Code maintenance for release 3.22.29           MySQL 3.22.29
       21-Jan-2000  mf  Code maintenance for release 3.22.30           MySQL 3.22.30
       07-Feb-2000  mf  Code maintenance for release 3.22.31           MySQL 3.22.31
       16-Feb-2000  mf  Code maintenance for release 3.22.32           MySQL 3.22.32
       13-Aug-2000  mf  Code maintenance for release 3.22.34           MySQL 3.22.34
       14-Aug-2000  mf  Reworked entire unit for first 3.23 release    MySQL 3.23.19-beta
       14-Aug-2000  mf  Added mysql_character_set_name()               MySQL 3.23.22-beta
       11-Sep-2000  mf  Added IS_NUM_FIELD and INTERNAL_NUM_FIELD      MySQL 3.23.24-beta
       08-Oct-2000  mf  Modified TMEM_ROOT, enum_server_command,       MySQL 3.23.25-beta
                        and INTERNAL_NUM_FIELD
       01-Nov-2000  mf  Code maintenance for release 3.23.27           MySQL 3.23.27-beta
       25-Nov-2000  mf  Code maintenance for release 3.23.28           MySQL 3.23.28-gamma
       05-Jan-2001  mf  Code maintenance for release 3.23.30           MySQL 3.23.30-gamma
       19-Jan-2001  mf  Code maintenance for release 3.23.31           MySQL 3.23.31
       11-Mar-2001  mf  Added functions mysql_real_send_query(),       MySQL 3.23.33
                        mysql_send_query(), and mysql_reap_query()
       28-Mai-2001  mf  Modified mysql_send_query(), removed           MySQL 3.23.38
                        mysql_real_send_query(), mysql_reap_query(),
                        added mysql_read_query_result(), and fixed
                        CLIENT_TRANSACTIONS
       07-Aug-2001  mf  Code maintenance for release 3.23.40           MySQL 3.23.40
       23-Sep-2001  mf  Code maintenance for release 3.23.42           MySQL 3.23.42
       29-Jan-2002  mf  Added libmysql_load(), libmysql_free(),        MySQL 3.23.47
                        libmysql_status and LIBMYSQL_ constants
                        for dynamic loading of libmySQL.dll
       11-Mar-2002  mf  Added MYSQL_OPT_LOCAL_INFILE to mysql_option   MySQL 3.23.49
       03-Jun-2002  so  result of mysql_row_tell is MYSQL_ROW_OFFSET
       05-Nov-2006  so  Update for LibMySQL Version 4.00 and 4.10      MySql 4.10
                        Different records for the varius versions
       26-May-2007  so  Update for LibMySQL Version 5.00 and 5.10      MySql 5.10
       29-Mar-2009  so  Remove all const in PAnsiChar-Params to
                        clearify what happend (C don't know "call by
                        reference")
       30-Mar-2009  so  Resourcestrings
                        Added functions mysql_field_flag,
                        mysql_field_type, mysql_field_name,
                        mysql_field_tablename
       11-Apr-2009  so  improved dynamic loading by new function
                        libmysql_fast_load
       13-Apr-2009  so  Added functions mysql_field_length, IS_LONGDATA;
                        Code maintenance enum_field_types
       17-Apr-2009  so  Added functions mysql_autocommit,
                        mysql_set_character_set, mysql_commit,
                        mysql_rollback, mysql_set_server_option,
                        mysql_sqlstate, mysql_warning_count
                        MySql_StrLen, CharSetNameToCodepage,
                        CodepageToCharSetName, MySqlToUTF16,
                        UTF16ToMySql
       01-May-2009  so  mysql_odbc_escape_string is deprecated
       08-Jun-2009  so  Added functions mysql_server_init, mysql_server_end
                        Added support for prepared statements
       09-Jun-2009  so  Added records: TNET501, TMYSQL501
       10-Jun-2009  so  Added functions mysql_thread_init, mysql_thread_end
       18-Jun-2009  so  Added functions mysql_more_results, mysql_next_result,
                        FormatIdentifier
       04-Jul-2009  so  Added functions EscapeString, EscapeForLike, QuoteString,
                        FullFieldname
                        Change FormatIdentifier to QuoteName
       04-Aug-2009  so  Bug in GetVersion fixed
       18-Oct-2010  so  Added function mysql_field_default
       23-Feb-2011  so  Added function mysql_get_client_filename
       22-Jul-2011  so  Corrected function mysql_ssl_set
       15-Sep-2011  so  Adaptation to Delphi XE2
       13-Oct-2015  so  Adaptation to FPC

   -----------------------------------------------------------------------------------------------

                     Latest releases of mysql.pas are made available through the
                      distribution site at: http://www.audio-data.de/mysql.html

                        See readme.txt for an introduction and documentation.

              *********************************************************************
              * The contents of this file are used with permission, subject to    *
              * the Mozilla Public License Version 1.1 (the "License"); you may   *
              * not use this file except in compliance with the License. You may  *
              * obtain a copy of the License at                                   *
              * http:  www.mozilla.org/MPL/MPL-1.1.html                           *
              *                                                                   *
              * Software distributed under the License is distributed on an       *
              * "AS IS" basis, WITHOUT WARRANTY OF ANY KIND, either express or    *
              * implied. See the License for the specific language governing      *
              * rights and limitations under the License.                         *
              *                                                                   *
              *  Contributor(s)                                                   *
              *  (mf)  Matthias Fichtner <matthias@fichtner.net>                  *
              *  (so)  Samuel Soldat     <samuel.soldat@audio-data.de>            *
              *                                                                   *
              *********************************************************************}

unit mysql;

{$ifdef FPC}
  {$MODE Delphi}
  {$define CONDITIONALEXPRESSIONS}
  {$ALIGN 8}
  {$ifdef CPUX86_64}
  {$define CPUX64}
  {$endif}
{$else}
  {$ALIGN ON}
{$endif}

{$IFNDEF DEBUG}
  {$DEBUGINFO OFF}
  {$LOCALSYMBOLS OFF}
  {$ASSERTIONS OFF}
{$ENDIF}
{$RANGECHECKS OFF}
{$TYPEDADDRESS OFF}
{$LONGSTRINGS ON}
{$EXTENDEDSYNTAX ON}
{$REFERENCEINFO ON}
{$MINENUMSIZE 4}

{$DEFINE DONT_LOAD_DLL}
{.$DEFINE EmbeddedCharacterConvert}
{$DEFINE Win32CharacterConvert}

// -----------------------------------------------------------------------------------------------
INTERFACE
// -----------------------------------------------------------------------------------------------

uses
  Windows,  // Needed for some type definitions
  Winsock;  // Needed for some type definitions

type
{$IFDEF CONDITIONALEXPRESSIONS}
  {Delphi 6 and above}
  {$IF NOT DECLARED(UnicodeString)}
  UnicodeString = WideString;
  {$IFEND}
  {$IF NOT DECLARED(RawByteString)}
  RawByteString = AnsiString;
  {$IFEND}
  {$IF DECLARED(UInt64)}
  my_ulonglong = UInt64;
  {$IFEND}
  {$IF NOT DECLARED(UInt64)}
  my_ulonglong = Int64;
  {$IFEND}
{$ELSE}
  UnicodeString = WideString;
  RawByteString = AnsiString;
  PPAnsiChar = ^PAnsiChar;
  {$IFDEF VER100} {For Delphi 3}
  longword = DWORD;
  pLongword = ^longword;
  my_ulonglong = record
   dwMyLow: DWORD;
   dwMyHigh: DWORD;
  end;
  {$ELSE}
  my_ulonglong = int64;
  {$ENDIF}
{$ENDIF}

// ----------------
// From mysql.h ...
// ----------------

  my_bool = ByteBool;
  Pmy_bool = ^my_bool;
  gptr = PAnsiChar;

type
  PUSED_MEM = ^TUSED_MEM;  // struct for once_alloc
  TUSED_MEM = record
    next: PUSED_MEM;       // Next block in use
    left: longword;        // memory left in block
    size: longword;        // size of block
  end;

// --------------------
// From my_alloc.h ...
// --------------------

type
  error_proc = procedure;

type
  TMEM_ROOT323 = record
    free: PUSED_MEM;
    used: PUSED_MEM;
    pre_alloc: PUSED_MEM;
    min_malloc: longword;
    block_size: longword;
    error_handler: error_proc;
  end;
  TMEM_ROOT400 = record
    free: PUSED_MEM;
    used: PUSED_MEM;
    pre_alloc: PUSED_MEM;
    min_malloc: longword;
    block_size: longword;
    block_num: longword;
    first_block_usage: longword;
    error_handler: error_proc;
  end;

type
  my_socket = TSocket;

// --------------------
// From mysql_com.h ...
// --------------------

const
  NAME_LEN = 64;               // Field/table name length
  HOSTNAME_LENGTH = 60;
  USERNAME_LENGTH = 16;
  SERVER_VERSION_LENGTH = 60;
  SQLSTATE_LENGTH = 5;
  SCRAMBLE_LENGTH = 20;
  SCRAMBLE_LENGTH_323 = 8;


  LOCAL_HOST = 'localhost';
  LOCAL_HOST_NAMEDPIPE = '.';

  MYSQL_NAMEDPIPE = 'MySQL';
  MYSQL_SERVICENAME = 'MySql';

type
  enum_server_command = (
    COM_SLEEP, COM_QUIT, COM_INIT_DB, COM_QUERY,
    COM_FIELD_LIST, COM_CREATE_DB, COM_DROP_DB, COM_REFRESH,
    COM_SHUTDOWN, COM_STATISTICS,
    COM_PROCESS_INFO, COM_CONNECT, COM_PROCESS_KILL,
    COM_DEBUG, COM_PING, COM_TIME, COM_DELAYED_INSERT,
    COM_CHANGE_USER, COM_BINLOG_DUMP,
    COM_TABLE_DUMP, COM_CONNECT_OUT
  );

const
  NOT_NULL_FLAG = 1;      // Field can't be NULL
  PRI_KEY_FLAG = 2;       // Field is part of a primary key
  UNIQUE_KEY_FLAG = 4;    // Field is part of a unique key
  MULTIPLE_KEY_FLAG = 8;  // Field is part of a key
  BLOB_FLAG = 16;         // Field is a blob
  UNSIGNED_FLAG = 32;     // Field is unsigned
  ZEROFILL_FLAG = 64;     // Field is zerofill
  BINARY_FLAG = 128;

  // The following are only sent to new clients

  ENUM_FLAG = 256;              // field is an enum
  AUTO_INCREMENT_FLAG = 512;    // field is a autoincrement field
  TIMESTAMP_FLAG = 1024;        // Field is a timestamp
  SET_FLAG = 2048;              // field is a set
  NUM_FLAG = 32768;             // Field is num (for clients)
  NO_DEFAULT_VALUE_FLAG = 4096; // Field doesn't have default value
  PART_KEY_FLAG = 16384;        // Intern; Part of some key
  GROUP_FLAG = 32768;           // Intern: Group field
  UNIQUE_FLAG = 65536;          // Intern: Used by sql_yacc
  BINCMP_FLAG = 131072;         // Intern: Used by sql_yacc

  REFRESH_GRANT = 1;     // Refresh grant tables
  REFRESH_LOG = 2;       // Start on new log file
  REFRESH_TABLES = 4;    // close all tables
  REFRESH_HOSTS = 8;     // Flush host cache
  REFRESH_STATUS = 16;   // Flush status variables
  REFRESH_THREADS = 32;  // Flush status variables
  REFRESH_SLAVE = 64;    // Reset master info and restart slave
                         // thread
  REFRESH_MASTER = 128;  // Remove all bin logs in the index
                         // and truncate the index

  // The following can't be set with mysql_refresh()

  REFRESH_READ_LOCK = 16384;  // Lock tables for read
  REFRESH_FAST = 32768;       // Intern flag

  // RESET (remove all queries) from query cache
  REFRESH_QUERY_CACHE = 65536;
  REFRESH_QUERY_CACHE_FREE = $20000; // pack query cache
  REFRESH_DES_KEY_FILE = $40000;
  REFRESH_USER_RESOURCES = $80000;

  CLIENT_LONG_PASSWORD = 1;         // new more secure passwords
  CLIENT_FOUND_ROWS = 2;            // Found instead of affected rows
  CLIENT_LONG_FLAG = 4;             // Get all column flags
  CLIENT_CONNECT_WITH_DB = 8;       // One can specify db on connect
  CLIENT_NO_SCHEMA = 16;            // Don't allow database.table.column
  CLIENT_COMPRESS = 32;             // Can use compression protcol
  CLIENT_ODBC = 64;                 // Odbc client
  CLIENT_LOCAL_FILES = 128;         // Can use LOAD DATA LOCAL
  CLIENT_IGNORE_SPACE = 256;        // Ignore spaces before '('
  CLIENT_INTERACTIVE = 1024;        // This is an interactive client
  CLIENT_SSL = 2048;                // Switch to SSL after handshake
  CLIENT_IGNORE_SIGPIPE = 4096;     // IGNORE sigpipes
  CLIENT_TRANSACTIONS = 8192;       // Client knows about transactions
  CLIENT_RESERVED = 16384;          // Old flag for 4.1 protocol
  CLIENT_SECURE_CONNECTION = 32768; // New 4.1 authentication
  CLIENT_MULTI_STATEMENTS = 65536;  // Enable/disable multi-stmt support
  CLIENT_MULTI_RESULTS = $20000;    // Enable/disable multi-results

  CLIENT_SSL_VERIFY_SERVER_CERT = $40000000;
  CLIENT_REMEMBER_OPTIONS = $80000000;

  SERVER_STATUS_IN_TRANS = 1;     // Transaction has started
  SERVER_STATUS_AUTOCOMMIT = 2;   // Server in auto_commit mode
  SERVER_MORE_RESULTS_EXISTS = 8; // Multi query - next query exists
  SERVER_QUERY_NO_GOOD_INDEX_USED = 16;
  SERVER_QUERY_NO_INDEX_USED = 32;
  SERVER_STATUS_CURSOR_EXISTS = 64;
  SERVER_STATUS_LAST_ROW_SENT = 128;
  SERVER_STATUS_DB_DROPPED = 256;
  SERVER_STATUS_NO_BACKSLASH_ESCAPES = 512;

  MYSQL_ERRMSG_SIZE = 200;
  MYSQL_ERRMSG_SIZE401 = 512;

  NET_READ_TIMEOUT = 30;       // Timeout on read
  NET_WRITE_TIMEOUT = 60;      // Timeout on write
  NET_WAIT_TIMEOUT = 8*60*60;  // Wait for new query

type
  PVio = ^TVio;
  TVio = record
  end;

type                    
  PNET = Pointer;
  TNET323 = record
    vio: PVio;
    fd: my_socket;
    fcntl: longint;
    buff, buff_end, write_pos, read_pos: pByte;
    last_error: array [0..MYSQL_ERRMSG_SIZE - 1] of AnsiChar;
    last_errno, max_packet, timeout, pkt_nr: longword;                         // 228
    error: byte;
    return_errno, compress: my_bool;
    no_send_ok: my_bool;
      // needed if we are doing several
      // queries in one command ( as in LOAD TABLE ... FROM MASTER ),
      // and do not want to confuse the client with OK at the wrong time
    remain_in_buf, length, buf_length, where_b: longword;
    return_status: pLongword;
    reading_or_writing: byte;
    save_char: AnsiChar;
  end;

type                    
  TNET400 = record
    vio: PVio;
    buff, buff_end, write_pos, read_pos: pByte;
    fd: my_socket;
    max_packet, max_packet_size: longword;
    last_errno, pkt_nr, compress_pkt_nr: longword;
    write_timeout, read_timeout, retry_count: longword;
    fcntl: Integer;
    last_error: array [0..MYSQL_ERRMSG_SIZE - 1] of AnsiChar;
    error: byte;
    return_errno, compress: my_bool;
    remain_in_buf, length, buf_length, where_b: longword;
    return_status: pLongword;
    reading_or_writing: byte;
    save_char: AnsiChar;
    no_send_ok: my_bool;  // needed if we are doing several
    query_cache_query: gptr;
  end;

type
  TNET401 = record
    vio: PVio;
    buff, buff_end, write_pos, read_pos: pByte;
    fd: my_socket;
    max_packet, max_packet_size: longword;
    pkt_nr, compress_pkt_nr: longword;
    write_timeout, read_timeout, retry_count: longword;
    fcntl: Integer;
    compress: my_bool;
    remain_in_buf, length, buf_length, where_b: longword;
    return_status: pLongword;
    reading_or_writing: byte;
    save_char: AnsiChar;
    no_send_ok: my_bool;  // needed if we are doing several
    last_error: array [0..MYSQL_ERRMSG_SIZE401 - 1] of AnsiChar;
    sqlState: array [0..SQLSTATE_LENGTH] of AnsiChar;
    last_errno: longword;
    error: byte;
    query_cache_query: gptr;
    report_error: my_bool;   //* We should report error (we have unreported error) */
    return_errno: my_bool;
  end;

type                    
  TNET500 = record
    vio: PVio;
    buff, buff_end, write_pos, read_pos: pByte;
    fd: my_socket;
    max_packet, max_packet_size: longword;
    pkt_nr, compress_pkt_nr: longword;
    write_timeout, read_timeout, retry_count: longword;
    fcntl: Integer;
    compress: my_bool;
    remain_in_buf, length, buf_length, where_b: longword;
    return_status: pLongword;
    reading_or_writing: byte;
    save_char: AnsiChar;
    no_send_ok: my_bool;  //  For SPs and other things that do multiple stmts
    no_send_eof: my_bool;  // For SPs' first version read-only cursors
    no_send_error: my_bool;
    last_error: array [0..MYSQL_ERRMSG_SIZE401 - 1] of AnsiChar;
    sqlState: array [0..SQLSTATE_LENGTH] of AnsiChar;
    last_errno: longword;
    error: byte;
    query_cache_query: gptr;
    report_error: my_bool;   //* We should report error (we have unreported error) */
    return_errno: my_bool;
  end;
type                    
  TNET501 = record
    vio: PVio;
    buff, buff_end, write_pos, read_pos: pByte;
    fd: my_socket;
    remain_in_buf, length, buf_length, where_b: longword;
    max_packet, max_packet_size: longword;
    pkt_nr, compress_pkt_nr: longword;
    write_timeout, read_timeout, retry_count: longword;
    fcntl: Integer;
    return_status: Plongword;
    reading_or_writing: Byte;
    save_char: Char;
    unused0: my_bool; //* Please remove with the next incompatible ABI change. */
    unused: my_bool ; //* Please remove with the next incompatible ABI change */
    compress: my_bool;
    unused1: my_bool; //* Please remove with the next incompatible ABI change. */
    query_cache_query: gptr;
    last_errno: longword;
    error: byte;
    unused2: my_bool; //* Please remove with the next incompatible ABI change. */
    return_errno: my_bool;
    last_error: array [0..MYSQL_ERRMSG_SIZE401 - 1] of AnsiChar;
    sqlState: array [0..SQLSTATE_LENGTH] of AnsiChar;
    extension: Pointer;
  end;

const
  packet_error: longword = $ffffffff;

{$IFDEF CONDITIONALEXPRESSIONS} {Delphi 6 and above}
type
  enum_field_types = (MYSQL_TYPE_DECIMAL, MYSQL_TYPE_TINY,
                      MYSQL_TYPE_SHORT, MYSQL_TYPE_LONG,
                      MYSQL_TYPE_FLOAT, MYSQL_TYPE_DOUBLE,
                      MYSQL_TYPE_NULL, MYSQL_TYPE_TIMESTAMP,
                      MYSQL_TYPE_LONGLONG, MYSQL_TYPE_INT24,
                      MYSQL_TYPE_DATE, MYSQL_TYPE_TIME,
                      MYSQL_TYPE_DATETIME, MYSQL_TYPE_YEAR,
                      MYSQL_TYPE_NEWDATE, MYSQL_TYPE_VARCHAR,
                      MYSQL_TYPE_BIT,
                      MYSQL_TYPE_NEWDECIMAL=246,
                      MYSQL_TYPE_ENUM=247,
                      MYSQL_TYPE_SET=248,
                      MYSQL_TYPE_TINY_BLOB=249,
                      MYSQL_TYPE_MEDIUM_BLOB=250,
                      MYSQL_TYPE_LONG_BLOB=251,
                      MYSQL_TYPE_BLOB=252,
                      MYSQL_TYPE_VAR_STRING=253,
                      MYSQL_TYPE_STRING=254,
                      MYSQL_TYPE_GEOMETRY=255);

const
  FIELD_TYPE_DECIMAL     = Ord(MYSQL_TYPE_DECIMAL);
  FIELD_TYPE_TINY        = Ord(MYSQL_TYPE_TINY);
  FIELD_TYPE_SHORT       = Ord(MYSQL_TYPE_DECIMAL);
  FIELD_TYPE_LONG        = Ord(MYSQL_TYPE_LONG);
  FIELD_TYPE_FLOAT       = Ord(MYSQL_TYPE_FLOAT);
  FIELD_TYPE_DOUBLE      = Ord(MYSQL_TYPE_DOUBLE);
  FIELD_TYPE_NULL        = Ord(MYSQL_TYPE_NULL);
  FIELD_TYPE_TIMESTAMP   = Ord(MYSQL_TYPE_TIMESTAMP);
  FIELD_TYPE_LONGLONG    = Ord(MYSQL_TYPE_LONGLONG);
  FIELD_TYPE_INT24       = Ord(MYSQL_TYPE_INT24);
  FIELD_TYPE_DATE        = Ord(MYSQL_TYPE_DATE);
  FIELD_TYPE_TIME        = Ord(MYSQL_TYPE_TIME);
  FIELD_TYPE_DATETIME    = Ord(MYSQL_TYPE_DATETIME);
  FIELD_TYPE_YEAR        = Ord(MYSQL_TYPE_YEAR);
  FIELD_TYPE_NEWDATE     = Ord(MYSQL_TYPE_NEWDATE);
  FIELD_TYPE_VARCHAR     = Ord(MYSQL_TYPE_VARCHAR);
  FIELD_TYPE_BIT         = Ord(MYSQL_TYPE_BIT);
  FIELD_TYPE_NEWDECIMAL  = Ord(MYSQL_TYPE_NEWDECIMAL);
  FIELD_TYPE_ENUM        = Ord(MYSQL_TYPE_ENUM);
  FIELD_TYPE_SET         = Ord(MYSQL_TYPE_SET);
  FIELD_TYPE_TINY_BLOB   = Ord(MYSQL_TYPE_TINY_BLOB);
  FIELD_TYPE_MEDIUM_BLOB = Ord(MYSQL_TYPE_BLOB);
  FIELD_TYPE_LONG_BLOB   = Ord(MYSQL_TYPE_VAR_STRING);
  FIELD_TYPE_BLOB        = Ord(MYSQL_TYPE_BLOB);
  FIELD_TYPE_VAR_STRING  = Ord(MYSQL_TYPE_VAR_STRING);
  FIELD_TYPE_STRING      = Ord(MYSQL_TYPE_STRING);
  FIELD_TYPE_GEOMETRY    = Ord(MYSQL_TYPE_GEOMETRY);
{$ELSE}
const
  FIELD_TYPE_DECIMAL      = 0;
  FIELD_TYPE_TINY         = 1;
  FIELD_TYPE_SHORT        = 2;
  FIELD_TYPE_LONG         = 3;
  FIELD_TYPE_FLOAT        = 4;
  FIELD_TYPE_DOUBLE       = 5;
  FIELD_TYPE_NULL         = 6;
  FIELD_TYPE_TIMESTAMP    = 7;
  FIELD_TYPE_LONGLONG     = 8;
  FIELD_TYPE_INT24        = 9;
  FIELD_TYPE_DATE         = 10;
  FIELD_TYPE_TIME         = 11;
  FIELD_TYPE_DATETIME     = 12;
  FIELD_TYPE_YEAR         = 13;
  FIELD_TYPE_NEWDATE      = 14;
  FIELD_TYPE_VARCHAR      = 15;
  FIELD_TYPE_BIT          = 16;
  FIELD_TYPE_NEWDECIMAL   = 246;
  FIELD_TYPE_ENUM         = 247;
  FIELD_TYPE_SET          = 248;
  FIELD_TYPE_TINY_BLOB    = 249;
  FIELD_TYPE_MEDIUM_BLOB  = 250;
  FIELD_TYPE_LONG_BLOB    = 251;
  FIELD_TYPE_BLOB         = 252;
  FIELD_TYPE_VAR_STRING   = 253;
  FIELD_TYPE_STRING       = 254;
  FIELD_TYPE_GEOMETRY     = 255;
  MYSQL_TYPE_DECIMAL      = FIELD_TYPE_DECIMAL;
  MYSQL_TYPE_TINY         = FIELD_TYPE_TINY;
  MYSQL_TYPE_SHORT        = FIELD_TYPE_SHORT;
  MYSQL_TYPE_LONG         = FIELD_TYPE_LONG;
  MYSQL_TYPE_FLOAT        = FIELD_TYPE_FLOAT;
  MYSQL_TYPE_DOUBLE       = FIELD_TYPE_DOUBLE;
  MYSQL_TYPE_NULL         = FIELD_TYPE_NULL;
  MYSQL_TYPE_TIMESTAMP    = FIELD_TYPE_TIMESTAMP;
  MYSQL_TYPE_LONGLONG     = FIELD_TYPE_LONGLONG;
  MYSQL_TYPE_INT24        = FIELD_TYPE_INT24;
  MYSQL_TYPE_DATE         = FIELD_TYPE_DATE;
  MYSQL_TYPE_TIME         = FIELD_TYPE_TIME;
  MYSQL_TYPE_DATETIME     = FIELD_TYPE_DATETIME;
  MYSQL_TYPE_YEAR         = FIELD_TYPE_YEAR;
  MYSQL_TYPE_NEWDATE      = FIELD_TYPE_NEWDATE;
  MYSQL_TYPE_VARCHAR      = FIELD_TYPE_VARCHAR;
  MYSQL_TYPE_BIT          = FIELD_TYPE_BIT;
  MYSQL_TYPE_NEWDECIMAL   = FIELD_TYPE_NEWDECIMAL;
  MYSQL_TYPE_ENUM         = FIELD_TYPE_ENUM;
  MYSQL_TYPE_SET          = FIELD_TYPE_SET;
  MYSQL_TYPE_TINY_BLOB    = FIELD_TYPE_TINY_BLOB;
  MYSQL_TYPE_MEDIUM_BLOB  = FIELD_TYPE_MEDIUM_BLOB;
  MYSQL_TYPE_LONG_BLOB    = FIELD_TYPE_LONG_BLOB;
  MYSQL_TYPE_BLOB         = FIELD_TYPE_BLOB;
  MYSQL_TYPE_VAR_STRING   = FIELD_TYPE_VAR_STRING;
  MYSQL_TYPE_STRING       = FIELD_TYPE_STRING;
  MYSQL_TYPE_GEOMETRY     = FIELD_TYPE_GEOMETRY;

type
  enum_field_types = FIELD_TYPE_DECIMAL..FIELD_TYPE_GEOMETRY;
{$ENDIF}

const
  FIELD_TYPE_CHAR        = FIELD_TYPE_TINY;  // For compability
  FIELD_TYPE_INTERVAL    = FIELD_TYPE_ENUM;  // For compability

// ------------------------
// From mysql_version.h ...
// ------------------------

const
  PROTOCOL_VERSION = 10;
  MYSQL_SERVER_SUFFIX = '';
  FRM_VER = 6;
  MYSQL_PORT = 3306;

// ----------------
// From mysql.h ...
// ----------------

function IS_PRI_KEY(n: longword): boolean;
function IS_AUTO_INC(n: longword): boolean;
function IS_NOT_NULL(n: longword): boolean;
function IS_BLOB(n: longword): boolean;
{.$IFDEF CONDITIONALEXPRESSIONS} {Delphi 6 and above}
function IS_NUM(t: enum_field_types): boolean;
function IS_LONGDATA(t: enum_field_types): boolean;
{ $ELSE
function IS_NUM(t: longword): boolean;
function IS_LONGDATA(t: longword): boolean;
 $ENDIF}

type
  TMYSQL_FIELD323 = record
    name: PAnsiChar;          // Name of column
    table: PAnsiChar;         // Table of column if column was a field
    def: PAnsiChar;           // Default value (set by mysql_list_fields)
    _type: enum_field_types;  // Type of field. Se mysql_com.h for types
    length: longword;         // Width of column
    max_length: longword;     // Max width of selected set
    flags: longword;          // Div flags
    decimals: longword;       // Number of decimals in field
  end;
  TMYSQL_FIELD400 = record
    name: PAnsiChar;          // Name of column
    table: PAnsiChar;         // Table of column if column was a field
    org_table: PAnsiChar;     // Org table name if table was an alias
    db: PAnsiChar;            // Database for table
    def: PAnsiChar;           // Default value (set by mysql_list_fields)
    length: longword;         // Width of column
    max_length: longword;     // Max width of selected set
    flags: longword;          // Div flags
    decimals: longword;       // Number of decimals in field
    _type: enum_field_types;  // Type of field. Se mysql_com.h for types
  end;
  TMYSQL_FIELD401 = record
    name: PAnsiChar;          // Name of column
    org_name: PAnsiChar;      // Original column name, if an alias
    table: PAnsiChar;         // Table of column if column was a field
    org_table: PAnsiChar;     // Org table name if table was an alias
    db: PAnsiChar;            // Database for table
    catalog: PAnsiChar;       // Catalog for table
    def: PAnsiChar;           // Default value (set by mysql_list_fields)
    length: longword;         // Width of column
    max_length: longword;     // Max width of selected set
    name_length: longword;
    org_name_length: longword;
    table_length: longword;
    org_table_length: longword;
    db_length: longword;
    catalog_length: longword;
    def_length: longword;
    flags: longword;          // Div flags
    decimals: longword;       // Number of decimals in field
    charsetnr: longword;      // Character set
    _type: enum_field_types;  // Type of field. Se mysql_com.h for types
  end;
  TMYSQL_FIELD501 = record
    name: PAnsiChar;          // Name of column
    org_name: PAnsiChar;      // Original column name, if an alias
    table: PAnsiChar;         // Table of column if column was a field
    org_table: PAnsiChar;     // Org table name if table was an alias
    db: PAnsiChar;            // Database for table
    catalog: PAnsiChar;       // Catalog for table
    def: PAnsiChar;           // Default value (set by mysql_list_fields)
    length: longword;         // Width of column
    max_length: longword;     // Max width of selected set
    name_length: longword;
    org_name_length: longword;
    table_length: longword;
    org_table_length: longword;
    db_length: longword;
    catalog_length: longword;
    def_length: longword;
    flags: longword;          // Div flags
    decimals: longword;       // Number of decimals in field
    charsetnr: longword;      // Character set
    _type: enum_field_types;  // Type of field. Se mysql_com.h for types
    extension: Pointer;
  end;
  TMYSQL_FIELD = TMYSQL_FIELD401;
  PMYSQL_FIELD = Pointer;

const
  PackedFIELD323Size = (3*SizeOf(Pointer) + 5*SizeOf(Longword));
  AlignedFIELD323Size = PackedFIELD323Size + PackedFIELD323Size mod 8;
  PackedFIELD400Size = 5*SizeOf(Pointer) + 5*SizeOf(Longword);
  AlignedFIELD400Size = PackedFIELD400Size + PackedFIELD400Size mod 8;
  PackedFIELD401Size = 7*SizeOf(Pointer) + 13*SizeOf(Longword);
  AlignedFIELD401Size = PackedFIELD401Size + PackedFIELD401Size mod 8;
  AlignedFIELD501Size = AlignedFIELD401Size + SizeOf(Pointer);

{$IFDEF CONDITIONALEXPRESSIONS}
   {$IF SizeOf(TMYSQL_FIELD323)<>AlignedFIELD323Size}
   {$Message Fatal 'Wrong size of TMYSQL_FIELD323'}
   {$IFEND}
   {$IF SizeOf(TMYSQL_FIELD400)<>AlignedFIELD400Size}
   {$Message Fatal 'Wrong size of TMYSQL_FIELD400'}
   {$IFEND}
   {$IF SizeOf(TMYSQL_FIELD401)<>AlignedFIELD401Size}
   {$Message Fatal 'Wrong size of TMYSQL_FIELD401'}
   {$IFEND}
   {$IF SizeOf(TMYSQL_FIELD501)<>AlignedFIELD501Size}
   {$Message Fatal 'Wrong size of TMYSQL_FIELD501'}
   {$IFEND}
{$ENDIF}

function IS_NUM_FLAG(n: longword): boolean;
function INTERNAL_NUM_FIELD(f: PMYSQL_FIELD): boolean;

{ Copy the content of a unspecific field to a well defined field record }
function UpdateField(f: PMYSQL_FIELD): TMYSQL_FIELD;

{ Get fieldtype of the field }
function mysql_field_type(f: PMYSQL_FIELD): enum_field_types;

{ Get fieldflags of the field }
function mysql_field_flag(f: PMYSQL_FIELD): longword;

{ Get Length of the field }
function mysql_field_length(f: PMYSQL_FIELD): longword;

{ Get the name of the field }
function mysql_field_name(f: PMYSQL_FIELD): PAnsiChar;

{ Get the corresponding tablename of the field }
function mysql_field_tablename(f: PMYSQL_FIELD): PAnsiChar;

{ Get the default value of the field }
function mysql_field_default(f: PMYSQL_FIELD): PAnsiChar;

type
  PMYSQL_ROW = ^TMYSQL_ROW;   // return data as array of strings
  TMYSQL_ROW = array[0..MaxInt div SizeOf(PAnsiChar) - 1] of PAnsiChar;

type
  MYSQL_FIELD_OFFSET = longword;  // offset to current field

const
  MYSQL_COUNT_ERROR: my_ulonglong = my_ulonglong(not 0);

type
  PMYSQL_ROWS = ^TMYSQL_ROWS;
  TMYSQL_ROWS = record
    next: PMYSQL_ROWS;        // list of rows
    data: PMYSQL_ROW;
  end;

type
  MYSQL_ROW_OFFSET = PMYSQL_ROWS;  // offset to current row

type
  PMYSQL_DATA323 = ^TMYSQL_DATA323;
  TMYSQL_DATA323 = record
    rows: my_ulonglong;
    fields: longword;
    data: PMYSQL_ROWS;
    alloc: TMEM_ROOT323;
  end;
  PMYSQL_DATA400 = ^TMYSQL_DATA400;
  TMYSQL_DATA400 = record
    rows: my_ulonglong;
    fields: longword;
    data: PMYSQL_ROWS;
    alloc: TMEM_ROOT400;
  end;

type
  mysql_option = (
  MYSQL_OPT_CONNECT_TIMEOUT, MYSQL_OPT_COMPRESS, MYSQL_OPT_NAMED_PIPE,
  MYSQL_INIT_COMMAND, MYSQL_READ_DEFAULT_FILE, MYSQL_READ_DEFAULT_GROUP,
  MYSQL_SET_CHARSET_DIR, MYSQL_SET_CHARSET_NAME, MYSQL_OPT_LOCAL_INFILE,
  MYSQL_OPT_PROTOCOL, MYSQL_SHARED_MEMORY_BASE_NAME, MYSQL_OPT_READ_TIMEOUT,
  MYSQL_OPT_WRITE_TIMEOUT, MYSQL_OPT_USE_RESULT,
  MYSQL_OPT_USE_REMOTE_CONNECTION, MYSQL_OPT_USE_EMBEDDED_CONNECTION,
  MYSQL_OPT_GUESS_CONNECTION, MYSQL_SET_CLIENT_IP, MYSQL_SECURE_AUTH,
  MYSQL_REPORT_DATA_TRUNCATION, MYSQL_OPT_RECONNECT,
  MYSQL_OPT_SSL_VERIFY_SERVER_CERT
  );

type
  enum_mysql_set_option = (MYSQL_OPTION_MULTI_STATEMENTS_ON, MYSQL_OPTION_MULTI_STATEMENTS_OFF);

type
  PMYSQL_OPTIONS = Pointer;
  TMYSQL_OPTIONS323 = record
    connect_timeout, client_flag: longword;
    compress, named_pipe: my_bool;
    port: longword;
    host, init_command, user, password, unix_socket, db: PAnsiChar;
    my_cnf_file, my_cnf_group, charset_dir, charset_name: PAnsiChar;
    use_ssl: my_bool;       // if to use SSL or not
    ssl_key: PAnsiChar;     // PEM key file
    ssl_cert: PAnsiChar;    // PEM cert file
    ssl_ca: PAnsiChar;      // PEM CA file
    ssl_capath: PAnsiChar;  // PEM directory of CA-s?
  end;
  TMYSQL_OPTIONS400 = record
    connect_timeout, client_flag: longword;
    port: longword;
    host, init_command, user, password, unix_socket, db: PAnsiChar;
    my_cnf_file, my_cnf_group, charset_dir, charset_name: PAnsiChar;
    ssl_key: PAnsiChar;     // PEM key file
    ssl_cert: PAnsiChar;    // PEM cert file
    ssl_ca: PAnsiChar;      // PEM CA file
    ssl_capath: PAnsiChar;  // PEM directory of CA-s?
    ssl_cipher: PAnsiChar;  // cipher to use
    max_allowed_packet: longword;
    use_ssl: my_bool;       // if to use SSL or not
    compress, named_pipe: my_bool;
    rpl_probe: my_bool;
    rpl_parse: my_bool;
    no_master_reads: my_bool;
  end;
  TMYSQL_OPTIONS401 = record
    connect_timeout, read_timeout, write_timeout: longword;
    port, protocol: longword;
    client_flag: longword;
    host, user, password, unix_socket, db: PAnsiChar;
    init_commands: PAnsiChar;
    my_cnf_file, my_cnf_group, charset_dir, charset_name: PAnsiChar;
    ssl_key: PAnsiChar;     // PEM key file
    ssl_cert: PAnsiChar;    // PEM cert file
    ssl_ca: PAnsiChar;      // PEM CA file
    ssl_capath: PAnsiChar;  // PEM directory of CA-s?
    ssl_cipher: PAnsiChar;  // cipher to use
    shared_memory_base_name: PAnsiChar;
    max_allowed_packet: longword;
    use_ssl: my_bool;       // if to use SSL or not
    compress, named_pipe: my_bool;
    rpl_probe: my_bool;
    rpl_parse: my_bool;
    no_master_reads: my_bool;
//    separate_thread: my_bool;
    methods_to_use: mysql_option;
    client_ip: PAnsiChar;
    secure_auth: my_bool;
    // function pointers for local infile support
    local_infile_init: Pointer;
    local_infile_read: Pointer;
    local_infile_end: Pointer;
    local_infile_error: Pointer;
    local_infile_userdata: Pointer;
  end;

  TMYSQL_OPTIONS500 = record
    connect_timeout, read_timeout, write_timeout: longword;
    port, protocol: longword;
    client_flag: longword;
    host, user, password, unix_socket, db: PAnsiChar;
    init_commands: PAnsiChar;
    my_cnf_file, my_cnf_group, charset_dir, charset_name: PAnsiChar;
    ssl_key: PAnsiChar;     // PEM key file
    ssl_cert: PAnsiChar;    // PEM cert file
    ssl_ca: PAnsiChar;      // PEM CA file
    ssl_capath: PAnsiChar;  // PEM directory of CA-s?
    ssl_cipher: PAnsiChar;  // cipher to use
    shared_memory_base_name: PAnsiChar;
    max_allowed_packet: longword;
    use_ssl: my_bool;       // if to use SSL or not
    compress, named_pipe: my_bool;
    rpl_probe: my_bool;
    rpl_parse: my_bool;
    no_master_reads: my_bool;
//    separate_thread: my_bool;
    methods_to_use: mysql_option;
    client_ip: PAnsiChar;
    secure_auth: my_bool;
    report_data_truncation: my_bool;
    // function pointers for local infile support
    local_infile_init: Pointer;
    local_infile_read: Pointer;
    local_infile_end: Pointer;
    local_infile_error: Pointer;
    local_infile_userdata: Pointer;
  end;

type
  mysql_status = (MYSQL_STATUS_READY, MYSQL_STATUS_GET_RESULT, MYSQL_STATUS_USE_RESULT);

type
  PMYSQL_FIELDS=Pointer;

type
  PCHARSET_INFO = ^TCHARSET_INFO;
  TCHARSET_INFO = record
    // Omitted: Structure not necessarily needed.
    // Definition of struct charset_info_st can be
    // found in include/m_ctype.h
  end;

type
  PMYSQL = Pointer;
  TMYSQL323 = record
    net: TNET323;                 // Communication parameters
    connector_fd: gptr;           // ConnectorFd for SSL
    host, user, passwd, unix_socket, server_version, host_info, info, db: PAnsiChar;     //  260, 264, 268, 272, 276, 280, 284
    port, client_flag, server_capabilities: longword;
    protocol_version: longword;
    field_count: longword;
    server_status: longword;
    thread_id: longword;          // Id for connection in server
    affected_rows: my_ulonglong;
    insert_id: my_ulonglong;      // id if insert on table with NEXTNR
    extra_info: my_ulonglong;     // Used by mysqlshow
    packet_length: longword;
    status: longword;             //seems to be a longword
//    status: mysql_status;
    fields: PMYSQL_FIELDS;
    field_alloc: TMEM_ROOT323;
    free_me: my_bool;             // If free in mysql_close
    reconnect: my_bool;           // set to 1 if automatic reconnect
    options: TMYSQL_OPTIONS323;
    scramble_buff: array [0..SCRAMBLE_LENGTH_323] of AnsiChar;
    charset: PCHARSET_INFO;
    server_language: longword;
  end;

  TMYSQL400 = record
    net: TNET400;                 // Communication parameters
    connector_fd: gptr;           // ConnectorFd for SSL
    host, user, passwd, unix_socket, server_version, host_info, info, db: PAnsiChar;     //  260, 264, 268, 272, 276, 280, 284
    charset: PCHARSET_INFO;
    fields: PMYSQL_FIELDS;
    field_alloc: TMEM_ROOT400;
    affected_rows: my_ulonglong;
    insert_id: my_ulonglong;      // id if insert on table with NEXTNR
    extra_info: my_ulonglong;     // Used by mysqlshow
    thread_id: longword;          // Id for connection in server
    packet_length: longword;
    port, client_flag, server_capabilities: longword;
    protocol_version: longword;
    field_count: longword;
    server_status: longword;
    server_language: longword;
    options: TMYSQL_OPTIONS400;
    status: longword;             //seems to be a longword
//    status: mysql_status;
    free_me: my_bool;             // If free in mysql_close
    reconnect: my_bool;           // set to 1 if automatic reconnect
    scramble_buff: array [0..SCRAMBLE_LENGTH_323] of AnsiChar;
    rpl_pivot: my_bool;
    master, next_slave: PMYSQL;
    last_used_slave: PMYSQL; //* needed for round-robin slave pick */
    //* needed for send/read/store/use result to work correctly with replication */
    last_used_con: PMYSQL;
  end;
  TMYSQL401 = record
    net: TNET401;                 // Communication parameters
    connector_fd: gptr;           // ConnectorFd for SSL
    host, user, passwd, unix_socket, server_version, host_info, info, db: PAnsiChar;
    charset: PCHARSET_INFO;
    fields: PMYSQL_FIELDS;
    field_alloc: TMEM_ROOT400;
    affected_rows: my_ulonglong;
    insert_id: my_ulonglong;      // id if insert on table with NEXTNR
    extra_info: my_ulonglong;     // Used by mysqlshow
    thread_id: longword;          // Id for connection in server
    packet_length: longword;
    port, client_flag, server_capabilities: longword;
    protocol_version: longword;
    field_count: longword;
    server_status: longword;
    server_language: longword;
    warning_count: longword;
    options: TMYSQL_OPTIONS401;
    status: mysql_status;
    free_me: my_bool;             // If free in mysql_close
    reconnect: my_bool;           // set to 1 if automatic reconnect
    scramble_buff: array [0..SCRAMBLE_LENGTH] of AnsiChar;
    rpl_pivot: my_bool;
    master, next_slave: PMYSQL;
    last_used_slave: PMYSQL;      //* needed for round-robin slave pick */
    //* needed for send/read/store/use result to work correctly with replication */
    last_used_con: PMYSQL;
    stmts: Pointer;               // list of all statements
    methods: Pointer;
    thd: Pointer;
    unbuffered_fetch_owner: Pmy_bool;
    current_stmt: Pointer;
  end;
  TMYSQL500 = record
    net: TNET500;                 // Communication parameters
    connector_fd: gptr;           // ConnectorFd for SSL
    host, user, passwd, unix_socket, server_version, host_info, info, db: PAnsiChar;
    charset: PCHARSET_INFO;
    fields: PMYSQL_FIELDS;
    field_alloc: TMEM_ROOT400;
    affected_rows: my_ulonglong;
    insert_id: my_ulonglong;      // id if insert on table with NEXTNR
    extra_info: my_ulonglong;     // Used by mysqlshow
    thread_id: longword;          // Id for connection in server
    packet_length: longword;
    port, client_flag, server_capabilities: longword;
    protocol_version: longword;
    field_count: longword;
    server_status: longword;
    server_language: longword;
    warning_count: longword;
    options: TMYSQL_OPTIONS500;
    status: mysql_status;
    free_me: my_bool;             // If free in mysql_close
    reconnect: my_bool;           // set to 1 if automatic reconnect
    scramble_buff: array [0..SCRAMBLE_LENGTH] of AnsiChar;
    rpl_pivot: my_bool;
    master, next_slave: PMYSQL;
    last_used_slave: PMYSQL;      //* needed for round-robin slave pick */
    //* needed for send/read/store/use result to work correctly with replication */
    last_used_con: PMYSQL;
    stmts: Pointer;               // list of all statements
    methods: Pointer;
    thd: Pointer;
    unbuffered_fetch_owner: Pmy_bool;
    info_buffer: Pointer;         // some info for embedded server
  end;
  TMYSQL501 = record
    net: TNET501;                 // Communication parameters
    connector_fd: gptr;           // ConnectorFd for SSL
    host, user, passwd, unix_socket, server_version, host_info, info, db: PAnsiChar;
    charset: PCHARSET_INFO;
    fields: PMYSQL_FIELDS;
    field_alloc: TMEM_ROOT400;
    affected_rows: my_ulonglong;
    insert_id: my_ulonglong;      // id if insert on table with NEXTNR
    extra_info: my_ulonglong;     // Used by mysqlshow
    thread_id: longword;          // Id for connection in server
    packet_length: longword;
    port, client_flag, server_capabilities: longword;
    protocol_version: longword;
    field_count: longword;
    server_status: longword;
    server_language: longword;
    warning_count: longword;
    options: TMYSQL_OPTIONS500;
    status: mysql_status;
    free_me: my_bool;             // If free in mysql_close
    reconnect: my_bool;           // set to 1 if automatic reconnect
    scramble_buff: array [0..SCRAMBLE_LENGTH] of AnsiChar;
    rpl_pivot: my_bool;
    master, next_slave: PMYSQL;
    last_used_slave: PMYSQL;      //* needed for round-robin slave pick */
    //* needed for send/read/store/use result to work correctly with replication */
    last_used_con: PMYSQL;
    stmts: Pointer;               // list of all statements
    methods: Pointer;
    thd: Pointer;
    unbuffered_fetch_owner: Pmy_bool;
    info_buffer: Pointer;         // some info for embedded server
    extension: Pointer;
  end;

type
  PMYSQL_RES = Pointer;
  TMYSQL_RES323 = record
    row_count: my_ulonglong;
    field_count, current_field: longword;
    fields: PMYSQL_FIELDS;
    data: PMYSQL_DATA323;
    data_cursor: PMYSQL_ROWS;
    field_alloc: TMEM_ROOT323;
    row: PMYSQL_ROW;              // If unbuffered read
    current_row: PMYSQL_ROW;      // buffer to current row
    lengths: pLongword;           // column lengths of current row
    handle: PMYSQL;               // for unbuffered reads
    eof: my_bool;                 // Used my mysql_fetch_row
  end;
  TMYSQL_RES400 = record
    row_count: my_ulonglong;
    field_count, current_field: longword;
    fields: PMYSQL_FIELDS;
    data: PMYSQL_DATA400;
    data_cursor: PMYSQL_ROWS;
    field_alloc: TMEM_ROOT400;
    row: PMYSQL_ROW;              // If unbuffered read
    current_row: PMYSQL_ROW;      // buffer to current row
    lengths: pLongword;           // column lengths of current row
    handle: PMYSQL;               // for unbuffered reads
    eof: my_bool;                 // Used my mysql_fetch_row
  end;
  TMYSQL_RES401 = record
    row_count: my_ulonglong;
    field_count, current_field: longword;
    fields: PMYSQL_FIELDS;
    data: PMYSQL_DATA400;
    data_cursor: PMYSQL_ROWS;
    field_alloc: TMEM_ROOT400;
    row: PMYSQL_ROW;              // If unbuffered read
    current_row: PMYSQL_ROW;      // buffer to current row
    lengths: pLongword;           // column lengths of current row
    handle: PMYSQL;               // for unbuffered reads
    eof: my_bool;                 // Used my mysql_fetch_row
    unbuffered_fetch_cancelled: my_bool;
    st_mysql_methods: Pointer;
  end;

// Functions to get information from the MYSQL and MYSQL_RES structures
// Should definitely be used if one uses shared libraries

  function mysql_num_rows(res: PMYSQL_RES): my_ulonglong;
  function mysql_num_fields(res: PMYSQL_RES): longword; 
  function mysql_eof(res: PMYSQL_RES): my_bool; 
  function mysql_fetch_field_direct(res: PMYSQL_RES; fieldnr: longword): PMYSQL_FIELD; 
  function mysql_fetch_fields(res: PMYSQL_RES): PMYSQL_FIELDS; 
  function mysql_row_tell(res: PMYSQL_RES): MYSQL_ROW_OFFSET; 
  function mysql_field_tell(res: PMYSQL_RES): longword; 

  function mysql_field_count(_mysql: PMYSQL): longword; 
  function mysql_affected_rows(_mysql: PMYSQL): my_ulonglong; 
  function mysql_insert_id(_mysql: PMYSQL): my_ulonglong; 
  function mysql_errno(_mysql: PMYSQL): longword; 
  function mysql_error(_mysql: PMYSQL): PAnsiChar; 
  function mysql_info(_mysql: PMYSQL): PAnsiChar; 
  function mysql_thread_id(_mysql: PMYSQL): longword; 
  function mysql_character_set_name(_mysql: PMYSQL): PAnsiChar;  //since Client 3.23.21

type
  PMYSQL_LENGTHS = ^TMYSQL_LENGTHS;
  TMYSQL_LENGTHS = array[0..MaxInt div SizeOf(longword) - 1] of longword;

type
  extend_buffer_func = function(void: pointer; _to: PAnsiChar; length: pLongword): PAnsiChar;

  function mysql_init(_mysql: PMYSQL): PMYSQL; 
  function mysql_ssl_set(_mysql: PMYSQL; key, cert, ca, capath, cipher: PAnsiChar): longint; 
  function mysql_ssl_cipher(_mysql: PMYSQL): PAnsiChar; 
  function mysql_ssl_clear(_mysql: PMYSQL): longint; 
  function mysql_connect(_mysql: PMYSQL; host, user, passwd: PAnsiChar): PMYSQL; 
  function mysql_change_user(_mysql: PMYSQL; user, passwd, db: PAnsiChar): my_bool; 
  function mysql_real_connect(_mysql: PMYSQL; host, user, passwd, db: PAnsiChar; port: longword; unix_socket: PAnsiChar; clientflag: longword): PMYSQL; 
  procedure mysql_close(sock: PMYSQL); 
  function mysql_select_db(_mysql: PMYSQL; db: PAnsiChar): longint; 
  function mysql_query(_mysql: PMYSQL; q: PAnsiChar): longint; 
  function mysql_send_query(_mysql: PMYSQL; q: PAnsiChar; length: longword): longint; 
  function mysql_read_query_result(_mysql: PMYSQL): longint; 
  function mysql_real_query(_mysql: PMYSQL; q: PAnsiChar; length: longword): longint; 
  function mysql_create_db(_mysql: PMYSQL; DB: PAnsiChar): longint; 
  function mysql_drop_db(_mysql: PMYSQL; DB: PAnsiChar): longint; 
  function mysql_shutdown(_mysql: PMYSQL): longint; 
  function mysql_dump_debug_info(_mysql: PMYSQL): longint; 
  function mysql_refresh(_mysql: PMYSQL; refresh_options: longword): longint; 
  function mysql_kill(_mysql: PMYSQL; pid: longword): longint; 
  function mysql_ping(_mysql: PMYSQL): longint; 
  function mysql_stat(_mysql: PMYSQL): PAnsiChar; 
  function mysql_get_server_info(_mysql: PMYSQL): PAnsiChar; 
  function mysql_get_client_info: PAnsiChar; 
  function mysql_get_host_info(_mysql: PMYSQL): PAnsiChar; 
  function mysql_get_proto_info(_mysql: PMYSQL): longword; 
  function mysql_list_dbs(_mysql: PMYSQL; wild: PAnsiChar): PMYSQL_RES; 
  function mysql_list_tables(_mysql: PMYSQL; wild: PAnsiChar): PMYSQL_RES; 
  function mysql_list_fields(_mysql: PMYSQL; table, wild: PAnsiChar): PMYSQL_RES; 
  function mysql_list_processes(_mysql: PMYSQL): PMYSQL_RES; 
  function mysql_store_result(_mysql: PMYSQL): PMYSQL_RES; 
  function mysql_use_result(_mysql: PMYSQL): PMYSQL_RES; 
  function mysql_more_results(_mysql: PMYSQL): my_bool; 
  function mysql_next_result(_mysql: PMYSQL): longint; 
  function mysql_options(_mysql: PMYSQL; option: mysql_option; arg: Pointer): longint; 
  procedure mysql_free_result(_mysql_res: PMYSQL_RES); 
  procedure mysql_data_seek(_mysql_res: PMYSQL_RES; offset: my_ulonglong); 
  function mysql_row_seek(_mysql_res: PMYSQL_RES; offset: MYSQL_ROW_OFFSET): MYSQL_ROW_OFFSET; 
  function mysql_field_seek(_mysql_res: PMYSQL_RES; offset: MYSQL_FIELD_OFFSET): MYSQL_FIELD_OFFSET; 
  function mysql_fetch_row(_mysql_res: PMYSQL_RES): PMYSQL_ROW; 
  function mysql_fetch_lengths(_mysql_res: PMYSQL_RES): PMYSQL_LENGTHS; 
  function mysql_fetch_field(_mysql_res: PMYSQL_RES): PMYSQL_FIELD; 
  //mysql_escape_string using Latin1 character set
  function mysql_escape_string(_to: PAnsiChar; from: PAnsiChar; from_length: longword): longword; 
  //mysql_escape_string using the character set of the established connection
  function mysql_real_escape_string(_mysql: PMYSQL; _to: PAnsiChar; from: PAnsiChar; length: longword): longword; 
  procedure mysql_debug(debug: PAnsiChar); 
  function mysql_odbc_escape_string(_mysql: PMYSQL; _to: PAnsiChar; to_length: longword; from: PAnsiChar; from_length: longword; param: pointer; extend_buffer: extend_buffer_func): PAnsiChar; 
  procedure myodbc_remove_escape(_mysql: PMYSQL; name: PAnsiChar); 
  function mysql_thread_safe: longword;
  function mysql_get_client_version: longword;
  function mysql_get_server_version(_mysql: PMYSQL): longword; 
  function mysql_set_character_set(_mysql: PMYSQL; csname: PAnsiChar): longint; 
  function mysql_autocommit(_mysql: PMYSQL; mode: my_bool ): my_bool; 
  function mysql_commit(_mysql: PMYSQL): my_bool; 
  function mysql_rollback(_mysql: PMYSQL): my_bool; 
  function mysql_set_server_option(_mysql: PMYSQL; option: enum_mysql_set_option): longint; 
  function mysql_sqlstate(_mysql: PMYSQL): PAnsiChar; 
  function mysql_warning_count(_mysql: PMYSQL): longword; 
  function mysql_server_init(argc: Integer; argv, groups: PPAnsiChar): Integer; 
  procedure mysql_server_end;
{  -----------------------------------------------------------------------------------------------
  "Jeremiah Gowdy" <jgowdycox.net> wrote on 10/11/2005 03:08:40 AM:
  The Windows DLL is thread safe. You do not have to call my_init()
  and my_thread_init() because Windows DLLs receive events when they
  are attached to a new process and when they are attached to a new
  thread in a process. This is one of the nicer features of Windows
  shared libraries. Other than that, you don't have to do anything
  special. I am a heavy user of libmysql under Win32. You simply
  mysql_init() your MYSQL struct, and then mysql_real_connect() and
  you're ready to mysql_query().
  -----------------------------------------------------------------------------------------------
  New on February 17, 2009 02:27AM: This is true until 5.0.77 -
  since this version this nice feature ist removed from dll.c.
  To obtain the previous behavior (DLL initialization code will be
  called), set the LIBMYSQL_DLLINIT environment variable to
  any value. http://forums.mysql.com/read.php?3,248207,248207 
 -----------------------------------------------------------------------------------------------
}
  function mysql_thread_init: my_bool;  //called internal by mysql_init or mysql_server_init

{ New on February 17, 2009 02:27AM: Since 5.0.77 mysql_thread_end
  is not called during DllMain() if the LIBMYSQL_DLLINIT environment variable is
  not set. So it is necessary to call mysql_thread_end to avoid memory leaks. }
  procedure mysql_thread_end;

  function mysql_reload(_mysql: PMySQL): longint;
  function mysql_fetch_db(_mysql: PMYSQL): PAnsiChar;


// -----------------------------------------------------------------------------------------------
// Prepared statements support
// -----------------------------------------------------------------------------------------------

type
  PMYSQL_STMT=Pointer;
  enum_stmt_attr_type=(
  {*
    When doing mysql_stmt_store_result calculate max_length attribute
    of statement metadata. This is to be consistent with the old API,
    where this was done automatically.
    In the new API we do that only by request because it slows down
    mysql_stmt_store_result sufficiently.
  *}
  STMT_ATTR_UPDATE_MAX_LENGTH,
  {*
    unsigned long with combination of cursor flags (read only, for update,
    etc)
  *}
  STMT_ATTR_CURSOR_TYPE,
  {*
    Amount of rows to retrieve from server per one fetch if using cursors.
    Accepts unsigned long attribute in the range 1 - ulong_max
  *}
  STMT_ATTR_PREFETCH_ROWS);

  TMYSQL_BIND401 = record    // Version>=40100
    length: PDWORD;          // output length pointer
    is_null: Pmy_bool;       // Pointer to null indicator
    buffer: Pointer;         // buffer to get/put data
    buffer_type: enum_field_types;
    buffer_length: DWORD;    // buffer length, must be set for string/binary
    row_ptr: PAnsiChar;      // for the current data position
    offset: DWORD;           // offset position for char/binary fetch
    length_value: DWORD;     // Used if length is nil
    param_number: DWORD;     // For null count and error messages
    pack_length: DWORD;      // Internal length for packed data
    is_unsigned: my_bool;    // set if integer type is unsigned
    long_data_used: my_bool; // If used with mysql_send_long_data
    is_null_value: my_bool;  // Used if is_null is nil
    store_param_func: FARPROC;
    fetch_result: FARPROC;
    skip_result: FARPROC;
  end;
  PMYSQL_BIND401=^TMYSQL_BIND401;

  TMYSQL_BIND500 = record    // Version>=50000
    length: PDWORD;          // output length pointer
    is_null: Pmy_bool;       // Pointer to null indicator
    buffer: Pointer;         // buffer to get/put data
//  set this if you want to track data truncations happened during fetch
    error: Pmy_bool;
    buffer_type: enum_field_types;
    buffer_length: DWORD;    // buffer length, must be set for string/binary
    row_ptr: PAnsiChar;      // for the current data position
    offset: DWORD;           // offset position for char/binary fetch
    length_value: DWORD;     // Used if length is nil
    param_number: DWORD;     // For null count and error messages
    pack_length: DWORD;      // Internal length for packed data
    error_value: my_bool;    // used if error is nil
    is_unsigned: my_bool;    // set if integer type is unsigned
    long_data_used: my_bool; // If used with mysql_send_long_data
    is_null_value: my_bool;  // Used if is_null is nil
    store_param_func: FARPROC;
    fetch_result: FARPROC;
    skip_result: FARPROC;
  end;
  PMYSQL_BIND500=^TMYSQL_BIND500;

  TMYSQL_BIND501 = record    // Version>=50100
    length: PDWORD;          // output length pointer
    is_null: Pmy_bool;       // Pointer to null indicator
    buffer: Pointer;         // buffer to get/put data
//  set this if you want to track data truncations happened during fetch
    error: Pmy_bool;
    row_ptr: PAnsiChar;      // for the current data position
    store_param_func: FARPROC;
    fetch_result: FARPROC;
    skip_result: FARPROC;
    buffer_length: DWORD;    // buffer length, must be set for string/binary
    offset: DWORD;           // offset position for char/binary fetch
    length_value: DWORD;     // Used if length is nil
    param_number: DWORD;     // For null count and error messages
    pack_length: DWORD;      // Internal length for packed data
    buffer_type: enum_field_types;
    error_value: my_bool;    // used if error is nil
    is_unsigned: my_bool;    // set if integer type is unsigned
    long_data_used: my_bool; // If used with mysql_send_long_data
    is_null_value: my_bool;  // Used if is_null is nil
    extension: Pointer;
  end;
  PMYSQL_BIND501=^TMYSQL_BIND501;

  TMYSQL_BIND=TMYSQL_BIND501;
  PMYSQL_BIND=Pointer;

{$IFDEF CONDITIONALEXPRESSIONS} {Delphi 6 and above}
type
  enum_mysql_timestamp_type=(
    MYSQL_TIMESTAMP_NONE = -2, MYSQL_TIMESTAMP_ERROR = -1,
    MYSQL_TIMESTAMP_DATE = 0, MYSQL_TIMESTAMP_DATETIME = 1, MYSQL_TIMESTAMP_TIME = 2);
{$ELSE}
const
  MYSQL_TIMESTAMP_NONE = -2;
  MYSQL_TIMESTAMP_ERROR = -1;
  MYSQL_TIMESTAMP_DATE = 0;
  MYSQL_TIMESTAMP_DATETIME = 1;
  MYSQL_TIMESTAMP_TIME = 2;
type
  enum_mysql_timestamp_type=Integer;
{$ENDIF}

type
  TMYSQL_TIME = record
    year, month, day, hour, minute, second: DWORD;
    second_part: DWORD;
    neg: my_bool;
    time_type: enum_mysql_timestamp_type;
  end;

  function mysql_stmt_affected_rows(stmt: PMYSQL_STMT): my_ulonglong; 
  function mysql_stmt_attr_get(stmt: PMYSQL_STMT; option: enum_stmt_attr_type; var arg): Integer; 
  function mysql_stmt_attr_set(stmt: PMYSQL_STMT; option: enum_stmt_attr_type; const arg): Integer; 
  function mysql_stmt_bind_param(stmt: PMYSQL_STMT; bind: PMYSQL_BIND): my_bool; 
  function mysql_stmt_bind_result(stmt: PMYSQL_STMT; bind: PMYSQL_BIND): my_bool; 
  function mysql_stmt_close(stmt: PMYSQL_STMT): my_bool; 
  procedure mysql_stmt_data_seek(stmt: PMYSQL_STMT; offset: my_ulonglong); 
  function mysql_stmt_errno(stmt: PMYSQL_STMT): DWORD; 
  function mysql_stmt_error(stmt: PMYSQL_STMT): PAnsiChar; 
  function mysql_stmt_execute(stmt: PMYSQL_STMT): Integer; 
  function mysql_stmt_fetch(stmt: PMYSQL_STMT): Integer; 
  function mysql_stmt_fetch_column(stmt: PMYSQL_STMT; bind: PMYSQL_BIND; column: DWORD; offset: DWORD): Integer; 
  function mysql_stmt_field_count(stmt: PMYSQL_STMT): DWORD; 
  function mysql_stmt_free_result(stmt: PMYSQL_STMT): my_bool; 
  function mysql_stmt_init(_mysql: PMYSQL): PMYSQL_STMT; 
  function mysql_stmt_insert_id(stmt: PMYSQL_STMT): my_ulonglong; 
  function mysql_stmt_num_rows(stmt: PMYSQL_STMT): my_ulonglong; 
  function mysql_stmt_param_count(stmt: PMYSQL_STMT): DWORD; 
  function mysql_stmt_param_metadata(stmt: PMYSQL_STMT): PMYSQL_RES; 
  function mysql_stmt_prepare(stmt: PMYSQL_STMT; query: PAnsiChar; length: DWORD): Integer; 
  function mysql_stmt_reset(stmt: PMYSQL_STMT): my_bool; 
  function mysql_stmt_result_metadata(stmt: PMYSQL_STMT): PMYSQL_RES; 
  function mysql_stmt_row_seek(stmt: PMYSQL_STMT; offset: MYSQL_ROW_OFFSET): MYSQL_ROW_OFFSET; 
  function mysql_stmt_row_tell(stmt: PMYSQL_STMT): MYSQL_ROW_OFFSET; 
  function mysql_stmt_send_long_data(stmt: PMYSQL_STMT; parameter_number: DWORD; data: PAnsiChar; length: DWORD): my_bool; 
  function mysql_stmt_sqlstate(stmt: PMYSQL_STMT): PAnsiChar; 
  function mysql_stmt_store_result(stmt: PMYSQL_STMT): Integer;

//-- Functions for library independent BIND handling --
  //Create initialized memory block for Bindings - Free it with FreeMem
  function mysql_bind_init(Count: Integer): PMYSQL_BIND;
  //Copy mySQL_Bind to bind record array
  function mysql_bind_copy_bind(bind: PMYSQL_BIND; Index: Integer; const mySQL_Bind: TMYSQL_BIND): Boolean;
  //Copy params to bind record array
  function mysql_bind_set_param(bind: PMYSQL_BIND; Index: Integer;
                                buffer_type: enum_field_types;
                                buffer: Pointer;         // buffer to get/put data
                                buffer_length: DWORD;
                                length: PDWORD;          // output length pointer
                                is_null: Pmy_bool        // Pointer to null indicator
                                ): Boolean;

// -----------------------------------------------------------------------------------------------
// Character Set support
// -----------------------------------------------------------------------------------------------

{ Normally it is not necessary to use this functions. The converter functions of Delphi - AnsiString()
  and UnicodeString() - should work properly in most cases. You could benefit from this functions, if
  - Your application must support more than one codepage at the same time (e.g. your server connection
    use another  character set than other parts of your application)
  - You want change the character set for the mysql client at runtime
  - You want change the codepage according to the character set of the mysql client at runtime
  - You want have more encoding performance especially for the data rows coming from the server
    (you can avoid multiple string scans by using mysql_fetch_lengths)
  - You want support unicode using Delphi prior Delphi 2009
}

{$IFDEF Win32CharacterConvert}
   {$DEFINE CharacterConvert}

function MySqlToUTF16(Source: PAnsiChar; Length: Integer=-1; CodePage: Word=CP_ACP): UnicodeString; overload;

function UTF16ToMySql(const Source: UnicodeString; CodePage: Word=CP_ACP): RawByteString; overload;

var
  DefaultMySqlCodePage: Word;

// If you feel more comfortable with a encoding class...
type
  TMySqlEncoding=class
  private
    FCodepage: Word;
  public
    constructor Create(Codepage: Word=CP_ACP);
    function MySqlToUTF16(Source: PAnsiChar; Length: Integer=-1): UnicodeString;
    function UTF16ToMySql(const Source: UnicodeString): RawByteString;
  end;

{$ENDIF}

// Not official supported set of conversion functions for high speed but great
// amount of memory

{$IFDEF EmbeddedCharacterConvert}
   {$DEFINE CharacterConvert}
type
  TCharsetHandle=Pointer;

// Create a new CharsetHandle - use this prior conversion
function CreateCharsetHandle(const csname: String): TCharsetHandle;

// Free the resources used by CharsetHandle - use this after conversion
procedure FreeCharsetHandle(CharSetHandle: TCharsetHandle);

function GetCharSetName(CharSetHandle: TCharsetHandle): String;

function CreateCharsetHandleById(CharsetId: Integer): TCharsetHandle;

function CharSetIsEmbeeded(CharSetHandle: TCharsetHandle): Boolean;

//Convert from MySql string to UTF16 (Unicode) String
function MySqlToUTF16(Source: PAnsiChar; Length: Integer; CharSetHandle: TCharsetHandle): UnicodeString; overload;

//Convert from UTF16 (Unicode) String to MySql string
function UTF16ToMySql(const Source: UnicodeString; CharSetHandle: TCharsetHandle): RawByteString; overload;

{$ENDIF}

{$IFDEF CharacterConvert}

// Get a comma separated list of all MySql character set names matches to the Codepage
function CodePageToCharsetName(CodePage: Word; List: Boolean=False): String;

// Get the Codepage matches to the MySql character set name
function CharsetNameToCodePage(CharacterSetName: String): Word;

{$ENDIF}

// -----------------------------------------------------------------------------------------------
// Utility Functions
// -----------------------------------------------------------------------------------------------

// Same as StrLen() but return 0 if Str is nil - usefull for Delphi prior Delphi 2009
// Since Delphi 2009 you can use Length(Str)
function MySql_StrLen(const Str: PAnsiChar): Cardinal;

// ------------------------------- U n i c o d e -------------------------------------------------
{ This Escape functions are native Delphi functions supporting Unicode.
  There are two different ways for transfering data to the SQL-Sever:
  a) Create SQL-Statement -> EscapeString -> Character Encoding -> mysql_real_query
  b) Create SQL-Statement -> Character Encoding -> mysql_real_escape_string -> mysql_real_query
}
{$IFDEF Unicode }
{ Escape String - Unicode Version }
function EscapeString(const Str: String): String; overload;

{ Quote and escape SQL String - for transfering Values to Server.}
function QuoteString(const Str: String): String; overload;

//"BackTick" the Identifier like Tablenames and Fieldnames
function QuoteName(const Str: String): String; overload; inline;

// Escape "\", "_" and "%" characters and all characters normaly escaped by mysql_escape_string
function EscapeForLike(const Str: String): String; overload;
{$ENDIF}

// ----------------------------- M u l t i b y t e -----------------------------------------------
{ This Escape functions are native Delphi functions supporting the System-Codepage.
  There are two different ways for transfering data to the SQL-Sever:
  a) Create SQL-Statement -> EscapeString -> [Character Encoding] -> mysql_real_query
  b) Create SQL-Statement -> [Character Encoding] -> mysql_real_escape_string -> mysql_real_query
}
{ Escape String - Multibyte-Character Version - using System-Codepage}
function EscapeString(const Str: AnsiString): AnsiString; overload;

{ Quoted and Escaped SQL String - for transfering Values to Server.
  This is the Multibyte-Character Version - using System-Codepage}
function QuoteString(const Str: AnsiString): AnsiString; overload;

function QuoteName(const Str: AnsiString): AnsiString; overload;
{$IFDEF CONDITIONALEXPRESSIONS}
{$IF defined(FPC) or (CompilerVersion>=18)}
inline;
{$IFEND}
{$ENDIF}

function EscapeForLike(const Str: AnsiString): AnsiString; overload;

function FullFieldname(const table, field: String): String;

// -----------------------------------------------------------------------------------------------
// Library loading
// -----------------------------------------------------------------------------------------------

type
  Tlibmysql_status=(LIBMYSQL_UNDEFINED,     // libmysql_load() has not yet been called
                    LIBMYSQL_MISSING,       // No suitable DLL could be located
                    LIBMYSQL_INCOMPATIBLE,  // A DLL was found but it is not compatible
                    LIBMYSQL_READY);        // The DLL was loaded successfully

var
  libmysql_handle: HMODULE = 0;

function libmysql_ClientVersion: longword; //current Client-Version as longword 3.23.58=32358
function libmysql_status: Tlibmysql_status;

//Load library and resolve all functions
function libmysql_load(name: PChar): Tlibmysql_status;
//Raise exception if library not loaded
procedure libmysql_load_check;

//Load library - functions are resolved if needed - Exception if library not loaded
procedure libmysql_fast_load(name: PChar=nil);

function mysql_get_client_filename: String;

//Unload library
procedure libmysql_free;

// -----------------------------------------------------------------------------------------------
IMPLEMENTATION
// -----------------------------------------------------------------------------------------------

{$IFDEF AD}
uses
  SysUtils, UadConsts;
{$ELSE}
uses
  SysUtils;
{$ENDIF}


resourcestring
  sLibMySql_Undefined = 'MySQL: libmysql not loaded';
  sLibMySql_Missing = 'MySQL: No suitable DLL could be located';
  sLibMySql_Incompatible = 'MySQL: A DLL was found but it is not compatible';
  sLibMySql_Version_Incompatible = 'MySQL: libmysql %s is not compatible';

{$IFNDEF AD}
  EProcNotFound = 'MySQL: Procedure "%1:s"  not found in library "%0:s"';
  ELibraryNotFound = 'MySQL: Library "%s" not found';
{$ENDIF}

const
  mysql_not_compatible_version=60100;

var
  internal_libmysql_status: Tlibmysql_status=LIBMYSQL_UNDEFINED;
  internal_libmysql_ClientVersion: longword;

function IS_PRI_KEY(n: longword): boolean;
begin
  Result := (n and PRI_KEY_FLAG) <> 0;
end;

function IS_AUTO_INC(n: longword): boolean;
begin
  Result := (n and AUTO_INCREMENT_FLAG) <> 0;
end;

function IS_NOT_NULL(n: longword): boolean;
begin
  Result := (n and NOT_NULL_FLAG) <> 0;
end;

function IS_BLOB(n: longword): boolean;
begin
  Result := (n and BLOB_FLAG) <> 0;
end;

function IS_NUM_FLAG(n: longword): boolean;
begin
  Result := (n and NUM_FLAG) <> 0
end;

function IS_NUM(t: enum_field_types): boolean;
begin
  Result := (t<>MYSQL_TYPE_TIMESTAMP) and ((t <= MYSQL_TYPE_INT24) or (t = MYSQL_TYPE_YEAR) or (t = MYSQL_TYPE_NEWDECIMAL));
end;

function IS_LONGDATA(t: enum_field_types): boolean;
begin
  Result := (t >= MYSQL_TYPE_TINY_BLOB) and (t <= MYSQL_TYPE_STRING);
end;

function INTERNAL_NUM_FIELD(f: PMYSQL_FIELD): boolean;
begin
  {$ifndef CPUX64}
  if internal_libmysql_ClientVersion<40000
  then begin
    with TMYSQL_FIELD323(f^) do
      Result := (((_type <= MYSQL_TYPE_INT24) and ((_type <> MYSQL_TYPE_TIMESTAMP) or (length = 14) or (length = 8))) or (_type = MYSQL_TYPE_YEAR));
  end
  else
  if internal_libmysql_ClientVersion<40100
  then begin
    with TMYSQL_FIELD400(f^) do
      Result := (((_type <= MYSQL_TYPE_INT24) and ((_type <> MYSQL_TYPE_TIMESTAMP) or (length = 14) or (length = 8))) or (_type = MYSQL_TYPE_YEAR));
  end
  else
  {$endif}
  if internal_libmysql_ClientVersion<mysql_not_compatible_version
  then begin
    with TMYSQL_FIELD401(f^) do
      Result := (((_type <= MYSQL_TYPE_INT24) and ((_type <> MYSQL_TYPE_TIMESTAMP) or (length = 14) or (length = 8))) or (_type = MYSQL_TYPE_YEAR));
  end
  else
    Result := False;
end;


function UpdateField(f: PMYSQL_FIELD): TMYSQL_FIELD;
{$HINTS OFF}
  {$IFNDEF CPUX64}
  procedure CopyStr(var dest: PAnsiChar; var DestLen: Cardinal; src: PAnsiChar);
  begin
    if (src<>nil) and (Cardinal(src)<>$BAADF00D)
    then begin
      dest := src;
      DestLen := MySql_StrLen(src);
    end
    else begin
      dest := nil;
      DestLen := 0;
    end;
  end;
  {$ENDIF}
begin
  if f<>nil
  then begin
    {$IFNDEF CPUX64}
    if internal_libmysql_ClientVersion<40000
    then begin
      CopyStr(Result.name, Result.name_length, TMYSQL_FIELD323(f^).name);
      CopyStr(Result.table,Result.table_length, TMYSQL_FIELD323(f^).table);
      CopyStr(Result.def, Result.def_length, TMYSQL_FIELD323(f^).def);
      Result.length := TMYSQL_FIELD323(f^).length;
      Result.max_length := TMYSQL_FIELD323(f^).max_length;
      Result.org_table := nil;
      Result.org_table_length := 0;
      Result.org_name := nil;
      Result.org_name_length := 0;
      Result.db := nil;
      Result.db_length := 0;
      Result.catalog := nil;
      Result.catalog_length := 0;
      Result.flags := TMYSQL_FIELD323(f^).flags;
      Result.decimals := TMYSQL_FIELD323(f^).decimals;
      Result.charsetnr := 0;
      Result._type := TMYSQL_FIELD323(f^)._type;
    end
    else
    if internal_libmysql_ClientVersion<40100
    then begin
      CopyStr(Result.name, Result.name_length, TMYSQL_FIELD400(f^).name);
      CopyStr(Result.table,Result.table_length, TMYSQL_FIELD400(f^).table);
      CopyStr(Result.org_table, Result.org_table_length, TMYSQL_FIELD400(f^).org_table);
      CopyStr(Result.db, Result.db_length, TMYSQL_FIELD400(f^).db);
      CopyStr(Result.def, Result.def_length, TMYSQL_FIELD400(f^).def);
      CopyStr(Result.org_table, Result.org_table_length, TMYSQL_FIELD400(f^).org_table);
      Result.length := TMYSQL_FIELD400(f^).length;
      Result.max_length := TMYSQL_FIELD400(f^).max_length;
      Result.org_name := nil;
      Result.org_name_length := 0;
      Result.catalog := nil;
      Result.catalog_length := 0;
      Result.flags := TMYSQL_FIELD400(f^).flags;
      Result.decimals := TMYSQL_FIELD400(f^).decimals;
      Result.charsetnr := 0;
      Result._type := TMYSQL_FIELD400(f^)._type;
    end
    else
    {$ENDIF}
    if internal_libmysql_ClientVersion<mysql_not_compatible_version
    then begin
      move(f^, Result, sizeof(TMYSQL_FIELD401));
    end;
  end;
{$HINTS ON}
end;

function GetVersion(VersionString: PAnsiChar): longword;
  function GetValue(var v: Cardinal; var p: PAnsiChar): Boolean;
  var
    t: SmallInt;
    c: AnsiChar;
  begin
    t := 0;
    c := p^;
    while ((c>='0') and (c<='9')) do
    begin
      t := t * 10 + Ord(c) - Ord('0');
      inc(p);
      c := p^;
    end;
    if c<>#0 then inc(P);
    v := v * 100 + Cardinal(t);
    Result := ((c='.') or (c='-') or (c=#0)) and (t<100);
  end;
begin
  if (VersionString=nil) or (VersionString^=#0)
  then
    Result := longword(-1)
  else begin
    Result := 0;
    if not GetValue(Result, VersionString) or
       not GetValue(Result, VersionString) or
       not GetValue(Result, VersionString)
    then
      Result := longword(-1);
  end;
end;


function libmysql_ClientVersion_substitute: longword; stdcall;
begin
  Result := GetVersion(mysql_get_client_info);
end;

function libmysql_ServerVersion_substitute(_mysql: PMYSQL): longword; stdcall;
begin
  Result := GetVersion(mysql_get_server_info(_mysql));
end;

function mysql_reload(_mysql: PMYSQL): longint;
begin
  Result := mysql_refresh(_mysql, REFRESH_GRANT);
end;

{$IFDEF CONDITIONALEXPRESSIONS}
  {$DEFINE DYNAMICARRAYS}
{$ENDIF}
{$IFDEF VER120} //Delphi 4
  {$DEFINE DYNAMICARRAYS}
{$ENDIF}
{$IFDEF VER130} //Delphi 5
  {$DEFINE DYNAMICARRAYS}
{$ENDIF}

{$IFDEF DYNAMICARRAYS}
var
  MysqlVarArray: array of ^Pointer;

procedure PushProc(procvar: Pointer);
var
  L: Integer;
begin
  L := Length(MysqlVarArray);
  SetLength(MysqlVarArray, L+1);
  MysqlVarArray[L] := procvar;
end;

procedure FinalizeLibmysql;
var
  i: Integer;
begin
  if MysqlVarArray<>nil
  then begin
    for i := High(MysqlVarArray) downto 0 do
    begin
      MysqlVarArray[i]^ := nil;
    end;
    SetLength(MysqlVarArray, 0);
  end;
end;

{$ELSE}
//dynamic array for Delphi 3 (not testet with Delphi 3)
Type
  TMysqlProcArray=array [0..4095] of ^Pointer;
  PMysqlProcArray=^TMysqlProcArray;
var
  MysqlVarArraySize: Integer;
  MysqlVarArray: PMysqlProcArray;

procedure PushProc(procvar: Pointer);
begin
  ReallocMem(MysqlVarArray, (MysqlVarArraySize+1)*SizeOf(Pointer));
  MysqlVarArray^[MysqlVarArraySize] := procvar;
  inc(MysqlVarArraySize);
end;

procedure FinalizeLibmysql;
var
  i: Integer;
begin
  if MysqlVarArray<>nil
  then begin
    for i := MysqlVarArraySize - 1 downto 0 do
    begin
      MysqlVarArray^[i]^ := nil;
    end;
    FreeMem(MysqlVarArray);
    MysqlVarArray := nil;
    MysqlVarArraySize := 0;
  end;
end;
{$ENDIF}

procedure LoadProcAddress(var proc: FARPROC; name: PAnsiChar);
var
  ModulPath: String;
begin
  if proc = nil
  then begin
    if libmysql_handle=0
    then
      raise Exception.Create(sLibMySql_Undefined);
    proc := GetProcAddress(libmysql_handle, name);
    if proc = nil
    then begin
      internal_libmysql_status := LIBMYSQL_INCOMPATIBLE;
      SetLength(ModulPath, MAX_PATH+1);
      SetLength(ModulPath, GetModuleFileName(libmysql_handle, Pointer(ModulPath), Length(ModulPath)));
      raise Exception.CreateFmt(EProcNotFound, [ModulPath, name])
    end;
    PushProc(@proc);
  end;
end;

function mysql_fetch_db(_mysql: PMYSQL): PAnsiChar;
begin
  {$ifndef CPUX64}
  if internal_libmysql_ClientVersion<40000
  then
    Result := TMYSQL323(_mysql^).db
  else
  if internal_libmysql_ClientVersion<40100
  then
    Result := TMYSQL400(_mysql^).db
  else
  {$endif}
  if internal_libmysql_ClientVersion<mysql_not_compatible_version
  then
    Result := TMYSQL401(_mysql^).db
  else
    Result := nil;
end;

function mysql_field_type(f: PMYSQL_FIELD): enum_field_types;
begin
  {$ifndef CPUX64}
  if internal_libmysql_ClientVersion<40000
  then
    Result := TMYSQL_FIELD323(f^)._type
  else
  if internal_libmysql_ClientVersion<40100
  then
    Result := TMYSQL_FIELD400(f^)._type
  else
  {$endif}
  if internal_libmysql_ClientVersion<mysql_not_compatible_version
  then
    Result := TMYSQL_FIELD401(f^)._type
  else
    raise Exception.Create(sLibMySql_Incompatible);
end;

function mysql_field_flag(f: PMYSQL_FIELD): longword;
begin
  {$ifndef CPUX64}
  if internal_libmysql_ClientVersion<40000
  then
    Result := TMYSQL_FIELD323(f^).flags
  else
  if internal_libmysql_ClientVersion<40100
  then
    Result := TMYSQL_FIELD400(f^).flags
  else
  {$endif}
  if internal_libmysql_ClientVersion<mysql_not_compatible_version
  then
    Result := TMYSQL_FIELD401(f^).flags
  else
    raise Exception.Create(sLibMySql_Incompatible);
end;

function mysql_field_length(f: PMYSQL_FIELD): longword;
begin
  {$ifndef CPUX64}
  if internal_libmysql_ClientVersion<40000
  then
    Result := TMYSQL_FIELD323(f^).length
  else
  if internal_libmysql_ClientVersion<40100
  then
    Result := TMYSQL_FIELD400(f^).length
  else
  {$endif}
  if internal_libmysql_ClientVersion<mysql_not_compatible_version
  then
    Result := TMYSQL_FIELD401(f^).length
  else
    raise Exception.Create(sLibMySql_Incompatible);
end;

function mysql_field_name(f: PMYSQL_FIELD): PAnsiChar;
begin
  Result := TMYSQL_FIELD(f^).name;
end;

function mysql_field_tablename(f: PMYSQL_FIELD): PAnsiChar;
begin
  {$ifndef CPUX64}
  if internal_libmysql_ClientVersion<40100
  then
    Result := TMYSQL_FIELD400(f^).table
  else
  {$endif}
  if internal_libmysql_ClientVersion<mysql_not_compatible_version
  then
    Result := TMYSQL_FIELD401(f^).table
  else
    raise Exception.Create(sLibMySql_Incompatible);
end;

function mysql_field_default(f: PMYSQL_FIELD): PAnsiChar;
begin
  {$ifndef CPUX64}
  if internal_libmysql_ClientVersion<40000
  then
    Result := TMYSQL_FIELD323(f^).def
  else
  if internal_libmysql_ClientVersion<40100
  then
    Result := TMYSQL_FIELD400(f^).def
  else
  {$endif}
  if internal_libmysql_ClientVersion<mysql_not_compatible_version
  then
    Result := TMYSQL_FIELD401(f^).def
  else
    raise Exception.Create(sLibMySql_Incompatible);
end;

var
  _mysql_num_rows: function (res: PMYSQL_RES): my_ulonglong; stdcall;

function mysql_num_rows(res: PMYSQL_RES): my_ulonglong;
begin
  if @_mysql_num_rows=nil
  then
    LoadProcAddress(@_mysql_num_rows, 'mysql_num_rows');
  Result := _mysql_num_rows(res);
end;

var
  _mysql_num_fields: function (res: PMYSQL_RES): longword; stdcall;

function mysql_num_fields(res: PMYSQL_RES): longword;
begin
  if @_mysql_num_fields=nil
  then
    LoadProcAddress(@_mysql_num_fields, 'mysql_num_fields');
  Result := _mysql_num_fields(res);
end;

var
  _mysql_eof: function (res: PMYSQL_RES): my_bool; stdcall;

function mysql_eof(res: PMYSQL_RES): my_bool;
begin
  if @_mysql_eof=nil
  then
    LoadProcAddress(@_mysql_eof, 'mysql_eof');
  Result := _mysql_eof(res);
end;

var
  _mysql_fetch_field_direct: function (res: PMYSQL_RES; fieldnr: longword): PMYSQL_FIELD; stdcall;

function mysql_fetch_field_direct(res: PMYSQL_RES; fieldnr: longword): PMYSQL_FIELD;
begin
  if @_mysql_fetch_field_direct=nil
  then
    LoadProcAddress(@_mysql_fetch_field_direct, 'mysql_fetch_field_direct');
  Result := _mysql_fetch_field_direct(res, fieldnr);
end;

var
  _mysql_fetch_fields: function (res: PMYSQL_RES): PMYSQL_FIELDS; stdcall;

function mysql_fetch_fields(res: PMYSQL_RES): PMYSQL_FIELDS;
begin
  if @_mysql_fetch_fields=nil
  then
    LoadProcAddress(@_mysql_fetch_fields, 'mysql_fetch_fields');
  Result := _mysql_fetch_fields(res);
end;

var
  _mysql_row_tell: function (res: PMYSQL_RES): MYSQL_ROW_OFFSET; stdcall;

function mysql_row_tell(res: PMYSQL_RES): MYSQL_ROW_OFFSET;
begin
  if @_mysql_row_tell=nil
  then
    LoadProcAddress(@_mysql_row_tell, 'mysql_row_tell');
  Result := _mysql_row_tell(res);
end;

var
  _mysql_field_tell: function (res: PMYSQL_RES): longword; stdcall;

function mysql_field_tell(res: PMYSQL_RES): longword;
begin
  if @_mysql_field_tell=nil
  then
    LoadProcAddress(@_mysql_field_tell, 'mysql_field_tell');
  Result := _mysql_field_tell(res);
end;

var
  _mysql_field_count: function (_mysql: PMYSQL): longword; stdcall;

function mysql_field_count(_mysql: PMYSQL): longword;
begin
  if @_mysql_field_count=nil
  then
    LoadProcAddress(@_mysql_field_count, 'mysql_field_count');
  Result := _mysql_field_count(_mysql);
end;

var
  _mysql_affected_rows: function (_mysql: PMYSQL): my_ulonglong; stdcall;

function mysql_affected_rows(_mysql: PMYSQL): my_ulonglong;
begin
  if @_mysql_affected_rows=nil
  then
    LoadProcAddress(@_mysql_affected_rows, 'mysql_affected_rows');
  Result := _mysql_affected_rows(_mysql);
end;

var
  _mysql_insert_id: function (_mysql: PMYSQL): my_ulonglong; stdcall;

function mysql_insert_id(_mysql: PMYSQL): my_ulonglong;
begin
  if @_mysql_insert_id=nil
  then
    LoadProcAddress(@_mysql_insert_id, 'mysql_insert_id');
  Result := _mysql_insert_id(_mysql);
end;

var
  _mysql_errno: function (_mysql: PMYSQL): longword; stdcall;

function mysql_errno(_mysql: PMYSQL): longword;
begin
  if @_mysql_errno=nil
  then
    LoadProcAddress(@_mysql_errno, 'mysql_errno');
  Result := _mysql_errno(_mysql);
end;

var
  _mysql_error: function (_mysql: PMYSQL): PAnsiChar; stdcall;

function mysql_error(_mysql: PMYSQL): PAnsiChar;
begin
  if @_mysql_error=nil
  then
    LoadProcAddress(@_mysql_error, 'mysql_error');
  Result := _mysql_error(_mysql);
end;

var
  _mysql_info: function (_mysql: PMYSQL): PAnsiChar; stdcall;

function mysql_info(_mysql: PMYSQL): PAnsiChar;
begin
  if @_mysql_info=nil
  then
    LoadProcAddress(@_mysql_info, 'mysql_info');
  Result := _mysql_info(_mysql);
end;

var
  _mysql_thread_id: function (_mysql: PMYSQL): longword; stdcall;

function mysql_thread_id(_mysql: PMYSQL): longword;
begin
  if @_mysql_thread_id=nil
  then
    LoadProcAddress(@_mysql_thread_id, 'mysql_thread_id');
  Result := _mysql_thread_id(_mysql);
end;

var
  _mysql_character_set_name: function (_mysql: PMYSQL): PAnsiChar; stdcall;

function mysql_character_set_name(_mysql: PMYSQL): PAnsiChar;
begin
  if @_mysql_character_set_name=nil
  then
    LoadProcAddress(@_mysql_character_set_name, 'mysql_character_set_name');
  Result := _mysql_character_set_name(_mysql);
end;

var
  _mysql_init: function (_mysql: PMYSQL): PMYSQL; stdcall;

function mysql_init(_mysql: PMYSQL): PMYSQL;
begin
  if @_mysql_init=nil
  then
    LoadProcAddress(@_mysql_init, 'mysql_init');
  Result := _mysql_init(_mysql);
end;

var
  _mysql_ssl_set: function (_mysql: PMYSQL; key, cert, ca, capath, cipher: PAnsiChar): longint; stdcall;

function mysql_ssl_set(_mysql: PMYSQL; key, cert, ca, capath, cipher: PAnsiChar): longint;
begin
  if @_mysql_ssl_set=nil
  then
    LoadProcAddress(@_mysql_ssl_set, 'mysql_ssl_set');
  Result := _mysql_ssl_set(_mysql, key, cert, ca, capath, cipher);
end;

var
  _mysql_ssl_cipher: function (_mysql: PMYSQL): PAnsiChar; stdcall;

function mysql_ssl_cipher(_mysql: PMYSQL): PAnsiChar;
begin
  if @_mysql_ssl_cipher=nil
  then
    LoadProcAddress(@_mysql_ssl_cipher, 'mysql_ssl_cipher');
  Result := _mysql_ssl_cipher(_mysql);
end;

var
  _mysql_ssl_clear: function (_mysql: PMYSQL): longint; stdcall;

function mysql_ssl_clear(_mysql: PMYSQL): longint;
begin
  if @_mysql_ssl_clear=nil
  then
    LoadProcAddress(@_mysql_ssl_clear, 'mysql_ssl_clear');
  Result := _mysql_ssl_clear(_mysql);
end;

var
  _mysql_connect: function (_mysql: PMYSQL; host, user, passwd: PAnsiChar): PMYSQL; stdcall;

function mysql_connect(_mysql: PMYSQL; host, user, passwd: PAnsiChar): PMYSQL;
begin
  if @_mysql_connect=nil
  then
    LoadProcAddress(@_mysql_connect, 'mysql_connect');
  Result := _mysql_connect(_mysql, host, user, passwd);
end;

var
  _mysql_change_user: function (_mysql: PMYSQL; user, passwd, db: PAnsiChar): my_bool; stdcall;

function mysql_change_user(_mysql: PMYSQL; user, passwd, db: PAnsiChar): my_bool;
begin
  if @_mysql_change_user=nil
  then
    LoadProcAddress(@_mysql_change_user, 'mysql_change_user');
  Result := _mysql_change_user(_mysql, user, passwd, db);
end;

var
  _mysql_real_connect: function (_mysql: PMYSQL; host, user, passwd, db: PAnsiChar; port: longword; unix_socket: PAnsiChar; clientflag: longword): PMYSQL; stdcall;

function mysql_real_connect(_mysql: PMYSQL; host, user, passwd, db: PAnsiChar; port: longword; unix_socket: PAnsiChar; clientflag: longword): PMYSQL;
begin
  if @_mysql_real_connect=nil
  then
    LoadProcAddress(@_mysql_real_connect, 'mysql_real_connect');
  Result := _mysql_real_connect(_mysql, host, user, passwd, db, port, unix_socket, clientflag);
end;

var
  _mysql_close: procedure (sock: PMYSQL); stdcall;

procedure mysql_close(sock: PMYSQL);
begin
  if @_mysql_close=nil
  then
    LoadProcAddress(@_mysql_close, 'mysql_close');
  _mysql_close(sock);
end;

var
  _mysql_select_db: function (_mysql: PMYSQL; db: PAnsiChar): longint; stdcall;

function mysql_select_db(_mysql: PMYSQL; db: PAnsiChar): longint;
begin
  if @_mysql_select_db=nil
  then
    LoadProcAddress(@_mysql_select_db, 'mysql_select_db');
  Result := _mysql_select_db(_mysql, db);
end;

var
  _mysql_query: function (_mysql: PMYSQL; q: PAnsiChar): longint; stdcall;

function mysql_query(_mysql: PMYSQL; q: PAnsiChar): longint;
begin
  if @_mysql_query=nil
  then
    LoadProcAddress(@_mysql_query, 'mysql_query');
  Result := _mysql_query(_mysql, q);
end;

var
  _mysql_send_query: function (_mysql: PMYSQL; q: PAnsiChar; length: longword): longint; stdcall;

function mysql_send_query(_mysql: PMYSQL; q: PAnsiChar; length: longword): longint;
begin
  if @_mysql_send_query=nil
  then
    LoadProcAddress(@_mysql_send_query, 'mysql_send_query');
  Result := _mysql_send_query(_mysql, q, length);
end;

var
  _mysql_read_query_result: function (_mysql: PMYSQL): longint; stdcall;

function mysql_read_query_result(_mysql: PMYSQL): longint;
begin
  if @_mysql_read_query_result=nil
  then
    LoadProcAddress(@_mysql_read_query_result, 'mysql_read_query_result');
  Result := _mysql_read_query_result(_mysql);
end;

var
  _mysql_real_query: function (_mysql: PMYSQL; q: PAnsiChar; length: longword): longint; stdcall;

function mysql_real_query(_mysql: PMYSQL; q: PAnsiChar; length: longword): longint;
begin
  if @_mysql_real_query=nil
  then
    LoadProcAddress(@_mysql_real_query, 'mysql_real_query');
  Result := _mysql_real_query(_mysql, q, length);
end;

var
  _mysql_create_db: function (_mysql: PMYSQL; DB: PAnsiChar): longint; stdcall;

function mysql_create_db(_mysql: PMYSQL; DB: PAnsiChar): longint;
begin
  if @_mysql_create_db=nil
  then
    LoadProcAddress(@_mysql_create_db, 'mysql_create_db');
  Result := _mysql_create_db(_mysql, DB);
end;

var
  _mysql_drop_db: function (_mysql: PMYSQL; DB: PAnsiChar): longint; stdcall;

function mysql_drop_db(_mysql: PMYSQL; DB: PAnsiChar): longint;
begin
  if @_mysql_drop_db=nil
  then
    LoadProcAddress(@_mysql_drop_db, 'mysql_drop_db');
  Result := _mysql_drop_db(_mysql, DB);
end;

var
  _mysql_shutdown: function (_mysql: PMYSQL): longint; stdcall;

function mysql_shutdown(_mysql: PMYSQL): longint;
begin
  if @_mysql_shutdown=nil
  then
    LoadProcAddress(@_mysql_shutdown, 'mysql_shutdown');
  Result := _mysql_shutdown(_mysql);
end;

var
  _mysql_dump_debug_info: function (_mysql: PMYSQL): longint; stdcall;

function mysql_dump_debug_info(_mysql: PMYSQL): longint;
begin
  if @_mysql_dump_debug_info=nil
  then
    LoadProcAddress(@_mysql_dump_debug_info, 'mysql_dump_debug_info');
  Result := _mysql_dump_debug_info(_mysql);
end;

var
  _mysql_refresh: function (_mysql: PMYSQL; refresh_options: longword): longint; stdcall;

function mysql_refresh(_mysql: PMYSQL; refresh_options: longword): longint;
begin
  if @_mysql_refresh=nil
  then
    LoadProcAddress(@_mysql_refresh, 'mysql_refresh');
  Result := _mysql_refresh(_mysql, refresh_options);
end;

var
  _mysql_kill: function (_mysql: PMYSQL; pid: longword): longint; stdcall;

function mysql_kill(_mysql: PMYSQL; pid: longword): longint;
begin
  if @_mysql_kill=nil
  then
    LoadProcAddress(@_mysql_kill, 'mysql_kill');
  Result := _mysql_kill(_mysql, pid);
end;

var
  _mysql_ping: function (_mysql: PMYSQL): longint; stdcall;

function mysql_ping(_mysql: PMYSQL): longint;
begin
  if @_mysql_ping=nil
  then
    LoadProcAddress(@_mysql_ping, 'mysql_ping');
  Result := _mysql_ping(_mysql);
end;

var
  _mysql_stat: function (_mysql: PMYSQL): PAnsiChar; stdcall;

function mysql_stat(_mysql: PMYSQL): PAnsiChar;
begin
  if @_mysql_stat=nil
  then
    LoadProcAddress(@_mysql_stat, 'mysql_stat');
  Result := _mysql_stat(_mysql);
end;

var
  _mysql_get_server_info: function (_mysql: PMYSQL): PAnsiChar; stdcall;

function mysql_get_server_info(_mysql: PMYSQL): PAnsiChar;
begin
  if @_mysql_get_server_info=nil
  then
    LoadProcAddress(@_mysql_get_server_info, 'mysql_get_server_info');
  Result := _mysql_get_server_info(_mysql);
end;

var
  _mysql_get_client_info: function : PAnsiChar; stdcall;

function mysql_get_client_info: PAnsiChar;
begin
  if @_mysql_get_client_info=nil
  then
    LoadProcAddress(@_mysql_get_client_info, 'mysql_get_client_info');
  if @_mysql_get_client_info<>nil
  then
    Result := _mysql_get_client_info
  else
    Result := nil;
end;

var
  _mysql_get_host_info: function (_mysql: PMYSQL): PAnsiChar; stdcall;

function mysql_get_host_info(_mysql: PMYSQL): PAnsiChar;
begin
  if @_mysql_get_host_info=nil
  then
    LoadProcAddress(@_mysql_get_host_info, 'mysql_get_host_info');
  Result := _mysql_get_host_info(_mysql);
end;

var
  _mysql_get_proto_info: function (_mysql: PMYSQL): longword; stdcall;

function mysql_get_proto_info(_mysql: PMYSQL): longword;
begin
  if @_mysql_get_proto_info=nil
  then
    LoadProcAddress(@_mysql_get_proto_info, 'mysql_get_proto_info');
  Result := _mysql_get_proto_info(_mysql);
end;

var
  _mysql_list_dbs: function (_mysql: PMYSQL; wild: PAnsiChar): PMYSQL_RES; stdcall;

function mysql_list_dbs(_mysql: PMYSQL; wild: PAnsiChar): PMYSQL_RES;
begin
  if @_mysql_list_dbs=nil
  then
    LoadProcAddress(@_mysql_list_dbs, 'mysql_list_dbs');
  Result := _mysql_list_dbs(_mysql, wild);
end;

var
  _mysql_list_tables: function (_mysql: PMYSQL; wild: PAnsiChar): PMYSQL_RES; stdcall;

function mysql_list_tables(_mysql: PMYSQL; wild: PAnsiChar): PMYSQL_RES;
begin
  if @_mysql_list_tables=nil
  then
    LoadProcAddress(@_mysql_list_tables, 'mysql_list_tables');
  Result := _mysql_list_tables(_mysql, wild);
end;

var
  _mysql_list_fields: function (_mysql: PMYSQL; table, wild: PAnsiChar): PMYSQL_RES; stdcall;

function mysql_list_fields(_mysql: PMYSQL; table, wild: PAnsiChar): PMYSQL_RES;
begin
  if @_mysql_list_fields=nil
  then
    LoadProcAddress(@_mysql_list_fields, 'mysql_list_fields');
  Result := _mysql_list_fields(_mysql, table, wild);
end;

var
  _mysql_list_processes: function (_mysql: PMYSQL): PMYSQL_RES; stdcall;

function mysql_list_processes(_mysql: PMYSQL): PMYSQL_RES;
begin
  if @_mysql_list_processes=nil
  then
    LoadProcAddress(@_mysql_list_processes, 'mysql_list_processes');
  Result := _mysql_list_processes(_mysql);
end;

var
  _mysql_store_result: function (_mysql: PMYSQL): PMYSQL_RES; stdcall;

function mysql_store_result(_mysql: PMYSQL): PMYSQL_RES;
begin
  if @_mysql_store_result=nil
  then
    LoadProcAddress(@_mysql_store_result, 'mysql_store_result');
  Result := _mysql_store_result(_mysql);
end;

var
  _mysql_use_result: function (_mysql: PMYSQL): PMYSQL_RES; stdcall;

function mysql_use_result(_mysql: PMYSQL): PMYSQL_RES;
begin
  if @_mysql_use_result=nil
  then
    LoadProcAddress(@_mysql_use_result, 'mysql_use_result');
  Result := _mysql_use_result(_mysql);
end;

var
  _mysql_more_results: function (_mysql: PMYSQL): my_bool; stdcall;

function mysql_more_results(_mysql: PMYSQL): my_bool;
begin
  if @_mysql_more_results=nil
  then
    LoadProcAddress(@_mysql_more_results, 'mysql_more_results');
  Result := _mysql_more_results(_mysql);
end;

var
  _mysql_next_result: function (_mysql: PMYSQL): longint; stdcall;

function mysql_next_result(_mysql: PMYSQL): longint;
begin
  if @_mysql_next_result=nil
  then
    LoadProcAddress(@_mysql_next_result, 'mysql_next_result');
  Result := _mysql_next_result(_mysql);
end;

var
  _mysql_options: function (_mysql: PMYSQL; option: mysql_option; arg: Pointer): longint; stdcall;

function mysql_options(_mysql: PMYSQL; option: mysql_option; arg: Pointer): longint;
begin
  if @_mysql_options=nil
  then
    LoadProcAddress(@_mysql_options, 'mysql_options');
  Result := _mysql_options(_mysql, option, arg);
end;

var
  _mysql_free_result: procedure (_mysql_res: PMYSQL_RES); stdcall;

procedure mysql_free_result(_mysql_res: PMYSQL_RES);
begin
  if @_mysql_free_result=nil
  then
    LoadProcAddress(@_mysql_free_result, 'mysql_free_result');
  _mysql_free_result(_mysql_res);
end;

var
  _mysql_data_seek: procedure (_mysql_res: PMYSQL_RES; offset: my_ulonglong); stdcall;

procedure mysql_data_seek(_mysql_res: PMYSQL_RES; offset: my_ulonglong);
begin
  if @_mysql_data_seek=nil
  then
    LoadProcAddress(@_mysql_data_seek, 'mysql_data_seek');
  _mysql_data_seek(_mysql_res, offset);
end;

var
  _mysql_row_seek: function (_mysql_res: PMYSQL_RES; offset: MYSQL_ROW_OFFSET): MYSQL_ROW_OFFSET; stdcall;

function mysql_row_seek(_mysql_res: PMYSQL_RES; offset: MYSQL_ROW_OFFSET): MYSQL_ROW_OFFSET;
begin
  if @_mysql_row_seek=nil
  then
    LoadProcAddress(@_mysql_row_seek, 'mysql_row_seek');
  Result := _mysql_row_seek(_mysql_res, offset);
end;

var
  _mysql_field_seek: function (_mysql_res: PMYSQL_RES; offset: MYSQL_FIELD_OFFSET): MYSQL_FIELD_OFFSET; stdcall;

function mysql_field_seek(_mysql_res: PMYSQL_RES; offset: MYSQL_FIELD_OFFSET): MYSQL_FIELD_OFFSET;
begin
  if @_mysql_field_seek=nil
  then
    LoadProcAddress(@_mysql_field_seek, 'mysql_field_seek');
  Result := _mysql_field_seek(_mysql_res, offset);
end;

var
  _mysql_fetch_row: function (_mysql_res: PMYSQL_RES): PMYSQL_ROW; stdcall;

function mysql_fetch_row(_mysql_res: PMYSQL_RES): PMYSQL_ROW;
begin
  if @_mysql_fetch_row=nil
  then
    LoadProcAddress(@_mysql_fetch_row, 'mysql_fetch_row');
  Result := _mysql_fetch_row(_mysql_res);
end;

var
  _mysql_fetch_lengths: function (_mysql_res: PMYSQL_RES): PMYSQL_LENGTHS; stdcall;

function mysql_fetch_lengths(_mysql_res: PMYSQL_RES): PMYSQL_LENGTHS;
begin
  if @_mysql_fetch_lengths=nil
  then
    LoadProcAddress(@_mysql_fetch_lengths, 'mysql_fetch_lengths');
  Result := _mysql_fetch_lengths(_mysql_res);
end;

var
  _mysql_fetch_field: function (_mysql_res: PMYSQL_RES): PMYSQL_FIELD; stdcall;

function mysql_fetch_field(_mysql_res: PMYSQL_RES): PMYSQL_FIELD;
begin
  if @_mysql_fetch_field=nil
  then
    LoadProcAddress(@_mysql_fetch_field, 'mysql_fetch_field');
  Result := _mysql_fetch_field(_mysql_res);
end;

var
  _mysql_escape_string: function (_to: PAnsiChar; from: PAnsiChar; from_length: longword): longword; stdcall;

function mysql_escape_string(_to: PAnsiChar; from: PAnsiChar; from_length: longword): longword;
begin
  if @_mysql_escape_string=nil
  then
    LoadProcAddress(@_mysql_escape_string, 'mysql_escape_string');
  Result := _mysql_escape_string(_to, from, from_length);
end;

var
  _mysql_real_escape_string: function (_mysql: PMYSQL; _to: PAnsiChar; from: PAnsiChar; length: longword): longword; stdcall;

function mysql_real_escape_string(_mysql: PMYSQL; _to: PAnsiChar; from: PAnsiChar; length: longword): longword;
begin
  if @_mysql_real_escape_string=nil
  then
    LoadProcAddress(@_mysql_real_escape_string, 'mysql_real_escape_string');
  Result := _mysql_real_escape_string(_mysql, _to, from, length);
end;

var
  _mysql_debug: procedure (debug: PAnsiChar); stdcall;

procedure mysql_debug(debug: PAnsiChar);
begin
  if @_mysql_debug=nil
  then
    LoadProcAddress(@_mysql_debug, 'mysql_debug');
  _mysql_debug(debug);
end;

var
  _mysql_odbc_escape_string: function (_mysql: PMYSQL; _to: PAnsiChar; to_length: longword; from: PAnsiChar; from_length: longword; param: pointer; extend_buffer: extend_buffer_func): PAnsiChar; stdcall;

function mysql_odbc_escape_string(_mysql: PMYSQL; _to: PAnsiChar; to_length: longword; from: PAnsiChar; from_length: longword; param: pointer; extend_buffer: extend_buffer_func): PAnsiChar;
begin
  if @_mysql_odbc_escape_string=nil
  then
    LoadProcAddress(@_mysql_odbc_escape_string, 'mysql_odbc_escape_string');
  Result := _mysql_odbc_escape_string(_mysql, _to, to_length, from, from_length, param, extend_buffer);
end;

var
  _myodbc_remove_escape: procedure (_mysql: PMYSQL; name: PAnsiChar); stdcall;

procedure myodbc_remove_escape(_mysql: PMYSQL; name: PAnsiChar);
begin
  if @_myodbc_remove_escape=nil
  then
    LoadProcAddress(@_myodbc_remove_escape, 'myodbc_remove_escape');
  _myodbc_remove_escape(_mysql, name);
end;

var
  _mysql_thread_safe: function : longword; stdcall;

function mysql_thread_safe: longword;
begin
  if @_mysql_thread_safe=nil
  then
    LoadProcAddress(@_mysql_thread_safe, 'mysql_thread_safe');
  Result := _mysql_thread_safe;
end;

var
  _mysql_get_client_version: function : longword; stdcall;

function mysql_get_client_version: longword;
begin
  if @_mysql_get_client_version=nil
  then
    LoadProcAddress(@_mysql_get_client_version, 'mysql_get_client_version');
  Result := _mysql_get_client_version;
end;

var
  _mysql_get_server_version: function (_mysql: PMYSQL): longword; stdcall;

function mysql_get_server_version(_mysql: PMYSQL): longword;
begin
  if @_mysql_get_server_version=nil
  then
    LoadProcAddress(@_mysql_get_server_version, 'mysql_get_server_version');
  Result := _mysql_get_server_version(_mysql);
end;

var
  _mysql_set_character_set: function (_mysql: PMYSQL; csname: PAnsiChar): longint; stdcall;

function mysql_set_character_set(_mysql: PMYSQL; csname: PAnsiChar): longint;
begin
  if @_mysql_set_character_set=nil
  then
    LoadProcAddress(@_mysql_set_character_set, 'mysql_set_character_set');
  Result := _mysql_set_character_set(_mysql, csname);
end;

var
  _mysql_autocommit: function (_mysql: PMYSQL; mode: my_bool ): my_bool; stdcall;

function mysql_autocommit(_mysql: PMYSQL; mode: my_bool ): my_bool;
begin
  if @_mysql_autocommit=nil
  then
    LoadProcAddress(@_mysql_autocommit, 'mysql_autocommit');
  Result := _mysql_autocommit(_mysql, mode);
end;

var
  _mysql_commit: function (_mysql: PMYSQL): my_bool; stdcall;

function mysql_commit(_mysql: PMYSQL): my_bool;
begin
  if @_mysql_commit=nil
  then
    LoadProcAddress(@_mysql_commit, 'mysql_commit');
  Result := _mysql_commit(_mysql);
end;

var
  _mysql_rollback: function (_mysql: PMYSQL): my_bool; stdcall;

function mysql_rollback(_mysql: PMYSQL): my_bool;
begin
  if @_mysql_rollback=nil
  then
    LoadProcAddress(@_mysql_rollback, 'mysql_rollback');
  Result := _mysql_rollback(_mysql);
end;

var
  _mysql_set_server_option: function (_mysql: PMYSQL; option: enum_mysql_set_option): longint; stdcall;

function mysql_set_server_option(_mysql: PMYSQL; option: enum_mysql_set_option): longint;
begin
  if @_mysql_set_server_option=nil
  then
    LoadProcAddress(@_mysql_set_server_option, 'mysql_set_server_option');
  Result := _mysql_set_server_option(_mysql, option);
end;

var
  _mysql_sqlstate: function (_mysql: PMYSQL): PAnsiChar; stdcall;

function mysql_sqlstate(_mysql: PMYSQL): PAnsiChar;
begin
  if @_mysql_sqlstate=nil
  then
    LoadProcAddress(@_mysql_sqlstate, 'mysql_sqlstate');
  Result := _mysql_sqlstate(_mysql);
end;

var
  _mysql_warning_count: function (_mysql: PMYSQL): longword; stdcall;

function mysql_warning_count(_mysql: PMYSQL): longword;
begin
  if @_mysql_warning_count=nil
  then
    LoadProcAddress(@_mysql_warning_count, 'mysql_warning_count');
  Result := _mysql_warning_count(_mysql);
end;

var
  _mysql_server_init: function (argc: Integer; argv, groups: PPAnsiChar): Integer; stdcall;

function mysql_server_init(argc: Integer; argv, groups: PPAnsiChar): Integer;
begin
  if @_mysql_server_init=nil
  then
    LoadProcAddress(@_mysql_server_init, 'mysql_server_init');
  Result := _mysql_server_init(argc, argv, groups);
end;

var
  _mysql_server_end: procedure; stdcall;

procedure mysql_server_end;
begin
  if @_mysql_server_end=nil
  then
    LoadProcAddress(@_mysql_server_end, 'mysql_server_end');
  _mysql_server_end;
end;

var
  _mysql_thread_init: function: my_bool; stdcall;

function mysql_thread_init: my_bool;
begin
  if @_mysql_thread_init=nil
  then
    LoadProcAddress(@_mysql_thread_init, 'mysql_thread_init');
  Result := _mysql_thread_init;
end;

var
  _mysql_thread_end: procedure; stdcall;

procedure mysql_thread_end;
begin
  if @_mysql_thread_end=nil
  then
    LoadProcAddress(@_mysql_thread_end, 'mysql_thread_end');
  _mysql_thread_end;
end;

var
  _mysql_stmt_affected_rows: function (stmt: PMYSQL_STMT): my_ulonglong; stdcall;

function mysql_stmt_affected_rows(stmt: PMYSQL_STMT): my_ulonglong;
begin
  if @_mysql_stmt_affected_rows=nil
  then
    LoadProcAddress(@_mysql_stmt_affected_rows, 'mysql_stmt_affected_rows');
  Result := _mysql_stmt_affected_rows(stmt);
end;

var
  _mysql_stmt_attr_get: function (stmt: PMYSQL_STMT; option: enum_stmt_attr_type; var arg): Integer; stdcall;

function mysql_stmt_attr_get(stmt: PMYSQL_STMT; option: enum_stmt_attr_type; var arg): Integer;
begin
  if @_mysql_stmt_attr_get=nil
  then
    LoadProcAddress(@_mysql_stmt_attr_get, 'mysql_stmt_attr_get');
  Result := _mysql_stmt_attr_get(stmt, option, arg);
end;

var
  _mysql_stmt_attr_set: function (stmt: PMYSQL_STMT; option: enum_stmt_attr_type; const arg): Integer; stdcall;

function mysql_stmt_attr_set(stmt: PMYSQL_STMT; option: enum_stmt_attr_type; const arg): Integer;
begin
  if @_mysql_stmt_attr_set=nil
  then
    LoadProcAddress(@_mysql_stmt_attr_set, 'mysql_stmt_attr_set');
  Result := _mysql_stmt_attr_set(stmt, option, arg);
end;

var
  _mysql_stmt_bind_param: function (stmt: PMYSQL_STMT; bind: PMYSQL_BIND): my_bool; stdcall;

function mysql_stmt_bind_param(stmt: PMYSQL_STMT; bind: PMYSQL_BIND): my_bool;
begin
  if @_mysql_stmt_bind_param=nil
  then
    LoadProcAddress(@_mysql_stmt_bind_param, 'mysql_stmt_bind_param');
  Result := _mysql_stmt_bind_param(stmt, bind);
end;

var
  _mysql_stmt_bind_result: function (stmt: PMYSQL_STMT; bind: PMYSQL_BIND): my_bool; stdcall;

function mysql_stmt_bind_result(stmt: PMYSQL_STMT; bind: PMYSQL_BIND): my_bool;
begin
  if @_mysql_stmt_bind_result=nil
  then
    LoadProcAddress(@_mysql_stmt_bind_result, 'mysql_stmt_bind_result');
  Result := _mysql_stmt_bind_result(stmt, bind);
end;

var
  _mysql_stmt_close: function (stmt: PMYSQL_STMT): my_bool; stdcall;

function mysql_stmt_close(stmt: PMYSQL_STMT): my_bool;
begin
  if @_mysql_stmt_close=nil
  then
    LoadProcAddress(@_mysql_stmt_close, 'mysql_stmt_close');
  Result := _mysql_stmt_close(stmt);
end;

var
  _mysql_stmt_data_seek: procedure (stmt: PMYSQL_STMT; offset: my_ulonglong); stdcall;

procedure mysql_stmt_data_seek(stmt: PMYSQL_STMT; offset: my_ulonglong);
begin
  if @_mysql_stmt_data_seek=nil
  then
    LoadProcAddress(@_mysql_stmt_data_seek, 'mysql_stmt_data_seek');
  _mysql_stmt_data_seek(stmt, offset);
end;

var
  _mysql_stmt_errno: function (stmt: PMYSQL_STMT): DWORD; stdcall;

function mysql_stmt_errno(stmt: PMYSQL_STMT): DWORD;
begin
  if @_mysql_stmt_errno=nil
  then
    LoadProcAddress(@_mysql_stmt_errno, 'mysql_stmt_errno');
  Result := _mysql_stmt_errno(stmt);
end;

var
  _mysql_stmt_error: function (stmt: PMYSQL_STMT): PAnsiChar; stdcall;

function mysql_stmt_error(stmt: PMYSQL_STMT): PAnsiChar;
begin
  if @_mysql_stmt_error=nil
  then
    LoadProcAddress(@_mysql_stmt_error, 'mysql_stmt_error');
  Result := _mysql_stmt_error(stmt);
end;

var
  _mysql_stmt_execute: function (stmt: PMYSQL_STMT): Integer; stdcall;

function mysql_stmt_execute(stmt: PMYSQL_STMT): Integer;
begin
  if @_mysql_stmt_execute=nil
  then
    LoadProcAddress(@_mysql_stmt_execute, 'mysql_stmt_execute');
  Result := _mysql_stmt_execute(stmt);
end;

var
  _mysql_stmt_fetch: function (stmt: PMYSQL_STMT): Integer; stdcall;

function mysql_stmt_fetch(stmt: PMYSQL_STMT): Integer;
begin
  if @_mysql_stmt_fetch=nil
  then
    LoadProcAddress(@_mysql_stmt_fetch, 'mysql_stmt_fetch');
  Result := _mysql_stmt_fetch(stmt);
end;

var
  _mysql_stmt_fetch_column: function (stmt: PMYSQL_STMT; bind: PMYSQL_BIND; column: DWORD; offset: DWORD): Integer; stdcall;

function mysql_stmt_fetch_column(stmt: PMYSQL_STMT; bind: PMYSQL_BIND; column: DWORD; offset: DWORD): Integer;
begin
  if @_mysql_stmt_fetch_column=nil
  then
    LoadProcAddress(@_mysql_stmt_fetch_column, 'mysql_stmt_fetch_column');
  Result := _mysql_stmt_fetch_column(stmt, bind, column, offset);
end;

var
  _mysql_stmt_field_count: function (stmt: PMYSQL_STMT): DWORD; stdcall;

function mysql_stmt_field_count(stmt: PMYSQL_STMT): DWORD;
begin
  if @_mysql_stmt_field_count=nil
  then
    LoadProcAddress(@_mysql_stmt_field_count, 'mysql_stmt_field_count');
  Result := _mysql_stmt_field_count(stmt);
end;

var
  _mysql_stmt_free_result: function (stmt: PMYSQL_STMT): my_bool; stdcall;

function mysql_stmt_free_result(stmt: PMYSQL_STMT): my_bool;
begin
  if @_mysql_stmt_free_result=nil
  then
    LoadProcAddress(@_mysql_stmt_free_result, 'mysql_stmt_free_result');
  Result := _mysql_stmt_free_result(stmt);
end;

var
  _mysql_stmt_init: function (_mysql: PMYSQL): PMYSQL_STMT; stdcall;

function mysql_stmt_init(_mysql: PMYSQL): PMYSQL_STMT;
begin
  if @_mysql_stmt_init=nil
  then
    LoadProcAddress(@_mysql_stmt_init, 'mysql_stmt_init');
  Result := _mysql_stmt_init(_mysql);
end;

var
  _mysql_stmt_insert_id: function (stmt: PMYSQL_STMT): my_ulonglong; stdcall;

function mysql_stmt_insert_id(stmt: PMYSQL_STMT): my_ulonglong;
begin
  if @_mysql_stmt_insert_id=nil
  then
    LoadProcAddress(@_mysql_stmt_insert_id, 'mysql_stmt_insert_id');
  Result := _mysql_stmt_insert_id(stmt);
end;

var
  _mysql_stmt_num_rows: function (stmt: PMYSQL_STMT): my_ulonglong; stdcall;

function mysql_stmt_num_rows(stmt: PMYSQL_STMT): my_ulonglong;
begin
  if @_mysql_stmt_num_rows=nil
  then
    LoadProcAddress(@_mysql_stmt_num_rows, 'mysql_stmt_num_rows');
  Result := _mysql_stmt_num_rows(stmt);
end;

var
  _mysql_stmt_param_count: function (stmt: PMYSQL_STMT): DWORD; stdcall;

function mysql_stmt_param_count(stmt: PMYSQL_STMT): DWORD;
begin
  if @_mysql_stmt_param_count=nil
  then
    LoadProcAddress(@_mysql_stmt_param_count, 'mysql_stmt_param_count');
  Result := _mysql_stmt_param_count(stmt);
end;

var
  _mysql_stmt_param_metadata: function (stmt: PMYSQL_STMT): PMYSQL_RES; stdcall;

function mysql_stmt_param_metadata(stmt: PMYSQL_STMT): PMYSQL_RES;
begin
  if @_mysql_stmt_param_metadata=nil
  then
    LoadProcAddress(@_mysql_stmt_param_metadata, 'mysql_stmt_param_metadata');
  Result := _mysql_stmt_param_metadata(stmt);
end;

var
  _mysql_stmt_prepare: function (stmt: PMYSQL_STMT; query: PAnsiChar; length: DWORD): Integer; stdcall;

function mysql_stmt_prepare(stmt: PMYSQL_STMT; query: PAnsiChar; length: DWORD): Integer;
begin
  if @_mysql_stmt_prepare=nil
  then
    LoadProcAddress(@_mysql_stmt_prepare, 'mysql_stmt_prepare');
  Result := _mysql_stmt_prepare(stmt, query, length);
end;

var
  _mysql_stmt_reset: function (stmt: PMYSQL_STMT): my_bool; stdcall;

function mysql_stmt_reset(stmt: PMYSQL_STMT): my_bool;
begin
  if @_mysql_stmt_reset=nil
  then
    LoadProcAddress(@_mysql_stmt_reset, 'mysql_stmt_reset');
  Result := _mysql_stmt_reset(stmt);
end;

var
  _mysql_stmt_result_metadata: function (stmt: PMYSQL_STMT): PMYSQL_RES; stdcall;

function mysql_stmt_result_metadata(stmt: PMYSQL_STMT): PMYSQL_RES;
begin
  if @_mysql_stmt_result_metadata=nil
  then
    LoadProcAddress(@_mysql_stmt_result_metadata, 'mysql_stmt_result_metadata');
  Result := _mysql_stmt_result_metadata(stmt);
end;

var
  _mysql_stmt_row_seek: function (stmt: PMYSQL_STMT; offset: MYSQL_ROW_OFFSET): MYSQL_ROW_OFFSET; stdcall;

function mysql_stmt_row_seek(stmt: PMYSQL_STMT; offset: MYSQL_ROW_OFFSET): MYSQL_ROW_OFFSET;
begin
  if @_mysql_stmt_row_seek=nil
  then
    LoadProcAddress(@_mysql_stmt_row_seek, 'mysql_stmt_row_seek');
  Result := _mysql_stmt_row_seek(stmt, offset);
end;

var
  _mysql_stmt_row_tell: function (stmt: PMYSQL_STMT): MYSQL_ROW_OFFSET; stdcall;

function mysql_stmt_row_tell(stmt: PMYSQL_STMT): MYSQL_ROW_OFFSET;
begin
  if @_mysql_stmt_row_tell=nil
  then
    LoadProcAddress(@_mysql_stmt_row_tell, 'mysql_stmt_row_tell');
  Result := _mysql_stmt_row_tell(stmt);
end;

var
  _mysql_stmt_send_long_data: function (stmt: PMYSQL_STMT; parameter_number: DWORD; data: PAnsiChar; length: DWORD): my_bool; stdcall;

function mysql_stmt_send_long_data(stmt: PMYSQL_STMT; parameter_number: DWORD; data: PAnsiChar; length: DWORD): my_bool;
begin
  if @_mysql_stmt_send_long_data=nil
  then
    LoadProcAddress(@_mysql_stmt_send_long_data, 'mysql_stmt_send_long_data');
  Result := _mysql_stmt_send_long_data(stmt, parameter_number, data, length);
end;

var
  _mysql_stmt_sqlstate: function (stmt: PMYSQL_STMT): PAnsiChar; stdcall;

function mysql_stmt_sqlstate(stmt: PMYSQL_STMT): PAnsiChar;
begin
  if @_mysql_stmt_sqlstate=nil
  then
    LoadProcAddress(@_mysql_stmt_sqlstate, 'mysql_stmt_sqlstate');
  Result := _mysql_stmt_sqlstate(stmt);
end;

var
  _mysql_stmt_store_result: function (stmt: PMYSQL_STMT): Integer; stdcall;

function mysql_stmt_store_result(stmt: PMYSQL_STMT): Integer;
begin
  if @_mysql_stmt_store_result=nil
  then
    LoadProcAddress(@_mysql_stmt_store_result, 'mysql_stmt_store_result');
  Result := _mysql_stmt_store_result(stmt);
end;

{$WARNINGS ON}
{.$WARN NO_RETVAL ON}

//Create initialized memory block for Bindings
function mysql_bind_init(Count: Integer): PMYSQL_BIND;
var
  Size: Integer;
begin
  Result := niL;
  if Count>0
  then begin
    if internal_libmysql_ClientVersion>=50100
    then
      Size := SizeOf(TMYSQL_BIND501)
    else
    if internal_libmysql_ClientVersion>=50000
    then
      Size := SizeOf(TMYSQL_BIND500)
    else
    if internal_libmysql_ClientVersion>=40100
    then
      Size := SizeOf(TMYSQL_BIND401)
    else
      exit;
    Result := AllocMem(Count*Size);
  end;
end;

//Copy mySQL_Bind to bind record array
function mysql_bind_copy_bind(bind: PMYSQL_BIND; Index: Integer; const mySQL_Bind: TMYSQL_BIND): Boolean;
begin
  Result := False;
  if bind<>nil
  then begin
    if internal_libmysql_ClientVersion>=50100
    then begin
      inc(PMYSQL_BIND501(bind), Index);
      move(mySQL_Bind, bind^, SizeOf(TMYSQL_BIND501));
      Result := true;
    end
    else
    if internal_libmysql_ClientVersion>=50000
    then begin
      inc(PMYSQL_BIND500(bind), Index);
      TMYSQL_BIND500(bind^).length := mySQL_Bind.length;
      TMYSQL_BIND500(bind^).is_null := mySQL_Bind.is_null;
      TMYSQL_BIND500(bind^).buffer := mySQL_Bind.buffer;
      TMYSQL_BIND500(bind^).error := mySQL_Bind.error;
      TMYSQL_BIND500(bind^).buffer_type := mySQL_Bind.buffer_type;
      TMYSQL_BIND500(bind^).buffer_length := mySQL_Bind.buffer_length;
      TMYSQL_BIND500(bind^).row_ptr := mySQL_Bind.row_ptr;
      TMYSQL_BIND500(bind^).offset := mySQL_Bind.offset;
      TMYSQL_BIND500(bind^).length_value := mySQL_Bind.length_value;
      TMYSQL_BIND500(bind^).param_number := mySQL_Bind.param_number;
      TMYSQL_BIND500(bind^).pack_length := mySQL_Bind.pack_length;
      TMYSQL_BIND500(bind^).error_value := mySQL_Bind.error_value;
      TMYSQL_BIND500(bind^).is_unsigned := mySQL_Bind.is_unsigned;
      TMYSQL_BIND500(bind^).long_data_used := mySQL_Bind.long_data_used;
      TMYSQL_BIND500(bind^).is_null_value := mySQL_Bind.is_null_value;
      TMYSQL_BIND500(bind^).store_param_func := mySQL_Bind.store_param_func;
      TMYSQL_BIND500(bind^).fetch_result := mySQL_Bind.fetch_result;
      TMYSQL_BIND500(bind^).skip_result := mySQL_Bind.skip_result;
      Result := true;
    end
    else
    if internal_libmysql_ClientVersion>=40100
    then begin
      inc(PMYSQL_BIND401(bind), Index);
      TMYSQL_BIND401(bind^).length := mySQL_Bind.length;
      TMYSQL_BIND401(bind^).is_null := mySQL_Bind.is_null;
      TMYSQL_BIND401(bind^).buffer := mySQL_Bind.buffer;
      TMYSQL_BIND401(bind^).buffer_type := mySQL_Bind.buffer_type;
      TMYSQL_BIND401(bind^).buffer_length := mySQL_Bind.buffer_length;
      TMYSQL_BIND401(bind^).row_ptr := mySQL_Bind.row_ptr;
      TMYSQL_BIND401(bind^).offset := mySQL_Bind.offset;
      TMYSQL_BIND401(bind^).length_value := mySQL_Bind.length_value;
      TMYSQL_BIND401(bind^).param_number := mySQL_Bind.param_number;
      TMYSQL_BIND401(bind^).pack_length := mySQL_Bind.pack_length;
      TMYSQL_BIND401(bind^).is_unsigned := mySQL_Bind.is_unsigned;
      TMYSQL_BIND401(bind^).long_data_used := mySQL_Bind.long_data_used;
      TMYSQL_BIND401(bind^).is_null_value := mySQL_Bind.is_null_value;
      TMYSQL_BIND401(bind^).store_param_func := mySQL_Bind.store_param_func;
      TMYSQL_BIND401(bind^).fetch_result := mySQL_Bind.fetch_result;
      TMYSQL_BIND401(bind^).skip_result := mySQL_Bind.skip_result;
      Result := true;
    end;
  end;
end;

//Copy params bind record array
function mysql_bind_set_param(bind: PMYSQL_BIND; Index: Integer;
                              buffer_type: enum_field_types;
                              buffer: Pointer;         // buffer to get/put data
                              buffer_length: DWORD;
                              length: PDWORD;          // output length pointer
                              is_null: Pmy_bool        // Pointer to null indicator
                              ): Boolean;
begin
  Result := False;
  if bind<>nil
  then begin
    if internal_libmysql_ClientVersion>=50100
    then begin
      inc(PMYSQL_BIND501(bind), Index);
      TMYSQL_BIND501(bind^).length := length;
      TMYSQL_BIND501(bind^).is_null := is_null;
      TMYSQL_BIND501(bind^).buffer := buffer;
      TMYSQL_BIND501(bind^).buffer_length := buffer_length;
      TMYSQL_BIND501(bind^).buffer_type := buffer_type;
      Result := true;
    end
    else
    if internal_libmysql_ClientVersion>=50000
    then begin
      inc(PMYSQL_BIND500(bind), Index);
      TMYSQL_BIND500(bind^).length := length;
      TMYSQL_BIND500(bind^).is_null := is_null;
      TMYSQL_BIND500(bind^).buffer := buffer;
      TMYSQL_BIND500(bind^).buffer_length := buffer_length;
      TMYSQL_BIND500(bind^).buffer_type := buffer_type;
      Result := true;
    end
    else
    if internal_libmysql_ClientVersion>=40100
    then begin
      inc(PMYSQL_BIND401(bind), Index);
      TMYSQL_BIND401(bind^).length := length;
      TMYSQL_BIND401(bind^).is_null := is_null;
      TMYSQL_BIND401(bind^).buffer := buffer;
      TMYSQL_BIND401(bind^).buffer_length := buffer_length;
      TMYSQL_BIND401(bind^).buffer_type := buffer_type;
      Result := true;
    end;
  end;
end;

{$IFDEF CPUX64}
function MySql_StrLen(const Str: PAnsiChar): Cardinal; inline;
begin
  {$ifdef FPC}
  Result := StrLen(Str)
  {$else}
  Result := Length(Str);
  {$endif}
end;
{$ELSE}
function MySql_StrLen(const Str: PAnsiChar): Cardinal;
begin
  if Str<>nil
  then
    {$if defined(FPC) or (CompilerVersion<20.00))}
    Result := StrLen(Str)
    {$else}
    Result := Length(Str)
    {$ifend}
  else
    Result := 0;
end;
{$ENDIF}

{$if not defined(FPC) and (CompilerVersion<20.00))}
type
  NativeInt = type Integer;     //Override NativeInt -> Wrong size of NativeInt in Delphi2007
{$IFEND}

{$IFDEF Unicode}
function EscapeString(const Str: String): String;
var
  L: Integer;
  src, dest: PChar;
  ch: Char;
begin
  L := Length(Str);
  SetLength(Result, Length(Str)*2);
  src := Pointer(Str); dest := Pointer(Result);
  while L>0 do
  begin
    ch := src^;
    if (ch='\') or (ch='"')
    then begin
      dest^ := '\'; inc(dest);
    end
    else
    if ch=#26
    then begin
      dest^ := '\'; inc(dest); ch := 'Z';
    end
    else
    if ch=#13
    then begin
      dest^ := '\'; inc(dest); ch := 'r';
    end
    else
    if ch=#10
    then begin
      dest^ := '\'; inc(dest); ch := 'n';
    end;
    dest^ := ch; inc(dest);
    inc(src); dec(L);
  end;
  L := (NativeInt(Dest)-NativeInt(Result)) shr 1;
  SetLength(Result, L);
end;
{$ENDIF}

function EscapeString(const Str: AnsiString): AnsiString;
var
  L, d: Integer;
  src, dest: PAnsiChar;
  ch: AnsiChar;
  {$IFDEF Unicode}
  CP: Word;
  {$ENDIF}
begin
  {$IFDEF Unicode}
  CP := DefaultSystemCodePage;
  {$ENDIF}
  L := Length(Str);
  SetLength(Result, Length(Str)*2);
  src := Pointer(Str); dest := Pointer(Result);
  while L>0 do
  begin
    if src^=#0
    then begin
      dest^ := #0; inc(dest); inc(src); dec(L);
    end
    else begin
      {$IFDEF Unicode}
      d := NativeInt(CharNextExA(CP, src, 0))-NativeInt(src);
      {$ELSE}
      {$WARNINGS OFF}{$HINTS OFF}
      d := NativeInt(CharNext(src))-NativeInt(src);
      {$WARNINGS ON}{$HINTS ON}
      {$ENDIF}
      if d>1
      then begin
        dec(L, d);
        while d>0 do
        begin
          dest^ := src^;
          inc(dest); inc(src);
          dec(d);
        end;
      end
      else begin
        ch := src^;
        if (ch='\') or (ch='"')
        then begin
          dest^ := '\'; inc(dest);
        end
        else
        if ch=#26
        then begin
          dest^ := '\'; inc(dest); ch := 'Z';
        end
        else
        if ch=#13
        then begin
          dest^ := '\'; inc(dest); ch := 'r';
        end
        else
        if ch=#10
        then begin
          dest^ := '\'; inc(dest); ch := 'n';
        end;
        dest^ := ch; inc(dest);
        inc(src); dec(L);
      end;
    end
  end;
  {$WARNINGS OFF}{$HINTS OFF}
  L := NativeInt(dest)-NativeInt(Result);
  {$WARNINGS ON}{$HINTS ON}
  SetLength(Result, L);
end;

{$IFDEF Unicode}
function QuoteString(const Str: String): String;
begin
  Result := '"' + EscapeString(Str) + '"';
end;
{$ENDIF}

function QuoteString(const Str: AnsiString): AnsiString;
begin
  Result := '"' + EscapeString(Str) + '"';
end;

{$IFDEF Unicode}
function QuoteName(const Str: String): String;
const
  BacktickChar=#96; //'`' $60
begin
  Result := BacktickChar + Str + BacktickChar;
end;
{$ENDIF}

function QuoteName(const Str: AnsiString): AnsiString;
const
  BacktickChar=#96; //'`' $60
begin
  Result := BacktickChar + Str + BacktickChar;
end;

{ Additional to normal escaped Characters this also escape "%" and "_". Use
  it, if you want to search for wildcards in LIKE
}
{$IFDEF Unicode}
function EscapeForLike(const Str: String): String;
{   Note: To search for '\', specify it as '\\\\'
    (the backslashes are stripped once by the parser
     and another time when the pattern match is done, leaving a
     single backslash to be matched). To search for '%' or '_',
     specify it as '\%' or '\_'.
}
var
  L: Integer;
  src, dest: PChar;
  ch: Char;
begin
  L := Length(Str);
  SetLength(Result, Length(Str)*4);
  src := Pointer(Str); dest := Pointer(Result);
  while L>0 do
  begin
    ch := src^;
    if ch='\'
    then begin
      dest^ := ch; inc(dest);
      dest^ := ch; inc(dest);
      dest^ := ch; inc(dest);
    end
    else
    if (ch='"') or (ch='%') or (ch='_')
    then begin
      dest^ := '\'; inc(dest);
    end
    else
    if ch=#26
    then begin
      dest^ := '\'; inc(dest);
      ch := 'Z';
    end
    else
    if ch=#13
    then begin
      dest^ := '\'; inc(dest);
      ch := 'r';
    end
    else
    if ch=#10
    then begin
      dest^ := '\'; inc(dest);
      ch := 'n';
    end;
    dest^ := ch; inc(dest);
    inc(src); dec(L);
  end;
  L := (NativeInt(dest)-NativeInt(Result)) shr 1;
  SetLength(Result, L);
end;
{$ENDIF}

function EscapeForLike(const Str: AnsiString): AnsiString;
var
  L, d: Integer;
  src, dest: PAnsiChar;
  ch: AnsiChar;
  {$IFDEF Unicode}
  CP: Word;
  {$ENDIF}
begin
  {$IFDEF Unicode}
  CP := DefaultSystemCodePage;
  {$ENDIF}
  L := Length(Str);
  SetLength(Result, Length(Str)*4);
  src := Pointer(Str); dest := Pointer(Result);
  while L>0 do
  begin
    if src^=#0
    then begin
      dest^ := #0; inc(dest); inc(src); dec(L);
    end
    else begin
      {$IFDEF Unicode}
      d := NativeInt(CharNextExA(CP, src, 0))-NativeInt(src);
      {$ELSE}
      {$WARNINGS OFF}{$HINTS OFF}
      d := NativeInt(CharNext(src))-NativeInt(src);
      {$WARNINGS ON}{$HINTS ON}
      {$ENDIF}
      if d>1
      then begin
        dec(L, d);
        while d>0 do
        begin
          dest^ := src^;
          inc(dest); inc(src);
          dec(d);
        end;
      end
      else begin
        ch := src^;
        if ch='\'
        then begin
          dest^ := ch; inc(dest);
          dest^ := ch; inc(dest);
          dest^ := ch; inc(dest);
        end
        else
        if (ch='"') or (ch='%') or (ch='_')
        then begin
          dest^ := '\'; inc(dest);
        end
        else
        if ch=#26
        then begin
          dest^ := '\'; inc(dest);
          ch := 'Z';
        end
        else
        if ch=#13
        then begin
          dest^ := '\'; inc(dest);
          ch := 'r';
        end
        else
        if ch=#10
        then begin
          dest^ := '\'; inc(dest);
          ch := 'n';
        end;
        dest^ := ch; inc(dest);
        inc(src); dec(L);
      end;
    end
  end;
  {$WARNINGS OFF}{$HINTS OFF}
  L := NativeInt(dest)-NativeInt(Result);
  {$WARNINGS ON}{$HINTS ON}
  SetLength(Result, L);
end;

function FullFieldname(const table, field: String): String;
begin
  Result := QuoteName(table) + '.' + QuoteName(field);
end;

function libmysql_load(name: PChar): Tlibmysql_status;
  procedure assign_proc(var proc: FARPROC; name: PAnsiChar);
  begin
    proc := GetProcAddress(libmysql_handle, name);
    if proc = nil
    then
      internal_libmysql_status := LIBMYSQL_INCOMPATIBLE
    else
      PushProc(@proc);
  end;
begin
  libmysql_free;
  if name = nil then name := 'libmysql.dll';
  libmysql_handle := LoadLibrary(name);
  if libmysql_handle = 0
  then
    internal_libmysql_status := LIBMYSQL_MISSING
  else begin
    internal_libmysql_status := LIBMYSQL_READY;
    assign_proc(@_mysql_num_rows, 'mysql_num_rows');
    assign_proc(@_mysql_num_fields, 'mysql_num_fields');
    assign_proc(@_mysql_eof, 'mysql_eof');
    assign_proc(@_mysql_fetch_field_direct, 'mysql_fetch_field_direct');
    assign_proc(@_mysql_fetch_fields, 'mysql_fetch_fields');
    assign_proc(@_mysql_row_tell, 'mysql_row_tell');
    assign_proc(@_mysql_field_tell, 'mysql_field_tell');
    assign_proc(@_mysql_field_count, 'mysql_field_count');
    assign_proc(@_mysql_affected_rows, 'mysql_affected_rows');
    assign_proc(@_mysql_insert_id, 'mysql_insert_id');
    assign_proc(@_mysql_errno, 'mysql_errno');
    assign_proc(@_mysql_error, 'mysql_error');
    assign_proc(@_mysql_info, 'mysql_info');
    assign_proc(@_mysql_thread_id, 'mysql_thread_id');
    assign_proc(@_mysql_character_set_name, 'mysql_character_set_name');
    assign_proc(@_mysql_init, 'mysql_init');
    {$IFDEF HAVE_OPENSSL}
    assign_proc(@_mysql_ssl_set, 'mysql_ssl_set');
    assign_proc(@_mysql_ssl_cipher, 'mysql_ssl_cipher');
    assign_proc(@_mysql_ssl_clear, 'mysql_ssl_clear');
    {$ENDIF} // HAVE_OPENSSL
    {$IFDEF USE_DEPRECATED}
    assign_proc(@_mysql_connect, 'mysql_connect');          //Old Client 3.23
    {$ENDIF}
    assign_proc(@_mysql_change_user, 'mysql_change_user');
    assign_proc(@_mysql_real_connect, 'mysql_real_connect');
    assign_proc(@_mysql_close, 'mysql_close');
    assign_proc(@_mysql_select_db, 'mysql_select_db');
    assign_proc(@_mysql_query, 'mysql_query');
    assign_proc(@_mysql_send_query, 'mysql_send_query');
    assign_proc(@_mysql_read_query_result, 'mysql_read_query_result');
    assign_proc(@_mysql_real_query, 'mysql_real_query');
    {$IFDEF USE_DEPRECATED}
    assign_proc(@_mysql_create_db, 'mysql_create_db');      //Old Client 3.23
    assign_proc(@_mysql_drop_db, 'mysql_drop_db');          //Old Client 3.23
    {$ENDIF}
    assign_proc(@_mysql_shutdown, 'mysql_shutdown');
    assign_proc(@_mysql_dump_debug_info, 'mysql_dump_debug_info');
    assign_proc(@_mysql_refresh, 'mysql_refresh');
    assign_proc(@_mysql_kill, 'mysql_kill');
    assign_proc(@_mysql_ping, 'mysql_ping');
    assign_proc(@_mysql_stat, 'mysql_stat');
    assign_proc(@_mysql_get_server_info, 'mysql_get_server_info');
    assign_proc(@_mysql_get_client_info, 'mysql_get_client_info');
    assign_proc(@_mysql_get_host_info, 'mysql_get_host_info');
    assign_proc(@_mysql_get_proto_info, 'mysql_get_proto_info');
    assign_proc(@_mysql_list_dbs, 'mysql_list_dbs');
    assign_proc(@_mysql_list_tables, 'mysql_list_tables');
    assign_proc(@_mysql_list_fields, 'mysql_list_fields');
    assign_proc(@_mysql_list_processes, 'mysql_list_processes');
    assign_proc(@_mysql_store_result, 'mysql_store_result');
    assign_proc(@_mysql_use_result, 'mysql_use_result');
    assign_proc(@_mysql_options, 'mysql_options');
    assign_proc(@_mysql_free_result, 'mysql_free_result');
    assign_proc(@_mysql_data_seek, 'mysql_data_seek');
    assign_proc(@_mysql_row_seek, 'mysql_row_seek');
    assign_proc(@_mysql_field_seek, 'mysql_field_seek');
    assign_proc(@_mysql_fetch_row, 'mysql_fetch_row');
    assign_proc(@_mysql_fetch_lengths, 'mysql_fetch_lengths');
    assign_proc(@_mysql_fetch_field, 'mysql_fetch_field');
    assign_proc(@_mysql_escape_string, 'mysql_escape_string');
    assign_proc(@_mysql_real_escape_string, 'mysql_real_escape_string');
    assign_proc(@_mysql_debug, 'mysql_debug');
    {$IFDEF USE_DEPRECATED}
    assign_proc(@_mysql_odbc_escape_string, 'mysql_odbc_escape_string'); //Removed from libmysql 5.0.54
    assign_proc(@_myodbc_remove_escape, 'myodbc_remove_escape');         //Removed - not supported as core-function
    {$ENDIF}
    assign_proc(@_mysql_thread_safe, 'mysql_thread_safe');
    _mysql_get_client_version := GetProcAddress(libmysql_handle, 'mysql_get_client_version');
    if (@_mysql_get_client_version=nil)
    then
      @_mysql_get_client_version := @libmysql_ClientVersion_substitute;
    PushProc(ADDR(@_mysql_get_client_version));
    internal_libmysql_ClientVersion := mysql_get_client_version;
    _mysql_get_server_version := GetProcAddress(libmysql_handle, 'mysql_get_server_version');
    if (@_mysql_get_server_version=nil)
    then
      @_mysql_get_server_version := @libmysql_ServerVersion_substitute;
    PushProc(ADDR(@_mysql_get_server_version));
    if internal_libmysql_ClientVersion>=mysql_not_compatible_version
    then
      internal_libmysql_status := LIBMYSQL_INCOMPATIBLE;
  end;
  Result := internal_libmysql_status;
end;

{ This kind of dynamic loading give the linker the chance to kick out all functions
  never used by the application. Furthermore if a function is not exposed by the
  library, but not needed by the application, it is ignored - same as it is done by
  static linking. If you use the mysql-library in more than one thread, it is a good
  idea to call this in the mainthread.
}
procedure libmysql_fast_load(name: PChar);
var
  err: DWORD;
begin
  libmysql_free;
  if name = nil then name := 'libmysql.dll';
  libmysql_handle := LoadLibrary(name);
  if libmysql_handle = 0
  then begin
    internal_libmysql_status := LIBMYSQL_MISSING;
    err := GetLastError;
    if err=ERROR_MOD_NOT_FOUND
    then
      raise Exception.CreateFmt(ELibraryNotFound, [String(name)])
    else
      raise Exception.CreateFmt('%s - %s', [SysErrorMessage(err), String(name)]);
  end
  else begin
    internal_libmysql_ClientVersion := mysql_get_client_version;
    if internal_libmysql_ClientVersion>=mysql_not_compatible_version
    then begin
      internal_libmysql_status := LIBMYSQL_INCOMPATIBLE;
      raise Exception.CreateFmt(sLibMySql_Version_Incompatible, [mysql_get_client_info]);
    end
    else
      internal_libmysql_status := LIBMYSQL_READY;
  end;
end;

procedure libmysql_free;
begin
  if libmysql_handle <> 0
  then
    FreeLibrary(libmysql_handle);
  libmysql_handle := 0;
  internal_libmysql_status := LIBMYSQL_UNDEFINED;
  FinalizeLibmysql;
end;

procedure libmysql_load_check;
var
  Old_libmysql_status: TLibMysql_status;
  ErrorText: String;
begin
  if internal_libmysql_status<>LIBMYSQL_READY
  then begin
    Old_libmysql_status := internal_libmysql_status;
    if libmysql_handle <> 0 then FreeLibrary(libmysql_handle);
    libmysql_handle := 0;
    internal_libmysql_status := LIBMYSQL_UNDEFINED;
    case Old_libmysql_status of
      LIBMYSQL_UNDEFINED: ErrorText := sLibMySql_Undefined;
      LIBMYSQL_MISSING: ErrorText := sLibMySql_Missing;
      LIBMYSQL_INCOMPATIBLE: ErrorText := sLibMySql_Incompatible;
    end;
    raise Exception.Create(ErrorText);
  end;
end;

function mysql_get_client_filename: String;
begin
  if libmysql_handle <> 0
  then begin
    SetLength(Result, 1024);
    SetLength(Result, GetModuleFileName(libmysql_handle, Pointer(Result), Length(Result)));
  end;
end;

function libmysql_status: Tlibmysql_status;
begin
  Result := internal_libmysql_status;
end;

//current Client-Version as longword 3.23.58=32358
function libmysql_ClientVersion: longword;
begin
  Result := internal_libmysql_ClientVersion;
end;

{$IFDEF EmbeddedCharacterConvert}
{$INCLUDE mysql_emb.inc}
{$ENDIF}

{$IFDEF Win32CharacterConvert}
{$INCLUDE mysql_win32.inc}
{$ENDIF}

// -----------------------------------------------------------------------------------------------
INITIALIZATION
// -----------------------------------------------------------------------------------------------

{$IFNDEF DONT_LOAD_DLL}
  libmysql_fast_load(nil);
{$ENDIF} // DONT_LOAD_DLL

{$IFDEF Win32CharacterConvert}
  DefaultMySqlCodePage := GetACP;
{$ENDIF}
  {$ifdef CPUX64}
  Assert(SizeOf(TNET500)=664, 'Wrong size of TNET500');
  Assert(SizeOf(TNET501)=656, 'Wrong size of TNET501');
  Assert(SizeOf(TMYSQL401)=1192, 'Wrong size of TMYSQL401');
  Assert(SizeOf(TMYSQL500)=1192, 'Wrong size of TMYSQL500');
  Assert(SizeOf(TMYSQL501)=1192, 'Wrong size of TMYSQL501');
  Assert(SizeOf(TMYSQL_FIELD401)=AlignedFIELD401Size, 'Wrong size of TMYSQL_FIELD401');
  Assert(SizeOf(TMYSQL_FIELD501)=AlignedFIELD501Size, 'Wrong size of TMYSQL_FIELD501');
  Assert(SizeOf(TMYSQL_BIND401)=88, 'Wrong size of TMYSQL_BIND401');
  Assert(SizeOf(TMYSQL_BIND500)=96, 'Wrong size of TMYSQL_BIND500');
  Assert(SizeOf(TMYSQL_BIND501)=104, 'Wrong size of TMYSQL_BIND501');
  {$else}
  Assert(SizeOf(TNET323)=272, 'Wrong size of TNET323');
  Assert(SizeOf(TNET400)=292, 'Wrong size of TNET400');
  Assert(SizeOf(TNET401)=620, 'Wrong size of TNET401');
  Assert(SizeOf(TNET500)=620, 'Wrong size of TNET500');
  Assert(SizeOf(TNET501)=620, 'Wrong size of TNET501');
  Assert(SizeOf(TMYSQL323)=496, 'Wrong size of TMYSQL323');
  Assert(SizeOf(TMYSQL400)=544, 'Wrong size of TMYSQL400');
  Assert(SizeOf(TMYSQL401)=960, 'Wrong size of TMYSQL401');
  Assert(SizeOf(TMYSQL500)=960, 'Wrong size of TMYSQL500');
  Assert(SizeOf(TMYSQL501)=960, 'Wrong size of TMYSQL501');
  Assert(SizeOf(TMYSQL_FIELD323)=AlignedFIELD323Size, 'Wrong size of TMYSQL_FIELD323');
  Assert(SizeOf(TMYSQL_FIELD400)=AlignedFIELD400Size, 'Wrong size of TMYSQL_FIELD400');
  Assert(SizeOf(TMYSQL_FIELD401)=AlignedFIELD401Size, 'Wrong size of TMYSQL_FIELD401');
  Assert(SizeOf(TMYSQL_FIELD501)=AlignedFIELD501Size, 'Wrong size of TMYSQL_FIELD501');
  Assert(SizeOf(TMYSQL_BIND401)=56, 'Wrong size of TMYSQL_BIND401');
  Assert(SizeOf(TMYSQL_BIND500)=60, 'Wrong size of TMYSQL_BIND500');
  Assert(SizeOf(TMYSQL_BIND501)=64, 'Wrong size of TMYSQL_BIND501');
  {$endif}
  Assert(SizeOf(TMYSQL_TIME)=36, 'Wrong size of TMYSQL_TIME');

// -----------------------------------------------------------------------------------------------
FINALIZATION
// -----------------------------------------------------------------------------------------------

  libmysql_free;

end.


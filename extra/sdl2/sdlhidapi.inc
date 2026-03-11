// from SDL_hidapi.h

(**
 *  Header file for SDL HIDAPI functions.
 *
 *  This is an adaptation of the original HIDAPI interface by Alan Ott,
 *  and includes source code licensed under the following BSD license:
 *
    Copyright (c) 2010, Alan Ott, Signal 11 Software
    All rights reserved.

    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright notice,
      this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of Signal 11 Software nor the names of its
      contributors may be used to endorse or promote products derived from
      this software without specific prior written permission.

    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
    AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
    IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
    ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
    LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
    CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
    SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
    INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
    CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
    ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
    POSSIBILITY OF SUCH DAMAGE.
 *
 * If you would like a version of SDL without this code, you can build SDL
 * with SDL_HIDAPI_DISABLED defined to 1. You might want to do this for example
 * on iOS or tvOS to avoid a dependency on the CoreBluetooth framework.
 *)

type
	(**
 	 *  \brief  A handle representing an open HID device.
 	 *)
	PSDL_hid_device = type Pointer;

	PSDL_hid_device_info = ^TSDL_hid_device_info;

	(**
 	 *  \brief  Information about a connected HID device
 	 *)
	TSDL_hid_device_info = record
		(** Platform-specific device path *)
		path: PAnsiChar;
		(** Device Vendor ID *)
		vendor_id: pcushort;
		(** Device Product ID *)
		product_id: pcushort;
		(** Serial Number *)
		serial_number: pcwchar_t;
		(** Device Release Number in binary-coded decimal, also known as Device Version Number *)
		release_number: cushort;
		(** Manufacturer String *)
		manufacturer_string: pcwchar_t;
		(** Product string *)
		product_string: pcwchar_t;
		(** Usage Page for this Device/Interface (Windows/Mac only). *)
		usage_page: cushort;
		(** Usage for this Device/Interface (Windows/Mac only). *)
		usage: cushort;
		(**
 		 * The USB interface which this logical device represents.
 		 * Valid on both Linux implementations in all cases.
 		 * Valid on the Windows implementation only if the device
 		 * contains more than one interface.
 		 *)
		interface_number: cint;

		(**
 		 * Additional information about the USB interface.
 		 * Valid on libusb and Android implementations.
 		 *)
		interface_class: cint;
		interface_subclass: cint;
		interface_protocol: cint;

		(** Pointer to the next device *)
		next: PSDL_hid_device_info;
	end;

(**
 * Initialize the HIDAPI library.
 *
 * This function initializes the HIDAPI library. Calling it is not strictly
 * necessary, as it will be called automatically by SDL_hid_enumerate() and
 * any of the SDL_hid_open_*() functions if it is needed. This function should
 * be called at the beginning of execution however, if there is a chance of
 * HIDAPI handles being opened by different threads simultaneously.
 *
 * Each call to this function should have a matching call to SDL_hid_exit()
 *
 * \returns 0 on success and -1 on error.
 *
 * \since This function is available since SDL 2.0.18.
 *
 * \sa SDL_hid_exit
 *)
function SDL_hid_init(): cint; cdecl;
	external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_hid_init' {$ENDIF} {$ENDIF};

(**
 * Finalize the HIDAPI library.
 *
 * This function frees all of the static data associated with HIDAPI. It
 * should be called at the end of execution to avoid memory leaks.
 *
 * \returns 0 on success and -1 on error.
 *
 * \since This function is available since SDL 2.0.18.
 *
 * \sa SDL_hid_init
 *)
function SDL_hid_exit(): cint; cdecl;
	external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_hid_exit' {$ENDIF} {$ENDIF};

(**
 * Check to see if devices may have been added or removed.
 *
 * Enumerating the HID devices is an expensive operation, so you can call this
 * to see if there have been any system device changes since the last call to
 * this function. A change in the counter returned doesn't necessarily mean
 * that anything has changed, but you can call SDL_hid_enumerate() to get an
 * updated device list.
 *
 * Calling this function for the first time may cause a thread or other system
 * resource to be allocated to track device change notifications.
 *
 * \returns a change counter that is incremented with each potential device
 *          change, or 0 if device change detection isn't available.
 *
 * \since This function is available since SDL 2.0.18.
 *
 * \sa SDL_hid_enumerate
 *)
function SDL_hid_device_change_count(): cUint32; cdecl;
	external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_hid_device_change_count' {$ENDIF} {$ENDIF};

(**
 * Enumerate the HID Devices.
 *
 * This function returns a linked list of all the HID devices attached to the
 * system which match vendor_id and product_id. If `vendor_id` is set to 0
 * then any vendor matches. If `product_id` is set to 0 then any product
 * matches. If `vendor_id` and `product_id` are both set to 0, then all HID
 * devices will be returned.
 *
 * \param vendor_id The Vendor ID (VID) of the types of device to open.
 * \param product_id The Product ID (PID) of the types of device to open.
 * \returns a pointer to a linked list of type SDL_hid_device_info, containing
 *          information about the HID devices attached to the system, or NIL
 *          in the case of failure. Free this linked list by calling
 *          SDL_hid_free_enumeration().
 *
 * \since This function is available since SDL 2.0.18.
 *
 * \sa SDL_hid_device_change_count
 *)
function SDL_hid_enumerate(vendor_id, product_id: cushort): PSDL_hid_device_info; cdecl;
	external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_hid_enumerate' {$ENDIF} {$ENDIF};

(**
 * Free an enumeration Linked List
 *
 * This function frees a linked list created by SDL_hid_enumerate().
 *
 * \param devs Pointer to a list of struct_device returned from
 *             SDL_hid_enumerate().
 *
 * \since This function is available since SDL 2.0.18.
 *)
procedure SDL_hid_free_enumeration(devs: PSDL_hid_device_info); cdecl;
	external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_hid_free_enumeration' {$ENDIF} {$ENDIF};

(**
 * Open a HID device using a Vendor ID (VID), Product ID (PID) and optionally
 * a serial number.
 *
 * If `serial_number` is NULL, the first device with the specified VID and PID
 * is opened.
 *
 * \param vendor_id The Vendor ID (VID) of the device to open.
 * \param product_id The Product ID (PID) of the device to open.
 * \param serial_number The Serial Number of the device to open
 *                      (optionally NIL).
 * \returns a pointer to a SDL_hid_device object on success or NIL on
 *          failure.
 *
 * \since This function is available since SDL 2.0.18.
 *)
function SDL_hid_open(vendor_id, product_id: cushort; serial_number: pcwchar_t): PSDL_hid_device; cdecl;
	external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_hid_open' {$ENDIF} {$ENDIF};

(**
 * Open a HID device by its path name.
 *
 * The path name be determined by calling SDL_hid_enumerate(), or a
 * platform-specific path name can be used (eg: /dev/hidraw0 on Linux).
 *
 * \param path The path name of the device to open
 * \returns a pointer to a SDL_hid_device object on success
 *          or NIL on failure.
 *
 * \since This function is available since SDL 2.0.18.
 *)
function SDL_hid_open_path(path: PAnsiChar; bExclusive: cuint): PSDL_hid_device; cdecl;
	external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_hid_open_path' {$ENDIF} {$ENDIF};

(**
 * Write an Output report to a HID device.
 *
 * The first byte of `data` must contain the Report ID. For devices which only
 * support a single report, this must be set to 0x0. The remaining bytes
 * contain the report data. Since the Report ID is mandatory, calls to
 * SDL_hid_write() will always contain one more byte than the report contains.
 * For example, if a hid report is 16 bytes long, 17 bytes must be passed to
 * SDL_hid_write(), the Report ID (or 0x0, for devices with a single report),
 * followed by the report data (16 bytes). In this example, the length passed
 * in would be 17.
 *
 * SDL_hid_write() will send the data on the first OUT endpoint, if one
 * exists. If it does not, it will send the data through the Control Endpoint
 * (Endpoint 0).
 *
 * \param dev A device handle returned from SDL_hid_open().
 * \param data The data to send, including the report number as the first
 *             byte.
 * \param length The length in bytes of the data to send.
 * \returns the actual number of bytes written and -1 on error.
 *
 * \since This function is available since SDL 2.0.18.
 *)
function SDL_hid_write(dev: PSDL_hid_device; data: pcUint8; length: csize_t): cint; cdecl;
	external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_hid_write' {$ENDIF} {$ENDIF};

(**
 * Read an Input report from a HID device with timeout.
 *
 * Input reports are returned to the host through the INTERRUPT IN endpoint.
 * The first byte will contain the Report number if the device uses numbered
 * reports.
 *
 * \param dev A device handle returned from SDL_hid_open().
 * \param data A buffer to put the read data into.
 * \param length The number of bytes to read. For devices with multiple
 *               reports, make sure to read an extra byte for the report
 *               number.
 * \param milliseconds timeout in milliseconds or -1 for blocking wait.
 * \returns the actual number of bytes read and -1 on error. If no packet was
 *          available to be read within the timeout period, this function
 *          returns 0.
 *
 * \since This function is available since SDL 2.0.18.
 *)
function SDL_hid_read_timeout(dev: PSDL_hid_device; data: pcUint8; length: csize_t; milliseconds: cint): cint; cdecl;
	external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_hid_read_timeout' {$ENDIF} {$ENDIF};

(**
 * Read an Input report from a HID device.
 *
 * Input reports are returned to the host through the INTERRUPT IN endpoint.
 * The first byte will contain the Report number if the device uses numbered
 * reports.
 *
 * \param dev A device handle returned from SDL_hid_open().
 * \param data A buffer to put the read data into.
 * \param length The number of bytes to read. For devices with multiple
 *               reports, make sure to read an extra byte for the report
 *               number.
 * \returns the actual number of bytes read and -1 on error. If no packet was
 *          available to be read and the handle is in non-blocking mode, this
 *          function returns 0.
 *
 * \since This function is available since SDL 2.0.18.
 *)
function SDL_hid_read(dev: PSDL_hid_device; data: pcUint8; length: csize_t): cint; cdecl;
	external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_hid_read' {$ENDIF} {$ENDIF};

(**
 * Set the device handle to be non-blocking.
 *
 * In non-blocking mode calls to SDL_hid_read() will return immediately with a
 * value of 0 if there is no data to be read. In blocking mode, SDL_hid_read()
 * will wait (block) until there is data to read before returning.
 *
 * Nonblocking can be turned on and off at any time.
 *
 * \param dev A device handle returned from SDL_hid_open().
 * \param nonblock enable or not the nonblocking reads - 1 to enable
 *                 nonblocking - 0 to disable nonblocking.
 * \returns 0 on success and -1 on error.
 *
 * \since This function is available since SDL 2.0.18.
 *)
function SDL_hid_set_nonblocking(dev: PSDL_hid_device; nonblock: cint): cint; cdecl;
	external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_hid_set_nonblocking' {$ENDIF} {$ENDIF};

(**
 * Send a Feature report to the device.
 *
 * Feature reports are sent over the Control endpoint as a Set_Report
 * transfer. The first byte of `data` must contain the Report ID. For devices
 * which only support a single report, this must be set to 0x0. The remaining
 * bytes contain the report data. Since the Report ID is mandatory, calls to
 * SDL_hid_send_feature_report() will always contain one more byte than the
 * report contains. For example, if a hid report is 16 bytes long, 17 bytes
 * must be passed to SDL_hid_send_feature_report(): the Report ID (or 0x0, for
 * devices which do not use numbered reports), followed by the report data (16
 * bytes). In this example, the length passed in would be 17.
 *
 * \param dev A device handle returned from SDL_hid_open().
 * \param data The data to send, including the report number as the first
 *             byte.
 * \param length The length in bytes of the data to send, including the report
 *               number.
 * \returns the actual number of bytes written and -1 on error.
 *
 * \since This function is available since SDL 2.0.18.
 *)
function SDL_hid_send_feature_report(dev: PSDL_hid_device; data: pcUint8; length: csize_t): cint; cdecl;
	external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_hid_send_feature_report' {$ENDIF} {$ENDIF};

(**
 * Get a feature report from a HID device.
 *
 * Set the first byte of `data` to the Report ID of the report to be read.
 * Make sure to allow space for this extra byte in `data`. Upon return, the
 * first byte will still contain the Report ID, and the report data will start
 * in data[1].
 *
 * \param dev A device handle returned from SDL_hid_open().
 * \param data A buffer to put the read data into, including the Report ID.
 *             Set the first byte of `data` to the Report ID of the report to
 *             be read, or set it to zero if your device does not use numbered
 *             reports.
 * \param length The number of bytes to read, including an extra byte for the
 *               report ID. The buffer can be longer than the actual report.
 * \returns the number of bytes read plus one for the report ID (which is
 *          still in the first byte), or -1 on error.
 *
 * \since This function is available since SDL 2.0.18.
 *)
function SDL_hid_get_feature_report(dev: PSDL_hid_device; data: pcUint8; length: csize_t): cint; cdecl;
	external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_hid_get_feature_report' {$ENDIF} {$ENDIF};

(**
 * Close a HID device.
 *
 * \param dev A device handle returned from SDL_hid_open().
 *
 * \since This function is available since SDL 2.0.18.
 *)
procedure SDL_hid_close(dev: PSDL_hid_device); cdecl;
	external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_hid_close' {$ENDIF} {$ENDIF};

(**
 * Get The Manufacturer String from a HID device.
 *
 * \param dev A device handle returned from SDL_hid_open().
 * \param string A wide string buffer to put the data into.
 * \param maxlen The length of the buffer in multiples of wchar_t.
 * \returns 0 on success and -1 on error.
 *
 * \since This function is available since SDL 2.0.18.
 *)
function SDL_hid_get_manufacturer_string(dev: PSDL_hid_device; str: pcwchar_t; maxlen: csize_t): cint; cdecl;
	external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_hid_get_manufacturer_string' {$ENDIF} {$ENDIF};

(**
 * Get The Product String from a HID device.
 *
 * \param dev A device handle returned from SDL_hid_open().
 * \param string A wide string buffer to put the data into.
 * \param maxlen The length of the buffer in multiples of wchar_t.
 * \returns 0 on success and -1 on error.
 *
 * \since This function is available since SDL 2.0.18.
 *)
function SDL_hid_get_product_string(dev: PSDL_hid_device; str: pcwchar_t; maxlen: csize_t): cint; cdecl;
	external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_hid_get_product_string' {$ENDIF} {$ENDIF};

(**
 * Get The Serial Number String from a HID device.
 *
 * \param dev A device handle returned from SDL_hid_open().
 * \param string A wide string buffer to put the data into.
 * \param maxlen The length of the buffer in multiples of wchar_t.
 * \returns 0 on success and -1 on error.
 *
 * \since This function is available since SDL 2.0.18.
 *)
function SDL_hid_get_serial_number_string(dev: PSDL_hid_device; str: pcwchar_t; maxlen: csize_t): cint; cdecl;
	external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_hid_get_serial_number_string' {$ENDIF} {$ENDIF};

(**
 * Get a string from a HID device, based on its string index.
 *
 * \param dev A device handle returned from SDL_hid_open().
 * \param string_index The index of the string to get.
 * \param string A wide string buffer to put the data into.
 * \param maxlen The length of the buffer in multiples of wchar_t.
 * \returns 0 on success and -1 on error.
 *
 * \since This function is available since SDL 2.0.18.
 *)
function SDL_hid_get_indexed_string(dev: PSDL_hid_device; string_index: cint; str: pcwchar_t; maxlen: csize_t): cint; cdecl;
	external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_hid_get_indexed_string' {$ENDIF} {$ENDIF};

(**
 * Start or stop a BLE scan on iOS and tvOS to pair Steam Controllers
 *
 * \param active SDL_TRUE to start the scan, SDL_FALSE to stop the scan
 *
 * \since This function is available since SDL 2.0.18.
 *)
procedure SDL_hid_ble_scan(active: TSDL_bool); cdecl;
	external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_hid_ble_scan' {$ENDIF} {$ENDIF};

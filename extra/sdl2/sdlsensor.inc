// based on SDL_sensor.h


{**
 *  \brief SDL_sensor.h
 *
 *  In order to use these functions, SDL_Init() must have been called
 *  with the ::SDL_INIT_SENSOR flag.  This causes SDL to scan the system
 *  for sensors, and load appropriate drivers.
 *}
type
	PPSDL_Sensor = ^PSDL_Sensor;
	PSDL_Sensor = type Pointer;

{**
 * This is a unique ID for a sensor for the time it is connected to the system,
 * and is never reused for the lifetime of the application.
 *
 * The ID value starts at 0 and increments from there. The value -1 is an invalid ID.
 *}
type
	PPSDL_SensorID = ^PSDL_SensorID;
	PSDL_SensorID = ^TSDL_SensorID;
	TSDL_SensorID = type cint32;

{**
 * The different sensors defined by SDL
 *
 * Additional sensors may be available, using platform dependent semantics.
 *
 * Hare are the additional Android sensors:
 * https://developer.android.com/reference/android/hardware/SensorEvent.html#values
 *}
type
	PPSDL_SensorType = ^PSDL_SensorType;
	PSDL_SensorType = ^TSDL_SensorType;
	TSDL_SensorType = type cint;

const
	SDL_SENSOR_INVALID = TSDL_SensorType(-1);    {**< Returned for an invalid sensor *}
	SDL_SENSOR_UNKNOWN = TSDL_SensorType(0);     {**< Unknown sensor type *}
	SDL_SENSOR_ACCEL   = TSDL_SensorType(1);     {**< Accelerometer *}
	SDL_SENSOR_GYRO    = TSDL_SensorType(2);     {**< Gyroscope *}
	SDL_SENSOR_ACCEL_L = TSDL_SensorType(3);     {**< Accelerometer for left Joy-Con controller and Wii nunchuk *}
	SDL_SENSOR_GYRO_L  = TSDL_SensorType(4);     {**< Gyroscope for left Joy-Con controller *}
	SDL_SENSOR_ACCEL_R = TSDL_SensorType(5);     {**< Accelerometer for right Joy-Con controller *}
	SDL_SENSOR_GYRO_R  = TSDL_SensorType(6);     {**< Gyroscope for right Joy-Con controller *}

{**
 * Accelerometer sensor
 *
 * The accelerometer returns the current acceleration in SI meters per
 * second squared. This measurement includes the force of gravity, so
 * a device at rest will have an value of SDL_STANDARD_GRAVITY away
 * from the center of the earth.
 *
 * values[0]: Acceleration on the x axis
 * values[1]: Acceleration on the y axis
 * values[2]: Acceleration on the z axis
 *
 * For phones held in portrait mode and game controllers held in front of you,
 * the axes are defined as follows:
 * -X ... +X : left ... right
 * -Y ... +Y : bottom ... top
 * -Z ... +Z : farther ... closer
 *
 * The axis data is not changed when the phone is rotated.
 *
 * \sa SDL_GetDisplayOrientation()
 *}
const
	SDL_STANDARD_GRAVITY = 9.80665;

{**
 * Gyroscope sensor
 *
 * The gyroscope returns the current rate of rotation in radians per second.
 * The rotation is positive in the counter-clockwise direction. That is,
 * an observer looking from a positive location on one of the axes would
 * see positive rotation on that axis when it appeared to be rotating
 * counter-clockwise.
 *
 * values[0]: Angular speed around the x axis (pitch)
 * values[1]: Angular speed around the y axis (yaw)
 * values[2]: Angular speed around the z axis (roll)
 *
 * For phones held in portrait mode and game controllers held in front of you,
 * the axes are defined as follows:
 * -X ... +X : left ... right
 * -Y ... +Y : bottom ... top
 * -Z ... +Z : farther ... closer
 *
 * The axis data is not changed when the phone or controller is rotated.
 *
 * \sa SDL_GetDisplayOrientation()
 *}

{--- Function prototypes ---}

{**
 * Locking for multi-threaded access to the sensor API
 *
 * If you are using the sensor API or handling events from multiple threads
 * you should use these locking functions to protect access to the sensors.
 *
 * In particular, you are guaranteed that the sensor list won't change, so
 * the API functions that take a sensor index will be valid, and sensor
 * events will not be delivered.
 *
 * \since This function is available since SDL 2.0.14.
 *}
procedure SDL_LockSensors(); cdecl;
	external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_LockSensors' {$ENDIF} {$ENDIF};
procedure SDL_UnlockSensors(); cdecl;
	external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_UnlockSensors' {$ENDIF} {$ENDIF};

{**
 * Count the number of sensors attached to the system right now.
 *
 * \returns the number of sensors detected.
 *
 * \since This function is available since SDL 2.0.9.
 *}
function SDL_NumSensors(): cint; cdecl;
	external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_NumSensors' {$ENDIF} {$ENDIF};

{**
 * Get the implementation dependent name of a sensor.
 *
 * \param device_index The sensor to obtain name from
 * \returns the sensor name, or NIL if `device_index` is out of range.
 *
 * \since This function is available since SDL 2.0.9.
 *}
function SDL_SensorGetDeviceName(device_index: cint): PAnsiChar; cdecl;
	external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_SensorGetDeviceName' {$ENDIF} {$ENDIF};

{**
 * Get the type of a sensor.
 *
 * \param device_index The sensor to get the type from
 * \returns the SDL_SensorType, or `SDL_SENSOR_INVALID` if `device_index` is
 *          out of range.
 *
 * \since This function is available since SDL 2.0.9.
 *}
function SDL_SensorGetDeviceType(device_index: cint): TSDL_SensorType; cdecl;
	external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_SensorGetDeviceType' {$ENDIF} {$ENDIF};

{**
 * Get the platform dependent type of a sensor.
 *
 * \param device_index The sensor to check
 * \returns the sensor platform dependent type, or -1 if `device_index` is out
 *          of range.
 *
 * \since This function is available since SDL 2.0.9.
 *}
function SDL_SensorGetDeviceNonPortableType(device_index: cint): cint; cdecl;
	external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_SensorGetDeviceNonPortableType' {$ENDIF} {$ENDIF};

{**
 * Get the instance ID of a sensor.
 *
 * \param device_index The sensor to get instance id from
 * \returns the sensor instance ID, or -1 if `device_index` is out of range.
 *
 * \since This function is available since SDL 2.0.9.
 *}
function SDL_SensorGetDeviceInstanceID(device_index: cint): TSDL_SensorID; cdecl;
	external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_SensorGetDeviceInstanceID' {$ENDIF} {$ENDIF};

{**
 * Open a sensor for use.
 *
 * \param device_index The sensor to open
 * \returns an SDL_Sensor sensor object, or NIL if an error occurred.
 *
 * \since This function is available since SDL 2.0.9.
 *}
function SDL_SensorOpen(device_index: cint): PSDL_Sensor; cdecl;
	external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_SensorOpen' {$ENDIF} {$ENDIF};

{**
 * Return the SDL_Sensor associated with an instance id.
 *
 * \param instance_id The sensor from instance id
 * \returns an SDL_Sensor object.
 *
 * \since This function is available since SDL 2.0.9.
 *}
function SDL_SensorFromInstanceID(instance_id: TSDL_SensorID): PSDL_Sensor; cdecl;
	external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_SensorFromInstanceID' {$ENDIF} {$ENDIF};

{**
 * Get the implementation dependent name of a sensor
 *
 * \param sensor The SDL_Sensor object
 * \returns the sensor name, or NIL if `sensor` is NIL.
 *
 * \since This function is available since SDL 2.0.9.
 *}
function SDL_SensorGetName(sensor: PSDL_Sensor): PAnsiChar; cdecl;
	external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_SensorGetName' {$ENDIF} {$ENDIF};

{**
 * Get the type of a sensor.
 *
 * \param sensor The SDL_Sensor object to inspect
 * \returns the SDL_SensorType type, or `SDL_SENSOR_INVALID`
 *          if `sensor` is NIL.
 *
 * \since This function is available since SDL 2.0.9.
 *}
function SDL_SensorGetType(sensor: PSDL_Sensor): TSDL_SensorType; cdecl;
	external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_SensorGetType' {$ENDIF} {$ENDIF};

{**
 * Get the platform dependent type of a sensor.
 *
 * \param sensor The SDL_Sensor object to inspect
 * \returns the sensor platform dependent type, or -1 if `sensor` is NIL.
 *
 * \since This function is available since SDL 2.0.9.
 *}
function SDL_SensorGetNonPortableType(sensor: PSDL_Sensor): cint; cdecl;
	external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_SensorGetNonPortableType' {$ENDIF} {$ENDIF};

{**
 * Get the instance ID of a sensor.
 *
 * \param sensor The SDL_Sensor object to inspect
 * \returns the sensor instance ID, or -1 if `sensor` is NIL.
 *
 * \since This function is available since SDL 2.0.9.
 *}
function SDL_SensorGetInstanceID(sensor: PSDL_Sensor): TSDL_SensorID; cdecl;
	external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_SensorGetInstanceID' {$ENDIF} {$ENDIF};

{**
 * Get the current state of an opened sensor.
 *
 * The number of values and interpretation of the data is sensor dependent.
 *
 * \param sensor The SDL_Sensor object to query
 * \param data A pointer filled with the current sensor state
 * \param num_values The number of values to write to data
 * \returns 0 or -1 if an error occurred.
 *
 * \since This function is available since SDL 2.0.9.
 *}
function SDL_SensorGetData(sensor: PSDL_Sensor; data: pcfloat; num_values: cint): cint; cdecl;
	external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_SensorGetData' {$ENDIF} {$ENDIF};

{**
 * Get the current state of an opened sensor with the timestamp of the last
 * update.
 *
 * The number of values and interpretation of the data is sensor dependent.
 *
 * \param sensor The SDL_Sensor object to query
 * \param timestamp A pointer filled with the timestamp in microseconds of the
 *                  current sensor reading if available, or 0 if not
 * \param data A pointer filled with the current sensor state
 * \param num_values The number of values to write to data
 * \returns 0 or -1 if an error occurred.
 *
 * \since This function is available since SDL 2.26.0.
 *}
function SDL_SensorGetDataWithTimestamp(sensor: PSDL_Sensor; timestamp: pcuint64; data: pcfloat; num_values: cint): cint; cdecl;
	external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_SensorGetDataWithTimestamp' {$ENDIF} {$ENDIF};

{**
 * Close a sensor previously opened with SDL_SensorOpen().
 *
 * \param sensor The SDL_Sensor object to close
 *
 * \since This function is available since SDL 2.0.9.
 *}
procedure SDL_SensorClose(sensor: PSDL_Sensor); cdecl;
	external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_SensorClose' {$ENDIF} {$ENDIF};

{**
 * Update the current state of the open sensors.
 *
 * This is called automatically by the event loop if sensor events are
 * enabled.
 *
 * This needs to be called from the thread that initialized the sensor
 * subsystem.
 *
 * \since This function is available since SDL 2.0.9.
 *}
procedure SDL_SensorUpdate(); cdecl;
	external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_SensorUpdate' {$ENDIF} {$ENDIF};

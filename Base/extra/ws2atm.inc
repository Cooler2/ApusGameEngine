//  Copyright 1997 - 1998 Microsoft Corporation
//
//  Module Name:
//
//  	ws2atm.h
//
//  Abstract:
//
//  	Winsock 2 ATM Annex definitions.
																						
																						
const
	ATMPROTO_AALUSER = $00; // User-defined AAL
	ATMPROTO_AAL1    = $01; // AAL 1
	ATMPROTO_AAL2    = $02; // AAL 2
	ATMPROTO_AAL34   = $03; // AAL 3/4
	ATMPROTO_AAL5    = $05; // AAL 5
		
	SAP_FIELD_ABSENT        = $FFFFFFFE;
	SAP_FIELD_ANY           = $FFFFFFFF;
	SAP_FIELD_ANY_AESA_SEL  = $FFFFFFFA;
	SAP_FIELD_ANY_AESA_REST = $FFFFFFFB;
	
// values used for AddressType in struct ATM_ADDRESS
	ATM_E164 = $01; // E.164 addressing scheme
	ATM_NSAP = $02; // NSAP-style ATM Endsystem Address scheme
	ATM_AESA = $02; // NSAP-style ATM Endsystem Address scheme
	
	ATM_ADDR_SIZE = 20;
type
	ATM_ADDRESS = packed record
		AddressType : DWORD;                        // E.164 or NSAP-style ATM Endsystem Address
		NumofDigits : DWORD;                        // number of digits;
		Addr : Array[0..(ATM_ADDR_SIZE)-1] of Byte; // IA5 digits for E164, BCD encoding for NSAP
																								// format as defined in the ATM Forum UNI 3.1
	end;
	
//-------------------------------------------------------------
// values used for Layer2Protocol in B-LLI
const
	BLLI_L2_ISO_1745       = $01; // Basic mode ISO 1745
	BLLI_L2_Q921           = $02; // CCITT Rec. Q.921
	BLLI_L2_X25L           = $06; // CCITT Rec. X.25, link layer
	BLLI_L2_X25M           = $07; // CCITT Rec. X.25, multilink
	BLLI_L2_ELAPB          = $08; // Extended LAPB; for half duplex operation
	BLLI_L2_HDLC_NRM       = $09; // HDLC NRM (ISO 4335)
	BLLI_L2_HDLC_ABM       = $0A; // HDLC ABM (ISO 4335)
	BLLI_L2_HDLC_ARM       = $0B; // HDLC ARM (ISO 4335)
	BLLI_L2_LLC            = $0C; // LAN logical link control (ISO 8802/2)
	BLLI_L2_X75            = $0D; // CCITT Rec. X.75, single link procedure
	BLLI_L2_Q922           = $0E; // CCITT Rec. Q.922
	BLLI_L2_USER_SPECIFIED = $10; // User Specified
	BLLI_L2_ISO_7776       = $11; // ISO 7776 DTE-DTE operation

//-------------------------------------------------------------
// values used for Layer3Protocol in B-LLI
	BLLI_L3_X25            = $06; // CCITT Rec. X.25, packet layer
	BLLI_L3_ISO_8208       = $07; // ISO/IEC 8208 (X.25 packet layer for DTE
	BLLI_L3_X223           = $08; // X.223/ISO 8878
	BLLI_L3_SIO_8473       = $09; // ISO/IEC 8473 (OSI connectionless)
	BLLI_L3_T70            = $0A; // CCITT Rec. T.70 min. network layer
	BLLI_L3_ISO_TR9577     = $0B; // ISO/IEC TR 9577 Network Layer Protocol ID
	BLLI_L3_USER_SPECIFIED = $10; // User Specified
	
//-------------------------------------------------------------
// values used for Layer3IPI in B-LLI
	BLLI_L3_IPI_SNAP = $80; // IEEE 802.1 SNAP identifier
	BLLI_L3_IPI_IP   = $CC; // Internet Protocol (IP) identifier

type
	ATM_BLLI = packed record
		// Identifies the layer-two protocol.
		// Corresponds to the User information layer 2 protocol field in the B-LLI information element.
		// A value of SAP_FIELD_ABSENT indicates that this field is not used, and a value of SAP_FIELD_ANY means wildcard.		
		Layer2Protocol              : DWORD; // User information layer 2 protocol
		// Identifies the user-specified layer-two protocol.
		// Only used if the Layer2Protocol parameter is set to BLLI_L2_USER_SPECIFIED.
		// The valid values range from zero–127.
		// Corresponds to the User specified layer 2 protocol information field in the B-LLI information element. 		
		Layer2UserSpecifiedProtocol : DWORD; // User specified layer 2 protocol information
		// Identifies the layer-three protocol.
		// Corresponds to the User information layer 3 protocol field in the B-LLI information element.
		// A value of SAP_FIELD_ABSENT indicates that this field is not used, and a value of SAP_FIELD_ANY means wildcard.
		Layer3Protocol              : DWORD; // User information layer 3 protocol
		// Identifies the user-specified layer-three protocol.
		// Only used if the Layer3Protocol parameter is set to BLLI_L3_USER_SPECIFIED.
		// The valid values range from zero–127.
		// Corresponds to the User specified layer 3 protocol information field in the B-LLI information element.
		Layer3UserSpecifiedProtocol : DWORD; // User specified layer 3 protocol information
		// Identifies the layer-three Initial Protocol Identifier.
		// Only used if the Layer3Protocol parameter is set to BLLI_L3_ISO_TR9577.
		// Corresponds to the ISO/IEC TR 9577 Initial Protocol Identifier field in the B-LLI information element. 		
		Layer3IPI                   : DWORD; // ISO/IEC TR 9577 Initial Protocol Identifier
		// Identifies the 802.1 SNAP identifier.
		// Only used if the Layer3Protocol parameter is set to BLLI_L3_ISO_TR9577 and Layer3IPI is set to BLLI_L3_IPI_SNAP,
		// indicating an IEEE 802.1 SNAP identifier. Corresponds to the OUI and PID fields in the B-LLI information element. 		
		SnapID                      : Array[0..4] of Byte; // SNAP ID consisting of OUI and PID
	end;
	
//-------------------------------------------------------------
// values used for the HighLayerInfoType field in ATM_BHLI
const
	BHLI_ISO                 = $00; // ISO
	BHLI_UserSpecific        = $01; // User Specific
	BHLI_HighLayerProfile    = $02; // High layer profile (only in UNI3.0)
	BHLI_VendorSpecificAppId = $03; // Vendor-Specific Application ID

type
	ATM_BHLI = packed record
		// Identifies the high layer information type field in the B-LLI information element.
		// Note that the type BHLI_HighLayerProfile has been eliminated in UNI 3.1.
		// A value of SAP_FIELD_ABSENT indicates that B-HLI is not present, and a value of SAP_FIELD_ANY means wildcard.
		HighLayerInfoType   : DWORD; // High Layer Information Type
		// Identifies the number of bytes from one to eight in the HighLayerInfo array.
		// Valid values include eight for the cases of BHLI_ISO and BHLI_UserSpecific,
		// four for BHLI_HighLayerProfile, and seven for BHLI_VendorSpecificAppId. 		
		HighLayerInfoLength : DWORD; // number of bytes in HighLayerInfo
		// Identifies the high layer information field in the B-LLI information element.
		// In the case of HighLayerInfoType being BHLI_VendorSpecificAppId,
		// the first 3 bytes consist of a globally-administered Organizationally Unique Identifier (OUI)
		// (as per IEEE standard 802-1990), followed by a 4-byte application identifier,
		// which is administered by the vendor identified by the OUI.
		// Value for the case of BHLI_UserSpecific is user defined and requires bilateral agreement between two end users. 		
		HighLayerInfo       : Array[0..7] of Byte; // the value dependent on the HighLayerInfoType field
	end;

//-------------------------------------------------------------
// A new address family, AF_ATM, is introduced for native ATM services,
// and the corresponding SOCKADDR structure, sockaddr_atm, is defined in the following.
// To open a socket for native ATM services, parameters in socket should contain
// AF_ATM, SOCK_RAW, and ATMPROTO_AAL5 or ATMPROTO_AALUSER, respectively.	
	sockaddr_atm = packed record
		// Identifies the address family, which is AF_ATM in this case.
		satm_family : u_short;
		// Identifies the ATM address that could be either in E.164 or NSAP-style ATM End Systems Address format.
		// This field will be mapped to the Called Party Number IE (Information Element)
		// if it is specified in bind and WSPBind for a listening socket, or in connect, WSAConnect, WSPConnect,
		// WSAJoinLeaf, or WSPJoinLeaf for a connecting socket.
		// It will be mapped to the Calling Party Number IE if specified in bind and WSPBind for a connecting socket.
		satm_number : ATM_ADDRESS;
		// Identifies the fields in the B-LLI Information Element that are used along with satm_bhli to identify an application.
		// Note that the B-LLI layer two information is treated as not present
		// if its Layer2Protocol field contains SAP_FIELD_ABSENT, or as a wildcard if it contains SAP_FIELD_ANY.
		// Similarly, the B-LLI layer three information is treated as not present
		// if its Layer3Protocol field contains SAP_FIELD_ABSENT, or as a wildcard if it contains SAP_FIELD_ANY. 		
		satm_blli   : ATM_BLLI;    // B-LLI
		// Identifies the fields in the B-HLI Information Element that are used along with satm_blli to identify an application.
		satm_bhli   : ATM_BHLI;    // B-HLI
	end;
	TSockAddrATM = sockaddr_atm;
	PSockAddrATM = ^TSockAddrATM;
	LPSockAddrATM = ^TSockAddrATM;
	PSOCKADDR_ATM = ^sockaddr_atm;
	LPSOCKADDR_ATM = ^sockaddr_atm;

//-------------------------------------------------------------
	Q2931_IE_TYPE = ( IE_AALParameters, IE_TrafficDescriptor,
		IE_BroadbandBearerCapability, IE_BHLI, IE_BLLI,IE_CalledPartyNumber,
		IE_CalledPartySubaddress, IE_CallingPartyNumber, IE_CallingPartySubaddress,
		IE_Cause, IE_QOSClass, IE_TransitNetworkSelection
	);

	Q2931_IE = record
		IEType   : Q2931_IE_TYPE;
		IELength : ULONG;
		IE       : Array[0..0] of Byte;
	end;
			
//-------------------------------------------------------------
// manifest constants for the AALType field in struct AAL_PARAMETERS_IE
	AAL_TYPE = LongInt;
const	
	AALTYPE_5    =  5; // AAL 5
	AALTYPE_USER = 16; // user-defined AAL
	
//-------------------------------------------------------------
// values used for the Mode field in struct AAL5_PARAMETERS
	AAL5_MODE_MESSAGE   = $01;
	AAL5_MODE_STREAMING = $02;

//-------------------------------------------------------------
// values used for the SSCSType field in struct AAL5_PARAMETERS
	AAL5_SSCS_NULL              = $00;
	AAL5_SSCS_SSCOP_ASSURED     = $01;
	AAL5_SSCS_SSCOP_NON_ASSURED = $02;
	AAL5_SSCS_FRAME_RELAY       = $04;

type
	AAL5_PARAMETERS = packed record
		ForwardMaxCPCSSDUSize  : ULONG;
		BackwardMaxCPCSSDUSize : ULONG;
		Mode     : Byte; // only available in UNI 3.0
		SSCSType : Byte;
	end;

	AALUSER_PARAMETERS = packed record
		UserDefined : ULONG;
	end;

	AAL_PARAMETERS_IE = packed record
		AALType : AAL_TYPE;
		AALSpecificParameters : packed record
		case Byte of
			 0 : ( AAL5Parameters    : AAL5_PARAMETERS );
			 1 : ( AALUserParameters : AALUSER_PARAMETERS );
		end;
	end;

	ATM_TD = packed record
		PeakCellRate_CLP0         : ULONG;
		PeakCellRate_CLP01        : ULONG;
		SustainableCellRate_CLP0  : ULONG;
		SustainableCellRate_CLP01 : ULONG;
		MaxBurstSize_CLP0         : ULONG;
		MaxBurstSize_CLP01        : ULONG;
		Tagging                   : LongBool;
	end;

	ATM_TRAFFIC_DESCRIPTOR_IE = packed record
		Forward    : ATM_TD;
		Backward   : ATM_TD;
		BestEffort : LongBool;
	end;
	
//-------------------------------------------------------------
// values used for the BearerClass field in struct ATM_BROADBAND_BEARER_CAPABILITY_IE
const
	BCOB_A = $01; // Bearer class A
	BCOB_C = $03; // Bearer class C
	BCOB_X = $10; // Bearer class X
	
//-------------------------------------------------------------
// values used for the TrafficType field in struct ATM_BROADBAND_BEARER_CAPABILITY_IE

	TT_NOIND = $00; // No indication of traffic type
	TT_CBR   = $04; // Constant bit rate
	TT_VBR   = $06; // Variable bit rate

//-------------------------------------------------------------
// values used for the TimingRequirements field in struct ATM_BROADBAND_BEARER_CAPABILITY_IE
	TR_NOIND         = $00; // No timing requirement indication
	TR_END_TO_END    = $01; // End-to-end timing required
	TR_NO_END_TO_END = $02; // End-to-end timing not required
	
//-------------------------------------------------------------
// values used for the ClippingSusceptability field in struct ATM_BROADBAND_BEARER_CAPABILITY_IE
	CLIP_NOT = $00; // Not susceptible to clipping
	CLIP_SUS = $20; // Susceptible to clipping

//-------------------------------------------------------------
// values used for the UserPlaneConnectionConfig field in struct ATM_BROADBAND_BEARER_CAPABILITY_IE
	UP_P2P  = $00; // Point-to-point connection
	UP_P2MP = $01; // Point-to-multipoint connection

type
	ATM_BROADBAND_BEARER_CAPABILITY_IE = packed record
		BearerClass : Byte;
		TrafficType : Byte;
		TimingRequirements        : Byte;
		ClippingSusceptability    : Byte;
		UserPlaneConnectionConfig : Byte;
	end;
	ATM_BHLI_IE = ATM_BHLI;

//-------------------------------------------------------------
// values used for the Layer2Mode field in struct ATM_BLLI_IE
const
	BLLI_L2_MODE_NORMAL = $40;
	BLLI_L2_MODE_EXT    = $80;

//-------------------------------------------------------------
// values used for the Layer3Mode field in struct ATM_BLLI_IE
	BLLI_L3_MODE_NORMAL = $40;
	BLLI_L3_MODE_EXT    = $80;

//-------------------------------------------------------------
// values used for the Layer3DefaultPacketSize field in struct ATM_BLLI_IE
	BLLI_L3_PACKET_16   = $04;
	BLLI_L3_PACKET_32   = $05;
	BLLI_L3_PACKET_64   = $06;
	BLLI_L3_PACKET_128  = $07;
	BLLI_L3_PACKET_256  = $08;
	BLLI_L3_PACKET_512  = $09;
	BLLI_L3_PACKET_1024 = $0A;
	BLLI_L3_PACKET_2048 = $0B;
	BLLI_L3_PACKET_4096 = $0C;
	
  // User information layer 2 protocol
  // User specified layer 2 protocol information
  // User information layer 3 protocol
  // User specified layer 3 protocol information
  // ISO/IEC TR 9577 Initial Protocol Identifier
  // SNAP ID consisting of OUI and PID

type
	
	ATM_BLLI_IE = record
		Layer2Protocol              : DWORD;
		Layer2Mode                  : Byte;
		Layer2WindowSize            : Byte;
		Layer2UserSpecifiedProtocol : DWORD;
		Layer3Protocol              : DWORD;
		Layer3Mode                  : Byte;
		Layer3DefaultPacketSize     : Byte;
		Layer3PacketWindowSize      : Byte;
		Layer3UserSpecifiedProtocol : DWORD;
		Layer3IPI                   : DWORD;
		SnapID       : Array[0..4] of Byte;
	end;
	ATM_CALLED_PARTY_NUMBER_IE = ATM_ADDRESS;
	ATM_CALLED_PARTY_SUBADDRESS_IE = ATM_ADDRESS;

//-------------------------------------------------------------
// values used for the Presentation_Indication field in struct ATM_CALLING_PARTY_NUMBER_IE
const
	PI_ALLOWED              = $00;
	PI_RESTRICTED           = $40;
	PI_NUMBER_NOT_AVAILABLE = $80;

//-------------------------------------------------------------
// values used for the Screening_Indicator field in struct ATM_CALLING_PARTY_NUMBER_IE
	SI_USER_NOT_SCREENED = $00;
	SI_USER_PASSED       = $01;
	SI_USER_FAILED       = $02;
	SI_NETWORK           = $03;

type
	ATM_CALLING_PARTY_NUMBER_IE = record
		ATM_Number              : ATM_ADDRESS;
		Presentation_Indication : Byte;
		Screening_Indicator     : Byte;
	end;
	ATM_CALLING_PARTY_SUBADDRESS_IE = ATM_ADDRESS;

//-------------------------------------------------------------
// values used for the Location field in struct ATM_CAUSE_IE
const
	CAUSE_LOC_USER                  = $00;
	CAUSE_LOC_PRIVATE_LOCAL         = $01;
	CAUSE_LOC_PUBLIC_LOCAL          = $02;
	CAUSE_LOC_TRANSIT_NETWORK       = $03;
	CAUSE_LOC_PUBLIC_REMOTE         = $04;
	CAUSE_LOC_PRIVATE_REMOTE        = $05;
	CAUSE_LOC_INTERNATIONAL_NETWORK = $06;
	CAUSE_LOC_BEYOND_INTERWORKING   = $0A;

//-------------------------------------------------------------
// values used for the Cause field in struct ATM_CAUSE_IE
	CAUSE_UNALLOCATED_NUMBER                = $01;
	CAUSE_NO_ROUTE_TO_TRANSIT_NETWORK       = $02;
	CAUSE_NO_ROUTE_TO_DESTINATION           = $03;
	CAUSE_VPI_VCI_UNACCEPTABLE              = $0A;
	CAUSE_NORMAL_CALL_CLEARING              = $10;
	CAUSE_USER_BUSY                         = $11;
	CAUSE_NO_USER_RESPONDING                = $12;
	CAUSE_CALL_REJECTED                     = $15;
	CAUSE_NUMBER_CHANGED                    = $16;
	CAUSE_USER_REJECTS_CLIR                 = $17;
	CAUSE_DESTINATION_OUT_OF_ORDER          = $1B;
	CAUSE_INVALID_NUMBER_FORMAT             = $1C;
	CAUSE_STATUS_ENQUIRY_RESPONSE           = $1E;
	CAUSE_NORMAL_UNSPECIFIED                = $1F;
	CAUSE_VPI_VCI_UNAVAILABLE               = $23;
	CAUSE_NETWORK_OUT_OF_ORDER              = $26;
	CAUSE_TEMPORARY_FAILURE                 = $29;
	CAUSE_ACCESS_INFORMAION_DISCARDED       = $2B;
	CAUSE_NO_VPI_VCI_AVAILABLE              = $2D;
	CAUSE_RESOURCE_UNAVAILABLE              = $2F;
	CAUSE_QOS_UNAVAILABLE                   = $31;
	CAUSE_USER_CELL_RATE_UNAVAILABLE        = $33;
	CAUSE_BEARER_CAPABILITY_UNAUTHORIZED    = $39;
	CAUSE_BEARER_CAPABILITY_UNAVAILABLE     = $3A;
	CAUSE_OPTION_UNAVAILABLE                = $3F;
	CAUSE_BEARER_CAPABILITY_UNIMPLEMENTED   = $41;
	CAUSE_UNSUPPORTED_TRAFFIC_PARAMETERS    = $49;
	CAUSE_INVALID_CALL_REFERENCE            = $51;
	CAUSE_CHANNEL_NONEXISTENT               = $52;
	CAUSE_INCOMPATIBLE_DESTINATION          = $58;
	CAUSE_INVALID_ENDPOINT_REFERENCE        = $59;
	CAUSE_INVALID_TRANSIT_NETWORK_SELECTION = $5B;
	CAUSE_TOO_MANY_PENDING_ADD_PARTY        = $5C;
	CAUSE_AAL_PARAMETERS_UNSUPPORTED        = $5D;
	CAUSE_MANDATORY_IE_MISSING              = $60;
	CAUSE_UNIMPLEMENTED_MESSAGE_TYPE        = $61;
	CAUSE_UNIMPLEMENTED_IE                  = $63;
	CAUSE_INVALID_IE_CONTENTS               = $64;
	CAUSE_INVALID_STATE_FOR_MESSAGE         = $65;
	CAUSE_RECOVERY_ON_TIMEOUT               = $66;
	CAUSE_INCORRECT_MESSAGE_LENGTH          = $68;
	CAUSE_PROTOCOL_ERROR                    = $6F;
	
//-------------------------------------------------------------
// values used for the Condition portion of the Diagnostics field
// in struct ATM_CAUSE_IE, for certain Cause values
	CAUSE_COND_UNKNOWN   = $00;
	CAUSE_COND_PERMANENT = $01;
	CAUSE_COND_TRANSIENT = $02;
	
//-------------------------------------------------------------
// values used for the Rejection Reason portion of the Diagnostics field
// in struct ATM_CAUSE_IE, for certain Cause values

	CAUSE_REASON_USER            = $00;
	CAUSE_REASON_IE_MISSING      = $04;
	CAUSE_REASON_IE_INSUFFICIENT = $08;
	
//-------------------------------------------------------------
// values used for the P-U flag of the Diagnostics field
// in struct ATM_CAUSE_IE, for certain Cause values
	CAUSE_PU_PROVIDER = $00;
	CAUSE_PU_USER     = $08;

//-------------------------------------------------------------
// values used for the N-A flag of the Diagnostics field
// in struct ATM_CAUSE_IE, for certain Cause values
	CAUSE_NA_NORMAL = $00;
	CAUSE_NA_ABNORMAL = $04;

type
	ATM_CAUSE_IE = record
		Location          : Byte;
		Cause             : Byte;
		DiagnosticsLength : Byte;
		Diagnostics       : Array[0..3] of Byte;
	end;
	
//-------------------------------------------------------------
// values used for the QOSClassForward and QOSClassBackward
// field in struct ATM_QOS_CLASS_IE
const
	QOS_CLASS0 = $00;
	QOS_CLASS1 = $01;
	QOS_CLASS2 = $02;
	QOS_CLASS3 = $03;
	QOS_CLASS4 = $04;

type
	ATM_QOS_CLASS_IE = packed record
		QOSClassForward  : Byte;
		QOSClassBackward : Byte;
	end;
	
//-------------------------------------------------------------
// values used for the TypeOfNetworkId field in struct ATM_TRANSIT_NETWORK_SELECTION_IE
const
	TNS_TYPE_NATIONAL = $40;

//-------------------------------------------------------------
// values used for the NetworkIdPlan field in struct ATM_TRANSIT_NETWORK_SELECTION_IE
	TNS_PLAN_CARRIER_ID_CODE = $01;

type
	ATM_TRANSIT_NETWORK_SELECTION_IE = record
		TypeOfNetworkId : Byte;
		NetworkIdPlan   : Byte;
		NetworkIdLength : Byte;
		NetworkId : Array[0..0] of Byte;
	end;
	
//-------------------------------------------------------------
// ATM specific Ioctl codes
const
	SIO_GET_NUMBER_OF_ATM_DEVICES = $50160001;
	SIO_GET_ATM_ADDRESS           = $d0160002;
	SIO_ASSOCIATE_PVC             = $90160003;
	SIO_GET_ATM_CONNECTION_ID     = $50160004; // ATM Connection Identifier

type
	ATM_CONNECTION_ID = packed record
		DeviceNumber : DWORD;
		VPI          : DWORD;
		VCI          : DWORD;
	end;
	
// Input buffer format for SIO_ASSOCIATE_PVC
	ATM_PVC_PARAMS = packed record
		PvcConnectionId : ATM_CONNECTION_ID;
		PvcQos          : QOS;
	end;


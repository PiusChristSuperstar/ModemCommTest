//
//  ArduinoResponse.h
//  SerialPortSample
//
//  Created by Pius Ott on 17/12/2024.
//  Copyright © 2024 WorldDom. All rights reserved.
//

#ifndef ArduinoResponse_h
#define ArduinoResponse_h

// Enum that defines the types of responses we can expect from the Arduino
typedef enum : NSUInteger {
    Unrecognised,   // not a valid response
    Ok,             // CTS:OK\n
    Error,          // CTS:ERROR \n
    Ready,          // CTS:READY\n
    AtCell          // CTS:ATCELL\n
} ArduinoResponse;

// String commands to send to the Arduino. All commands are prefixed with 'STC:'
#define CMD_NEXTCELL    "STC:NEXTCELL"  // Instruction to move to the next film cell
#define CMD_REWIND      "STC:REWIND"    // Instruction to rewind the film
#define CMD_MOTORON     "STC:MOTORON"   // Instruction to turn the main motor on
#define CMD_MOTOROFF    "STC:MOTOROFF"  // Instruction to turn the main motor off
#define CMD_PING        "STC:PING"      // Connection check sent to test if the Arduino is online
#define CMD_TESTOPTO    "STC:OPTIC"     // Run a test function to report the state of the optic sensor

// String responses we expect from the Arduino. All responses are prefixed with 'CTS:'
#define CMD_OK          "CTS:OK"        // Acknowledgement. To be sent as a response to each command
#define RSP_ERR         "CTS:ERROR: "   // Error response. Will be followed by an error code or text
#define CMD_READY       "CTS:READY"     // Sent when the Arduino is ready to receive instructions
#define CMD_ATCELL      "CTS:ATCELL"    // The film has been positioned and is ready for a photo capture


#endif /* ArduinoResponse_h */

//
//  SerialComms.h
//  SerialPortSample
//
//  Created by Pius Ott on 17/12/2024.
//  Copyright © 2024 WorldDom. All rights reserved.
//

#ifndef SerialComms_h
#define SerialComms_h

#import <string.h>
#import <sys/ioctl.h>
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <IOKit/IOKitLib.h>
#import <IOKit/serial/IOSerialKeys.h>
#import <IOKit/serial/ioss.h>
#import <IOKit/IOBSD.h>
#import <IOKit/usb/IOUSBLib.h>
#import <IOKit/IOCFPlugIn.h>

#import "Utilities.h"
#import "ArduinoResponse.h"

@interface SerialComms : NSObject

// Hold the original termios attributes so we can reset them
@property struct termios gOriginalTTYAttrs;
@property io_iterator_t serialPortIterator;
@property NSString *preferedPath;       // configured USB port. If not found, the app will try the first one available
@property int fileDescriptor;           // the file descriptor that we're using to read/write through

- (id)init:(NSString *)preferedPath;

// Function prototypes
//- (kern_return_t) findSerialPorts:(io_iterator_t *)matchingServices;
- (kern_return_t) findSerialPorts;

//- (kern_return_t) getModemPath:(io_iterator_t) serialPortIterator defaultPath:(NSString **)preferredPort;
- (kern_return_t) findUsbPath;

- (NSString *) usbPath;

// TODO : make the fileDescriptor a class property
- (int)openSerialPort;

- (void)closeSerialPort;

- (Boolean) isArduinoOnline;

- (ArduinoResponse) readSerialCommand;


/*
 I'll try to explain what you have here,
 -(NSInteger) pickerView:(UIPickerView*)pickerView numberOfRowsInComponent:(NSInteger)component.

 - (NSInteger)
 This first portion indicates that this is an Objective C instance method that returns a NSInteger object. the - (dash) indicates that this is an instance method, where a + would indicate that this is a class method. The first value in parenthesis is the return type of the method.

 pickerView:
 This portion is a part of the message name. The full message name in this case is pickerView:numberOfRowsInComponent:. The Objective-C runtime takes this method information and sends it to the indicated receiver. In pure C, this would look like
 NSInteger pickerView(UIPickerView* pickerView, NSInteger component). However, since this is Objective-C, additional information is packed into the message name.

 (UIPickerView*)pickerView
 This portion is part of the input. The input here is of type UIPickerView* and has a local variable name of pickerView.

 numberOfRowsInComponent:
 This portion is the second part of the message name. As you can see here, message names are split up to help indicate what information you are passing to the receiver. Thus, if I were to message an object myObject with the variables foo and bar, I would type:
 [myObject pickerView:foo numberOfRowsInComponent:bar];
 as opposed to C++ style:
 myObject.pickerView(foo, bar);.

 (NSInteger)component
 This is the last portion of the input. the input here is of type NSInteger and has a local variable name of component.
 
 */



@end

#endif /* SerialComms_h */

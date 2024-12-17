//
//  SerialComms.m
//  Handles the communication via the USB serial port
//
//  Created by Pius Ott on 17/12/2024.
//  Copyright © 2024 WorldDom. All rights reserved.
//

#import "SerialComms.h"

@implementation SerialComms

// -------------------------------------------------------------------------------------------

- (instancetype)init:(NSString *)preferredPort
{
    self = [super init];
    if (self)
    {
        _preferedPath = preferredPort;
        //IOObjectRelease(serialPortIterator);  // I doubt this is needed
    }
    return self;
}

// -------------------------------------------------------------------------------------------

// After running 'findSerialPorts' and 'getUsbPath' we should have a valid USB serial path.
// This function opens that port for reading and writing.
// Return the file descriptor associated with the device.
/// - Tag: openSerialPortFunction
// PTO : For the time being I'm just using 9600 Baud, because that's what the Arduino defaults to
- (int)openSerialPort
//- (int)openSerialPort:(NSString *)portPath
{
    int fileDescriptor = -1;
    int handshake;
    struct termios options;
    NSString *lastError = @"";
    
    
    // The port functions require a char array, so convert the NSString
    const char *cPortPath = [_preferedPath UTF8String];
    
    // Open the serial port read/write, with no controlling terminal, and don't wait for a connection.
    // The O_NONBLOCK flag also causes subsequent I/O on the device to be non-blocking.
    // See open(2) <x-man-page://2/open> for details.
    fileDescriptor = open(cPortPath, O_RDWR | O_NOCTTY | O_NONBLOCK);
    if (fileDescriptor == -1)
    {
        NSLog(@"Error opening serial port %@ - %s(%d).\n", _preferedPath, strerror(errno), errno);
        goto error;
    }

    // Note that open() follows POSIX semantics: multiple open() calls to the same file will succeed
    // unless the TIOCEXCL ioctl is issued. This will prevent additional opens except by root-owned
    // processes.
    // See tty(4) <x-man-page//4/tty> and ioctl(2) <x-man-page//2/ioctl> for details.
    if (ioctl(fileDescriptor, TIOCEXCL) == -1)
    {
        NSLog(@"Error setting TIOCEXCL on %@ - %s(%d).\n", _preferedPath, strerror(errno), errno);
        goto error;
    }
    
    // Now that the device is open, clear the O_NONBLOCK flag so subsequent I/O will block.
    // See fcntl(2) <x-man-page//2/fcntl> for details.
    if (fcntl(fileDescriptor, F_SETFL, 0) == -1)
    {
        NSLog(@"Error clearing O_NONBLOCK %@ - %s(%d).\n", _preferedPath, strerror(errno), errno);
        goto error;
    }
    
    // Get the current options and save them so we can restore the default settings later.
    if (tcgetattr(fileDescriptor, &_gOriginalTTYAttrs) == -1)
    {
        NSLog(@"Error getting tty attributes %@ - %s(%d).\n", _preferedPath, strerror(errno), errno);
        goto error;
    }
    
    // The serial port attributes such as timeouts and baud rate are set by modifying the termios
    // structure and then calling tcsetattr() to cause the changes to take effect. Note that the
    // changes will not become effective without the tcsetattr() call.
    // See tcsetattr(4) <x-man-page://4/tcsetattr> for details.
    options = _gOriginalTTYAttrs;
    
    // Print the current input and output baud rates.
    // See tcsetattr(4) <x-man-page://4/tcsetattr> for details.
    
    NSLog(@"Current input baud rate is %d\n", (int) cfgetispeed(&options));
    NSLog(@"Current output baud rate is %d\n", (int) cfgetospeed(&options));
    
    // Set raw input (non-canonical) mode, with reads blocking until either a single character
    // has been received or a one second timeout expires.
    // See tcsetattr(4) <x-man-page://4/tcsetattr> and termios(4) <x-man-page://4/termios> for details.
    cfmakeraw(&options);
    options.c_cc[VMIN] = 0;     // minimum characters to read
    options.c_cc[VTIME] = 10;   // time out (10 = 1sec) before we give up
    
    // The baud rate, word length, and handshake options can be set as follows:
    cfsetspeed(&options, B9600);        // Set 9600 baud
/*    options.c_cflag |= (CS8        |     // Use 8 bit words
                        PARENB       |     // Parity enable (even parity if PARODD not also set)
                        CCTS_OFLOW |     // CTS flow control of output
                        CRTS_IFLOW);    // RTS flow control of input
 */
    /*
     PTO: Disabled. I only want 9600 baud for the moment
    
    // The IOSSIOSPEED ioctl can be used to set arbitrary baud rates
    // other than those specified by POSIX. The driver for the underlying serial hardware
    // ultimately determines which baud rates can be used. This ioctl sets both the input
    // and output speed.
    speed_t speed = 14400; // Set 14400 baud
    if (ioctl(fileDescriptor, IOSSIOSPEED, &speed) == -1)
    {
        printf("Error calling ioctl(..., IOSSIOSPEED, ...) %s - %s(%d).\n",
               bsdPath, strerror(errno), errno);
    }
    */
    
    // Print the new input and output baud rates. Note that the IOSSIOSPEED ioctl interacts with the serial driver
    // directly bypassing the termios struct. This means that the following two calls will not be able to read
    // the current baud rate if the IOSSIOSPEED ioctl was used but will instead return the speed set by the last call
    // to cfsetspeed.
    NSLog(@"Input baud rate changed to %d\n", (int) cfgetispeed(&options));
    NSLog(@"Output baud rate changed to %d\n", (int) cfgetospeed(&options));
    
    // Cause the new options to take effect immediately.
    if (tcsetattr(fileDescriptor, TCSANOW, &options) == -1)
    {
        lastError = [NSString stringWithFormat:@"Error setting tty attributes %@ - %s(%d).", _preferedPath, strerror(errno), errno];
        NSLog(@"%@", lastError);
        goto error;
    }
    
    // To set the modem handshake lines, use the following ioctls.
    // See tty(4) <x-man-page//4/tty> and ioctl(2) <x-man-page//2/ioctl> for details.
    
    // Assert Data Terminal Ready (DTR)
    if (ioctl(fileDescriptor, TIOCSDTR) == -1)
    {
        lastError = [NSString stringWithFormat:@"Error asserting DTR %@ - %s(%d).", _preferedPath, strerror(errno), errno];
        NSLog(@"%@", lastError);
    }
    
    // Clear Data Terminal Ready (DTR)
    if (ioctl(fileDescriptor, TIOCCDTR) == -1)
    {
        lastError = [NSString stringWithFormat:@"Error clearing DTR %@ - %s(%d).", _preferedPath, strerror(errno), errno];
        NSLog(@"%@", lastError);
    }
    
    // Set the modem lines depending on the bits set in handshake
    handshake = TIOCM_DTR | TIOCM_RTS | TIOCM_CTS | TIOCM_DSR;
    if (ioctl(fileDescriptor, TIOCMSET, &handshake) == -1)
    {
        lastError = [NSString stringWithFormat:@"Error setting handshake lines %@ - %s(%d).", _preferedPath, strerror(errno), errno];
        NSLog(@"%@", lastError);
    }
    
    // To read the state of the modem lines, use the following ioctl.
    // See tty(4) <x-man-page//4/tty> and ioctl(2) <x-man-page//2/ioctl> for details.
    
    // Store the state of the modem lines in handshake
    if (ioctl(fileDescriptor, TIOCMGET, &handshake) == -1)
    {
        lastError = [NSString stringWithFormat:@"Error getting handshake lines %@ - %s(%d).", _preferedPath, strerror(errno), errno];
        NSLog(@"%@", lastError);
    }
    
    NSLog(@"Handshake lines currently set to %d\n", handshake);
    
    unsigned long mics = 1UL;
    
    // Set the receive latency in microseconds. Serial drivers use this value to determine how often to
    // dequeue characters received by the hardware. Most applications don't need to set this value: if an
    // app reads lines of characters, the app can't do anything until the line termination character has been
    // received anyway. The most common applications which are sensitive to read latency are MIDI and IrDA
    // applications.
    if (ioctl(fileDescriptor, IOSSDATALAT, &mics) == -1)
    {
        // set latency to 1 microsecond
        lastError = [NSString stringWithFormat:@"Error setting read latency %@ - %s(%d).", _preferedPath, strerror(errno), errno];
        NSLog(@"%@", lastError);
        goto error;
    }
    
    // Success
    return fileDescriptor;
    
    // Failure path
error:
    if (fileDescriptor != -1)
    {
        close(fileDescriptor);
    }
    
    return -1;
}

// -------------------------------------------------------------------------------------------

// Given the file descriptor for a serial device, close that device.
- (void)closeSerialPort:(int)fileDescriptor
{
    // Block until all written output has been sent from the device.
    // Note that this call is simply passed on to the serial device driver.
    // See tcsendbreak(3) <x-man-page://3/tcsendbreak> for details.
    if (tcdrain(fileDescriptor) == -1)
    {
        NSLog(@"Error waiting for drain - %s(%d).", strerror(errno), errno);
    }
    
    // Traditionally it is good practice to reset a serial port back to
    // the state in which you found it. This is why the original termios struct
    // was saved.
    if (tcsetattr(fileDescriptor, TCSANOW, &_gOriginalTTYAttrs) == -1)
    {
        NSLog(@"Error resetting tty attributes - %s(%d).", strerror(errno), errno);
    }

    close(fileDescriptor);
}

// ------------------------------------------------------------------------------------------------


//- (kern_return_t) findSerialPorts:(io_iterator_t *)matchingServices
- (kern_return_t) findSerialPorts
{
    kern_return_t kernResult;
    CFMutableDictionaryRef classesToMatch;
    
    // Serial devices are instances of class IOSerialBSDClient.
    // Create a matching dictionary to find those instances.

    // Each serial device object has a property with key
    // kIOSerialBSDTypeKey and a value that is one of kIOSerialBSDAllTypes,
    // kIOSerialBSDModemType, or kIOSerialBSDRS232Type. You can experiment with the
    // matching by changing the last parameter in the above call to CFDictionarySetValue.
    
    // As shipped, this sample is only interested in modems,
    // so add this property to the CFDictionary we're matching on.
    // This will find devices that advertise themselves as modems,
    // such as built-in and USB modems. However, this match won't find serial modems.
    classesToMatch = IOServiceMatching(kIOSerialBSDServiceValue);
    if (classesToMatch == NULL)
    {
        NSLog(@"IOServiceMatching returned a NULL dictionary.");
    }
    else
    {
        // Look for devices that claim to be USB ports.
        CFDictionarySetValue(classesToMatch,
                             CFSTR(kIOSerialBSDTypeKey),
                             CFSTR(kIOSerialBSDModemType));
    }
    
    // Get an iterator across all matching devices.
    kernResult = IOServiceGetMatchingServices(kIOMainPortDefault, classesToMatch, &_serialPortIterator);
    if (KERN_SUCCESS != kernResult)
    {
        NSLog(@"IOServiceGetMatchingServices returned %d", kernResult);
        goto exit;
    }
    
exit:
    return kernResult;
}

// -------------------------------------------------------------------------------------------

// Find the modem path. If we have been passed in a preferredPort value then we check the available paths
// to see if it exists and return success if so. If no preferredPort has been passed then we simply
// return the first path found and assign the value to preferredPort.
// If no valid ports are found the path name is set to an empty string.
// We assume that 'findSerialPorts' has been run before which has initialised '_serialPortIterator'
//- (kern_return_t) getModemPath:(io_iterator_t) serialPortIterator defaultPath:(NSString **)preferredPort
- (kern_return_t) getUsbPath
{
    io_object_t modemService;
    kern_return_t kernResult = KERN_FAILURE;
    Boolean modemFound = false;
       
    // Iterate across all modems found. In this example, we bail after finding the first modem.
    while ((modemService = IOIteratorNext(_serialPortIterator)) && !modemFound)
    {
        CFTypeRef bsdPathAsCFString;
        
        // Get the USB port's device's path (/dev/cu.xxxxx). We will need this to open the port later on
        bsdPathAsCFString = IORegistryEntryCreateCFProperty(modemService,
                                                            CFSTR(kIOCalloutDeviceKey),
                                                            kCFAllocatorDefault,
                                                            0);
        if (bsdPathAsCFString)
        {
            // [MyClass aClassMethod];
            
            NSString *discoveredPort = [Utilities convertCFTypeRefToNSString:bsdPathAsCFString];
            Boolean result = false;

            if (_preferedPath)
            {
                if( [discoveredPort caseInsensitiveCompare:_preferedPath] == NSOrderedSame )
                {
                    // Assign the preferredPort name with the one we've found, just in case the case of the passed in string
                    // was incorrect. Then break out of loop
                    _preferedPath = discoveredPort;
                    result = true;
                }
            }
            else
            {
                // No preferred port, we just return the first one we've found
                _preferedPath = [Utilities convertCFTypeRefToNSString:bsdPathAsCFString];
                result = true;
            }
            
            CFRelease(bsdPathAsCFString);

            if (result)
            {
                NSLog(@"Modem found with BSD path: %@", discoveredPort);
                modemFound = true;
                kernResult = KERN_SUCCESS;
            }
        }
        
        // Release the io_service_t now that we are done with it.
        (void) IOObjectRelease(modemService);
    }
    
    IOObjectRelease(_serialPortIterator);
    
    return kernResult;
}

// -------------------------------------------------------------------------------------------

- (NSString *) usbPath
{
    return _preferedPath;
}

// -------------------------------------------------------------------------------------------

// Given the file descriptor for the USB port where the Arduino is plugged in, check if we can
// communicate with it. If comms has been established and the Arduino is ready to receive
// instructions, return true.
- (Boolean) isArduinoOnline:(int) fileDescriptor
{
    char buffer[256];    // Input buffer
    char *bufPtr;        // Current char in buffer
    ssize_t numBytes;        // Number of bytes read or written
    int tries;            // Number of tries so far
    Boolean  result = false;
    const int retries = 3;      // Number of attemps we make to try and talk to the Arduino
    ArduinoResponse response = Unrecognised;

    // First check if there is anything in the buffer. This is likely the case. After opening the USB port, the
    // Arduino sends at least a CMD_READY notification
    bufPtr = buffer;
    numBytes = read(fileDescriptor, bufPtr, &buffer[sizeof(buffer)] - bufPtr - 1);
    
    if (numBytes == -1)
    {
        NSLog(@"%@", [NSString stringWithFormat:@"Error reading from Arduino - %s(%d).", strerror(errno), errno]);
    }
    else if (numBytes > 0)
    {
        NSLog(@"Buffer cleared. Contained [%s]", [Utilities logString:buffer]);
    }
    
    for (tries = 1; tries <= retries; tries++)
    {
        NSLog(@"Try #%d", tries);
        
        // Send a ping to the Arduino
        numBytes = write(fileDescriptor, CMD_PING, strlen(CMD_PING));
        if (numBytes == -1)
        {
            NSLog(@"%@", [NSString stringWithFormat:@"Error writing to Arduino - %s(%d).", strerror(errno), errno]);
            continue;
        }
        else
        {
            NSLog(@"Wrote %ld bytes [%s]", numBytes, [Utilities logString:CMD_PING]);
        }
        
        if (numBytes < strlen(CMD_PING))
        {
            continue;
        }
        
        // TODO: this is not good. We should really use the read command with a timeout
        usleep(1000000);    // Give the Arduino time to respond
        
        NSLog(@"Looking for [%s]", [Utilities logString:CMD_OK]);
        
        ///TODO: Normally we still have the CTS:READY in our buffer first, which the Arduino sends after opening the port.
        ///So most buffers on first read look something like "CTS:READY\nCTS:READY\nCTS:OK\n". We need to decipher this properly.

        response = [self readSerialCommand:fileDescriptor];
        if (response == Ok)
        {
            result = true;
            break;
        }
    }
    
    return result;
}

// -------------------------------------------------------------------------------------------

// Read a command from the USB port. Commands (or responses) are terminated by a NewLine character.
// We assume that the port has been opened successfully by this stage.
-(ArduinoResponse) readSerialCommand:(int)fileDescriptor
{
    char buffer[256];       // Input buffer
    char *bufPtr;           // Current char in buffer
    ssize_t numBytes;       // Number of bytes read or written
    ArduinoResponse response = Unrecognised;
    
    // Read characters into our buffer until we get a newline
    bufPtr = buffer;
    do
    {
        numBytes = read(fileDescriptor, bufPtr, &buffer[sizeof(buffer)] - bufPtr - 1);
        if (numBytes == -1)
        {
            NSLog(@"%@", [NSString stringWithFormat:@"Error reading from port - %s(%d).", strerror(errno), errno]);
        }
        else if (numBytes > 0)
        {
            bufPtr += numBytes;
            // NewLine indicates end of the Arduino response, we have received a full response
            if (*(bufPtr - 1) == '\n' || *(bufPtr - 1) == '\r')
            {
                // exit do-while loop
                break;
            }
        }
        else
        {
            NSLog(@"Nothing read.");
        }
    } while (numBytes > 0);
    
    // NUL terminate the string and find out which response we've received
    *bufPtr = '\0';
    NSLog(@"Read [%s]", [Utilities logString:buffer]);
    
    response = [Utilities translateResponse:buffer];
    return response;
}

// -------------------------------------------------------------------------------------------
// -------------------------------------------------------------------------------------------

@end

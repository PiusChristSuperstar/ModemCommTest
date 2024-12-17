 /*
See LICENSE folder for this sample’s licensing information.

Abstract:
Command line tool that demonstrates how to use IOKitLib to find all serial ports on macOS.
*/

#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <paths.h>
#include <sysexits.h>
#include <sys/param.h>
#include <sys/select.h>
#include <sys/time.h>
#include <time.h>
#include <Foundation/Foundation.h>
#include <CoreFoundation/CoreFoundation.h>

#import "SerialBuffer.h"
#import "SerialComms.h"
#import "ArduinoResponse.h"

// The file that holds the instructions and configuration for our app
#define SETTINGS_FILE "/Users/Pius/dev/XCode/ModemCommTest/settings.xcconfig"

// -------------------------------------------------------------------------------------------------

// Arduino Vendor and Product ID. These are identifier we can use to open the appropriate port that
// the Arduino is currently plugged in.
// TODO: These are probably not needed. This only works for Custom USB devices, not serial port ones like the Arduino
#define kMyVendorID         0x10c4
#define kMyProductID        0xea60
 

// ------------------------------------------------------------------------------------------------
// Background thread that reads data from the USB serial (i.e. the Arduino) and populates a buffer
@interface FileReader : NSObject
@property (nonatomic, strong) dispatch_queue_t backgroundQueue;
@property (nonatomic, assign) BOOL shouldContinueReading;
@property (nonatomic, strong) NSString *filePath;
- (instancetype)initWithFilePath:(NSString *)filePath;
- (void)startReading;
- (void)stopReading;
@end

// ------------------------------------------------------------------------------------------------

static int gCurrentState;               // the current state of the port.
static NSString *gLastError = @"";      // most recent error message

// settings values, initialised to default but can be overridden by values found in the SETTINGS_FILE
static NSInteger gCellsToRead = 10;             // how many film cells to scan. This is just used for testing during development
static NSString *gUsbPort = @"/dev/cu.usbserial-0001";  // USB port to communicate with the Arduino

static NSString *gLogName = @"ScanBrain.log";           // Log file to use. Filename only. Log file will be in the Documents folder

static NSString *gImageLocation = @"~/ScanBrain/Images";    // Location of where to store the captured photos

static NSInteger gCapturePause = 2;     // How long to pause (in seconds) after sending Arduino instructions. This gives the
                                        // Arduino time to process what has been received. But I'm also using this during development
                                        // to simulate a delay during the photo capture

// ------------------------------------------------------------------------------------------------
// ------------------------------------------------------------------------------------------------

// Interface implementation. This runs the background thread reading serial data received from the
// Arduino via USB
@implementation FileReader

- (instancetype)initWithFilePath:(NSString *)filePath
{
    self = [super init];
    if (self)
    {
        _filePath = filePath;
        _shouldContinueReading = YES;
        _backgroundQueue = dispatch_queue_create("com.example.filereader", DISPATCH_QUEUE_CONCURRENT);
    }
    return self;
}

// ------------------------------------------------------------------------------------------------

- (void)startReading
{
    // TODO: This is currently attempting to read from a file. Change this to read from the USB serial port
    // TODO: Also create a buffer that we'll write the data to.
    // TODO: Add another function to clear the buffer. This needs to be accessed (and probably defined) outside
    //       of this interface. But make sure we don't clash with any current writes.
    dispatch_async(self.backgroundQueue, ^{
        @autoreleasepool {
            // Open the file for reading
            NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath:self.filePath];
            if (!fileHandle)
            {
                NSLog(@"Failed to open file at path: %@", self.filePath);
                return;
            }

            // Continuously read data from the file
            while (self.shouldContinueReading)
            {
                NSData *data = [fileHandle readDataOfLength:1024]; // Read 1 KB at a time
                if (data.length == 0)
                {
                    [NSThread sleepForTimeInterval:0.1]; // Pause if EOF is reached
                    continue;
                }

                // Process the data (or store it in a buffer)
                NSString *stringData = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                NSLog(@"Read data: %@", stringData);
                
                // Simulate processing delay
                [NSThread sleepForTimeInterval:0.1];
            }

            // Close the file when done
            [fileHandle closeFile];
        }
    });
}

// ------------------------------------------------------------------------------------------------

- (void)stopReading
{
    self.shouldContinueReading = NO;
}

// ------------------------------------------------------------------------------------------------

@end

// ------------------------------------------------------------------------------------------------
// ------------------------------------------------------------------------------------------------

/// Load the configuration settings. If no file is defined, or the file could not be opened, we just use default values.
static void readSettings(void)
{
    NSError *error = nil;
    NSString *fileContents = [NSString stringWithContentsOfFile:@SETTINGS_FILE encoding:NSUTF8StringEncoding error:&error];

    if (error)
    {
        NSLog(@"Error reading config file: [%@] - using default configurations instead", error.localizedDescription);
        return;
    }

    // split all lines into an array
    NSArray *configLines = [fileContents componentsSeparatedByString:@"\n"];
    
    for (int i = 0; i < configLines.count; i++)
    {
        if ([configLines[i] hasPrefix:@"//"])
        {
            // Comment line, ignore it
        }
        else
        {
            NSArray *components = [configLines[i] componentsSeparatedByString:@"="];
            
            // Ensure there are exactly two components
            if (components.count == 2)
            {
                NSString *settingName = [components[0] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                NSString *valueWithQuotes = components[1];
                
                // Strip the single quotes and line end from the value
                NSString *settingValue = [valueWithQuotes stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"'\n"]];
                
                NSLog(@"Setting: %@, Value: %@\n", settingName, settingValue);
                if ([settingName isEqualToString:@"CELLS_TO_READ"])
                {
                    gCellsToRead = [Utilities getNumberFromString:settingValue];
                }
                else if ([settingName isEqualToString:@"CAPTURE_PAUSE"])
                {
                    gCapturePause = [Utilities getNumberFromString:settingValue];
                }
                else if ([settingName isEqualToString:@"USB_PORT"])
                {
                    gUsbPort = settingValue;
                }
                else if ([settingName isEqualToString:@"LOGFILE_NAME"])
                {
                    gLogName = settingValue;
                }
                else if ([settingName isEqualToString:@"IMAGE_LOCATION"])
                {
                    gImageLocation = settingValue;
                }
            }
            else
            {
                //NSLog(@"The input string [%@] is invalid", configLine);
            }
        }
    }
}

// ------------------------------------------------------------------------------------------------

// Function to continually read data from the serial port and store it in a buffer array. This
// is running in a separate thread
static void readToSerialBuffer(int fileDescriptor)
{
    
}

// ------------------------------------------------------------------------------------------------


/// Run a single scan of a film cell. We first move the film to the NEXTCELL and then run the capture and store the image
void scanPhoto(int fileDescriptor, SerialComms *serialComms)
{
    char        buffer[256];    // Input buffer
    char        *bufPtr;        // Current char in buffer
    ssize_t        numBytes;        // Number of bytes read or written
    Boolean        result = false;
    ArduinoResponse response = Unrecognised;

    // First check if there is anything in the buffer. This is likely the case. After opening the USB port, the
    // Arduino sends at least a CMD_READY notification
    bufPtr = buffer;
/*    numBytes = read(fileDescriptor, bufPtr, &buffer[sizeof(buffer)] - bufPtr - 1);
    
    if (numBytes == -1)
    {
        gLastError = [NSString stringWithFormat:@"Error reading from Arduino - %s(%d).", strerror(errno), errno];
        NSLog(@"%@", gLastError);
    }
    else if (numBytes > 0)
    {
        NSLog(@"Buffer cleared. Contained [%s]", logString(buffer));
    }
  */
    // Tell the Arduino to move to the next cell
    numBytes = write(fileDescriptor, CMD_NEXTCELL, strlen(CMD_NEXTCELL));
    if (numBytes == -1)
    {
        gLastError = [NSString stringWithFormat:@"Error writing to Arduino - %s(%d).", strerror(errno), errno];
        NSLog(@"%@", gLastError);
    }
    else
    {
        NSLog(@"Wrote %ld bytes [%s]", numBytes, [Utilities logString:CMD_NEXTCELL]);
    }
        
        
        // TODO: this is not good. We should really use the read command with a timeout
        usleep((int)gCapturePause * 1000000);    // Give the Arduino time to respond
        
        NSLog(@"Looking for [%s]", [Utilities logString:CMD_OK]);
        
        ///TODO: Normally we still have the CTS:READY in our buffer first, which the Arduino sends after opening the port.
        ///So most buffers on first read look something like "CTS:READY\nCTS:READY\nCTS:OK\n". We need to decipher this properly.
/*
 Read [Log: Moving to next cell.\nLog: Turning motor on to move to next cell\nLog: Starting clutch.\nERROR: Timeout while moving to next cell. Stopping clutch.\nCTS:OK\n]
 
 Read [Log: sensorLowCount: 2\nCTS:ATCELL\nLog: We're at the next cell. Stopping clutch.\nCTS:OK\nLog: Moving to next cell.\nLog: Turning motor on to move to next cell\nLog: Starting clutch.\n]
 */
    
    response = [serialComms readSerialCommand:fileDescriptor];
        if (response == Ok)
        {
            result = true;
            // TODO :  Ok, now we can run the photo capture....
        }
}

// ------------------------------------------------------------------------------------------------

/// Function that handles the scanning of film cells. We do this by issuing a NEXTCELL command to the Arduino to move
/// the film to the next cell, then do a photo capture and store the image.
/// We assume that the Arduino is available to receive commands at this point and that the camera has been initalised
void runScanning(int fileDescriptor, SerialComms *serialComms)
{
    for(int i = 0; i < gCellsToRead; i++)
    {
        scanPhoto(fileDescriptor, serialComms);
    }
}

// ------------------------------------------------------------------------------------------------

/// Redirect the NSLog output to our log file instead of the console
void redirectConsoleLogToDocumentFolder(void)
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *logPath = [documentsDirectory stringByAppendingPathComponent:gLogName];
    freopen([logPath fileSystemRepresentation],"a+",stderr);
}

// ------------------------------------------------------------------------------------------------

int main(int argc, const char * argv[])
{
    int             fileDescriptor;
    kern_return_t	kernResult;
    //NSString *preferedPath = gUsbPort;      // configured USB port. If not found, the app will try the first one available
    
    // Uncomment this to use a log file instead of the console log
    //redirectConsoleLogToDocumentFolder();
    
    readSettings();     // load the configurations

    // clear error string buffer
    gLastError = @"";
    gCurrentState = 0;   // TODO : work out error and success state values

    /* Remove me
    @autoreleasepool
    {
        SerialBuffer *receiveBuffer = [[SerialBuffer alloc] init];
        [receiveBuffer enqueue:@"testing"];
        [receiveBuffer enqueue:@"item 2"];
        [receiveBuffer enqueue:@"third thing"];
        NSUInteger i = receiveBuffer.size;
        NSLog(@"receiveBuffer initialised and it holds [%ld] items", i);
        while (receiveBuffer.size > 0)
        {
            NSLog(@"receiveBuffer held [%@]", receiveBuffer.dequeue);
        }
        NSLog(@"receiveBuffer item  and it holds [%ld] items", receiveBuffer.size);
//        SerialBuffer *buff = [[SerialBuffer alloc] initWithName:@"Carol"];
//         [buff greet];
    }
    */
    
    @autoreleasepool
    {
        SerialComms *serialComms = [[SerialComms alloc] init: gUsbPort];
        
        //kernResult = [serialComms findSerialPorts: &serialPortIterator];
        kernResult = [serialComms findSerialPorts];
        if (KERN_SUCCESS != kernResult)
        {
            gCurrentState = EX_UNAVAILABLE;
            gLastError = @"No USB ports were found";
            NSLog(@"%@", gLastError);
        }
        
        NSLog(@"Before: %@", [serialComms usbPath]);
        //kernResult = [serialComms getModemPath: serialPortIterator defaultPath: &preferedPath];
        kernResult = [serialComms getUsbPath];
        NSLog(@"After: %@", [serialComms usbPath]);
        if (KERN_SUCCESS != kernResult)
        {
            gCurrentState = EX_UNAVAILABLE;
            gLastError = @"Could not get path for USB";
            NSLog(@"%@", gLastError);
        }

        if (![serialComms usbPath])
        {
            gLastError = @"No USB port found";
            NSLog(@"%@", gLastError);
            gCurrentState = EX_UNAVAILABLE;
            return EX_UNAVAILABLE;
        }
        
        // Now open the port we found and check whether we have an Arduino responding
        fileDescriptor = [serialComms openSerialPort];
        if (-1 == fileDescriptor)
        {
            gCurrentState = EX_IOERR;
            gLastError = @"Failed opening USB port";
            NSLog(@"%@", gLastError);
            return EX_IOERR;
        }

        // TODO: replace this with a loop where we wait for CTS:READY
        NSLog(@"Sleeping for [%ld] seconds to allow Arduino to initialise.", gCapturePause);
        usleep((int)gCapturePause * 1000000);
        
        if ([serialComms isArduinoOnline:fileDescriptor])
        {
            NSLog(@"Arduino is online and ready to receive commands.");
            runScanning(fileDescriptor, serialComms);  // We're ready to go, start scanning
        }
        else
        {
            gLastError = @"Could not talk to Arduino.";
            NSLog(@"%@", gLastError);
            gCurrentState = EX_IOERR;
        }
        
        [serialComms closeSerialPort:fileDescriptor];
        NSLog(@"Modem port closed.");
    }
    
    return 0;
     /*
    ////// testing 2
    ///test reading a file in a background thread while we do other things
    @autoreleasepool {
        //FileReader *reader = [[FileReader alloc] initWithFilePath:@"/path/to/your/file.txt"];
        FileReader *reader = [[FileReader alloc] initWithFilePath:@"/Users/pius/Public/FreeForAll/filmScanner.py"];
        [reader startReading];
        
        // Simulate doing other work on the main thread
        [NSThread sleepForTimeInterval:5.0]; // Run for 5 seconds
        
        [reader stopReading];
        NSLog(@"Stopped reading file.");
    }
    return 0;
    */
    
    /*
     Note: This does not work. This method does not use the USB port to emulate a serial port. I'm leaving it in for the moment,
     but will eventually delete it if it really looks like I can't use it. There may still be ways to utilise parts of it.
    ////// testing
    IOUSBDeviceInterface ** devInterface = newFindAndOpenUSBPort();
    sendData(devInterface);
    receiveData(devInterface);
    closeUSBPort(devInterface);
    return 0;
    */
    
    /* remove me
    kernResult = findSerialPorts(&serialPortIterator);
    if (KERN_SUCCESS != kernResult)
    {
        gCurrentState = EX_UNAVAILABLE;
        gLastError = @"No USB ports were found";
        NSLog(@"%@", gLastError);
    }
    
    NSLog(@"Before: %@", preferedPath);
    kernResult = getModemPath(serialPortIterator, &preferedPath);
    NSLog(@"After: %@", preferedPath);
    if (KERN_SUCCESS != kernResult)
    {
        gCurrentState = EX_UNAVAILABLE;
        gLastError = @"Could not get path for USB";
        NSLog(@"%@", gLastError);
    }
    
    IOObjectRelease(serialPortIterator);	// Release the iterator.
    */

    
    
    
    return EX_OK;
}

// ------------------------------------------------------------------------------------------------




// ------------------------------------------------------------------------------------------------


//
//  Utilities.m
//  SerialPortSample
//
//  Created by Pius Ott on 17/12/2024.
//  Copyright © 2024 Apple. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "Utilities.h"

@implementation Utilities

// -------------------------------------------------------------------------------------------

+(NSString *)convertCFTypeRefToNSString:(CFTypeRef)cfType
{
    if (CFGetTypeID(cfType) == CFStringGetTypeID())
    {
        // It's a CFStringRef, cast it to CFStringRef
        CFStringRef cfString = (CFStringRef)cfType;

        // Convert CFStringRef to NSString
        return (__bridge NSString *)cfString;
    }
    else
    {
        // Handle the case where cfType is not a CFStringRef
        NSLog(@"Provided CFTypeRef is not a CFStringRef.");
        return nil;
    }
}

// -------------------------------------------------------------------------------------------

+(NSInteger) getNumberFromString:(NSString *)input
{
    NSInteger result = 0;
    
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.numberStyle = NSNumberFormatterDecimalStyle;

    NSNumber *number = [formatter numberFromString:input];

    if (number)
    {
        result = [number integerValue];
        //NSLog(@"The integer value is: %d", (int)result);
    }
    else
    {
        NSLog(@"Invalid number string: %@", input);
    }

    return result;
}

// -------------------------------------------------------------------------------------------

// Replace non-printable characters in str with '\'-escaped equivalents.
// This function is used for convenient logging of data traffic.
+ (char *)logString:(char *)str
{
    static char     buf[2048];
    char            *ptr = buf;
    int             i;
    
    *ptr = '\0';
    
    while (*str)
    {
        if (isprint(*str))
        {
            *ptr++ = *str++;
        }
        else
        {
            switch(*str)
            {
                case ' ':
                    *ptr++ = *str;
                    break;
                    
                case 27:
                    *ptr++ = '\\';
                    *ptr++ = 'e';
                    break;
                    
                case '\t':
                    *ptr++ = '\\';
                    *ptr++ = 't';
                    break;
                    
                case '\n':
                    *ptr++ = '\\';
                    *ptr++ = 'n';
                    break;
                    
                case '\r':
                    *ptr++ = '\\';
                    *ptr++ = 'r';
                    break;
                    
                default:
                    i = *str;
                    (void)sprintf(ptr, "\\%03o", i);
                    ptr += 4;
                    break;
            }
            
            str++;
        }
        
        *ptr = '\0';
    }
    
    return buf;
}

// ------------------------------------------------------------------------------------------------


// Translate the Arduino response to a valid command.
+ (ArduinoResponse) translateResponse:(char *)str
{
    // TODO: The RSP_ERR does not work with this yet because it will be followed by a code or text
    //       of undefined length. If we get an RSP_ERR start, we need to read the rest of the buffer
    //       until we get to a \n. Also, we need to somehow return that error text too.
    
    ArduinoResponse response = Unrecognised;
    
    if (strncmp(str, CMD_OK, strlen(CMD_OK)) == 0)
        response = Ok;
    else if (strncmp(str, RSP_ERR, strlen(RSP_ERR)) == 0)
        response = Error;
    else if (strncmp(str, CMD_READY, strlen(CMD_READY)) == 0)
        response = Ready;
    else if (strncmp(str, CMD_ATCELL, strlen(CMD_ATCELL)) == 0)
        response = AtCell;
    
    return response;
}

// -------------------------------------------------------------------------------------------
// -------------------------------------------------------------------------------------------

@end

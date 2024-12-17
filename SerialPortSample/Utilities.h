//
//  Utilities.h
//  Various utility functions, mostly around string manipulation
//
//  Created by Pius Ott on 17/12/2024.
//  Copyright © 2024 WorldDom. All rights reserved.
//

#ifndef Utilities_h
#define Utilities_h

#import "ArduinoResponse.h"

@interface Utilities : NSObject

// ------------------------------------------------------------------------------------------------

+(NSString *) convertCFTypeRefToNSString:(CFTypeRef)cfType;

+(NSInteger) getNumberFromString:(NSString *)input;

+(char *) logString:(char *)str;

+ (ArduinoResponse) translateResponse:(char *)str;

@end

#endif /* Utilities_h */

//
//  SerialBuffer.m
//  FIFO buffer that holds data read via the USB serial port until it can be processed
//
//  Created by Pius Ott on 3/12/2024.
//  Copyright © 2024 Worlddom. All rights reserved.
//

#import "SerialBuffer.h"

@implementation SerialBuffer

// -------------------------------------------------------------------------------------------

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        _buffer = [NSMutableArray array];
    }
    return self;
}

// -------------------------------------------------------------------------------------------

- (void)enqueue:(NSString *)string
{
    [self.buffer addObject:string];
}

// -------------------------------------------------------------------------------------------

- (NSString *)dequeue
{
    if ([self isEmpty])
    {
        return nil; // Return nil if the buffer is empty
    }
    
    NSString *firstString = self.buffer[0];
    [self.buffer removeObjectAtIndex:0];
    return firstString;
}

// -------------------------------------------------------------------------------------------

- (NSUInteger)size
{
    return self.buffer.count;
}

// -------------------------------------------------------------------------------------------

- (BOOL)isEmpty
{
    return self.buffer.count == 0;
}

// -------------------------------------------------------------------------------------------

@end




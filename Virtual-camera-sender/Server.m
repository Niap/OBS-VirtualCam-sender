//
//  Server.m
//  VsMediaSender
//
//  Created by VislaNiap on 2021/5/25.
//  Copyright © 2021 John Boiles . All rights reserved.
//


#import "Server.h"

@interface Server () <NSPortDelegate>
@property NSPort *port;
@property NSMutableSet *clientPorts;
@end

@implementation Server


- (id)init {
    if (self = [super init]) {
        self.clientPorts = [[NSMutableSet alloc] init];
    }
    return self;
}

- (void)run {
    self.port = [[NSMachBootstrapServer sharedInstance] servicePortWithName:@MACH_SERVICE_NAME];
    if (self.port == nil) {
        // This probably means another instance is running.
        NSLog(@"Unable to open server port.");
        return;
    }

    self.port.delegate = self;

    NSRunLoop *runLoop = [NSRunLoop currentRunLoop];

    [runLoop addPort:self.port forMode:NSDefaultRunLoopMode];

    NSLog(@"Server running");
    [runLoop run];
    NSLog(@"Server exiting");
}

- (void)handlePortMessage:(NSPortMessage *)message {
    switch (message.msgid) {
        case MachMsgIdConnect:
            NSLog(@"Received Notify message");
            if (message.sendPort != nil) {
                NSLog(@"mach server received connect message from port %d!", ((NSMachPort *)message.sendPort).machPort);
                [self.clientPorts addObject:message.sendPort];
            }
            break;

        default:
            NSLog(@"Unexpected message ID %u", (unsigned)message.msgid);
            break;
    }
}

- (void)sendFrameWithSize:(NSSize)size timestamp:(uint64_t)timestamp fpsNumerator:(uint32_t)fpsNumerator fpsDenominator:(uint32_t)fpsDenominator frameBytes:(uint8_t *)frameBytes {
    if ([self.clientPorts count] <= 0) {
        return;
    }

//    FILE * fp = fopen("/tmp/capture.yuv","a+");
//    fwrite(frameBytes, size.width*size.height*2, 1, fp);
//    fclose(fp);
    @autoreleasepool {
        CGFloat width = size.width;
        NSData *widthData = [NSData dataWithBytes:&width length:sizeof(width)];
        CGFloat height = size.height;
        NSData *heightData = [NSData dataWithBytes:&height length:sizeof(height)];
        NSData *timestampData = [NSData dataWithBytes:&timestamp length:sizeof(timestamp)];
        NSData *fpsNumeratorData = [NSData dataWithBytes:&fpsNumerator length:sizeof(fpsNumerator)];
        NSData *fpsDenominatorData = [NSData dataWithBytes:&fpsDenominator length:sizeof(fpsDenominator)];

        // NOTE: I'm not totally sure about the safety of dataWithBytesNoCopy in this context.
        // Seems like there could potentially be an issue if the frameBuffer went away before the
        // mach message finished sending. But it seems to be working and avoids a memory copy. Alternately
        // we could do something like
        // NSData *frameData = [NSData dataWithBytes:(void *)frameBytes length:size.width * size.height * 2];
        NSData *frameData = [NSData dataWithBytesNoCopy:(void *)frameBytes length:size.width * size.height * 2 freeWhenDone:NO];
        [self sendMessageToClientsWithMsgId:MachMsgIdFrame components:@[widthData, heightData, timestampData, frameData, fpsNumeratorData, fpsDenominatorData]];
    }
}

- (void)sendMessageToClientsWithMsgId:(uint32_t)msgId components:(nullable NSArray *)components {
    if ([self.clientPorts count] <= 0) {
        return;
    }

    NSMutableSet *removedPorts = [NSMutableSet set];

    for (NSPort *port in self.clientPorts) {
        @try {
            NSPortMessage *message = [[NSPortMessage alloc] initWithSendPort:port receivePort:nil components:components];
            message.msgid = msgId;
            if (![message sendBeforeDate:[NSDate dateWithTimeIntervalSinceNow:1.0]]) {
                NSLog(@"failed to send message to %d, removing it from the clients!", ((NSMachPort *)port).machPort);
                [removedPorts addObject:port];
            }
        } @catch (NSException *exception) {
            NSLog(@"failed to send message (exception) to %d, removing it from the clients!", ((NSMachPort *)port).machPort);
            [removedPorts addObject:port];
        }
    }

    // Remove dead ports if necessary
    [self.clientPorts minusSet:removedPorts];
}

@end

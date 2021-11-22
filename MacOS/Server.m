//
//  Server.m
//  VsMediaSender
//
//  Created by VislaNiap on 2021/5/25.
//  Copyright © 2021 John Boiles . All rights reserved.
//


#import "Server.h"
#import <PTChannel.h>
#import <libyuv/convert_from_argb.h>



@interface Server () <NSPortDelegate,PTChannelDelegate>{
    NSNumber *connectingToDeviceID_;
    NSNumber *connectedDeviceID_;
    dispatch_queue_t notConnectedQueue_;
    NSDictionary *connectedDeviceProperties_;
    PTChannel *connectedChannel_;
    BOOL notConnectedQueueSuspended_;
}
@property NSPort *port;
@property NSMutableSet *clientPorts;
@end

@implementation Server


- (id)init {
    if (self = [super init]) {
        self.clientPorts = [[NSMutableSet alloc] init];
        notConnectedQueue_ = dispatch_queue_create("VME.notConnectedQueue", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)run {
    
    [self startListeningForDevices];
    [self enqueueConnectToLocalIPv4Port];
    [self startMachServer];
  
}

- (void)startMachServer {
    self.port = [[NSMachBootstrapServer sharedInstance] servicePortWithName:@MACH_SERVICE_NAME];
    if (self.port == nil) {
        // This probably means another instance is running.
        NSLog(@"Unable to open server port.");
        return;
    }
    
    self.port.delegate = self;

    NSRunLoop *runLoop = [NSRunLoop currentRunLoop];

    [runLoop addPort:self.port forMode:NSDefaultRunLoopMode];

    NSLog(@"Mach Server running");
    [runLoop run];
    NSLog(@"Mach Server exiting");}

- (void)handlePortMessage:(NSPortMessage *)message {
    switch (message.msgid) {
        case MachMsgIdConnect:
            //NSLog(@"Received Notify message");
            if (message.sendPort != nil) {
                //NSLog(@"mach server received connect message from port %d!", ((NSMachPort *)message.sendPort).machPort);
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
        NSData *frameData = [NSData dataWithBytesNoCopy:(void *)frameBytes length:size.width*size.height*2 freeWhenDone:NO];
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

#pragma mark - Wired device connections

- (void)startListeningForDevices {
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  
  [nc addObserverForName:PTUSBDeviceDidAttachNotification object:PTUSBHub.sharedHub queue:nil usingBlock:^(NSNotification *note) {
    NSNumber *deviceID = [note.userInfo objectForKey:PTUSBHubNotificationKeyDeviceID];
    //NSLog(@"PTUSBDeviceDidAttachNotification: %@", note.userInfo);
    NSLog(@"PTUSBDeviceDidAttachNotification: %@", deviceID);

    dispatch_async(self->notConnectedQueue_, ^{
      if (!self->connectingToDeviceID_ || ![deviceID isEqualToNumber:self->connectingToDeviceID_]) {
        [self disconnectFromCurrentChannel];
				self->connectingToDeviceID_ = deviceID;
				self->connectedDeviceProperties_ = [note.userInfo objectForKey:PTUSBHubNotificationKeyProperties];
        [self enqueueConnectToUSBDevice];
      }
    });
  }];
  
  [nc addObserverForName:PTUSBDeviceDidDetachNotification object:PTUSBHub.sharedHub queue:nil usingBlock:^(NSNotification *note) {
    NSNumber *deviceID = [note.userInfo objectForKey:PTUSBHubNotificationKeyDeviceID];
    //NSLog(@"PTUSBDeviceDidDetachNotification: %@", note.userInfo);
    NSLog(@"PTUSBDeviceDidDetachNotification: %@", deviceID);
    
    if ([self->connectingToDeviceID_ isEqualToNumber:deviceID]) {
			self->connectedDeviceProperties_ = nil;
			self->connectingToDeviceID_ = nil;
      if (self->connectedChannel_) {
        [self->connectedChannel_ close];
      }
    }
  }];
}

- (PTChannel*)connectedChannel {
  return connectedChannel_;
}

- (void)setConnectedChannel:(PTChannel*)connectedChannel {
  connectedChannel_ = connectedChannel;
  
  // Toggle the notConnectedQueue_ depending on if we are connected or not
  if (!connectedChannel_ && notConnectedQueueSuspended_) {
    dispatch_resume(notConnectedQueue_);
    notConnectedQueueSuspended_ = NO;
  } else if (connectedChannel_ && !notConnectedQueueSuspended_) {
    dispatch_suspend(notConnectedQueue_);
    notConnectedQueueSuspended_ = YES;
  }
  
  if (!connectedChannel_ && connectingToDeviceID_) {
    [self enqueueConnectToUSBDevice];
  }
}

- (void)disconnectFromCurrentChannel {
  if (connectedDeviceID_ && connectedChannel_) {
    [connectedChannel_ close];
    self.connectedChannel = nil;
  }
}


- (void)enqueueConnectToLocalIPv4Port {
  dispatch_async(notConnectedQueue_, ^{
    dispatch_async(dispatch_get_main_queue(), ^{
      [self connectToLocalIPv4Port];
    });
  });
}

- (void)connectToLocalIPv4Port {
  PTChannel *channel = [PTChannel channelWithDelegate:self];
  channel.userInfo = [NSString stringWithFormat:@"127.0.0.1:%d", VMEPeertalkPortNumber];
  [channel connectToPort:VMEPeertalkPortNumber IPv4Address:INADDR_LOOPBACK callback:^(NSError *error, PTAddress *address) {
    if (error) {
      if (error.domain == NSPOSIXErrorDomain && (error.code == ECONNREFUSED || error.code == ETIMEDOUT)) {
        // this is an expected state
      } else {
        NSLog(@"Failed to connect to 127.0.0.1:%d: %@", VMEPeertalkPortNumber, error);
      }
    } else {
      [self disconnectFromCurrentChannel];
      self.connectedChannel = channel;
      channel.userInfo = address;
      NSLog(@"Connected to %@", address);
    }
    [self performSelector:@selector(enqueueConnectToLocalIPv4Port) withObject:nil afterDelay:PTAppReconnectDelay];
  }];
}


- (void)enqueueConnectToUSBDevice {
  dispatch_async(notConnectedQueue_, ^{
    dispatch_async(dispatch_get_main_queue(), ^{
      [self connectToUSBDevice];
    });
  });
}



- (void)connectToUSBDevice {
  PTChannel *channel = [PTChannel channelWithDelegate:self];
  channel.userInfo = connectingToDeviceID_;
  channel.delegate = self;
  
  [channel connectToPort:VMEPeertalkPortNumber overUSBHub:PTUSBHub.sharedHub deviceID:connectingToDeviceID_ callback:^(NSError *error) {
    if (error) {
      if (error.domain == PTUSBHubErrorDomain && error.code == PTUSBHubErrorConnectionRefused) {
        //NSLog(@"Failed to connect to device #%@: %@", channel.userInfo, error);
      } else {
        NSLog(@"Failed to connect to device #%@: %@", channel.userInfo, error);
      }
      if (channel.userInfo == self->connectingToDeviceID_) {
        [self performSelector:@selector(enqueueConnectToUSBDevice) withObject:nil afterDelay:PTAppReconnectDelay];
      }
    } else {
        self->connectedDeviceID_ = self->connectingToDeviceID_;
        self.connectedChannel = channel;
    }
  }];
}

- (void)didDisconnectFromDevice:(NSNumber*)deviceID {
  NSLog(@"Disconnected from device");
  if ([connectedDeviceID_ isEqualToNumber:deviceID]) {
    [self willChangeValueForKey:@"connectedDeviceID"];
    connectedDeviceID_ = nil;
    [self didChangeValueForKey:@"connectedDeviceID"];
  }
}


#pragma mark - PTChannelDelegate


- (BOOL)ioFrameChannel:(PTChannel*)channel shouldAcceptFrameOfType:(uint32_t)type tag:(uint32_t)tag payloadSize:(uint32_t)payloadSize {
  if (   type != PTFrameTypeVideo) {
    NSLog(@"Unexpected frame of type %u", type);
    [channel close];
    return NO;
  } else {
    return YES;
  }
}

- (void)ioFrameChannel:(PTChannel*)channel didReceiveFrameOfType:(uint32_t)type tag:(uint32_t)tag payload:(NSData *)payload {
  NSLog(@"received %@, %u, %u, %@", channel, type, tag, payload);
  if (type == PTFrameTypeVideo) {
     
    @autoreleasepool {
        PTVideoFrame *videoFrame = (PTVideoFrame*)payload.bytes;
        NSSize size;
        size.width =videoFrame->width;
        size.height =videoFrame->height;
        //unsigned char * argbData = (unsigned char *)malloc( size.width*size.height*4 );
        //MJPGToARGB(videoFrame->data,videoFrame->length,argbData,size.width*4,size.width,size.height,size.width,size.height);
        
//        NSData * data = [[NSData alloc]initWithBytes:videoFrame->data length:videoFrame->length];
//        NSImage * image = [[NSImage alloc] initWithData:data];
//        CVPixelBufferRef argbPixcel = [self venusFastImageFromNSImage:image];
        unsigned char * yuv422Data = (unsigned char *)malloc( size.width*size.height*2 );
        
        ARGBToUYVY(videoFrame->data, size.width*4, yuv422Data, size.width*2, size.width, size.height);
        
        //[self RgbaToNV12PixelBuffer:argbData pixelBufferYUV:yuv422Data];
        [self sendFrameWithSize:size timestamp:0 fpsNumerator:10 fpsDenominator:10 frameBytes:yuv422Data];
        free(yuv422Data);
    }
  }
}


- (void)ioFrameChannel:(PTChannel*)channel didEndWithError:(NSError*)error {
  if (connectedDeviceID_ && [connectedDeviceID_ isEqualToNumber:channel.userInfo]) {
    [self didDisconnectFromDevice:connectedDeviceID_];
  }
  
  if (connectedChannel_ == channel) {
    self.connectedChannel = nil;
  }
}



@end

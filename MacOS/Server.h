//
//  Server.h
//  CMIOMinimalSample
//
//  Created by VislaNiap on 2021/5/25.
//  Copyright © 2021 John Boiles . All rights reserved.
//

#import <Foundation/Foundation.h>

#define MACH_SERVICE_NAME "com.johnboiles.obs-mac-virtualcam.server"
typedef enum {
    //! Initial connect message sent from the client to the server to initate a connection
    MachMsgIdConnect = 1,
    //! Message containing data for a frame
    MachMsgIdFrame = 2,
    //! Indicates the server is going to stop sending frames
    MachMsgIdStop = 3,
} MachMsgId;


enum {
  PTFrameTypeVideo = 100,
};

typedef struct _PTVideoFrame {
    uint32_t height;
    uint32_t width;
    uint32_t length;
    uint8_t data[0];
} PTVideoFrame;


static const int VMEPeertalkPortNumber = 2345;
static const NSTimeInterval PTAppReconnectDelay = 1.0;

@interface Server : NSObject

- (void)run;
- (void)sendFrameWithSize:(NSSize)size timestamp:(uint64_t)timestamp fpsNumerator:(uint32_t)fpsNumerator fpsDenominator:(uint32_t)fpsDenominator frameBytes:(uint8_t *)frameBytes;
@end

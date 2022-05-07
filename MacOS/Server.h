//
//  Server.h
//  CMIOMinimalSample
//
//  Created by VislaNiap on 2021/5/25.
//  Copyright © 2021 John Boiles . All rights reserved.
//

#import <Foundation/Foundation.h>

#define MACH_SERVICE_NAME "com.obsproject.obs-mac-virtualcam.server"
typedef enum {
    //! Initial connect message sent from the client to the server to initate a connection
    MachMsgIdConnect = 1,
    //! Message containing data for a frame
    MachMsgIdFrame = 2,
    //! Indicates the server is going to stop sending frames
    MachMsgIdStop = 3,
} MachMsgId;


@interface Server : NSObject

- (void)run;
- (void)sendFrameWithSize:(NSSize)size timestamp:(uint64_t)timestamp fpsNumerator:(uint32_t)fpsNumerator fpsDenominator:(uint32_t)fpsDenominator frameBytes:(uint8_t *)frameBytes;
@end

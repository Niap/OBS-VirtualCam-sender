//
//  Capture.h
//  CoreMediaCommand
//
//  Created by VislaNiap on 2021/5/26.
//

#import "Server.h"

@interface Capture: NSObject
- (bool) setupDevice:(NSString *)udid;
- (void) run;
- (id) init:(Server *)server;
@end



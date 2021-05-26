//
//  main.m
//  Virtual-camera-sender
//
//  Created by VislaNiap on 2021/5/26.
//

#import <Foundation/Foundation.h>
#import "Capture.h"
#import "Server.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // insert code here...
        Server *server = [[Server alloc] init];
        [NSThread detachNewThreadWithBlock:^{
            [server run];
        }];
        Capture * cap =  [[Capture alloc]init:server];
        [cap run];
        [cap setupDevice:@"0x8020000005ac8514"];
        [[NSRunLoop mainRunLoop] run];
    }
    return 0;
}

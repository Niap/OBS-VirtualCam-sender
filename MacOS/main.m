//
//  main.m
//  Virtual-camera-sender
//
//  Created by VislaNiap on 2021/5/26.
//

#import <Foundation/Foundation.h>
//#import "Capture.h"
#import "Server.h"

#define HEIGHT 720
#define WIDTH 1280
#define BUFSIZE WIDTH*HEIGHT*2



int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // insert code here...
        Server *server = [[Server alloc] init];
        //[NSThread detachNewThreadWithBlock:^{
        [server run];
        //}];
        [[NSRunLoop mainRunLoop] run];
    }
    return 0;
}

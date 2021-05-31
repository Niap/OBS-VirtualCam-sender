//
//  main.m
//  Virtual-camera-sender
//
//  Created by VislaNiap on 2021/5/26.
//

#import <Foundation/Foundation.h>
//#import "Capture.h"
#import "Server.h"
#include "video_generator.h"

#define HEIGHT 720
#define WIDTH 1280
#define BUFSIZE WIDTH*HEIGHT*2


void YUV444ToUYVY422( uint8_t* uyvy422,  uint8_t* y, uint8_t* u,uint8_t * v, int width, int height)
{
    int nums=width*height;
    int i,j,k=0;
    for(i=0;i<nums;i++){
        uyvy422[i*2+1]=y[i];
    }
    
    for(i=0;i<nums;i++){
        if(i%2==0){
            int halfI = (int)(i/2.0);
            uyvy422[halfI*4] = u[i];
            uyvy422[halfI*4+2] = v[i];
        }
        
   }
  
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // insert code here...
        Server *server = [[Server alloc] init];
        [NSThread detachNewThreadWithBlock:^{
            [server run];
        }];
        video_generator_settings cfg;
        video_generator gen;

        printf("\n\nVideo Generator.\n\n");

        /* Set the video generator settings. */
        cfg.width = WIDTH;
        cfg.height = HEIGHT;
        cfg.fps = 30;
        cfg.audio_callback = NULL;


        if (0 != video_generator_init(&cfg, &gen)) {
           printf("Error: cannot initialize the video generator.\n");
           return -1;
        }
        int time = 0;
        
        uint8_t buffer[BUFSIZE];
        while( time < 10000 ){
            video_generator_update(&gen);
            YUV444ToUYVY422(buffer,gen.y,gen.u,gen.v,WIDTH,HEIGHT);
            [server sendFrameWithSize:CGSizeMake(WIDTH, HEIGHT) timestamp:0 fpsNumerator:10 fpsDenominator:10 frameBytes:buffer];
            time += 33;
            usleep(33*1000);
        }
//        Capture * cap =  [[Capture alloc]init:server];
//        [cap run];
//        [cap setupDevice:@"0x8020000005ac8514"];
//        [[NSRunLoop mainRunLoop] run];
    }
    return 0;
}

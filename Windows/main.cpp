#include <stdio.h>
#include "./queue/share_queue_write.h"
#include "../video_generator.h"

#define HEIGHT 720
#define WIDTH 1280
#define BUFSIZE WIDTH*HEIGHT*2

void YUV444ToUYVY422(uint8_t* uyvy422, uint8_t* y, uint8_t* u, uint8_t* v, int width, int height)
{
    int nums = width * height;
    int i = 0;
    for (i = 0; i < nums; i++) {
        uyvy422[i * 2 + 1] = y[i];
    }

    for (i = 0; i < nums; i++) {
        if (i % 2 == 0) {
            int halfI = (int)(i / 2.0);
            uyvy422[halfI * 4] = u[i];
            uyvy422[halfI * 4 + 2] = v[i];
        }
    }
}



int main(int argc, char* argv[]){

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

    //push to virtual 
    share_queue video_queue;
    uint64_t interval = static_cast<int64_t>(1000000000 / 30);
    int nb = 0;
    uint8_t * buffer = (uint8_t*) malloc(BUFSIZE);
    uint32_t linesize[3] = { WIDTH*2,0,0};
    uint8_t* data[3] = {nullptr,nullptr,nullptr};
    shared_queue_create(&video_queue,ModeVideo, AV_PIX_FMT_UYVY422, WIDTH, HEIGHT,interval, 10);
    //shared_queue_set_delay(&video_queue,0);
    int time = 0;
    while( time < 10000 ){
        printf("Frame: %llu\n", gen.frame);
        video_generator_update(&gen);
        YUV444ToUYVY422(buffer, gen.y, gen.u, gen.v, WIDTH, HEIGHT);
        data[0] = buffer;
        shared_queue_push_video(&video_queue, linesize, WIDTH, HEIGHT, data, time);
        time += 33;
        Sleep(33);
    }
    shared_queue_write_close(&video_queue);
    
}
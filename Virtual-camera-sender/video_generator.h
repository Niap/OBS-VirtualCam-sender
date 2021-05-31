/*

  Video Generator
  ================

  The Video Generator library is used to create a continuous YUV420P
  video signal with optionally a 44100hz, int16, interleaved 2-channel
  raw PCM signal. This library was created to test video and audio
  encoders over a longer period. Therefore the video signal contains a
  time field that shows how long the generator has been running. The
  time is based on the generated number of video frames. It's up to
  the user to make sure that the `video_generator_update()` function
  is called often enough to keep up with the number of frames you want
  to generate.


  Using the Video Generator
  -------------------------

  First initialize the generator using `video_generator_init()` then
  call `video_generator_update()` every time you want to generate a
  new video frame. When you call `video_generator_update()` the
  `frame` member of the `video_generator` struct is updated. Each time
  you call `video_generator_update()` it will update the contents of
  the Y, U, and V planes. When you're using audio it will call the
  audio callback at the right intervals to simulate a audio-capture
  callback. When ready clean memory using `video_generator_clear()`.

  IMPORTANT: when you use audio, note that the callback is called from
             a separate thread, just like a normal audio capture
             callback would do. Do not peform heavy tasks in this
             callback!

  video_generator_init()       - initialize, see below for the declaration.
  video_generator_update()     - generate a new video frame, see below for the declaration.
  video_generator_clear()      - frees allocated memory, see below for the declaration.


  Settings:
  ---------

  When you call `video_generator_init()` you pass it a `video_generator_settings` object that
  describes some things about the video and audio you want to generate. You can set the
  following settings.

  width            - width of the video frames (e.g. 640).
  height           - height of the video frames (e.g. 480).
  fps              - framerate (e.g. 25)
  bip_frequency    - the frequency that is used for the bip sound (e.g. 700).
  bop_frequency    - the frequency that is used for the bop sound (e.g. 1500).
  audio_callback   - set this t the audio callback that will receive the audio buffer.

  Specification
  ---------------

  Audio: 2 channels interleaved
         44100hz
         int16

  Video: YUV420P / I420P
         1 continuous block of memory
         y-stride = width
         u-stride = width / 2
         v-stride = width / 2


  Convert video / audio with avconv
  ----------------------------------

  You can write the video / audio frames into a file and use avconv to encode it to some format:

       ````sh
       ./avconv -f rawvideo -pix_fmt yuv420p -s 640x480 -i output.yuv -vcodec h264 -r 25 -y out.mov
       ./avconv -f s16le -ac 2 -ar 44100 -i out_s16_44100_stereo.pcm out.wav
       ````

  Example:
  --------
  <example>

     fp = fopen("output.yuv", "wb");

     video_generator gen;
     video_geneator_settings cfg;

     cfg.width = WIDTH;
     cfg.height = HEIGHT;
     cfg.fps = FPS;

     if (0 != video_generator_init(&cfg, &gen)) {
       printf("Error: cannot initialize the generator.\n");
       exit(1);
     }

     while(1) {

        printf("Frame: %llu\n", gen.frame);

        video_generator_update(&gen);

        // write video planes to a file
        fwrite((char*)gen.y, gen.ybytes,1,  fp);
        fwrite((char*)gen.u, gen.ubytes,1, fp);
        fwrite((char*)gen.v, gen.vbytes,1, fp);

        if (gen.frame > 250) {
          break;
        }

        usleep(gen.fps);
     }

    fclose(fp);

    video_generator_clear(&gen);

  </example>
 */

#ifndef VIDEO_GENERATOR_H
#define VIDEO_GENERATOR_H

#define RXS_MAX_CHARS 11
#include <stdint.h>

#if defined(__cplusplus)
extern "C" {
#endif

/* ----------------------------------------------------------------------------------- */
/*                          T H R E A D I N G                                          */
/* ----------------------------------------------------------------------------------- */

/* ------------------------------------------------------------------------- */

struct thread;                                                 /* Forward declared. */
struct mutex;                                                  /* Forward declared. */
typedef struct thread thread;
typedef struct mutex mutex;
typedef void*(*thread_function)(void* param);                  /* The thread function you need to write. */

thread* thread_alloc(thread_function func, void* param);       /* Create a new thread handle. Don't forget to call thread_free(). */
int thread_free(thread* t);                                    /* Frees the thread that was allocated by `thread_alloc()` */
int thread_join(thread* t);                                    /* Join the thread. */
int mutex_init(mutex* m);                                      /* Initialize a mutex. */
int mutex_destroy(mutex* m);                                   /* Destroy the mutex. */
int mutex_lock(mutex* m);                                      /* Lock the mutex. */
int mutex_unlock(mutex* m);                                    /* Unlock the mutex. */

/* ------------------------------------------------------------------------- */

#if defined(_WIN32)

#define WIN32_LEAN_AND_MEAN
    #include <windows.h>

    struct thread {
      HANDLE handle;
      DWORD thread_id;
      thread_function func;
      void* user;
    };

    struct mutex {
      HANDLE handle;
    };

    DWORD WINAPI thread_wrapper_function(LPVOID param);

#elif defined(__linux) || defined(__APPLE__)

#include <string.h>
#include <stdlib.h>
#include <pthread.h>

struct thread {
    pthread_t handle;
    thread_function func;
    void* user;
};

struct mutex {
    pthread_mutex_t handle;
};

void* thread_function_wrapper(void* t);

#endif

/* ----------------------------------------------------------------------------------- */
/*                          V I D E O   G E N E R A T O  R                             */
/* ----------------------------------------------------------------------------------- */

typedef struct video_generator video_generator;
typedef struct video_generator_settings video_generator_settings;
typedef struct video_generator_char video_generator_char;

/*
   When we generate audio we do this from a separate thread to make sure we
   simulate a real audio input system that e.g. captures audio from a microphone.
   Also this means that the user doesn't need to call a update() function or something
   that would normally be used to retrieve audio samples.

   Make sure that you don't do too much in the callback because we need to keep up
   with the samplerate.

   @param samples        The samples that you need to process.
   @param nbytes         The number of bytes in `samples`
   @param nframes        The number of frames in `samples`.
*/
typedef void(*video_generator_audio_callback)(const int16_t* samples, uint32_t nbytes, uint32_t nframes);

struct video_generator_char {
    int id;
    int x;
    int y;
    int width;
    int height;
    int xoffset;
    int yoffset;
    int xadvance;
};

struct video_generator_settings {
    uint32_t width;
    uint32_t height;
    uint32_t fps;
    uint16_t bip_frequency;
    uint16_t bop_frequency;
    video_generator_audio_callback audio_callback;
};

struct video_generator {

    /* video  */
    uint64_t frame;                                         /* current frame number, which is incremented by one in `video_generator_update`. */
    uint8_t* y;                                             /* points to the y-plane. */
    uint8_t* u;                                             /* points to the u-plane. */
    uint8_t* v;                                             /* points to the v-plane. */
    uint32_t width;                                         /* width of the video frame (and y-plane). */
    uint32_t height;                                        /* height of the video frame (and y-plane). */
    uint32_t ybytes;                                        /* number of bytes in the y-plane. */
    uint32_t ubytes;                                        /* number of bytes in the u-plane. */
    uint32_t vbytes;                                        /* number of bytes in the v-plane. */
    uint32_t nbytes;                                        /* total number of bytes in the allocated buffer for the yuv420p buffer. */
    uint8_t* planes[3];                                     /* pointers to the planes (similar to the y, u and v members). */
    uint32_t strides[3];                                    /* strides for the separate planes. */
    int fps_num;                                            /* framerate numerator e.g. 1. */
    int fps_den;                                            /* framerate denominator e.g. 25. */
    double fps;                                             /* framerate in microseconds, 1 fps == 1.000.000 us. */
    double step;                                            /* used to create/translate the moving bar. */
    double perc;                                            /* position of the moving bar in percentages. */
    video_generator_char chars[RXS_MAX_CHARS];              /* bitmap characters, `0-9` and `:` */
    int font_w;                                             /* width of the bitmap (which is stored in video_generator.c). */
    int font_h;                                             /* height of the bitmap (which is stored in video_generator.c). */
    int font_line_height;

    /* Audio */
    uint16_t audio_nchannels;                               /* number of audio channels, for now always 2. */
    uint8_t audio_nseconds;                                 /* the number of seconds of audio we have in the audio_buffer. Always 4. */
    uint16_t audio_samplerate;                              /* for now always: 44100 */
    uint16_t audio_bip_frequency;                           /* frequency for the bip sound, 600hz. */
    uint16_t audio_bop_frequency;                           /* frequency for the bop sound, 300hz. */
    uint32_t audio_bip_millis;                              /* number of millis for the bip sound */
    uint32_t audio_bop_millis;                              /* number of millis for the bop sound */
    uint32_t audio_nbytes;                                  /* number of bytes in audio_buffer. */
    uint64_t audio_nsamples;                                /* number of samples that are passed to the audio callback whenever needed. */
    int16_t* audio_buffer;                                  /* this will contain the audio samples */
    video_generator_audio_callback audio_callback;          /* will be called from the thread when the user needs to process audio. */
    thread* audio_thread;                                   /* the audio callback is called from another thread to simulate microphone input.*/
    mutex audio_mutex;                                      /* used to sync. shared data */
    uint8_t audio_thread_must_stop;                         /* is set to 1 when the thread needs to stop */
    uint8_t audio_is_bip;                                   /* is set to 1 as soon as the bip audio part it passed into the callback. */
    uint8_t audio_is_bop;                                   /* is set to 1 as soon as the bop audio part is passed into the callback. */
};

int video_generator_init(video_generator_settings* cfg, video_generator* g);
int video_generator_update(video_generator* g);
int video_generator_clear(video_generator* g);

#if defined(__cplusplus)
} /* extern "C" */
#endif

#endif
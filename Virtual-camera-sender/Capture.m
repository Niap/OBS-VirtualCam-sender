//
//  Capture.m
//  CoreMediaCommand
//
//  Created by VislaNiap on 2021/5/26.
//

#import <Foundation/Foundation.h>
#import "Capture.h"

#import <CoreMedia/CoreMedia.h>
#import <CoreMediaIO/CMIOHardware.h>
#import <AVFoundation/AVFoundation.h>


@interface Capture  () <AVCaptureVideoDataOutputSampleBufferDelegate>

@property id connObs;
@property id disconnObs;
@property NSNotificationCenter * notiCenter;
@property AVCaptureSession *mSession;
@property AVCaptureDevice *mDevice;
@property AVCaptureDeviceInput *mDeviceInput;
@property AVCaptureVideoDataOutput *mDeviceOutput;

@property Server * server;

@end


@implementation Capture


- (id) init:(Server *)server {

    self.mSession = [[AVCaptureSession alloc] init];
    self.server = server;
    return self;
}


- (void)dealloc ; {
    [_notiCenter removeObserver:_connObs];
    [_notiCenter removeObserver:_disconnObs];
}


- (bool) setupDevice:(NSString *)udid {
    self.mDevice = [AVCaptureDevice deviceWithUniqueID: udid];
    if (self.mDevice == nil) {
        NSLog(@"device with udid '%@' not found", udid);
        return false;
    }
    [self.mSession beginConfiguration];
    // Add session input
    NSError *error;
    self.mDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:self.mDevice error:&error];
    if (self.mDeviceInput == nil) {
        NSLog(@"%@", error);
        return false;
    } else {
        [self.mSession addInput:self.mDeviceInput];
    }
    // Add session output
    self.mDeviceOutput = [[AVCaptureVideoDataOutput alloc] init];
    self.mDeviceOutput.alwaysDiscardsLateVideoFrames = YES;
    self.mDeviceOutput.videoSettings = [NSDictionary dictionaryWithObjectsAndKeys:
        AVVideoScalingModeResizeAspect, (id)AVVideoScalingModeKey,
        [NSNumber numberWithUnsignedInt:1280], (id)kCVPixelBufferWidthKey,
        [NSNumber numberWithUnsignedInt:720], (id)kCVPixelBufferHeightKey,
        [NSNumber numberWithUnsignedInt:kCVPixelFormatType_422YpCbCr8], kCVPixelBufferPixelFormatTypeKey,
        nil];
    dispatch_queue_t videoQueue = dispatch_queue_create("videoQueue", DISPATCH_QUEUE_SERIAL);
    [self.mDeviceOutput setSampleBufferDelegate:self queue:videoQueue];
    [self.mSession addOutput:self.mDeviceOutput];
    [self.mSession commitConfiguration];
    [self.mSession startRunning];
    return true;
}

- (void) captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    CVPixelBufferLockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
    
    [self.server sendFrameWithSize:CGSizeMake(width, height) timestamp:0 fpsNumerator:10 fpsDenominator:10 frameBytes:CVPixelBufferGetBaseAddress(imageBuffer)];
    CVPixelBufferUnlockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
}


- (void) listDevice {

    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    unsigned long deviceCount = [devices count];

    if (deviceCount > 0) {
        printf("Found %li available video devices:\n", deviceCount);
        for (AVCaptureDevice *device in devices) {
            printf("* %s\n", [[device localizedName] UTF8String]);
            printf("uuid %s\n", [[device uniqueID] UTF8String]);
        }
    } else {
        printf("No video devices found.\n");
    }
}

- (void) run {
    CMIOObjectPropertyAddress prop = {
        kCMIOHardwarePropertyAllowScreenCaptureDevices,
        kCMIOObjectPropertyScopeGlobal,
        kCMIOObjectPropertyElementMaster
    };
    UInt32 allow = 1;
    CMIOObjectSetPropertyData(kCMIOObjectSystemObject, &prop, 0, NULL, sizeof(allow), &allow);
    [self listDevice];

    _notiCenter = [NSNotificationCenter defaultCenter];
    _connObs =[_notiCenter addObserverForName:AVCaptureDeviceWasConnectedNotification
                                        object:nil
                                         queue:[NSOperationQueue mainQueue]
                                    usingBlock:^(NSNotification *note)
                                                {
        [self listDevice];
                                                    // Device addition logic
                                                }];
    _disconnObs =[_notiCenter addObserverForName:AVCaptureDeviceWasDisconnectedNotification
                                         object:nil
                                            queue:[NSOperationQueue mainQueue]
                                     usingBlock:^(NSNotification *note)
                                                {
                                                    // Device removal logic
                                                }];
    [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:3]];


}

@end

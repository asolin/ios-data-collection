//
//  OpenCVWrapper.m
//  test
//
//  Created by Cortes Reina Santiago on 25/09/2017.
//  Copyright © 2017 Cortes Reina Santiago. All rights reserved.
//

#import "OpenCVWrapper.h"
#import <opencv2/videoio/cap_ios.h>




@interface OpenCVWrapper () < CvVideoCameraDelegate>
@property (nonatomic, strong) CvVideoCamera* videoCamera;
@end

@implementation OpenCVWrapper

-(void) OpenCVWrapper:( void *)parent{
    //CvVideoCameraDelegate
    
        /* Camera setup */
    self.videoCamera = [[CvVideoCamera alloc]  initWithParentView:parent.imageView];
    self.videoCamera.delegate = self;
    self.videoCamera.defaultAVCaptureDevicePosition = AVCaptureDevicePositionBack;
    self.videoCamera.defaultAVCaptureSessionPreset = AVCaptureSessionPreset640x480; // AVCaptureSessionPreset1280x720;
    self.videoCamera.defaultAVCaptureVideoOrientation = AVCaptureVideoOrientationPortrait;
    self.videoCamera.defaultFPS = 10;
    self.videoCamera.grayscaleMode = YES;
    self.videoCamera.recordVideo = YES;

}


-(void) startCapture{
    
    // Start recording
    [self.videoCamera start];
    
    /* Set focus and ISO/exposure (shutter time) */
    [self.videoCamera setFocus:1.00];
    [self.videoCamera setExposure:400 shutter:CMTimeMake(1,100)];
}


-(void) endCapture{
    
    [self.videoCamera stop];
}

//videoCAmera = new CvVideoCamera;
- (void) isThisWorking {
    //std::cout << "Hey" << std::endl;
    NSLog(@"Yay!");
    
    
    
    
    
 //   @property (nonatomic, strong) CvVideoCamera* videoCamera;
    
    // remember to make delegate
    //CvVideoCameraDelegate
    

    
    

    
}

    - (void)processImage:(cv::Mat&)image atTime: (CMTime)lastSampleTime
    {
    
        NSLog(@"Frame %i captured at t=%f",0,CMTimeGetSeconds(lastSampleTime));
        
    }
    
    - (void)videoRecordingStarted
    {
        // This is the zero point in the video
        
    }
    
    
    
    


@end

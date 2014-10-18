//
//  ViewController.m
//  VideoCompositionSimulatorBug
//
//  Created by Scott Carter on 10/17/14.
//  Copyright (c) 2014 Scott Carter. All rights reserved.
//

#import "ViewController.h"

#import <MediaPlayer/MediaPlayer.h>

#import <AVFoundation/AVFoundation.h>

#import "SDAVAssetExportSession.h"



@interface ViewController ()

@property (strong, nonatomic) MPMoviePlayerController *player;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    [self export];
}



// Export the bundled movie as MP4 to the tmp directory and then play inside a
// MPMoviePlayerController instance.
//
- (void)export {
    
    // Get the resource path to the movie
    
    // Some video samples work fine such as portrait_rear_facing.MOV
    // NSString *videoPath = [[NSBundle mainBundle] pathForResource:@"portrait_rear_facing" ofType:@"MOV"];
    
    // Other video samples such as portrait_front_facing.MOV display the hang bug.
    NSString *videoPath = [[NSBundle mainBundle] pathForResource:@"portrait_front_facing" ofType:@"MOV"];
    

    
    NSURL *videoURL = [NSURL fileURLWithPath:videoPath];
    
    AVAsset *videoAsset = [[AVURLAsset alloc] initWithURL:videoURL options:nil];
    
    
    
    // Temporary output path for MP4 file export
    NSString *exportPath = [NSString stringWithFormat:@"%@from_library.mp4",NSTemporaryDirectory()];
    
    // Make sure file doesn't already exist.
    [[NSFileManager defaultManager] removeItemAtPath:exportPath error:nil];
    
    NSURL *outputURL = [NSURL fileURLWithPath:exportPath];
    
    
    
    AVAssetTrack *videoTrack = [[videoAsset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
    
    
    NSLog(@"videoTrack.naturalSize:  size.width = %f size.height = %f", videoTrack.naturalSize.width, videoTrack.naturalSize.height);
    
    
    // Since we are reading in a Portrait video with 90 degree rotation and writing out a video
    // with 0 rotation, we need to swap width and height.
    //
    // We also adjust the Portrait size so that the height does not exceed 640 (to avoid memory issues).
    //
    CGFloat scaleFactor = videoTrack.naturalSize.width/ 640.0; // Scaling Portrait height (naturalSize.width in original movie)
    
    CGSize videoSize = CGSizeMake(videoTrack.naturalSize.height/scaleFactor, videoTrack.naturalSize.width/scaleFactor);
    
    NSLog(@"Adjusted width = %f height = %f", videoSize.width, videoSize.height);
    
    
    SDAVAssetExportSession *encoder = [SDAVAssetExportSession.alloc initWithAsset:videoAsset];
    
    // Our video composition will set the render size and scale the movie as needed.
    encoder.videoComposition = [self getVideoComposition:videoAsset videoSize:videoSize];
    
    
    // Exporting as MP4
    encoder.outputFileType = AVFileTypeMPEG4;
    encoder.outputURL = outputURL;
    
    
    encoder.videoSettings = @
    {
    AVVideoCodecKey: AVVideoCodecH264,
        
    AVVideoWidthKey: [NSNumber numberWithFloat:videoSize.width],
    AVVideoHeightKey: [NSNumber numberWithFloat:videoSize.height],
        
    AVVideoCompressionPropertiesKey: @
        {
        AVVideoAverageBitRateKey: @725000,
        AVVideoProfileLevelKey: AVVideoProfileLevelH264Baseline30,
        },
    };
    
    
    encoder.audioSettings = @
    {
    AVFormatIDKey: @(kAudioFormatMPEG4AAC),
    AVNumberOfChannelsKey: @1,
    AVSampleRateKey: @44100,
    AVEncoderBitRateKey: @64000,
    };
    
    
    encoder.shouldOptimizeForNetworkUse = YES;
    
    
    
    [encoder exportAsynchronouslyWithCompletionHandler:^
     {
         
         if (encoder.status == AVAssetExportSessionStatusCompleted)
         {
             NSLog(@"Video export succeeded");
             
             // Play the movie after export.
             dispatch_sync(dispatch_get_main_queue(), ^{
                 [self playMovie:outputURL];
             });
             
         }
         else if (encoder.status == AVAssetExportSessionStatusCancelled)
         {
             NSLog(@"Video export cancelled");
         }
         else
         {
             NSLog(@"Video export failed with error: %@ (%ld)", encoder.error.localizedDescription, (long)encoder.error.code);
         }
     }];
    
    
}


// Video composition will set the render size and scale the movie as needed.
//
-(AVMutableVideoComposition *) getVideoComposition:(AVAsset *)asset
                                         videoSize:(CGSize)videoSize
{
    AVAssetTrack *videoTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
    
    AVMutableVideoComposition *videoComposition = [AVMutableVideoComposition videoComposition];
    
    // videoSize has already been resized (as needed) and width/height swapped for Portrait.
    videoComposition.renderSize = videoSize;
    
    
    videoComposition.frameDuration = CMTimeMakeWithSeconds( 1 / videoTrack.nominalFrameRate, 600);
    
    NSLog(@"frameDuration value = %lld  frameDuration timescale = %d  nominalFrameRate = %f", videoComposition.frameDuration.value, videoComposition.frameDuration.timescale, videoTrack.nominalFrameRate);
    
    
    AVMutableVideoCompositionLayerInstruction *videolayerInstruction = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:videoTrack];
    
    
    // Need to scale our video to fit in the new dimensions represented by videoSize.
    // The original Portrait width is represented by videoTrack.naturalSize.height because
    // we had a 90 degree rotation.
    CGFloat scaleToFitRatio = videoSize.width / videoTrack.naturalSize.height;
    
    CGAffineTransform scaleTransform = CGAffineTransformMakeScale(scaleToFitRatio,scaleToFitRatio);
    [videolayerInstruction setTransform:CGAffineTransformConcat(videoTrack.preferredTransform, scaleTransform) atTime:kCMTimeZero];
    
        
    [videolayerInstruction setOpacity:0.0 atTime:asset.duration];
    
    AVMutableVideoCompositionInstruction *inst = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
    inst.timeRange = CMTimeRangeMake(kCMTimeZero, asset.duration);
    inst.layerInstructions = [NSArray arrayWithObject:videolayerInstruction];
    videoComposition.instructions = [NSArray arrayWithObject:inst];
    
    
    return videoComposition;
}


// Fill our view with the movie and play.
//
- (void)playMovie:(NSURL *)assetURL
{
    // Important to remove previous player from super view if it exists.
    if(self.player != nil){
        [self.player.view removeFromSuperview];
        self.player = nil;
    }

    
    self.player = [[MPMoviePlayerController alloc] initWithContentURL: assetURL];
    
    [self.player.view setFrame: self.view.bounds];  // player's frame must match parent's
    
    self.player.scalingMode = MPMovieScalingModeAspectFit;

    [self.view addSubview: self.player.view];
    
    [self.player play];
    
    
}



@end


# Overview

This project is intended to show a bug that occurs on the Xcode simulator when certain movies are processed by adding an instance of AVAssetReaderVideoCompositionOutput
to an  AVAssetReader object using the addOutput: method.

The bug manifests itself as a hang of the call to the AVAssetReaderOutput method copyNextSampleBuffer.

There is no issue on a real device.


# Environment

**Xcode Version:** 6.0.1 (6A317)



# Details

**Example**

This project contains an example which shows the issue.   In ViewController.m, viewDidLoad will call the export method which will export the bundled movie as MP4 to the tmp directory and then play the movie inside a MPMoviePlayerController instance.

There are two movies included in the Bundle Resources, either of which may be loaded at the start of the export method.

portrait_rear_facing.MOV is commented out by default.   This movie will load, export and play correctly on both the simulator and real device.

portrait_front_facing.MOV is enabled by default.  This movie will load, export and play correctly on a real device.   It will hang on the simulator.


**copyNextSampleBuffer**

The hang on the simulator occurs in SDAVAssetExportSession.m in the method encodeReadySamplesFromOutput:toInput: at line 228 where copyNextSampleBuffer is called.

This code for SDAVAssetExportSession.m was obtained from https://github.com/rs/SDAVAssetExportSession.  It is a AVAssetExportSession drop-in replacement with customizable audio&video settings.   There is no indication that any of this code is responsible for the bug.


**AVAssetReaderVideoCompositionOutput**

An instance of AVAssetReaderVideoCompositionOutput is added to AVAssetReader in SDAVAssetExportSession.m.   The videoComposition property of the former instance is set based on the output of getVideoComposition:videoSize: in ViewController.m.

I have determined that the AVMutableVideoComposition returned by getVideoComposition:videoSize: is not a factor in the bug.

I was able to also produce the bug when the videoComposition property in SDAVAssetExportSession.m was instead set by a call to 
[AVVideoComposition videoCompositionWithPropertiesOfAsset:self.asset];


**AVAssetReaderTrackOutput**

Replacing the AVAssetReaderVideoCompositionOutput with an instance of AVAssetReaderTrackOutput fixes the bug.  In this case, there is no AVVideoComposition property.

This has led me to conclude that the bug is restricted to the use of a video composition.



**Expected output**

Upon success, the console should output "Video export succeeded" and the exported MP4 movie should begin playback.







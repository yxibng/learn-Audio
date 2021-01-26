//
//  RZRecorder.m
//  AudioQueue-Demo
//
//  Created by yxibng on 2021/1/26.
//

#import "RZRecorder.h"
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>


static const int kNumberBuffers = 3;
struct AQRecorderState {
    
    AudioStreamBasicDescription mDataFormat;
    AudioQueueRef mQueue;
    AudioQueueBufferRef mBuffers[kNumberBuffers];
    AudioFileID mAudioFile;
    UInt32 bufferByteSize;
    SInt64 mCurrentPacket;
    bool mIsRunning;
};

static AQRecorderState aqData;


static void HandleInputBuffer (void                                 *aqData,
                               AudioQueueRef                        inAQ,
                               AudioQueueBufferRef                  inBuffer,
                               const AudioTimeStamp                 *inStartTime,
                               UInt32                               inNumPackets,
                               const AudioStreamPacketDescription   *inPacketDesc)
{
    AQRecorderState *pAqData = (AQRecorderState *) aqData;               // 1
    
    if (inNumPackets == 0 &&                                             // 2
        pAqData->mDataFormat.mBytesPerPacket != 0)
        inNumPackets =
        inBuffer->mAudioDataByteSize / pAqData->mDataFormat.mBytesPerPacket;
    
    if (AudioFileWritePackets (                                          // 3
                               pAqData->mAudioFile,
                               false,
                               inBuffer->mAudioDataByteSize,
                               inPacketDesc,
                               pAqData->mCurrentPacket,
                               &inNumPackets,
                               inBuffer->mAudioData
                               ) == noErr) {
        pAqData->mCurrentPacket += inNumPackets;                     // 4
    }
    if (pAqData->mIsRunning == 0)                                         // 5
        return;
    
    AudioQueueEnqueueBuffer (                                            // 6
                             pAqData->mQueue,
                             inBuffer,
                             0,
                             NULL
                             );
}


void DeriveBufferSize(AudioQueueRef audioQueue,
                      AudioStreamBasicDescription  &ASBDescription,
                      Float64 seconds,
                      UInt32 *outBufferSize)
{
    static const int maxBufferSize = 0x50000;
    
    int maxPacketSize = ASBDescription.mBytesPerPacket;
    if (maxPacketSize == 0) {
        UInt32 maxVBRPacketSize = sizeof(maxPacketSize);
        AudioQueueGetProperty (audioQueue,
//                               kAudioQueueProperty_MaximumOutputPacketSize,
                               // in Mac OS X v10.5, instead use
                                  kAudioConverterPropertyMaximumOutputPacketSize,
                               &maxPacketSize,
                               &maxVBRPacketSize);
    }
    
    Float64 numBytesForTime =
    ASBDescription.mSampleRate * maxPacketSize * seconds;
    *outBufferSize =
    UInt32 (numBytesForTime < maxBufferSize ?
            numBytesForTime : maxBufferSize);
}


OSStatus SetMagicCookieForFile (AudioQueueRef inQueue, AudioFileID  inFile)
{
    OSStatus result = noErr;
    UInt32 cookieSize;
    result = AudioQueueGetPropertySize (inQueue,
                                        kAudioQueueProperty_MagicCookie,
                                        &cookieSize);
    if (result != noErr) {
        return result;
    }
    
    char* magicCookie = (char *) malloc (cookieSize);
    result = AudioQueueGetProperty(inQueue,
                                   kAudioQueueProperty_MagicCookie,
                                   magicCookie,
                                   &cookieSize
                                   );
    if (result != noErr) {
        free(magicCookie);
        return result;
    }
    result = AudioFileSetProperty (inFile,
                                   kAudioFilePropertyMagicCookieData,
                                   cookieSize,
                                   magicCookie
                                   );
    free(magicCookie);
    return  result;
}



OSStatus createAudioQueue() {

    aqData.mDataFormat.mFormatID         = kAudioFormatLinearPCM; // 2
    aqData.mDataFormat.mSampleRate       = 44100.0;               // 3
    aqData.mDataFormat.mChannelsPerFrame = 2;                     // 4
    aqData.mDataFormat.mBitsPerChannel   = 16;                    // 5
    aqData.mDataFormat.mBytesPerPacket   =                        // 6
       aqData.mDataFormat.mBytesPerFrame =
          aqData.mDataFormat.mChannelsPerFrame * sizeof (SInt16);
    aqData.mDataFormat.mFramesPerPacket  = 1;                     // 7
    aqData.mDataFormat.mFormatFlags =                             // 9
        kLinearPCMFormatFlagIsBigEndian
        | kLinearPCMFormatFlagIsSignedInteger
        | kLinearPCMFormatFlagIsPacked;
    
    OSStatus status =  AudioQueueNewInput (&aqData.mDataFormat,
                                           HandleInputBuffer,
                                           &aqData,
                                           NULL,
                                           kCFRunLoopCommonModes,
                                           0,
                                           &aqData.mQueue);

    //Getting the Full Audio Format from an Audio Queue
//    UInt32 dataFormatSize = sizeof (aqData.mDataFormat);
//    status = AudioQueueGetProperty (aqData.mQueue,
//                                    //                           kAudioQueueProperty_StreamDescription,
//                                    // in Mac OS X, instead use
//                                    kAudioConverterCurrentInputStreamDescription,
//                                    &aqData.mDataFormat,
//                                    &dataFormatSize
//                                    );
//    assert(status == noErr);

    //Set an Audio Queue Buffer Size
    DeriveBufferSize (
                      aqData.mQueue,
                      aqData.mDataFormat,
                      0.5,
                      &aqData.bufferByteSize
                      );

    //Prepare a Set of Audio Queue Buffers
    for (int i = 0; i < kNumberBuffers; ++i) {
        AudioQueueAllocateBuffer (aqData.mQueue,
                                  aqData.bufferByteSize,
                                  &aqData.mBuffers[i]);

        AudioQueueEnqueueBuffer (aqData.mQueue,
                                 aqData.mBuffers[i],
                                 0,
                                 NULL);
    }

    
    //create auido file
    AudioFileTypeID fileType = kAudioFileAIFFType;
    const char *filePath = [NSHomeDirectory() stringByAppendingPathComponent:@"audio.aif"].cString;
    NSLog(@"file path = %s",filePath);
    
    CFURLRef audioFileURL = CFURLCreateFromFileSystemRepresentation (NULL,
                                                                     (const UInt8 *)filePath,
                                                                     strlen (filePath),
                                                                     false);
    status = AudioFileCreateWithURL (audioFileURL,
                                     fileType,
                                     &aqData.mDataFormat,
                                     kAudioFileFlags_EraseFile,
                                     &aqData.mAudioFile
                                     );
    
    return status;
}



void startRecording() {
    
    aqData.mCurrentPacket = 0;
    aqData.mIsRunning = true;
    AudioQueueStart (
                     aqData.mQueue,
                     NULL
                     );
}

void stopRecording() {
    AudioQueueStop (
                    aqData.mQueue,
                    true
                    );
    aqData.mIsRunning = false;
}


void cleanup() {
    
    if (aqData.mQueue) {
        AudioQueueDispose (                                 // 1
                           aqData.mQueue,                                  // 2
                           true                                            // 3
                           );
        aqData.mQueue = NULL;
    }
    
    if (aqData.mAudioFile) {
        AudioFileClose (aqData.mAudioFile);
        aqData.mAudioFile = NULL;
    }
}


@interface RZRecorder ()

@property (nonatomic, assign) BOOL setupSuccess;

@end

@implementation RZRecorder





- (BOOL)setup {
    
    if (_setupSuccess) {
        return YES;
    }
    OSStatus status = createAudioQueue();
    if (status != noErr) {
        return NO;
    }
    _setupSuccess = YES;
    return YES;
}

- (void)start {
    
    if (!self.setupSuccess) {
        return;
    }
    startRecording();
}

- (void)stop {
    if (!_setupSuccess) {
        return;
    }
    stopRecording();
}


@end

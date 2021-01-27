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
    AQRecorderState *pAqData = (AQRecorderState *) aqData;
    
    if (inNumPackets == 0 && pAqData->mDataFormat.mBytesPerPacket != 0) {
        inNumPackets = inBuffer->mAudioDataByteSize / pAqData->mDataFormat.mBytesPerPacket;
    }
        
    OSStatus status = AudioFileWritePackets(pAqData->mAudioFile,
                                             false,
                                             inBuffer->mAudioDataByteSize,
                                             inPacketDesc,
                                             pAqData->mCurrentPacket,
                                             &inNumPackets,
                                             inBuffer->mAudioData
                                             );

    if (status != noErr) {
        NSLog(@"HandleInputBuffer: AudioFileWritePackets failed, status = %d",status);
    } else {
        pAqData->mCurrentPacket += inNumPackets;
    }

    if (pAqData->mIsRunning == 0) {
        return;
    }
    
    status = AudioQueueEnqueueBuffer(pAqData->mQueue,
                                      inBuffer,
                                      0,
                                      NULL);
    if (status != noErr) {
        NSLog(@"HandleInputBuffer: AudioQueueEnqueueBuffer failed, status = %d",status);
    }
}


static void DeriveBufferSize(AudioQueueRef audioQueue,
                      AudioStreamBasicDescription  &ASBDescription,
                      Float64 seconds,
                      UInt32 *outBufferSize)
{
    static const int maxBufferSize = 0x50000;
    
    int maxPacketSize = ASBDescription.mBytesPerPacket;
    if (maxPacketSize == 0) {
        UInt32 maxVBRPacketSize = sizeof(maxPacketSize);
        AudioQueueGetProperty (audioQueue,
                               kAudioQueueProperty_MaximumOutputPacketSize,
                               // in Mac OS X v10.5, instead use
                               // kAudioConverterPropertyMaximumOutputPacketSize,
                               &maxPacketSize,
                               &maxVBRPacketSize);
    }
    
    Float64 numBytesForTime =
    ASBDescription.mSampleRate * maxPacketSize * seconds;
    *outBufferSize =
    UInt32 (numBytesForTime < maxBufferSize ?
            numBytesForTime : maxBufferSize);
}


static OSStatus SetMagicCookieForFile (AudioQueueRef inQueue, AudioFileID  inFile)
{
    
    UInt32 cookieSize;
    OSStatus status = AudioQueueGetPropertySize (inQueue,
                                        kAudioQueueProperty_MagicCookie,
                                        &cookieSize);
    if (status != noErr) {
        NSLog(@"AudioQueueGetPropertySize:kAudioQueueProperty_MagicCookie failed, status = %d", status);
        return status;
    }
    
    char* magicCookie = (char *) malloc (cookieSize);
    status = AudioQueueGetProperty(inQueue,
                                   kAudioQueueProperty_MagicCookie,
                                   magicCookie,
                                   &cookieSize
                                   );
    if (status != noErr) {
        free(magicCookie);
        NSLog(@"AudioQueueGetProperty:kAudioQueueProperty_MagicCookie failed, status = %d", status);
        return status;
    }
    status = AudioFileSetProperty (inFile,
                                   kAudioFilePropertyMagicCookieData,
                                   cookieSize,
                                   magicCookie
                                   );
    if (status != noErr) {
        NSLog(@"AudioFileSetProperty:kAudioFilePropertyMagicCookieData failed, status = %d", status);
    }
    free(magicCookie);
    return status;
}



static OSStatus createAudioQueue() {

    /*
     设置采集为aac，非pcm
     让AudioQueue决定真实的数据格式
     */
    aqData.mDataFormat.mFormatID = kAudioFormatMPEG4AAC;
    aqData.mDataFormat.mSampleRate = 44100.0;
    aqData.mDataFormat.mChannelsPerFrame = 1;
    aqData.mDataFormat.mBitsPerChannel = 0;
    aqData.mDataFormat.mBytesPerFrame = 0;
    aqData.mDataFormat.mBytesPerPacket = 0;
    aqData.mDataFormat.mFramesPerPacket = 0;
    aqData.mDataFormat.mFormatFlags = 0;
    
    OSStatus status = AudioQueueNewInput (&aqData.mDataFormat,
                                           HandleInputBuffer,
                                           &aqData,
                                           NULL,
                                           kCFRunLoopCommonModes,
                                           0,
                                           &aqData.mQueue);
    if (status != noErr) {
        NSLog(@"AudioQueueNewInput failed, status = %d",status);
        return status;
    }

    //Getting the Full Audio Format from an Audio Queue
    UInt32 dataFormatSize = sizeof (aqData.mDataFormat);
    status = AudioQueueGetProperty (aqData.mQueue,
                                    kAudioQueueProperty_StreamDescription,
                                    // in Mac OS X, instead use
                                    // kAudioConverterCurrentInputStreamDescription,
                                    &aqData.mDataFormat,
                                    &dataFormatSize
                                    );
    assert(status == noErr);

    //Set an Audio Queue Buffer Size
    DeriveBufferSize (
                      aqData.mQueue,
                      aqData.mDataFormat,
                      0.02,
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
    AudioFileTypeID fileType = kAudioFileAAC_ADTSType;
    const char *filePath = [[NSHomeDirectory() stringByAppendingPathComponent:@"audio.aac"] cStringUsingEncoding:NSUTF8StringEncoding];
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
    
    CFRelease(audioFileURL);
    assert(status == noErr);
    if (status != noErr) {
        NSLog(@"AudioFileCreateWithURL failed, status = %d", status);
        return status;
    }

    //set magic cookie
    SetMagicCookieForFile(aqData.mQueue, aqData.mAudioFile);
    
    
    return status;
}



static void startRecording() {
    
    if (!aqData.mQueue) {
        NSLog(@"startRecording: aqData.mQueue is not created!!!");
        return;
    }
    aqData.mCurrentPacket = 0;
    OSStatus status = AudioQueueStart (aqData.mQueue, NULL);
    if (status != noErr) {
        NSLog(@"AudioQueueStart failed, status = %d", status);
        return;
    }
    aqData.mIsRunning = true;
}

static void stopRecording() {
    if (!aqData.mQueue) {
        NSLog(@"stopRecording: aqData.mQueue is not created!!!");
        return;
    }
    AudioQueueStop (aqData.mQueue, true);
    aqData.mIsRunning = false;
}


static void cleanup() {
    
    if (aqData.mQueue) {
        AudioQueueDispose (aqData.mQueue,true);
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

- (void)dealloc
{
    cleanup();
}


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

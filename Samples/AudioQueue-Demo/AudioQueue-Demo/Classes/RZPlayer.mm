//
//  RZPlayer.m
//  AudioQueue-Demo
//
//  Created by yxibng on 2021/1/27.
//

#import "RZPlayer.h"
#import <AudioToolbox/AudioToolbox.h>

static const int kNumberBuffers = 3;                              // 1
struct AQPlayerState {
    AudioStreamBasicDescription   mDataFormat;                    // 2
    AudioQueueRef                 mQueue;                         // 3
    AudioQueueBufferRef           mBuffers[kNumberBuffers];       // 4
    AudioFileID                   mAudioFile;                     // 5
    UInt32                        bufferByteSize;                 // 6
    SInt64                        mCurrentPacket;                 // 7
    UInt32                        mNumPacketsToRead;              // 8
    AudioStreamPacketDescription  *mPacketDescs;                  // 9
    bool                          mIsRunning;                     // 10
};

static AQPlayerState aqData;

static void HandleOutputBuffer (void *aqData,
                                AudioQueueRef inAQ,
                                AudioQueueBufferRef inBuffer)
{
    AQPlayerState *pAqData = (AQPlayerState *)aqData;
    if (!pAqData->mIsRunning) {
        return;
    }
    
    NSLog(@"😘😘HandleOutputBuffer");
    
    UInt32 numBytesReadFromFile;                              // 3
    UInt32 numPackets = pAqData->mNumPacketsToRead;           // 4
    OSStatus status = AudioFileReadPacketData(pAqData->mAudioFile,
                                              false,
                                              &numBytesReadFromFile,
                                              pAqData->mPacketDescs,
                                              pAqData->mCurrentPacket,
                                              &numPackets,
                                              inBuffer->mAudioData);
    
    assert(status == noErr);
    if (numPackets > 0) {
        inBuffer->mAudioDataByteSize = numBytesReadFromFile;
        AudioQueueEnqueueBuffer (
                                 pAqData->mQueue,
                                 inBuffer,
                                 (pAqData->mPacketDescs ? numPackets : 0),
                                 pAqData->mPacketDescs
                                 );
        pAqData->mCurrentPacket += numPackets;
    } else {
        AudioQueueStop (
                        pAqData->mQueue,
                        false
                        );
        pAqData->mIsRunning = false;
    }
}

static void DeriveBufferSize (
                              AudioStreamBasicDescription &ASBDesc,                            // 1
                              UInt32                      maxPacketSize,                       // 2
                              Float64                     seconds,                             // 3
                              UInt32                      *outBufferSize,                      // 4
                              UInt32                      *outNumPacketsToRead                 // 5
) {
    static const int maxBufferSize = 0x50000;                        // 6
    static const int minBufferSize = 0x4000;                         // 7
    
    if (ASBDesc.mFramesPerPacket != 0) {                             // 8
        Float64 numPacketsForTime =
        ASBDesc.mSampleRate / ASBDesc.mFramesPerPacket * seconds;
        *outBufferSize = numPacketsForTime * maxPacketSize;
    } else {                                                         // 9
        *outBufferSize =
        maxBufferSize > maxPacketSize ?
        maxBufferSize : maxPacketSize;
    }
    
    if (                                                             // 10
        *outBufferSize > maxBufferSize &&
        *outBufferSize > maxPacketSize
        )
        *outBufferSize = maxBufferSize;
    else {                                                           // 11
        if (*outBufferSize < minBufferSize)
            *outBufferSize = minBufferSize;
    }
    
    *outNumPacketsToRead = *outBufferSize / maxPacketSize;           // 12
}


static void startPlaying() {
    
    aqData.mIsRunning = true;
    for (int i = 0; i<kNumberBuffers; i++) {
        HandleOutputBuffer (                                  // 7
                            &aqData,                                          // 8
                            aqData.mQueue,                                    // 9
                            aqData.mBuffers[i]                                // 10
                            );
    }
    
    UInt32 outNumberOfFramesPrepared;
    OSStatus result = AudioQueuePrime(aqData.mQueue, 0, &outNumberOfFramesPrepared);
    assert(result == noErr);
    if (result != noErr) {
        NSLog(@"AudioQueuePrime failed, status = %d",result);
        return;
    }
    
    NSLog(@"AudioQueuePrime: outNumberOfFramesPrepared = %d",outNumberOfFramesPrepared);

    AudioQueueStart (aqData.mQueue, NULL);
    do {
        CFRunLoopRunInMode (kCFRunLoopDefaultMode, 0.25, false);
    } while (aqData.mIsRunning);

    CFRunLoopRunInMode (kCFRunLoopDefaultMode, 1, false);
}

static void stopPlaying() {
    AudioQueueStop(aqData.mQueue, TRUE);
    aqData.mIsRunning = NO;
}


static OSStatus setup() {
    //Obtaining a CFURL Object for an Audio File
    const char *filePath = [[NSHomeDirectory() stringByAppendingPathComponent:@"audio.aac"] cStringUsingEncoding:NSUTF8StringEncoding];
    CFURLRef audioFileURL = CFURLCreateFromFileSystemRepresentation (
                                                                     NULL,
                                                                     (const UInt8 *) filePath,
                                                                     strlen (filePath),
                                                                     false
                                                                     );
    
    
    
    //Opening an audio file for playback
    OSStatus result = AudioFileOpenURL (audioFileURL,
                                        kAudioFileReadPermission,
                                        0,
                                        &aqData.mAudioFile);
    CFRelease (audioFileURL);
    assert(result == noErr);
    if (result != noErr) {
        NSLog(@"AudioFileOpenURL failed, status = %d",result);
        return result;
    }
    //Obtaining a File’s Audio Data Format
    UInt32 dataFormatSize = sizeof (aqData.mDataFormat);
    result = AudioFileGetProperty (
                                   aqData.mAudioFile,
                                   kAudioFilePropertyDataFormat,
                                   &dataFormatSize,
                                   &aqData.mDataFormat
                                   );
    
    assert(result == noErr);
    if (result != noErr) {
        NSLog(@"AudioFileGetProperty:kAudioFilePropertyDataFormat failed, status = %d",result);
        return result;
    }
    
    //Create a Playback Audio Queue
    result = AudioQueueNewOutput (&aqData.mDataFormat,
                                  HandleOutputBuffer,
                                  &aqData,
                                  CFRunLoopGetCurrent (),
                                  kCFRunLoopCommonModes,
                                  0,
                                  &aqData.mQueue
                                  );
    assert(result == noErr);
    if (result != noErr) {
        NSLog(@"AudioQueueNewOutput failed, status = %d",result);
        return result;
    }
    
    //Setting Buffer Size and Number of Packets to Read
    UInt32 maxPacketSize;
    UInt32 propertySize = sizeof (maxPacketSize);
    AudioFileGetProperty (
                          aqData.mAudioFile,
                          kAudioFilePropertyPacketSizeUpperBound,
                          &propertySize,
                          &maxPacketSize
                          );
    
    NSLog(@"maxPacketSize = %d", maxPacketSize);
    
    DeriveBufferSize (
                      aqData.mDataFormat,
                      maxPacketSize,
                      0.5,
                      &aqData.bufferByteSize,
                      &aqData.mNumPacketsToRead
                      );
    
    NSLog(@"mNumPacketsToRead: %d, size: %d, every 0.5 sec", aqData.mNumPacketsToRead, aqData.bufferByteSize);
    
    
    //Allocating Memory for a Packet Descriptions Array
    bool isFormatVBR = (aqData.mDataFormat.mBytesPerPacket == 0 || aqData.mDataFormat.mFramesPerPacket == 0);
    if (isFormatVBR) {
        NSLog(@"auido file is VBR");
        aqData.mPacketDescs = (AudioStreamPacketDescription*) malloc (aqData.mNumPacketsToRead * sizeof (AudioStreamPacketDescription));
    } else {
        NSLog(@"auido file is CBR");
        aqData.mPacketDescs = NULL;
    }
    
    //Set a Magic Cookie for a Playback Audio Queue
    UInt32 cookieSize = sizeof (UInt32);
    bool couldNotGetProperty =
    result = AudioFileGetPropertyInfo (aqData.mAudioFile,
                                       kAudioFilePropertyMagicCookieData,
                                       &cookieSize,
                                       NULL);
    assert(result == noErr);
    if (result != noErr) {
        NSLog(@"AudioFileGetPropertyInfo:kAudioFilePropertyMagicCookieData failed, status = %d", result);
        return result;
    }
    
    if (!couldNotGetProperty && cookieSize) {
        char* magicCookie = (char *) malloc (cookieSize);
        AudioFileGetProperty (aqData.mAudioFile,
                              kAudioFilePropertyMagicCookieData,
                              &cookieSize,
                              magicCookie);
        
        AudioQueueSetProperty (aqData.mQueue,
                               kAudioQueueProperty_MagicCookie,
                               magicCookie,
                               cookieSize);
        free (magicCookie);
    }
    
    //Allocate and Prime Audio Queue Buffers
    aqData.mCurrentPacket = 0;
    for (int i = 0; i < kNumberBuffers; ++i) {                // 2
       OSStatus status = AudioQueueAllocateBuffer (                            // 3
                                  aqData.mQueue,                                    // 4
                                  aqData.bufferByteSize,                            // 5
                                  &aqData.mBuffers[i]                               // 6
                                  );
        assert(status == noErr);
    }
    //Set an Audio Queue’s Playback Gain
    Float32 gain = 1.0;                                       // 1
    // Optionally, allow user to override gain setting here
    AudioQueueSetParameter (                                  // 2
                            aqData.mQueue,                                        // 3
                            kAudioQueueParam_Volume,                              // 4
                            gain                                                  // 5
                            );
    return noErr;
}


static void cleanup() {
    if (aqData.mQueue) {
        AudioQueueDispose (aqData.mQueue, true);
        aqData.mQueue = NULL;
    }
    
    if (aqData.mAudioFile) {
        AudioFileClose (aqData.mAudioFile);
        aqData.mAudioFile = NULL;
    }
    
    if (aqData.mPacketDescs) {
        free (aqData.mPacketDescs);
        aqData.mPacketDescs = NULL;
    }
    
}


@interface RZPlayer ()

@property (nonatomic, strong) dispatch_queue_t playQueue;
@end

@implementation RZPlayer

- (instancetype)init
{
    self = [super init];
    if (self) {
        _playQueue = dispatch_queue_create("com.xx.playback.queue", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}


- (void)dealloc {
    cleanup();
}

- (BOOL)setup {
    OSStatus status = setup();
    if (status == noErr) {
        return YES;
    }
    return NO;
}

- (void)start {
    dispatch_async(self.playQueue, ^{
        startPlaying();
    });
}
- (void)stop {
    dispatch_async(self.playQueue, ^{
        stopPlaying();
    });
}

@end

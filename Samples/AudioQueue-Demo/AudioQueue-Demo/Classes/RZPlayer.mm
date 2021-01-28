//
//  RZPlayer.m
//  AudioQueue-Demo
//
//  Created by yxibng on 2021/1/27.
//

#import "RZPlayer.h"
#import <AudioToolbox/AudioToolbox.h>
#import <OSLog/OSLog.h>

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
    UInt32 numBytesReadFromFile;
    UInt32 numPackets = pAqData->mNumPacketsToRead;
    OSStatus status = AudioFileReadPackets(pAqData->mAudioFile,
                                              true,
                                              &numBytesReadFromFile,
                                              pAqData->mPacketDescs,
                                              pAqData->mCurrentPacket,
                                              &numPackets,
                                              inBuffer->mAudioData);
    if (status != noErr) {
        os_log_error(OS_LOG_DEFAULT, "AudioFileReadPacketData, numPackets = %d", numPackets);
    }

    assert(status == noErr);
    if (numPackets > 0) {
        inBuffer->mAudioDataByteSize = numBytesReadFromFile;
       status = AudioQueueEnqueueBuffer (
                                 pAqData->mQueue,
                                 inBuffer,
                                 (pAqData->mPacketDescs ? numPackets : 0),
                                 pAqData->mPacketDescs
                                 );
        assert(status == noErr);
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
                              AudioStreamBasicDescription &ASBDesc,
                              UInt32                      maxPacketSize,
                              Float64                     seconds,
                              UInt32                      *outBufferSize,
                              UInt32                      *outNumPacketsToRead)
{
    static const int maxBufferSize = 0x10000;// limit size to 64K
    static const int minBufferSize = 0x4000;// limit size to 16K
    
    if (ASBDesc.mFramesPerPacket != 0) {
        //算出0.5秒有多少个包 21.53
        Float64 numPacketsForTime = ASBDesc.mSampleRate / ASBDesc.mFramesPerPacket * seconds;
        UInt32 bufferSizeForTime = numPacketsForTime * maxPacketSize;
        NSLog(@"maxPack size = %d, pack number = %f, bufferSize = %d", maxPacketSize, numPacketsForTime, bufferSizeForTime);
        *outBufferSize = bufferSizeForTime;
    } else {
        *outBufferSize = maxBufferSize > maxPacketSize ? maxBufferSize : maxPacketSize;
    }
    
    if (*outBufferSize > maxBufferSize && *outBufferSize > maxPacketSize) {
        *outBufferSize = maxBufferSize;
    } else {
        if (*outBufferSize < minBufferSize) {
            *outBufferSize = minBufferSize;
        }
    }
    
    int toRead = *outBufferSize / maxPacketSize;
    *outNumPacketsToRead = toRead;// 12
}


static void startPlaying() {
    
    aqData.mIsRunning = true;
    aqData.mCurrentPacket = 0;
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

    NSURL *fileURL = [[NSBundle mainBundle] URLForResource:@"audio" withExtension:@"aac"];
    //Opening an audio file for playback
    OSStatus result = AudioFileOpenURL ((__bridge CFURLRef)fileURL,
                                        kAudioFileReadPermission,
                                        0,
                                        &aqData.mAudioFile);
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
       result = AudioFileGetProperty (aqData.mAudioFile,
                              kAudioFilePropertyMagicCookieData,
                              &cookieSize,
                              magicCookie);
        assert(result == noErr);
        
        result = AudioQueueSetProperty (aqData.mQueue,
                               kAudioQueueProperty_MagicCookie,
                               magicCookie,
                               cookieSize);
        assert(result == noErr);
        free (magicCookie);
    }
    
    //Allocate and Prime Audio Queue Buffers
    for (int i = 0; i < kNumberBuffers; ++i) {
       OSStatus status = AudioQueueAllocateBuffer (
                                  aqData.mQueue,
                                  aqData.bufferByteSize,
                                  &aqData.mBuffers[i]
                                  );
        
//        OSStatus status = AudioQueueAllocateBufferWithPacketDescriptions(aqData.mQueue, aqData.bufferByteSize, aqData.mNumPacketsToRead, &aqData.mBuffers[i]);
        
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

//
//  AudioUnitRecorder.m
//  AudioUnit-demo
//
//  Created by yxibng on 2021/1/29.
//

#import "AudioUnitRecorder.h"
#import "AudioUtil.h"
#import <AVFoundation/AVFoundation.h>

static UInt32 kInputBus = 1;
static UInt32 kOutputBus = 0;

//设置20ms读写一次
static NSTimeInterval kIODuration = 0.02;

struct AudioUnitRecorderInfo{
    AudioUnit audioUnit;
    AudioStreamBasicDescription outputStreamDesc;
    BOOL setupSuccess;
    BOOL isRunning;
    __weak AudioUnitRecorder *recorder;
};

static struct AudioUnitRecorderInfo recorderInfo;



@implementation AudioUnitRecorder

static OSStatus renderCallback(void *inRefCon,
                        AudioUnitRenderActionFlags *ioActionFlags,
                        const AudioTimeStamp *inTimeStamp,
                        UInt32 inBusNumber,
                        UInt32 inNumberFrames,
                        AudioBufferList * __nullable ioData)
{
    
    struct AudioUnitRecorderInfo *info = (struct AudioUnitRecorderInfo *)inRefCon;
    
    
    AudioBufferList list;
    list.mNumberBuffers = 1;
    list.mBuffers[0].mData = NULL;
    list.mBuffers[0].mDataByteSize = 0;
    
    OSStatus status = AudioUnitRender(info->audioUnit, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, &list);
    assert(status == noErr);
    
    AudioUnitRecorder *recorder = info->recorder;
    if ([recorder.delegate respondsToSelector:@selector(audioRecorder:didCaptureData:sampleRate:length:)]) {
        [recorder.delegate audioRecorder:recorder didCaptureData:list.mBuffers[0].mData sampleRate:info->outputStreamDesc.mSampleRate length:list.mBuffers[0].mDataByteSize];
    }
    
    return noErr;
}

static OSStatus setup() {

    if (recorderInfo.setupSuccess) {
        return noErr;
    }
        
    AudioComponentDescription desc;
    desc.componentType = kAudioUnitType_Output;
    desc.componentSubType = kAudioUnitSubType_HALOutput;
    desc.componentManufacturer = kAppleManufacturer;
    desc.componentFlags = 0;
    desc.componentFlagsMask = 0;
    
    AudioComponent componet = AudioComponentFindNext(NULL, &desc);
    OSStatus status =  AudioComponentInstanceNew(componet, &recorderInfo.audioUnit);
    assert(status == noErr);
    if (status != noErr) {
        return status;
    }
    
    //enable input
    UInt32 inputEnableFlag = 1;
    status =  AudioUnitSetProperty(recorderInfo.audioUnit,
                                   kAudioOutputUnitProperty_EnableIO,
                                   kAudioUnitScope_Input,
                                   kInputBus,
                                   &inputEnableFlag,
                                   sizeof(inputEnableFlag));
    assert(status == noErr);
    if (status != noErr) {
        return status;
    }
    //disable output
    UInt32 outputEnableFlag = 0;
    status =  AudioUnitSetProperty(recorderInfo.audioUnit,
                                   kAudioOutputUnitProperty_EnableIO,
                                   kAudioUnitScope_Output,
                                   kOutputBus,
                                   &outputEnableFlag,
                                   sizeof(outputEnableFlag));
    assert(status == noErr);
    if (status != noErr) {
        return status;
    }
    //get current device ID
    AudioDeviceID deviceID;
    UInt32 propSize = sizeof(AudioDeviceID);
    AudioObjectPropertyAddress propertyAddress = {
        .mSelector = kAudioHardwarePropertyDefaultInputDevice,
        .mScope = kAudioObjectPropertyScopeGlobal,
        .mElement = kAudioObjectPropertyElementMaster
    };
    
    status = AudioObjectGetPropertyData(kAudioObjectSystemObject,
                                        &propertyAddress,
                                        0,
                                        NULL,
                                        &propSize,
                                        &deviceID);
    assert(status == noErr);
    if (status != noErr) {
        return status;
    }
    if (deviceID == kAudioDeviceUnknown) {
        //no input device found
        return kAudioHardwareBadDeviceError;
    }
    
    
    status = setCurrentDevice(deviceID);
    assert(status == noErr);
    if (status != noErr) {
        return status;
    }
    
   
    //set call back
    AURenderCallbackStruct renderCallbackStruct;
    renderCallbackStruct.inputProcRefCon = (void *)&(recorderInfo);
    renderCallbackStruct.inputProc = renderCallback;
    status = AudioUnitSetProperty(recorderInfo.audioUnit,
                                  kAudioOutputUnitProperty_SetInputCallback,
                                  kAudioUnitScope_Global, kInputBus,
                                  &renderCallbackStruct,
                                  sizeof(AURenderCallbackStruct));
    assert(status == noErr);
    if (status != noErr) {
        return status;
    }
    
    status = AudioUnitInitialize(recorderInfo.audioUnit);
    assert(status == noErr);
    if (status != noErr) {
        return status;
    }
    
    recorderInfo.setupSuccess = YES;
    
    //init
    return noErr;
}



static OSStatus setCurrentDevice(AudioDeviceID deviceID) {
    //set input device
   OSStatus status = AudioUnitSetProperty(recorderInfo.audioUnit,
                                  kAudioOutputUnitProperty_CurrentDevice,
                                  kAudioUnitScope_Global,
                                  kInputBus,
                                  &deviceID,
                                  sizeof(AudioDeviceID));
    
    //get mic output stream desc
    AudioStreamBasicDescription inputStreamDesc;
    UInt32 streamPropSize = sizeof(AudioStreamBasicDescription);
    status = AudioUnitGetProperty(recorderInfo.audioUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Input,
                                  kInputBus,
                                  &inputStreamDesc,
                                  &streamPropSize);
    assert(status == noErr);
    if (status != noErr) {
        return status;
    }
    
    //set stream desc (ouptput sampleRate = input sampleRate)
    AudioStreamBasicDescription outputStreamDesc = *([[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatInt16 sampleRate:16000 channels:1 interleaved:YES].streamDescription);
    /*
     如果采样率和输入的采用不同，在audioRender的时候，会失败 报错 -10863
     */
    outputStreamDesc.mSampleRate = inputStreamDesc.mSampleRate;
    status = AudioUnitSetProperty(recorderInfo.audioUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Output,
                                  kInputBus,
                                  &outputStreamDesc,
                                  sizeof(AudioStreamBasicDescription));
    assert(status == noErr);
    if (status != noErr) {
        return status;
    }
    //记录采集的数据格式
    recorderInfo.outputStreamDesc = outputStreamDesc;
    
    //get range
    UInt32 min, max;
    status = GetIOBufferFrameSizeRangeOfDevice(deviceID, &min, &max);
    assert(status == noErr);
    assert(status == noErr);
    if (status != noErr) {
        return status;
    }
    
    //set max of unit to range max
    status = AudioUnitSetMaxIOBufferFrameSize(recorderInfo.audioUnit, max);
    assert(status == noErr);
    if (status != noErr) {
        return status;
    }
    
    //get max of  unit
    UInt32 maxIOBufferFrameSize;
    status = AudioUnitGetMaxIOBufferFrameSize(recorderInfo.audioUnit, &maxIOBufferFrameSize);
    assert(status == noErr);
    if (status != noErr) {
        return status;
    }
    
    //set current
    UInt32 ioSize = ceil(kIODuration * outputStreamDesc.mSampleRate);
    SetCurrentIOBufferFrameSizeOfDevice(deviceID, ioSize);
    
    //get current
    UInt32 currentIOBufferFrameSize;
    status = GetCurrentIOBufferFrameSizeOfDevice(deviceID, &currentIOBufferFrameSize);
    assert(status == noErr);
    if (status != noErr) {
        return status;
    }
    
    NSLog(@"sample rate = %f\n min = %d, max = %d\n current = %d, maxIO = %d",outputStreamDesc.mSampleRate, min, max, currentIOBufferFrameSize, maxIOBufferFrameSize);
    return noErr;
}


static void start() {
    if (recorderInfo.isRunning) {
        return;
    }
    OSStatus status = AudioOutputUnitStart(recorderInfo.audioUnit);
    assert(status == noErr);
    recorderInfo.isRunning = YES;
}

static void stop() {
    if (!recorderInfo.isRunning) {
        return;
    }
    OSStatus status = AudioOutputUnitStop(recorderInfo.audioUnit);
    assert(status == noErr);
    recorderInfo.isRunning = NO;
}

static void dispose() {
    OSStatus status = AudioComponentInstanceDispose(recorderInfo.audioUnit);
    assert(status == noErr);
    recorderInfo.setupSuccess = NO;
}


- (void)dealloc {
    dispose();
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        recorderInfo.recorder = self;
        setup();
    }
    return self;
}


- (void)start {
    start();
}

- (void)stop {
    stop();
}

- (void)changeDevice:(AudioDeviceID)deviceID
{
    if (deviceID == kAudioDeviceUnknown) {
        NSLog(@"changeDevice failed, device not exist");
        return;
    }
    
    if (!recorderInfo.setupSuccess) {
        NSLog(@"changeDevice failed, audio unit not initialized");

    }
    setCurrentDevice(deviceID);
}

@end

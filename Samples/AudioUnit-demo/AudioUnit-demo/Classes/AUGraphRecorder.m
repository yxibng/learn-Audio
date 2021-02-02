//
//  AUGraphRecorder.m
//  AudioUnit-demo
//
//  Created by yxibng on 2021/2/1.
//

#import "AUGraphRecorder.h"
#import <AVFoundation/AVFoundation.h>
#import "AudioUtil.h"


static UInt32 kInputBus = 1;
static UInt32 kOutputBus = 0;

//设置20ms读写一次
static NSTimeInterval kIODuration = 0.02;


typedef struct {
    AUGraph graph;
    AUNode inputNode;
    AudioUnit inputUnit;
    
    AudioStreamBasicDescription outputStreamDesc;
    
    BOOL setupSuccess;
    BOOL isRunning;
} AUGraphInfo;



static OSStatus setCurrentDevice(AudioDeviceID deviceID, AudioUnit audioUnit, AudioStreamBasicDescription *ouputDesc) {
    //set input device
   OSStatus status = AudioUnitSetProperty(audioUnit,
                                  kAudioOutputUnitProperty_CurrentDevice,
                                  kAudioUnitScope_Global,
                                  kInputBus,
                                  &deviceID,
                                  sizeof(AudioDeviceID));
    
    //get mic output stream desc
    AudioStreamBasicDescription inputStreamDesc;
    UInt32 streamPropSize = sizeof(AudioStreamBasicDescription);
    status = AudioUnitGetProperty(audioUnit,
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
    status = AudioUnitSetProperty(audioUnit,
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
    *ouputDesc = outputStreamDesc;
    
    //get range
    UInt32 min, max;
    status = GetIOBufferFrameSizeRangeOfDevice(deviceID, &min, &max);
    assert(status == noErr);
    assert(status == noErr);
    if (status != noErr) {
        return status;
    }
    
    //set max of unit to range max
    status = AudioUnitSetMaxIOBufferFrameSize(audioUnit, max);
    assert(status == noErr);
    if (status != noErr) {
        return status;
    }
    
    //get max of  unit
    UInt32 maxIOBufferFrameSize;
    status = AudioUnitGetMaxIOBufferFrameSize(audioUnit, &maxIOBufferFrameSize);
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





@interface AUGraphRecorder()
{
    @public
    AUGraphInfo _graphInfo;
}

@end

@implementation AUGraphRecorder

- (void)dealloc
{
    [self dispose];
}


- (instancetype)init
{
    self = [super init];
    if (self) {
        [self setup];
    }
    return self;
}

- (OSStatus)setup {
    
    if (_graphInfo.setupSuccess) {
        return noErr;
    }
    
    OSStatus status = NewAUGraph(&_graphInfo.graph);
    assert(status == noErr);
    if (status != noErr) {
        return status;
    }
    
    //add input node
    AudioComponentDescription inputComponetDesc = {
        .componentType = kAudioUnitType_Output,
        .componentSubType = kAudioUnitSubType_HALOutput,
        .componentManufacturer = kAudioUnitManufacturer_Apple,
        .componentFlags = 0,
        .componentFlagsMask = 0
    };
    
    status = AUGraphAddNode(_graphInfo.graph, &inputComponetDesc, &_graphInfo.inputNode);
    assert(status == noErr);
    if (status != noErr) {
        return status;
    }
    
    // open the graph AudioUnits are open but not initialized (no resource allocation occurs here)
    status = AUGraphOpen(_graphInfo.graph);
    assert(status == noErr);
    if (status != noErr) {
        return status;
    }
    
    // grab the audio unit instances from the nodes
    status = AUGraphNodeInfo(_graphInfo.graph, _graphInfo.inputNode, &inputComponetDesc, &_graphInfo.inputUnit);
    assert(status == noErr);
    if (status != noErr) {
        return status;
    }
    
    /*-----------------------------config audio unit---------------------------------*/
    //enable input
    UInt32 inputEnableFlag = 1;
    status = AudioUnitSetProperty(_graphInfo.inputUnit,
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
    status = AudioUnitSetProperty(_graphInfo.inputUnit,
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
    
    AudioStreamBasicDescription ouputDesc;
    status = setCurrentDevice(deviceID, _graphInfo.inputUnit, &ouputDesc);
    assert(status == noErr);
    if (status != noErr) {
        return status;
    }
    _graphInfo.outputStreamDesc = ouputDesc;
    
    //set call back
    AURenderCallbackStruct renderCallbackStruct;
    renderCallbackStruct.inputProcRefCon = (__bridge void *)self;
    renderCallbackStruct.inputProc = renderCallback;
    status = AudioUnitSetProperty(_graphInfo.inputUnit,
                                  kAudioOutputUnitProperty_SetInputCallback,
                                  kAudioUnitScope_Global,
                                  kInputBus,
                                  &renderCallbackStruct,
                                  sizeof(AURenderCallbackStruct));
    
    status = AUGraphInitialize(_graphInfo.graph);
    assert(status == noErr);
    if (status != noErr) {
        return status;
    }
    _graphInfo.setupSuccess = YES;
    return noErr;
}


- (void)start {
    
    if (!_graphInfo.setupSuccess) {
        return;
    }
    
    if (_graphInfo.isRunning) {
        return;
    }
    OSStatus status = AUGraphStart(_graphInfo.graph);
    assert(status == noErr);
    _graphInfo.isRunning = YES;
    
}

- (void)stop {
    if (!_graphInfo.setupSuccess) {
        return;
    }
    if (!_graphInfo.isRunning) {
        return;
    }
    OSStatus status = AUGraphStop(_graphInfo.graph);
    assert(status == noErr);
    _graphInfo.isRunning = NO;
}

- (void)dispose {
    
    if (!_graphInfo.setupSuccess) {
        return;
    }
    //stop
    [self stop];
        
    //dispose
    OSStatus status = AUGraphUninitialize(_graphInfo.graph);
    assert(status == noErr);
    status = DisposeAUGraph(_graphInfo.graph);
    assert(status == noErr);
    _graphInfo.setupSuccess = NO;
}

- (void)changeDevice:(AudioDeviceID)deviceID {
    AudioStreamBasicDescription outputDesc;
    OSStatus status = setCurrentDevice(deviceID, _graphInfo.inputUnit, &outputDesc);
    assert(status == noErr);
    _graphInfo.outputStreamDesc = outputDesc;
}


static OSStatus renderCallback(void *inRefCon,
                        AudioUnitRenderActionFlags *ioActionFlags,
                        const AudioTimeStamp *inTimeStamp,
                        UInt32 inBusNumber,
                        UInt32 inNumberFrames,
                        AudioBufferList * __nullable ioData)
{
    AUGraphRecorder *recorder = (__bridge AUGraphRecorder *)inRefCon;
    
    AudioBufferList list;
    list.mNumberBuffers = 1;
    list.mBuffers[0].mData = NULL;
    list.mBuffers[0].mDataByteSize = 0;
    
    OSStatus status = AudioUnitRender(recorder->_graphInfo.inputUnit, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, &list);
    assert(status == noErr);

    if ([recorder.delegate respondsToSelector:@selector(audioRecorder:didCaptureData:length:format:)]) {
        [recorder.delegate audioRecorder:recorder didCaptureData:list.mBuffers[0].mData length:list.mBuffers[0].mDataByteSize format:recorder->_graphInfo.outputStreamDesc];
    }

    return noErr;
}


@end

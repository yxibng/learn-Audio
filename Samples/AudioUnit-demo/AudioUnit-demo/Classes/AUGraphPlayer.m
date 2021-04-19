//
//  AUGraphPlayer.m
//  AudioUnit-demo
//
//  Created by yxibng on 2021/4/16.
//

#import "AUGraphPlayer.h"

#import "AudioUtil.h"
static UInt32 kInputBus = 1;
static UInt32 kOutputBus = 0;

typedef struct {
    AUGraph graph;
    AUNode outputNode;
    AudioUnit outputUnit;
    
    AudioStreamBasicDescription inputStreamDesc;
    
    BOOL setupSuccess;
    BOOL isRunning;
} AUGraphInfo;

#if 0
static OSStatus setCurrentDevice(AudioDeviceID deviceID, AudioUnit audioUnit, AudioConfig config, AudioStreamBasicDescription *ouputDesc) {
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
    UInt32 channelCount = config.channelCount;
    BOOL interleaved = config.interleaved;
    AudioStreamBasicDescription outputStreamDesc = *([[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatInt16 sampleRate:16000 channels:channelCount interleaved:interleaved].streamDescription);
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
    UInt32 ioSize = ceil(config.ioDuration * outputStreamDesc.mSampleRate);
    if (ioSize > max) {
        ioSize = max;
    }
    if (ioSize < min) {
        ioSize = min;
    }
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


#endif


@interface AUGraphPlayer()
{
    @public
    AUGraphInfo _graphInfo;
}
@property (nonatomic, assign) AudioPlayConfig playConfig;
@end


@implementation AUGraphPlayer

- (void)dealloc
{
    [self dispose];
}

- (instancetype)initWithPlayConifg:(AudioPlayConfig)playConfig delegate:(id<AUGraphPlayerDelegate>)delegate
{
    self = [super init];
    if (self) {

        //got play format
        AVAudioFormat *format =  [[AVAudioFormat alloc] initWithCommonFormat:playConfig.pcmFormat sampleRate:playConfig.sampleRate channels:playConfig.channelCount interleaved:playConfig.interleaved];
        _graphInfo.inputStreamDesc = *(format.streamDescription);
        format = nil;
        
        _playConfig = playConfig;
        _delegate = delegate;
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
    
    //add ouput node
    AudioComponentDescription inputComponetDesc = {
        .componentType = kAudioUnitType_Output,
        .componentSubType = kAudioUnitSubType_HALOutput,
        .componentManufacturer = kAudioUnitManufacturer_Apple,
        .componentFlags = 0,
        .componentFlagsMask = 0
    };
    
    status = AUGraphAddNode(_graphInfo.graph, &inputComponetDesc, &_graphInfo.outputNode);
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
    status = AUGraphNodeInfo(_graphInfo.graph, _graphInfo.outputNode, &inputComponetDesc, &_graphInfo.outputUnit);
    assert(status == noErr);
    if (status != noErr) {
        return status;
    }
    
    /*-----------------------------config audio unit---------------------------------*/
    //disable input
    UInt32 inputEnableFlag = 0;
    status = AudioUnitSetProperty(_graphInfo.outputUnit,
                                   kAudioOutputUnitProperty_EnableIO,
                                   kAudioUnitScope_Input,
                                   kInputBus,
                                   &inputEnableFlag,
                                   sizeof(inputEnableFlag));
    assert(status == noErr);
    if (status != noErr) {
        return status;
    }
    
    //config input format
    status = AudioUnitSetProperty(_graphInfo.outputUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Input,
                                  kOutputBus,
                                  &(_graphInfo.inputStreamDesc),
                                  sizeof(_graphInfo.inputStreamDesc));
    assert(status == noErr);
    if (status != noErr) {
        return status;
    }
    
    //set play callback
    AURenderCallbackStruct rcbs;
    rcbs.inputProc = &playbackCallback;
    rcbs.inputProcRefCon = (__bridge void * _Nullable)(self);
    status = AUGraphSetNodeInputCallback(_graphInfo.graph, _graphInfo.outputNode, kOutputBus, &rcbs);
    assert(status == noErr);
    if (status != noErr) {
        return status;
    }

    status = AUGraphInitialize(_graphInfo.graph);
    assert(status == noErr);
    if (status != noErr) {
        return status;
    }
    _graphInfo.setupSuccess = YES;
    
    
    //get current device ID
    AudioDeviceID deviceID;
    UInt32 propSize = sizeof(AudioDeviceID);
    AudioObjectPropertyAddress propertyAddress = {
        .mSelector = kAudioHardwarePropertyDefaultOutputDevice,
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
    
    [self configDevice:deviceID];
    
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
    if (deviceID == kAudioDeviceUnknown) {
        return;
    }
    
    //更改当前使用的播放设备
    OSStatus status = AudioUnitSetProperty(_graphInfo.outputUnit,
                                           kAudioOutputUnitProperty_CurrentDevice,
                                           kAudioUnitScope_Global,
                                           0,
                                           &deviceID,
                                           sizeof(AudioDeviceID));
    NSAssert(status == noErr, @"failed to set current audio output device, status = %d", status);
    if (status != noErr) {
        return;
    }
    
    [self configDevice:deviceID];
}

- (void)configDevice:(AudioDeviceID)deviceID {
    if (deviceID == kAudioDeviceUnknown) {
        return;
    }
    
    UInt32 min, max;
    OSStatus status = GetIOBufferFrameSizeRangeOfDevice(deviceID, &min, &max);
    if (status != noErr) {
        return;
    }
    //获取需要输入的数据的格式
    UInt32 propSize = sizeof(AudioStreamBasicDescription);
    AudioStreamBasicDescription desc;
    status = AudioUnitGetProperty(_graphInfo.outputUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Input,
                                  kOutputBus,
                                  &desc,
                                  &propSize);
    NSAssert(status == noErr, @"failed to get current audioUnit stream format, status = %d", status);
    if (status!=noErr) {
        return;
    }

    //设置当前设备的每次读取的采样个数
    //当前 unit 的最大 slice
    status = AudioUnitSetMaxIOBufferFrameSize(_graphInfo.outputUnit, max);
    NSAssert(status == noErr, @"failed to set current audioUnit max IO Buffer Frame Size to %d, status = %d",  max, status);
    if (status != noErr) {
        return;
    }

    //设置每次IO的buffer 为 0.02 秒采样率的长度, 但是没有用
    UInt32 ioBufferFrameSize = desc.mSampleRate * 0.02;
    status = SetCurrentIOBufferFrameSizeOfDevice(deviceID, ioBufferFrameSize);
    NSAssert(status == noErr, @"failed to set current device %d, IO Buffer Frame Size to %d, status = %d", deviceID, max, status);
    if (status != noErr) {
        return;
    }
}


static OSStatus playbackCallback(void *inRefCon,
                                 AudioUnitRenderActionFlags *ioActionFlags,
                                 const AudioTimeStamp *inTimeStamp,
                                 UInt32 inBusNumber,
                                 UInt32 inNumberFrames,
                                 AudioBufferList *ioData)
{
    
    AUGraphPlayer *player = (__bridge AUGraphPlayer *)inRefCon;
    if ([player.delegate respondsToSelector:@selector(audioPlayer:fillAudioBufferList:inBusNumber:inNumberFrames:)]) {
        [player.delegate audioPlayer:player fillAudioBufferList:ioData inBusNumber:inBusNumber inNumberFrames:inNumberFrames];
    }
    return noErr;
}




@end

//
//  AUGraphRecorder.m
//  AudioUnit-iOS
//
//  Created by yxibng on 2021/2/2.
//

#import "AudioRecorder.h"
#import <AVFoundation/AVFoundation.h>
static UInt32 kInputBus = 1;
static UInt32 kOutputBus = 0;

typedef struct {
    AUGraph graph;
    AUNode inputNode;
    AudioUnit inputUnit;
    
    AudioStreamBasicDescription outputStreamDesc;
    
    BOOL setupSuccess;
    BOOL isRunning;
} AUGraphInfo;

@interface AudioRecorder()
{
    @public
    AUGraphInfo _graphInfo;
}

@end

@implementation AudioRecorder

- (void)dealloc
{
    [self dispose];
}


- (instancetype)initWithSampleRate:(Float64)sampleRate delegate:(id<AUGraphRecorderDelegate>)delegate
{
    self = [super init];
    if (self) {
        _delegate = delegate;
        _graphInfo.outputStreamDesc = *([[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatInt16 sampleRate:sampleRate channels:1 interleaved:NO].streamDescription);
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
        .componentSubType = kAudioUnitSubType_VoiceProcessingIO,
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
    
    //set output format
    status = AudioUnitSetProperty(_graphInfo.inputUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Output,
                                  kInputBus,
                                  &_graphInfo.outputStreamDesc,
                                  sizeof(AudioStreamBasicDescription));
    
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
    
    [AVCaptureDevice requestAccessForMediaType:AVMediaTypeAudio completionHandler:^(BOOL granted) {
        
        if (granted) {
            OSStatus status = AUGraphStart(self->_graphInfo.graph);
            assert(status == noErr);
            self->_graphInfo.isRunning = YES;
            if ([self.delegate respondsToSelector:@selector(audioRecorderDidStart:)]) {
                [self.delegate audioRecorderDidStart:self];
            }
        } else {
            if ([self.delegate respondsToSelector:@selector(audioRecorder:didOccurError:userInfo:)]) {
                [self.delegate audioRecorder:self didOccurError:AUGraphErrorNoPermission userInfo:nil];
            }
        }
    }];
    

    
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
    if ([self.delegate respondsToSelector:@selector(audioRecorderDidStop:)]) {
        [self.delegate audioRecorderDidStop:self];
    }
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

- (void)handleAudioServicesReset {
    //重新构建
    _graphInfo.setupSuccess = NO;
    _graphInfo.isRunning = NO;
    _graphInfo.graph = NULL;
    [self setup];
}


static OSStatus renderCallback(void *inRefCon,
                        AudioUnitRenderActionFlags *ioActionFlags,
                        const AudioTimeStamp *inTimeStamp,
                        UInt32 inBusNumber,
                        UInt32 inNumberFrames,
                        AudioBufferList * __nullable ioData)
{
    AudioRecorder *recorder = (__bridge AudioRecorder *)inRefCon;
    
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

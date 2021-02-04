//
//  ViewController.m
//  AudioUnit-demo
//
//  Created by yxibng on 2021/1/29.
//

#import "ViewController.h"
#import "AudioUnitRecorder.h"
#import "AUGraphRecorder.h"
#import "AudioDevice.h"
#import "AudioConverter.h"

static BOOL kUseGraph = NO;


@interface ViewController ()<AudioRecorderDelegate>

@property (weak) IBOutlet NSPopUpButton *inputListButton;
@property (nonatomic, strong) NSArray<AudioDevice *> *inputDevices;
@property (nonatomic, strong) AudioDevice *currentInputDevice;
@property (nonatomic, strong) id<AudioRecorderProtocol>recorder;
@property (nonatomic, assign) AudioStreamBasicDescription destinationFormat;
@property (nonatomic, strong) AudioConverter *audioConverter;

@end


@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    /*
     采集双声道，平面型
     */
    AudioConfig config = {
        .channelCount = 2,
        .interleaved = NO,
        .ioDuration = 0.02
    };
    
    if (kUseGraph) {
        _recorder = [[AUGraphRecorder alloc] initWithConfig:config delegate:self];
    } else {
        _recorder = [[AudioUnitRecorder alloc] initWithConfig:config delegate:self];
    }
    _recorder.delegate = self;

    _currentInputDevice = [AudioDevice defaultInputDevice];
    _inputDevices = [AudioDevice inputDevices];


    [self.inputListButton removeAllItems];
    for (AudioDevice *device in _inputDevices) {
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:device.localizedName action:@selector(onClickInputDevice:) keyEquivalent:@""];
        [self.inputListButton.menu addItem:item];
        if (device.deviceID == _currentInputDevice.deviceID) {
            NSInteger index = [_inputDevices indexOfObject:device];
            [self.inputListButton selectItemAtIndex:index];
        }
    }
    //set device
    [_recorder changeDevice:_currentInputDevice.deviceID];
    
    
    AudioStreamBasicDescription desc;
    desc.mFormatID = kAudioFormatLinearPCM;
    desc.mSampleRate = 16000;
    desc.mChannelsPerFrame = 1;
    desc.mBitsPerChannel = 16;
    desc.mBytesPerFrame = 2;
    desc.mBytesPerPacket = 2;
    desc.mFramesPerPacket = 1;
    desc.mFormatFlags = kAudioFormatFlagIsBigEndian | kAudioFormatFlagIsPacked | kAudioFormatFlagIsSignedInteger;
    desc.mReserved = 0;
    _destinationFormat = desc;
    
    
    _audioConverter = [[AudioConverter alloc] init];
    
}


- (void)audioRecorder:(id)audioRecorder didCaptureAudioBufferList:(AudioBufferList *)audioBufferList format:(AudioStreamBasicDescription)format {
    
    UInt32 channelCount = audioBufferList->mNumberBuffers;
    UInt32 lengthPerChannel = audioBufferList->mBuffers[0].mDataByteSize;
    
    NSLog(@"sample rate = %f, channelCount = %d, lengthPerChannel = %d", format.mSampleRate, channelCount, lengthPerChannel);
    
    AudioBufferList dstList;
    [_audioConverter convertAuidoBufferList:audioBufferList sourceFormat:format destinationAudioBufferList:&dstList destinationFormat:_destinationFormat];
    
    
}



- (IBAction)onClickStart:(id)sender {
    [_recorder start];
}

- (IBAction)onClickStop:(id)sender {
    [_recorder stop];
}

- (void)onClickInputDevice:(id)sender {
    
    NSInteger index = [self.inputListButton indexOfSelectedItem];
    AudioDevice *device = [_inputDevices objectAtIndex:index];
    _currentInputDevice = device;
    [_recorder changeDevice:device.deviceID];
}
    
@end

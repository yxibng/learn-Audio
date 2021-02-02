//
//  ViewController.m
//  AudioUnit-demo
//
//  Created by yxibng on 2021/1/29.
//

#import "ViewController.h"
#import "AudioUnitRecorder.h"
#import "AudioRecorder.h"
#import "AudioDevice.h"
#import "PCMConverter.h"

static BOOL kUseGraph = YES;


@interface ViewController ()<AudioRecorderDelegate>

@property (weak) IBOutlet NSPopUpButton *inputListButton;
@property (nonatomic, strong) NSArray<AudioDevice *> *inputDevices;
@property (nonatomic, strong) AudioDevice *currentInputDevice;
@property (nonatomic, strong) id<AudioRecorderProtocol>recorder;


@property (nonatomic, assign) AudioStreamBasicDescription destinationFormat;

@property (nonatomic, strong) PCMConverter *converter;


@end


@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    
    if (kUseGraph) {
        _recorder = [[AudioRecorder alloc] init];
    } else {
        _recorder = [[AudioUnitRecorder alloc] init];
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
    
}


- (void)audioRecorder:(id)audioRecorder didCaptureData:(void *)data length:(UInt32)length format:(AudioStreamBasicDescription)format {

    NSLog(@"sample rate = %f, length = %d", format.mSampleRate, length);
    
    if (!_converter) {
        _converter = [[PCMConverter alloc] initWithSourceFormat:format destinationFormat:_destinationFormat];
    }
    
    [_converter convertPcm:data length:length sourceFormat:format];

    
    

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

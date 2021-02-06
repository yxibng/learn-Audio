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
#import "AudioEncoder.h"
#import "AudioDecoder.h"
#import <AVFoundation/AVFoundation.h>

static BOOL kUseGraph = NO;


@interface ViewController ()<AudioRecorderDelegate, AudioConverterDelegate, AudioEncoderDelegate, AudioDecoderDelegate>

@property (weak) IBOutlet NSPopUpButton *inputListButton;
@property (nonatomic, strong) NSArray<AudioDevice *> *inputDevices;
@property (nonatomic, strong) AudioDevice *currentInputDevice;
@property (nonatomic, strong) id<AudioRecorderProtocol>recorder;
@property (nonatomic, assign) AudioStreamBasicDescription destinationFormat;
@property (nonatomic, strong) AudioConverter *audioConverter;

@property (nonatomic, strong) AudioEncoder *opusEncoder;
@property (nonatomic, strong) AudioDecoder *opusDecoder;


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
    
    
    int sampleRate = 16000;
    int channleCount = 1;

    _destinationFormat = *([[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatInt16 sampleRate:sampleRate channels:channleCount interleaved:YES].streamDescription);
    _audioConverter = [[AudioConverter alloc] initWithDestinationFormat:_destinationFormat];
    _audioConverter.delegate = self;
    
    _opusEncoder = [[AudioEncoder alloc] initSampleRate:sampleRate channelCount:channleCount];
    _opusEncoder.delegate = self;
    
    _opusDecoder = [[AudioDecoder alloc] initSampleRate:sampleRate channelCount:channleCount];
    _opusDecoder.delegate = self;
}


- (void)audioRecorder:(id)audioRecorder didCaptureAudioBufferList:(AudioBufferList *)audioBufferList format:(AudioStreamBasicDescription)format sampleCount:(int)sampleCount {
    
//    UInt32 channelCount = audioBufferList->mNumberBuffers;
//    UInt32 lengthPerChannel = audioBufferList->mBuffers[0].mDataByteSize;
    
//    NSLog(@"sample rate = %f, channelCount = %d, lengthPerChannel = %d", format.mSampleRate, channelCount, lengthPerChannel);
    [_audioConverter convertAuidoBufferList:audioBufferList sourceFormat:format sourceSampleCount:sampleCount];
    
    
}

- (void)audioConverter:(AudioConverter *)converter
gotInt16InterleavedData:(uint8_t *)data
          channelCount:(int)channelCount
              lineSize:(int)lineSize
           sampleCount:(int)sampleCount
            sampleRate:(int)sampleRate
{
    [_opusEncoder encodeData:data length:lineSize sampleCount:sampleCount];
}


- (void)audioEncoder:(AudioEncoder *)audioEncoder gotEncodedData:(void *)data length:(int)length {
    
    [_opusDecoder decodeData:data length:length];
}

- (void)audioDecoder:(AudioDecoder *)audioDecoder gotDecodedData:(void *)data length:(int)length {
    //write data to file
    static FILE *file;
    if (!file) {
        NSString *path = [NSHomeDirectory() stringByAppendingPathComponent:@"decoded_audio.pcm"];
        NSLog(@"path = %@",path);
        [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
        file = fopen([path cStringUsingEncoding:NSUTF8StringEncoding], "a+");
    }
    fwrite(data, 1, length, file);
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

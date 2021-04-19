//
//  AudioPlayerViewController.m
//  AudioUnit-demo
//
//  Created by yxibng on 2021/4/19.
//

#import "AudioPlayerViewController.h"
#import "AUGraphPlayer.h"
#import "AudioDevice.h"
#include <time.h>

@interface AudioPlayerViewController ()<AUGraphPlayerDelegate>
@property (nonatomic, strong) AUGraphPlayer *player;
@property (nonatomic, strong) NSArray<AudioDevice *> *outputDevices;
@property (nonatomic, strong) AudioDevice *currentOutputDevice;
@property (weak) IBOutlet NSPopUpButton *outputListButton;
@property (nonatomic, assign) AudioPlayConfig config;
@end

@implementation AudioPlayerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    
    AudioPlayConfig config = {
        .sampleRate = 16000,
        .pcmFormat = AVAudioPCMFormatInt16,
        .channelCount = 1,
        .interleaved = NO
    };
    
    self.config = config;
    
    _player = [[AUGraphPlayer alloc] initWithPlayConifg:config delegate:self];
    
    _currentOutputDevice = [AudioDevice defaultOutputDevice];
    _outputDevices = [AudioDevice outputDevices];
    
    [self.outputListButton removeAllItems];
    for (AudioDevice *device in _outputDevices) {
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:device.localizedName action:@selector(onClickOutputDevice:) keyEquivalent:@""];
        [self.outputListButton.menu addItem:item];
        if (device.deviceID == _currentOutputDevice.deviceID) {
            NSInteger index = [_outputDevices indexOfObject:device];
            [self.outputListButton selectItemAtIndex:index];
        }
    }
}

- (IBAction)onClickStart:(id)sender {
    [_player start];
}

- (IBAction)onClickStop:(id)sender {
    [_player stop];
}

- (void)onClickOutputDevice:(id)sender {
    
    NSInteger index = [self.outputListButton indexOfSelectedItem];
    AudioDevice *device = [_outputDevices objectAtIndex:index];
    _currentOutputDevice = device;
    [_player changeDevice:device.deviceID];
}



#pragma mark -

- (void)audioPlayer:(AUGraphPlayer *)audioPlayer fillAudioBufferList:(AudioBufferList *)audioBufferList inBusNumber:(UInt32)inBusNumber inNumberFrames:(UInt32)inNumberFrames {
    NSLog(@"inNumberFrames  = %d, require buffer length = %d", inNumberFrames, audioBufferList->mBuffers[0].mDataByteSize);
    
    
    
    for (NSInteger i = 0; i < audioBufferList->mNumberBuffers; i++) {
        if (i == 0) {
            srand((unsigned)time(NULL));
            for (int i = 0; i< audioBufferList->mBuffers[0].mDataByteSize; i++) {
                UInt8 value = rand() % UINT8_MAX;
                memset(audioBufferList->mBuffers[0].mData+i, 1, value);
            }
        } else {
            memcpy(audioBufferList->mBuffers[i].mData, audioBufferList->mBuffers[0].mData, audioBufferList->mBuffers[i].mDataByteSize);
        }
    }
    
}

@end

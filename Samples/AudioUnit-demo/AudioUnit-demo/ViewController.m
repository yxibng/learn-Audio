//
//  ViewController.m
//  AudioUnit-demo
//
//  Created by yxibng on 2021/1/29.
//

#import "ViewController.h"
#import "AudioUnitRecorder.h"
#import "AudioDevice.h"

@interface ViewController ()<AudioUnitRecorderDelegate>

@property (nonatomic, strong) AudioUnitRecorder *recorder;
@property (weak) IBOutlet NSPopUpButton *inputListButton;
@property (nonatomic, strong) NSArray<AudioDevice *> *inputDevices;
@property (nonatomic, strong) AudioDevice *currentInputDevice;

@end


@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _recorder = [[AudioUnitRecorder alloc] init];
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
}


- (void)audioRecorder:(AudioUnitRecorder *)audioRecorder didCaptureData:(void *)data sampleRate:(Float64)sampleRate length:(UInt32)length {

    NSLog(@"sample rate = %f, length = %d", sampleRate, length);
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

//
//  ViewController.m
//  AudioUnit-iOS
//
//  Created by yxibng on 2021/2/2.
//

#import "ViewController.h"
#import "AudioSessionUtil.h"
#import "AudioRecorder.h"
#import <AVFoundation/AVFoundation.h>

@interface ViewController ()<AUGraphRecorderDelegate, AudioSessionUtilDelegate>
@property (nonatomic, strong) AudioRecorder *recorder;
@property (nonatomic, assign) BOOL stateBeforeInterrupt;
@property (nonatomic, assign) BOOL isRunning;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [[AudioSessionUtil sharedUtil] activeSession];
    [AudioSessionUtil sharedUtil].delegate = self;
    _recorder = [[AudioRecorder alloc] initWithSampleRate: kSampleRate delegate: self];
    [_recorder start];
}

- (void)audioSessionUtil:(nonnull AudioSessionUtil *)audioSessionUtil receiveAudioServicesResetNotification:(nonnull NSNotification *)notification {
    NSLog(@"%s",__FUNCTION__);
    [[AudioSessionUtil sharedUtil] activeSession];
    [self.recorder handleAudioServicesReset];
}

- (void)audioSessionUtil:(nonnull AudioSessionUtil *)audioSessionUtil receiveAudioSessionInterruptionNotification:(nonnull NSNotification *)notification {
    NSLog(@"%s",__FUNCTION__);
    
    
    int type = [notification.userInfo[AVAudioSessionInterruptionTypeKey] intValue];
    if (AVAudioSessionInterruptionTypeBegan == type) {
        //打断开始，保存上一个运行状态
        self.stateBeforeInterrupt = self.isRunning;
        [self.recorder stop];
    } else if (AVAudioSessionInterruptionTypeEnded == type) {
        if (self.stateBeforeInterrupt) {
            //如果之前是运行状态，打断结束之后，恢复运行
            [self.recorder start];
            self.stateBeforeInterrupt = NO;
        }
    }
}

- (void)audioRecorder:(id)audioRecorder
       didCaptureData:(void *)data
               length:(UInt32)length
               format:(AudioStreamBasicDescription)format {
    NSLog(@"lenght = %d, sampleRate = %f",length, format.mSampleRate);
}


- (void)audioRecorderDidStart:(id)audioRecorder {
    NSLog(@"%s",__FUNCTION__);
    self.isRunning = YES;
}

- (void)audioRecorderDidStop:(id)audioRecorder {
    NSLog(@"%s",__FUNCTION__);
    self.isRunning = NO;
}

- (void)audioRecorder:(id)audioRecorder didOccurError:(AUGraphError)error userInfo:(id _Nullable)userInfo {
    
}


@end

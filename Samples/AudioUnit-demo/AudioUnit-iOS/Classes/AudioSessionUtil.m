//
//  AudioSessionUtil.m
//  AudioUnit-iOS
//
//  Created by yxibng on 2021/2/2.
//

#import "AudioSessionUtil.h"
#import <AVFoundation/AVFoundation.h>
#import <OSLog/OSLog.h>

@implementation AudioSessionUtil
+ (instancetype)sharedUtil {
    static AudioSessionUtil *util;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        util = [[AudioSessionUtil alloc] init];
    });
    return util;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _ioBufferDuraion = kIOBufferDuration;
        _sampleRate = kSampleRate;
        [self addNotifications];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)addNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receiveInterrupt:) name:AVAudioSessionInterruptionNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receiveReset:) name:AVAudioSessionMediaServicesWereResetNotification object:nil];
}


- (void)receiveReset:(NSNotification *)notification {
    
    if ([self.delegate respondsToSelector:@selector(audioSessionUtil:receiveAudioServicesResetNotification:)]) {
        [self.delegate audioSessionUtil:self receiveAudioServicesResetNotification:notification];
    }
}

- (void)receiveInterrupt:(NSNotification *)notification {
    if ([self.delegate respondsToSelector:@selector(audioSessionUtil:receiveAudioSessionInterruptionNotification:)]) {
        [self.delegate audioSessionUtil:self receiveAudioServicesResetNotification:notification];
    }
}


- (void)activeSession {
    
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    BOOL ok = NO;
    NSError *setCategoryError = nil;

    if ([audioSession.category isEqualToString:AVAudioSessionCategoryPlayAndRecord]) {
        return;
    }
    
    
    if (@available(iOS 11.0, *)) {
        AVAudioSessionCategoryOptions options = AVAudioSessionCategoryOptionMixWithOthers |
        AVAudioSessionCategoryOptionAllowBluetooth |
        AVAudioSessionCategoryOptionAllowBluetoothA2DP |
        AVAudioSessionCategoryOptionAllowAirPlay|
        AVAudioSessionCategoryOptionDefaultToSpeaker;
        ok = [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord
                                  mode:AVAudioSessionModeVideoChat
                               options:options
                                 error:&setCategoryError];
        
    } else if (@available(iOS 10.0, *)) {
        
        AVAudioSessionCategoryOptions options = AVAudioSessionCategoryOptionMixWithOthers |
        AVAudioSessionCategoryOptionAllowBluetooth |
        AVAudioSessionCategoryOptionAllowBluetoothA2DP |
        AVAudioSessionCategoryOptionAllowAirPlay |
        AVAudioSessionCategoryOptionDefaultToSpeaker;
        ok = [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord
                           withOptions:options
                                 error:&setCategoryError];
    } else {
        
        AVAudioSessionCategoryOptions options = AVAudioSessionCategoryOptionMixWithOthers |
        AVAudioSessionCategoryOptionAllowBluetooth | AVAudioSessionCategoryOptionDefaultToSpeaker;
        ok = [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord
                           withOptions:options
                                 error:&setCategoryError];
    }

    if (!ok) {
        NSLog(@"config audio session failed");
        return;
    }
    
    NSError *error = nil;
    [audioSession setPreferredSampleRate:kSampleRate error:&error];
    if (error) {
        os_log_error(OS_LOG_DEFAULT, "AVAudioSession setPreferredSampleRate %f error: %@", kSampleRate, error);
    }

    [audioSession setPreferredIOBufferDuration: kIOBufferDuration error:&error];
    if (error) {
        os_log_error(OS_LOG_DEFAULT, "AVAudioSession setPreferredIOBufferDuration %f error: %@", kIOBufferDuration, error);
    }

    [audioSession setActive:YES withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:&error];
    if (error) {
        os_log_error(OS_LOG_DEFAULT, "AVAudioSession setActive YES error: %@",error);
    }
    
    assert(error == nil);
    //真正的采样率和 iO 间隔
    _ioBufferDuraion = audioSession.IOBufferDuration;
    _sampleRate = audioSession.sampleRate;
    
    
    NSLog(@"real io duration = %f, sample rate = %f", _ioBufferDuraion, _sampleRate);
    
}



@end

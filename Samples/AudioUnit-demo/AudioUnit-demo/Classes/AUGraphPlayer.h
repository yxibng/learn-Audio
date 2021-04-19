//
//  AUGraphPlayer.h
//  AudioUnit-demo
//
//  Created by yxibng on 2021/4/16.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef struct {
    int sampleRate;
    AVAudioCommonFormat pcmFormat;
    AVAudioChannelCount channelCount;
    BOOL interleaved;
    
} AudioPlayConfig;


@class AUGraphPlayer;
@protocol AUGraphPlayerDelegate <NSObject>
- (void)audioPlayer:(AUGraphPlayer *)audioPlayer fillAudioBufferList:(AudioBufferList *)audioBufferList inBusNumber:(UInt32)inBusNumber inNumberFrames:(UInt32)inNumberFrames;
@end

@interface AUGraphPlayer : NSObject
- (instancetype)initWithPlayConifg:(AudioPlayConfig)playConfig delegate:(id<AUGraphPlayerDelegate>)delegate;
@property (nonatomic, weak) id<AUGraphPlayerDelegate>delegate;
- (void)start;
- (void)changeDevice:(AudioDeviceID)deviceID;
- (void)stop;
@end

NS_ASSUME_NONNULL_END

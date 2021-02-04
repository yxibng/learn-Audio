//
//  AudioRecorderDelegate.h
//  AudioUnit-demo
//
//  Created by yxibng on 2021/2/1.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

NS_ASSUME_NONNULL_BEGIN




typedef struct {
    //1 mono 2 stereo
    UInt32 channelCount;
    //是否是交错的
    BOOL interleaved;
    /*
     每次IO的音频时长，单位秒,例如0.02，每次回调20ms的数据
     根据时长计算出的，IO Frame Size 超出IOBufferFrameSizeRange的话，会内部纠错
     */
    NSTimeInterval ioDuration;
} AudioConfig;



@protocol AudioRecorderDelegate <NSObject>
@optional

- (void)audioRecorder:(id)audioRecorder didCaptureAudioBufferList:(AudioBufferList *)audioBufferList
               format:(AudioStreamBasicDescription)format sampleCount:(int)sampleCount;
@end

@protocol AudioRecorderProtocol <NSObject>

@property (nonatomic, weak) id<AudioRecorderDelegate>delegate;
@property (nonatomic, assign, readonly) AudioConfig config;

- (instancetype)initWithConfig:(AudioConfig)config delegate:(id<AudioRecorderDelegate>)delegate;

- (void)start;
- (void)stop;
- (void)changeDevice:(AudioDeviceID)deviceID;

@end




NS_ASSUME_NONNULL_END

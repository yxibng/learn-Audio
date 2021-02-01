//
//  AudioUnitRecorder.h
//  AudioUnit-demo
//
//  Created by yxibng on 2021/1/29.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

NS_ASSUME_NONNULL_BEGIN

@class AudioUnitRecorder;
@protocol AudioUnitRecorderDelegate <NSObject>

@optional

- (void)audioRecorder:(AudioUnitRecorder *)audioRecorder
       didCaptureData:(void *)data
           sampleRate:(Float64)sampleRate
               length:(UInt32)length;

@end


@interface AudioUnitRecorder : NSObject

@property (nonatomic, weak) id<AudioUnitRecorderDelegate>delegate;

- (void)start;
- (void)changeDevice:(AudioDeviceID)deviceID;
- (void)stop;
@end

NS_ASSUME_NONNULL_END

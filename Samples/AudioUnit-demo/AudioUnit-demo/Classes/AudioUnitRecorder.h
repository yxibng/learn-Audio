//
//  AudioUnitRecorder.h
//  AudioUnit-demo
//
//  Created by yxibng on 2021/1/29.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "AudioRecorderDelegate.h"

NS_ASSUME_NONNULL_BEGIN



@interface AudioUnitRecorder : NSObject<AudioRecorderProtocol>

@property (nonatomic, weak) id<AudioRecorderDelegate>delegate;

- (void)start;
- (void)changeDevice:(AudioDeviceID)deviceID;
- (void)stop;
@end

NS_ASSUME_NONNULL_END

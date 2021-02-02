//
//  AudioRecorderDelegate.h
//  AudioUnit-demo
//
//  Created by yxibng on 2021/2/1.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

NS_ASSUME_NONNULL_BEGIN

@protocol AudioRecorderDelegate <NSObject>
@optional

- (void)audioRecorder:(id)audioRecorder
       didCaptureData:(void *)data
               length:(UInt32)length
               format:(AudioStreamBasicDescription)format;

@end

@protocol AudioRecorderProtocol <NSObject>

- (void)start;
- (void)stop;
- (void)changeDevice:(AudioDeviceID)deviceID;
@property (nonatomic, weak) id<AudioRecorderDelegate>delegate;
@end




NS_ASSUME_NONNULL_END

//
//  AUGraphRecorder.h
//  AudioUnit-iOS
//
//  Created by yxibng on 2021/2/2.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, AUGraphError) {
    AUGraphErrorNoError,
    AUGraphErrorNoPermission,
    AUGraphErrorUnknown
};


@protocol AUGraphRecorderDelegate <NSObject>
@optional
- (void)audioRecorder:(id)audioRecorder
       didCaptureData:(void *)data
               length:(UInt32)length
               format:(AudioStreamBasicDescription)format;


- (void)audioRecorderDidStart:(id)audioRecorder;
- (void)audioRecorderDidStop:(id)audioRecorder;
- (void)audioRecorder:(id)audioRecorder didOccurError:(AUGraphError)error userInfo:(id _Nullable)userInfo;

@end

@interface AudioRecorder : NSObject

@property (nonatomic, weak) id<AUGraphRecorderDelegate>delegate;

- (instancetype)initWithSampleRate:(Float64)sampleRate delegate:(id<AUGraphRecorderDelegate>)delegate;

- (void)start;
- (void)stop;

- (void)handleAudioServicesReset;

@end

NS_ASSUME_NONNULL_END

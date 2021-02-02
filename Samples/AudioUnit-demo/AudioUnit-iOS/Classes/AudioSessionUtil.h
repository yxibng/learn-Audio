//
//  AudioSessionUtil.h
//  AudioUnit-iOS
//
//  Created by yxibng on 2021/2/2.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

static const  NSTimeInterval kIOBufferDuration = 0.02;
static const Float64 kSampleRate = 16000;
@class AudioSessionUtil;
@protocol AudioSessionUtilDelegate <NSObject>

- (void)audioSessionUtil:(AudioSessionUtil *)audioSessionUtil receiveAudioServicesResetNotification:(NSNotification *)notification;
- (void)audioSessionUtil:(AudioSessionUtil *)audioSessionUtil receiveAudioSessionInterruptionNotification:(NSNotification *)notification;

@end

@interface AudioSessionUtil : NSObject

+ (instancetype)sharedUtil;

@property (nonatomic, weak) id<AudioSessionUtilDelegate>delegate;
@property (nonatomic, assign, readonly) NSTimeInterval ioBufferDuraion;
@property (nonatomic, assign, readonly) Float64 sampleRate;

//play and record
- (void)activeSession;


@end

NS_ASSUME_NONNULL_END

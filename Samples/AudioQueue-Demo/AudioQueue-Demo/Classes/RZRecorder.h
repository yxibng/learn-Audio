//
//  RZRecorder.h
//  AudioQueue-Demo
//
//  Created by yxibng on 2021/1/26.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN


/*
 采集aac 并写入文件
 参考：
 # Audio Queue - Recording to a compressed audio format.
 https://developer.apple.com/library/archive/qa/qa1615/_index.html#//apple_ref/doc/uid/DTS40008016
 ## Audio Queue Services Programming Guide
 https://developer.apple.com/library/archive/documentation/MusicAudio/Conceptual/AudioQueueProgrammingGuide/Introduction/Introduction.html#//apple_ref/doc/uid/TP40005343
 */


@interface RZRecorder : NSObject
- (BOOL)setup;
- (void)start;
- (void)stop;
@end

NS_ASSUME_NONNULL_END

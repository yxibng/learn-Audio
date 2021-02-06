//
//  AudioEncoder.h
//  AudioUnit-demo
//
//  Created by yxibng on 2021/2/5.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AudioEncoder : NSObject

- (instancetype)initSampleRate:(int)sampleRate channelCount:(int)channelCount;



@end

NS_ASSUME_NONNULL_END

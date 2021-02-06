//
//  AudioEncoder.h
//  AudioUnit-demo
//
//  Created by yxibng on 2021/2/5.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class AudioEncoder;
@protocol AudioEncoderDelegate <NSObject>

- (void)audioEncoder:(AudioEncoder *)audioEncoder gotEncodedData:(void *)data length:(int)length;

@end


@interface AudioEncoder : NSObject

@property (nonatomic, weak) id<AudioEncoderDelegate>delegate;
- (instancetype)initSampleRate:(int)sampleRate channelCount:(int)channelCount;


- (void)encodeData:(void *)data length:(int)length sampleCount:(int)sampleCount;

@end

NS_ASSUME_NONNULL_END

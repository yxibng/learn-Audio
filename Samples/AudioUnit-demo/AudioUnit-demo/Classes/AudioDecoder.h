//
//  AudioDecoder.h
//  AudioUnit-demo
//
//  Created by yxibng on 2021/2/6.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@class AudioDecoder;
@protocol AudioDecoderDelegate <NSObject>

- (void)audioDecoder:(AudioDecoder *)audioDecoder gotDecodedData:(void *)data length:(int)length;

@end

@interface AudioDecoder : NSObject
@property (nonatomic, weak) id<AudioDecoderDelegate>delegate;
- (instancetype)initSampleRate:(int)sampleRate channelCount:(int)channelCount;
- (void)decodeData:(void *)data length:(int)length;


@end

NS_ASSUME_NONNULL_END

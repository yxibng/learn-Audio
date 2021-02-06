//
//  AudioConverter.h
//  AudioUnit-demo
//
//  Created by yxibng on 2021/2/4.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

NS_ASSUME_NONNULL_BEGIN

@class AudioConverter;
@protocol AudioConverterDelegate<NSObject>

- (void)audioConverter:(AudioConverter *)converter gotInt16InterleavedData:(uint8_t *)data
          channelCount:(int)channelCount
              lineSize:(int)lineSize
           sampleCount:(int)sampleCount
            sampleRate:(int)sampleRate;

@end

@interface AudioConverter : NSObject

- (instancetype)initWithDestinationFormat:(AudioStreamBasicDescription)destinationFormat;
@property (nonatomic, weak) id<AudioConverterDelegate>delegate;

- (void)convertAuidoBufferList:(AudioBufferList *)sourceAudioBufferList
                  sourceFormat:(AudioStreamBasicDescription)sourceFormat
             sourceSampleCount:(int)sourceSampleCount;

@end

NS_ASSUME_NONNULL_END

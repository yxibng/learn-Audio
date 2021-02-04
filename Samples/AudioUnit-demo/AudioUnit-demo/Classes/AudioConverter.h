//
//  AudioConverter.h
//  AudioUnit-demo
//
//  Created by yxibng on 2021/2/4.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

NS_ASSUME_NONNULL_BEGIN

@interface AudioConverter : NSObject




- (instancetype)initWithDestinationFormat:(AudioStreamBasicDescription)destinationFormat;


- (void)convertAuidoBufferList:(AudioBufferList *)sourceAudioBufferList
                  sourceFormat:(AudioStreamBasicDescription)sourceFormat
             sourceSampleCount:(int)sourceSampleCount;




@end

NS_ASSUME_NONNULL_END

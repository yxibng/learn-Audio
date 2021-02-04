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


- (void)convertAuidoBufferList:(AudioBufferList *)sourceAudioBufferList
                  sourceFormat:(AudioStreamBasicDescription)sourceFormat
    destinationAudioBufferList:(AudioBufferList *)destinationAudioBufferList
             destinationFormat:(AudioStreamBasicDescription)destinationFormat;




@end

NS_ASSUME_NONNULL_END

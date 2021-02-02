//
//  PCMConverter.h
//  AudioUnit-demo
//
//  Created by yxibng on 2021/2/2.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>


NS_ASSUME_NONNULL_BEGIN

@interface PCMConverter : NSObject
- (instancetype)initWithSourceFormat:(AudioStreamBasicDescription)sourceFormat
                   destinationFormat:(AudioStreamBasicDescription)destinationFormat;


- (void)convertPcm:(void *)data length:(UInt32)length sourceFormat:(AudioStreamBasicDescription)sourceFormat;


@end

NS_ASSUME_NONNULL_END

//
//  AudioEncoder.m
//  AudioUnit-demo
//
//  Created by yxibng on 2021/2/5.
//

#import "AudioEncoder.h"
#include <opus/opus.h>

@interface AudioEncoder ()
{
    OpusEncoder *_encoder;
}
@end


@implementation AudioEncoder
- (instancetype)initSampleRate:(int)sampleRate channelCount:(int)channelCount {
    if (self = [super init]) {
        
        int error;
        _encoder = opus_encoder_create(sampleRate, channelCount, OPUS_APPLICATION_VOIP, &error);
        assert(error == OPUS_OK);
        
        opus_encoder_ctl(_encoder, OPUS_SET_BITRATE(sampleRate));
        opus_encoder_ctl(_encoder, OPUS_SET_COMPLEXITY(5));
        opus_encoder_ctl(_encoder, OPUS_SET_SIGNAL(OPUS_SIGNAL_VOICE));
    }
    return self;
}






@end

//
//  AudioEncoder.m
//  AudioUnit-demo
//
//  Created by yxibng on 2021/2/5.
//

#import "AudioEncoder.h"
#include <opus/opus.h>


typedef struct {
    OpusEncoder *encoder;
    int sampleRate;
    int channleCount;
    int64_t bitRate;
    int capacity;
    unsigned char *ouput;
} AudioEncoderInfo;

@interface AudioEncoder ()
{
    AudioEncoderInfo _encoderInfo;
}
@end


@implementation AudioEncoder
- (instancetype)initSampleRate:(int)sampleRate channelCount:(int)channelCount {
    if (self = [super init]) {
        
        int error;
        _encoderInfo.encoder = opus_encoder_create(sampleRate, channelCount, OPUS_APPLICATION_VOIP, &error);
        _encoderInfo.sampleRate = sampleRate;
        _encoderInfo.channleCount = channelCount;
        _encoderInfo.bitRate = channelCount * sampleRate;
        assert(error == OPUS_OK);
        
        opus_encoder_ctl(_encoderInfo.encoder, OPUS_SET_BITRATE(_encoderInfo.bitRate));
        opus_encoder_ctl(_encoderInfo.encoder, OPUS_SET_COMPLEXITY(5));
        opus_encoder_ctl(_encoderInfo.encoder, OPUS_SET_SIGNAL(OPUS_SIGNAL_VOICE));
        _encoderInfo.capacity = 1276;
        _encoderInfo.ouput = malloc(_encoderInfo.capacity);
    }
    return self;
}



- (void)encodeData:(void *)data length:(int)length sampleCount:(int)sampleCount {
    
    memset(_encoderInfo.ouput, 0, _encoderInfo.capacity);
    opus_int32 out_bytes = opus_encode(_encoderInfo.encoder, (const opus_int16 *)data, sampleCount, _encoderInfo.ouput, _encoderInfo.capacity);
    
    if (out_bytes <= 1) {
        return;
    } else {
        NSLog(@"out bytes = %d",out_bytes);
    }
    
    if ([self.delegate respondsToSelector:@selector(audioEncoder:gotEncodedData:length:)]) {
        [self.delegate audioEncoder:self gotEncodedData:_encoderInfo.ouput length:out_bytes];
    }
}


@end

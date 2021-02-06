//
//  AudioDecoder.m
//  AudioUnit-demo
//
//  Created by yxibng on 2021/2/6.
//

#import "AudioDecoder.h"
#include <opus/opus.h>

typedef struct {
    OpusDecoder *decoder;
    int sampleRate;
    int channleCount;
    opus_int16 *output;
    int capacity;
} AudioDecoderInfo;


@interface AudioDecoder ()
{
    AudioDecoderInfo _decoderInfo;
}
@end

@implementation AudioDecoder

- (instancetype)initSampleRate:(int)sampleRate channelCount:(int)channelCount {
    
    if (self = [super init]) {
        int error;
        _decoderInfo.decoder = opus_decoder_create(sampleRate, channelCount, &error);
        assert(error == OPUS_OK);
        _decoderInfo.sampleRate= sampleRate;
        _decoderInfo.channleCount = channelCount;
        _decoderInfo.capacity = sampleRate * 2;
        _decoderInfo.output = malloc(_decoderInfo.capacity);
    }
    return self;
}

- (void)decodeData:(void *)data length:(int)length {
    memset(_decoderInfo.output, 0, _decoderInfo.capacity);
    int ouput_samples = opus_decode(_decoderInfo.decoder,
                                (const unsigned char *)data,
                                length,
                                _decoderInfo.output,
                                _decoderInfo.capacity,
                                0);
    
    if ([self.delegate respondsToSelector:@selector(audioDecoder:gotDecodedData:length:)]) {
        [self.delegate audioDecoder:self gotDecodedData:_decoderInfo.output length:ouput_samples * 2];
    }
    NSLog(@"decode length = %d",ouput_samples * 2);
}


@end

//
//  AudioConverter.m
//  AudioUnit-demo
//
//  Created by yxibng on 2021/2/4.
//

#import "AudioConverter.h"
#include <libavutil/opt.h>
#include <libavutil/channel_layout.h>
#include <libavutil/samplefmt.h>
#include <libswresample/swresample.h>


typedef struct {
    /*
     原始数据
     */
    uint8_t **data;
    /*
     如果是单声道，每个声道的长度
     如果是双声道，平面型，代表 每个声道的长度
     如果是双声道，交错型，代表 每个声道的长度 * 2
     */
    int lineSize;
    //声道数
    int channelCount;
    //采样率
    int sampleRate;
    //采样个数
    uint64_t nb_samples;
    //for output
    uint64_t max_nb_samples;
    //是否是平面类型
    BOOL isPlanar;
    //采样位深,平面或交错（int16,int32, int64, float32, float64）
    enum AVSampleFormat sample_fmt;
} AudioData;


typedef struct {
    SwrContext *swr_ctx;
    AudioData source;
    AudioData destination;
    BOOL setupSuccess;
} AudioConverterInfo;


@interface AudioConverter()
{
    AudioConverterInfo _converterInfo;
}
@end


@implementation AudioConverter

static enum AVSampleFormat ff_formatFromStreamDesc(AudioStreamBasicDescription sourceFormat)
{
    BOOL isPlanar = sourceFormat.mFormatFlags & kAudioFormatFlagIsNonInterleaved;
    BOOL isFLoat = sourceFormat.mFormatFlags & kAudioFormatFlagIsFloat;
    if (isPlanar) {
        
        int bytesPerChannel = sourceFormat.mBitsPerChannel / 8;
        if (bytesPerChannel == 2) {
            return AV_SAMPLE_FMT_S16P;
        } else if (bytesPerChannel == 4) {
            if (isFLoat) {
                return AV_SAMPLE_FMT_FLTP;
            }
            return AV_SAMPLE_FMT_S32P;
        } else if (bytesPerChannel == 8) {
            if (isFLoat) {
                return AV_SAMPLE_FMT_DBLP;
            }
            return AV_SAMPLE_FMT_S64P;
        }
    } else {
        //交错型
        int bytesPerChannel = sourceFormat.mBitsPerChannel / 8;
        if (bytesPerChannel == 2) {
            return AV_SAMPLE_FMT_S16;
        } else if (bytesPerChannel == 4) {
            if (isFLoat) {
                return AV_SAMPLE_FMT_FLT;
            }
            return AV_SAMPLE_FMT_S32;
        } else if (bytesPerChannel == 8) {
            if (isFLoat) {
                return AV_SAMPLE_FMT_DBL;
            }
            return AV_SAMPLE_FMT_S64;
        }
    }

    @throw [NSException exceptionWithName:@"format not support" reason:@"bad params" userInfo:nil];
    return AV_SAMPLE_FMT_U8;
}





- (instancetype)initWithDestinationFormat:(AudioStreamBasicDescription)destinationFormat {
    
    if (self = [super init]) {
        int sampleRate = (int)destinationFormat.mSampleRate;
        int channleCount = destinationFormat.mChannelsPerFrame;
        BOOL isPlanar = (destinationFormat.mFormatFlags & kAudioFormatFlagIsNonInterleaved) > 0;
     
        _converterInfo.destination.channelCount = channleCount;
        _converterInfo.destination.sampleRate = sampleRate;
        _converterInfo.destination.isPlanar = isPlanar;

    }
    return self;
    
    
}


- (void)convertAuidoBufferList:(AudioBufferList *)sourceAudioBufferList
                  sourceFormat:(AudioStreamBasicDescription)sourceFormat
             sourceSampleCount:(int)sourceSampleCount
{
    if (!_converterInfo.setupSuccess) {
        //setup
        _converterInfo.source.nb_samples = sourceSampleCount;
        enum AVSampleFormat format = ff_formatFromStreamDesc(sourceFormat);
        _converterInfo.source.sample_fmt = format;
        BOOL isPlanar = (sourceFormat.mFormatFlags & kAudioFormatFlagIsNonInterleaved) > 0;
        _converterInfo.source.isPlanar = isPlanar;
        int sourceChannleCount = sourceFormat.mChannelsPerFrame;
        _converterInfo.source.channelCount = sourceChannleCount;
        _converterInfo.source.sampleRate = sourceFormat.mSampleRate;
        //alloc memory for source
        int ret = av_samples_alloc_array_and_samples(&_converterInfo.source.data,
                                                     &_converterInfo.source.lineSize,
                                                     sourceChannleCount,
                                                     sourceSampleCount,
                                                     format,
                                                     0);
        assert(ret >= 0);
        if (ret < 0) {
            return;
        }
    
        //alloc context
        _converterInfo.swr_ctx = swr_alloc();
        if (!_converterInfo.swr_ctx) {
            return;
        }
        
        //config context
        av_opt_set_int(_converterInfo.swr_ctx, "in_channel_layout",    av_get_default_channel_layout (_converterInfo.source.channelCount), 0);
        av_opt_set_int(_converterInfo.swr_ctx, "in_sample_rate",       _converterInfo.source.sampleRate, 0);
        av_opt_set_sample_fmt(_converterInfo.swr_ctx, "in_sample_fmt", _converterInfo.source.sample_fmt, 0);

        av_opt_set_int(_converterInfo.swr_ctx, "out_channel_layout",    av_get_default_channel_layout (_converterInfo.destination.channelCount), 0);
        av_opt_set_int(_converterInfo.swr_ctx, "out_sample_rate",       _converterInfo.destination.sampleRate, 0);
        av_opt_set_sample_fmt(_converterInfo.swr_ctx, "out_sample_fmt", _converterInfo.destination.sample_fmt, 0);
        
        ret = swr_init(_converterInfo.swr_ctx);
        assert(ret >= 0);
        if (ret < 0) {
            av_freep(&_converterInfo.source.data[0]);
            av_freep(&_converterInfo.source.data);
            swr_free(&_converterInfo.swr_ctx);
            return;
        }
        //alloc memory for destination
        //计算目标采样个数
        int dst_nb_samples = (int)av_rescale_rnd(_converterInfo.source.nb_samples,
                                            _converterInfo.destination.sampleRate,
                                            _converterInfo.source.sampleRate,
                                            AV_ROUND_UP);
        _converterInfo.destination.nb_samples = dst_nb_samples;
        _converterInfo.destination.max_nb_samples = dst_nb_samples;
        //开辟空间
        ret = av_samples_alloc_array_and_samples(&_converterInfo.destination.data,
                                                 &_converterInfo.destination.lineSize,
                                                 (int)av_get_default_channel_layout (_converterInfo.destination.channelCount),
                                                 (int)_converterInfo.destination.nb_samples,
                                                 _converterInfo.destination.sample_fmt,
                                                 0);
        assert(ret >= 0);
        if (ret < 0) {
            av_freep(&_converterInfo.source.data[0]);
            av_freep(&_converterInfo.source.data);
            swr_free(&_converterInfo.swr_ctx);
            return;
        }
        _converterInfo.setupSuccess = YES;
    }
    //fill data
    if (_converterInfo.source.isPlanar) {
        for (int i = 0; i< _converterInfo.source.channelCount; i++) {
            memcpy(_converterInfo.source.data[i], sourceAudioBufferList->mBuffers[i].mData, sourceAudioBufferList->mBuffers[i].mDataByteSize);
        }
    } else {
        memcpy(_converterInfo.source.data[0], sourceAudioBufferList->mBuffers[0].mData, sourceAudioBufferList->mBuffers[0].mDataByteSize);
    }

    //start convert
    
    int64_t delay = swr_get_delay(_converterInfo.swr_ctx, _converterInfo.source.sampleRate) + _converterInfo.source.nb_samples;
    
    _converterInfo.destination.nb_samples = av_rescale_rnd(delay, _converterInfo.destination.sampleRate, _converterInfo.source.sampleRate, AV_ROUND_UP);
    
    if (_converterInfo.destination.nb_samples > _converterInfo.destination.max_nb_samples) {
        
        av_freep(&_converterInfo.destination.data[0]);
        int ret = av_samples_alloc(_converterInfo.destination.data,
                                   &_converterInfo.destination.lineSize,
                                   _converterInfo.destination.channelCount,
                                   (int)_converterInfo.destination.nb_samples,
                                   _converterInfo.destination.sample_fmt,
                                   1);
        assert(ret >= 0);
        if (ret < 0) {
            return;
        }
    }
    
    //do convert
    
    int out_smaples_per_channel = swr_convert(_converterInfo.swr_ctx,
                                              _converterInfo.destination.data,
                                              (int)_converterInfo.destination.nb_samples,
                                              (const uint8_t **)_converterInfo.source.data,
                                              (int)_converterInfo.source.nb_samples);

    assert(out_smaples_per_channel >= 0);
    
    int dst_buf_size = av_samples_get_buffer_size(&_converterInfo.destination.lineSize,
                                                  _converterInfo.destination.channelCount,
                                                  out_smaples_per_channel,
                                                  _converterInfo.destination.sample_fmt,
                                                  1);
    
    NSLog(@"dst buf size = %d",dst_buf_size);
}



@end

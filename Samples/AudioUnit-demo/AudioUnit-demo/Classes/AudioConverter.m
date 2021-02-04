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
    int64_t ch_layout;
    //采样率
    int sampleRate;
    //采样个数
    uint64_t nb_samples;
    //for output
    uint64_t max_nb_samples;
    
    //采样位深,平面或交错（int16,int32, int64, float32, float64）
    enum AVSampleFormat sample_fmt;
} AudioData;


typedef struct {
    SwrContext *swr_ctx;
    AudioData source;
    AudioData destination;
    
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

- (void)convertAuidoBufferList:(AudioBufferList *)sourceAudioBufferList
                  sourceFormat:(AudioStreamBasicDescription)sourceFormat
    destinationAudioBufferList:(AudioBufferList *)destinationAudioBufferList
             destinationFormat:(AudioStreamBasicDescription)destinationFormat
{
    
    uint8_t **source = NULL;
    int sourceLineSize = 0;
    int sourceSampleRate = (int)sourceFormat.mSampleRate;
    int sourceChannleCount = sourceFormat.mChannelsPerFrame;
    BOOL isPlanar = (sourceFormat.mFormatFlags & kAudioFormatFlagIsNonInterleaved) > 0;
    int64_t nb_samples = 0;
    if (isPlanar) {
        nb_samples = sourceAudioBufferList->mBuffers[0].mDataByteSize / (sourceFormat.mBitsPerChannel / 8);
    } else {
        nb_samples = sourceAudioBufferList->mBuffers[0].mDataByteSize / sourceFormat.mBytesPerFrame;
    }
    
    enum AVSampleFormat format = ff_formatFromStreamDesc(sourceFormat);
    int ret = av_samples_alloc_array_and_samples(&source, &sourceLineSize, sourceChannleCount, (int)nb_samples, format, 0);
    assert(ret >= 0);
    
    //fill data
    for (UInt32 i = 0; i < sourceAudioBufferList->mNumberBuffers ; i++) {
        memcpy(source[i], sourceAudioBufferList->mBuffers[i].mData, sourceAudioBufferList->mBuffers[i].mDataByteSize);
    }
    
    
    uint8_t **dst = NULL;
    int dstLineSize = 0;
    int dstChannelCount = destinationFormat.mChannelsPerFrame;
    int64_t dst_nb_samples = 0;
    int64_t dst_max_nb_samples = 0;
    BOOL dstIsPlanar = (destinationFormat.mFormatFlags & kAudioFormatFlagIsNonInterleaved) > 0;
    enum AVSampleFormat dst_format = ff_formatFromStreamDesc(destinationFormat);
    int dstSampleRate = (int)destinationFormat.mSampleRate;
    
    SwrContext *context = swr_alloc();
    if (!context) {
        return;
    }
    
    av_opt_set_int(context, "in_channel_layout",    AV_CH_LAYOUT_STEREO, 0);
    av_opt_set_int(context, "in_sample_rate",       sourceSampleRate, 0);
    av_opt_set_sample_fmt(context, "in_sample_fmt", format, 0);

    av_opt_set_int(context, "out_channel_layout",    AV_CH_LAYOUT_STEREO, 0);
    av_opt_set_int(context, "out_sample_rate",       dstSampleRate, 0);
    av_opt_set_sample_fmt(context, "out_sample_fmt", dst_format, 0);

    
    ret = swr_init(context);
    assert(ret >= 0);
    
    
    
    //计算目标采样个数
    dst_nb_samples = av_rescale_rnd(nb_samples, dstSampleRate, sourceSampleRate, AV_ROUND_UP);
    dst_max_nb_samples = dst_nb_samples;
    
    
    ret = av_samples_alloc_array_and_samples(&dst, &dstLineSize, dstChannelCount, (int)dst_nb_samples, dst_format, 0);
    assert(ret >= 0);
    
    dst_nb_samples = av_rescale_rnd(swr_get_delay(context, sourceSampleRate) + nb_samples, dstSampleRate, sourceSampleRate, AV_ROUND_UP);
    
    if (dst_nb_samples > dst_max_nb_samples) {
        av_freep(&dst[0]);
        av_freep(&dst);
        ret = av_samples_alloc_array_and_samples(&dst, &dstLineSize, dstChannelCount, (int)dst_max_nb_samples, dst_format, 0);
        assert(ret >= 0);
        dst_nb_samples = dst_max_nb_samples;
    }
    
    int out_nb_samples = swr_convert(context, dst, (int)dst_nb_samples, (const uint8_t **)source, nb_samples);
    assert(ret >= 0);
    
    
    int dstBufferSize = av_samples_get_buffer_size(&dstLineSize, dstChannelCount, out_nb_samples, dst_format, 0);
    
    
    
    
    
    
    
    
    
    
    
    


    
    
    
    
    //do convert
    
    
    

    
    
}



@end

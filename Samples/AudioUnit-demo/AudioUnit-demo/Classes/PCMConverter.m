//
//  PCMConverter.m
//  AudioUnit-demo
//
//  Created by yxibng on 2021/2/2.
//

#import "PCMConverter.h"

typedef struct {
    AudioConverterRef converter;
    AudioStreamBasicDescription sourceFormat;
    AudioStreamBasicDescription destinationFormat;
} AudioConvererInfo;


@interface PCMConverter ()
{
    AudioConvererInfo _converterInfo;
}

@end

@implementation PCMConverter

OSStatus AudioConverterCallback (  AudioConverterRef               inAudioConverter,
                                        UInt32 *                        ioNumberDataPackets,
                                        AudioBufferList *               ioData,
                                        AudioStreamPacketDescription * __nullable * __nullable outDataPacketDescription,
                                 void * __nullable               inUserData) {
    return noErr;
}


- (instancetype)initWithSourceFormat:(AudioStreamBasicDescription)sourceFormat destinationFormat:(AudioStreamBasicDescription)destinationFormat {
    if (self = [super init]) {
        _converterInfo.sourceFormat = sourceFormat;
        _converterInfo.destinationFormat = destinationFormat;
        OSStatus status = [self setup];
        assert(status == noErr);
    }
    return self;
}


- (OSStatus)setup {
    
    OSStatus status = AudioConverterNew(&_converterInfo.sourceFormat, &_converterInfo.destinationFormat, &_converterInfo.converter);
    if (status != noErr) {
        return status;
    }
    
    UInt32 minInputBufferSize;
    UInt32 minInputBufferPropSize = sizeof(minInputBufferSize);
    status = AudioConverterGetProperty(_converterInfo.converter, kAudioConverterPropertyMinimumInputBufferSize, &minInputBufferPropSize, &minInputBufferSize);
    assert(status == noErr);
    
    UInt32 minOutputBufferSize;
    UInt32 minOutputBufferPropSize = sizeof(minOutputBufferSize);
    status = AudioConverterGetProperty(_converterInfo.converter, kAudioConverterPropertyMinimumOutputBufferSize, &minOutputBufferPropSize, &minOutputBufferSize);
    assert(status == noErr);
    
    NSLog(@"min input = %d, min output = %d",minInputBufferSize, minOutputBufferSize);
    return noErr;
}


- (void)convertPcm:(void *)data length:(UInt32)length sourceFormat:(AudioStreamBasicDescription)sourceFormat {
    
    UInt32 inPacketSize = length / sourceFormat.mBytesPerPacket;
    //TODO: need imp
}

@end

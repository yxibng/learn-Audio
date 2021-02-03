//
//  AudioUtil.m
//  AudioUnit-demo
//
//  Created by yxibng on 2021/2/1.
//

#import "AudioUtil.h"

OSStatus GetCurrentIOBufferFrameSizeOfDevice(AudioObjectID inDeviceID,
                                             UInt32 *outIOBufferFrameSize)
{
    if (inDeviceID == kAudioDeviceUnknown) {
        return -1;
    }
    
    AudioObjectPropertyAddress theAddress = {
        kAudioDevicePropertyBufferFrameSize,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMaster};
    
    UInt32 theDataSize = sizeof(UInt32);
    return AudioObjectGetPropertyData(inDeviceID,
                                      &theAddress,
                                      0,
                                      NULL,
                                      &theDataSize,
                                      outIOBufferFrameSize);
}

OSStatus SetCurrentIOBufferFrameSizeOfDevice(AudioObjectID inDeviceID,
                                             UInt32 inIOBufferFrameSize)
{
    AudioObjectPropertyAddress theAddress = {
        kAudioDevicePropertyBufferFrameSize,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMaster};
    
    return AudioObjectSetPropertyData(inDeviceID,
                                      &theAddress,
                                      0,
                                      NULL,
                                      sizeof(UInt32),
                                      &inIOBufferFrameSize);
}


OSStatus GetIOBufferFrameSizeRangeOfDevice(AudioObjectID inDeviceID,
                                           UInt32 *outMinimum,
                                           UInt32 *outMaximum)
{
    if (inDeviceID == kAudioDeviceUnknown) {
        return -1;
    }
    AudioObjectPropertyAddress theAddress = {
        kAudioDevicePropertyBufferFrameSizeRange,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMaster};
    
    AudioValueRange theRange = {0, 0};
    UInt32 theDataSize = sizeof(AudioValueRange);
    OSStatus theError = AudioObjectGetPropertyData(inDeviceID,
                                                   &theAddress,
                                                   0,
                                                   NULL,
                                                   &theDataSize,
                                                   &theRange);
    if (theError == 0) {
        *outMinimum = theRange.mMinimum;
        *outMaximum = theRange.mMaximum;
    }
    return theError;
}


#pragma mark -
OSStatus AudioUnitSetMaxIOBufferFrameSize(AudioUnit audioUnit,
                                          UInt32 inIOBufferFrameSize)
{
    UInt32 maximumBufferSize;
    UInt32 propSize = sizeof(maximumBufferSize);
    OSStatus status = AudioUnitSetProperty(audioUnit,
                                           kAudioUnitProperty_MaximumFramesPerSlice,
                                           kAudioUnitScope_Global,
                                           0,
                                           &inIOBufferFrameSize,
                                           propSize);
    return status;
}

OSStatus AudioUnitGetMaxIOBufferFrameSize(AudioUnit audioUnit,
                                          UInt32 *outIOBufferFrameSize)
{
    UInt32 maximumBufferSize;
    UInt32 propSize = sizeof(maximumBufferSize);
    OSStatus status = AudioUnitGetProperty(audioUnit,
                                           kAudioUnitProperty_MaximumFramesPerSlice,
                                           kAudioUnitScope_Global,
                                           0,
                                           outIOBufferFrameSize,
                                           &propSize);
    return status;
}

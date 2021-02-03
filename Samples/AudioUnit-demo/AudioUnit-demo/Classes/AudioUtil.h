//
//  AudioUtil.h
//  AudioUnit-demo
//
//  Created by yxibng on 2021/2/1.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>


OSStatus GetCurrentIOBufferFrameSizeOfDevice(AudioObjectID inDeviceID,
                                             UInt32 *outIOBufferFrameSize);

OSStatus SetCurrentIOBufferFrameSizeOfDevice(AudioObjectID inDeviceID,
                                             UInt32 inIOBufferFrameSize);


OSStatus GetIOBufferFrameSizeRangeOfDevice(AudioObjectID inDeviceID,
                                           UInt32 *outMinimum,
                                           UInt32 *outMaximum);


OSStatus AudioUnitSetMaxIOBufferFrameSize(AudioUnit audioUnit,
                                          UInt32 inIOBufferFrameSize);

OSStatus AudioUnitGetMaxIOBufferFrameSize(AudioUnit audioUnit,
                                          UInt32 *outIOBufferFrameSize);

//
//  AudioDevice.m
//  AudioUnit-demo
//
//  Created by yxibng on 2021/2/1.
//

#import "AudioDevice.h"

@interface AudioDevice ()

@property (nonatomic, assign, readwrite) AudioDeviceID deviceID;
@property (nonatomic, copy, readwrite) NSString *localizedName;
@property (nonatomic, assign, readwrite) UInt32 portType;
@property (nonatomic, copy, readwrite) NSString *manufacturer;
@property (nonatomic, assign, readwrite) UInt32 inputChannelCount;
@property (nonatomic, assign, readwrite) UInt32 outputChannelCount;
@property (nonatomic, copy, readwrite) NSString *UID;

@end


@implementation AudioDevice


#pragma mark - Utility

+ (AudioObjectPropertyAddress)addressForPropertySelector:(AudioObjectPropertySelector)selector
{
    AudioObjectPropertyAddress address;
    address.mScope = kAudioObjectPropertyScopeGlobal;
    address.mElement = kAudioObjectPropertyElementMaster;
    address.mSelector = selector;
    return address;
}

+ (NSString *)stringPropertyForSelector:(AudioObjectPropertySelector)selector
                           withDeviceID:(AudioDeviceID)deviceID
{
    AudioObjectPropertyAddress address = [self addressForPropertySelector:selector];
    CFStringRef string;
    UInt32 propSize = sizeof(CFStringRef);
    OSStatus status = AudioObjectGetPropertyData(deviceID,
                                                 &address,
                                                 0,
                                                 NULL,
                                                 &propSize,
                                                 &string);

    NSString *errorString = [NSString stringWithFormat:@"Failed to get device property (%u)", (unsigned int)selector];
    NSAssert(status == noErr, errorString);
    if (status) {
        return @"";
    }
    return (__bridge_transfer NSString *)string;
}


+ (UInt32)portTypeForDeviceID:(AudioDeviceID)deviceID {
    
    AudioObjectPropertyAddress address = [self addressForPropertySelector:kAudioDevicePropertyTransportType];
    
    UInt32 portType;
    UInt32 propSize = sizeof(UInt32);
    
    OSStatus status = AudioObjectGetPropertyData(deviceID,
                                                 &address,
                                                 0,
                                                 NULL,
                                                 &propSize,
                                                 &portType);

    NSString *errorString = [NSString stringWithFormat:@"Failed to get device property (%u)", (unsigned int)kAudioDevicePropertyTransportType];
    NSAssert(status == noErr, errorString);
    return portType;
}

+ (NSString *)manufacturerForDeviceID:(AudioDeviceID)deviceID
{
    return [self stringPropertyForSelector:kAudioDevicePropertyDeviceManufacturerCFString
                              withDeviceID:deviceID];
}

+ (NSString *)namePropertyForDeviceID:(AudioDeviceID)deviceID
{
    return [self stringPropertyForSelector:kAudioDevicePropertyDeviceNameCFString
                              withDeviceID:deviceID];
}

+ (NSString *)UIDPropertyForDeviceID:(AudioDeviceID)deviceID
{
    return [self stringPropertyForSelector:kAudioDevicePropertyDeviceUID
                              withDeviceID:deviceID];
}



+ (UInt32)channelCountForScope:(AudioObjectPropertyScope)scope
                      forDeviceID:(AudioDeviceID)deviceID
{
    AudioObjectPropertyAddress address;
    address.mScope = scope;
    address.mElement = kAudioObjectPropertyElementMaster;
    address.mSelector = kAudioDevicePropertyStreamConfiguration;

    AudioBufferList streamConfiguration;
    UInt32 propSize = sizeof(streamConfiguration);
    OSStatus status = AudioObjectGetPropertyData(deviceID,
                                                 &address,
                                                 0,
                                                 NULL,
                                                 &propSize,
                                                 &streamConfiguration);
    NSAssert(status == noErr, @"Failed to get frame size");
    UInt32 channelCount = 0;
    for (NSInteger i = 0; i < streamConfiguration.mNumberBuffers; i++) {
        channelCount += streamConfiguration.mBuffers[i].mNumberChannels;
    }
    return channelCount;
}


+ (AudioDevice * _Nullable)deviceWithPropertySelector:(AudioObjectPropertySelector)propertySelector
{
    AudioDeviceID deviceID;
    UInt32 propSize = sizeof(AudioDeviceID);
    AudioObjectPropertyAddress address = [self addressForPropertySelector:propertySelector];
    OSStatus status = AudioObjectGetPropertyData(kAudioObjectSystemObject,
                                                 &address,
                                                 0,
                                                 NULL,
                                                 &propSize,
                                                 &deviceID);

    NSAssert(status == noErr, @"Failed to get device on OSX");
    if (deviceID == kAudioDeviceUnknown) {
        return nil;
    }
    
    AudioDevice *device = [[AudioDevice alloc] init];
    device.deviceID = deviceID;
    device.manufacturer = [self manufacturerForDeviceID:deviceID];
    device.localizedName = [self namePropertyForDeviceID:deviceID];
    device.UID = [self UIDPropertyForDeviceID:deviceID];
    device.inputChannelCount = [self channelCountForScope:kAudioObjectPropertyScopeInput forDeviceID:deviceID];
    device.outputChannelCount = [self channelCountForScope:kAudioObjectPropertyScopeOutput forDeviceID:deviceID];
    return device;
}

@end


@implementation AudioDevice (Util)

+ (AudioDevice *)defaultInputDevice {
    return [self deviceWithPropertySelector:kAudioHardwarePropertyDefaultInputDevice];
}

+ (AudioDevice *)defaultOutputDevice {
    return [self deviceWithPropertySelector:kAudioHardwarePropertyDefaultOutputDevice];
}

+ (NSArray<AudioDevice *> *)allDevices {
    
    // get the present system devices
    AudioObjectPropertyAddress address = [self addressForPropertySelector:kAudioHardwarePropertyDevices];
    UInt32 devicesDataSize;
    OSStatus status = AudioObjectGetPropertyDataSize(kAudioObjectSystemObject,
                                                     &address,
                                                     0,
                                                     NULL,
                                                     &devicesDataSize);
    NSAssert(status == noErr, @"Failed to get data size");
    if (status != noErr) {
        return @[];
    }
    // enumerate devices
    NSInteger count = devicesDataSize / sizeof(AudioDeviceID);
    AudioDeviceID *deviceIDs = (AudioDeviceID *)malloc(devicesDataSize);
    // fill in the devices
    status = AudioObjectGetPropertyData(kAudioObjectSystemObject,
                                        &address,
                                        0,
                                        NULL,
                                        &devicesDataSize,
                                        deviceIDs);
    NSAssert(status == noErr, @"Failed to get device IDs for available devices on OSX");
    if (status != noErr) {
        free(deviceIDs);
        return @[];
    }
    
    NSMutableArray *devices = [NSMutableArray array];
    for (UInt32 i = 0; i < count; i++) {
        AudioDeviceID deviceID = deviceIDs[i];
        AudioDevice *device = [[AudioDevice alloc] init];
        device.deviceID = deviceID;
        device.portType = [self portTypeForDeviceID:deviceID];
        device.manufacturer = [self manufacturerForDeviceID:deviceID];
        device.localizedName = [self namePropertyForDeviceID:deviceID];
        device.UID = [self UIDPropertyForDeviceID:deviceID];
        device.inputChannelCount = [self channelCountForScope:kAudioObjectPropertyScopeInput forDeviceID:deviceID];
        device.outputChannelCount = [self channelCountForScope:kAudioObjectPropertyScopeOutput forDeviceID:deviceID];
        [devices addObject:device];
    }
    free(deviceIDs);
    return [devices copy];
}

+ (NSArray<AudioDevice *> *)inputDevices {
    
    NSPredicate *predict = [NSPredicate predicateWithFormat:@"inputChannelCount > 0"];
    NSArray *devices = [self allDevices];
    return [devices filteredArrayUsingPredicate:predict];
}

+ (NSArray<AudioDevice *> *)outputDevices {
    NSPredicate *predict = [NSPredicate predicateWithFormat:@"outputChannelCount > 0"];
    NSArray *devices = [self allDevices];
    return [devices filteredArrayUsingPredicate:predict];
}


@end


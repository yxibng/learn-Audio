//
//  AudioDevice.h
//  AudioUnit-demo
//
//  Created by yxibng on 2021/2/1.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

NS_ASSUME_NONNULL_BEGIN

@interface AudioDevice : NSObject

@property (nonatomic, assign, readonly) AudioDeviceID deviceID;

@property (nonatomic, copy, readonly) NSString *localizedName;

@property (nonatomic, assign, readonly) UInt32 inputChannelCount;
@property (nonatomic, assign, readonly) UInt32 ouputChannelCount;
/*
 参考：kAudioDeviceTransportType
 USB/HDMI/Builtin/Bluetooth/...
 */
@property (nonatomic, assign, readonly) UInt32 portType;

/*
 An NSString representing the persistent identifier for the AudioDevice.
 */
@property (nonatomic, copy, readonly) NSString *UID;

/*
 An NSString representing the name of the manufacturer of the device.
 */
@property (nonatomic, copy, readonly) NSString *manufacturer;
@end


@interface AudioDevice (Util)

+ (AudioDevice *)defaultInputDevice;
+ (AudioDevice *)defaultOutputDevice;

+ (NSArray<AudioDevice *> *)inputDevices;
+ (NSArray<AudioDevice *> *)outputDevices;
+ (NSArray<AudioDevice *> *)allDevices;

@end


NS_ASSUME_NONNULL_END

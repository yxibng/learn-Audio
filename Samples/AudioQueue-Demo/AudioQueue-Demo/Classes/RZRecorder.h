//
//  RZRecorder.h
//  AudioQueue-Demo
//
//  Created by yxibng on 2021/1/26.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface RZRecorder : NSObject
- (BOOL)setup;
- (void)start;
- (void)stop;
@end

NS_ASSUME_NONNULL_END

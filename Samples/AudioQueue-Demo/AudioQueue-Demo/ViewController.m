//
//  ViewController.m
//  AudioQueue-Demo
//
//  Created by yxibng on 2021/1/26.
//

#import "ViewController.h"
#import "RZRecorder.h"


@interface ViewController ()

@property (nonatomic, strong) RZRecorder *recorder;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    _recorder = [[RZRecorder alloc] init];
    [_recorder setup];
    [_recorder start];

}





- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}


@end

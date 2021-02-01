//
//  ViewController.m
//  AudioUnit-demo
//
//  Created by yxibng on 2021/1/29.
//

#import "ViewController.h"
#import "AudioUnitRecorder.h"

@interface ViewController ()

@property (nonatomic, strong) AudioUnitRecorder *recorder;

@end


@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    _recorder = [[AudioUnitRecorder alloc] init];
    [_recorder start];
    

    // Do any additional setup after loading the view.
}


- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}


@end

//
//  ViewController.m
//  AudioQueue-Demo
//
//  Created by yxibng on 2021/1/26.
//

#import "ViewController.h"
#import "RZRecorder.h"
#import "RZPlayer.h"


@interface ViewController ()

@property (nonatomic, strong) RZRecorder *recorder;
@property (nonatomic, strong) RZPlayer *player;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    //test capture audio as aac
    [self startRecorder];
    
    //test play aac audio file
    [self startPlayer];

}


- (void)startRecorder {
    _recorder = [[RZRecorder alloc] init];
    [_recorder setup];
    [_recorder start];
}

- (void)startPlayer {
    _player = [[RZPlayer alloc] init];
    [_player setup];
    [_player start];
}


- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}


@end

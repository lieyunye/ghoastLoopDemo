//
//  ViewController.m
//  ghoastLoopDemo
//
//  Created by lieyunye on 1/12/16.
//  Copyright © 2016 lieyunye. All rights reserved.
//

#import "ViewController.h"
#import "GhoastMediaUtil.h"

@interface ViewController ()
{
    AVPlayer *_player;
    AVPlayerLayer *_playerLayer;
}
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    NSInteger repeatCount = 5;
    NSInteger repeatFrameCpoyCount = 30;//每30帧一个关键帧

    NSString *audioPath = [[NSBundle mainBundle] pathForResource:@"audio" ofType:@"m4a"];
    NSString *videoPath = [[NSBundle mainBundle] pathForResource:@"video" ofType:@"mp4"];
    
    [GhoastMediaUtil ghoastVideoLoopWithSourceVideoPath:videoPath repeatCount:repeatCount repeatFrameCpoyCount:repeatFrameCpoyCount handler:^(CMTime startTime, CMTime endTime, CMTime interval) {
        [GhoastMediaUtil ghoastAuidoLoopWithSourceAudioFilePath:audioPath repeatCount:repeatCount startTime:startTime endTime:endTime interval:interval completionHandler:^(NSString *filePath) {
            [[GhoastMediaUtil sharedClient] removeAllItem];
            [self playWithFilePath:filePath];
        }];
    }];
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (void)playWithFilePath:(NSString *)filePath
{
    dispatch_async(dispatch_get_main_queue(), ^{
        _player = [[AVPlayer alloc] initWithURL:[NSURL fileURLWithPath:filePath]];
        _playerLayer = [[AVPlayerLayer alloc] init];
        _playerLayer.player = _player;
        [self.view.layer addSublayer:_playerLayer];
        _playerLayer.frame = self.view.bounds;
        [_player play];
    });
    
}
@end

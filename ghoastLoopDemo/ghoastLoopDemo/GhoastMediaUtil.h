//
//  GhoastMediaUtil.h
//  ghoastLoopDemo
//
//  Created by lieyunye on 1/12/16.
//  Copyright © 2016 lieyunye. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface GhoastMediaUtil : NSObject

+ (instancetype)sharedClient;
- (void)addItem:(id)item;
- (void)removeAllItem;


+ (void)readAuidoFileWithSourceAudioFilePath:(NSString *)sourceAudioFilePath repeatCount:(NSInteger)repeatCount startTime:(CMTime)startTime duration:(CMTime)duration fileName:(NSString *)filePath completionHandler:(void (^)(NSString *filePath))handler;
+ (void)ghoastVideoLoopWithSourceVideoPath:(NSString *)sourceVideoPath repeatCount:(NSInteger)repeatCount repeatFrameCpoyCount:(NSInteger)repeatFrameCpoyCount handler:(void (^)(CMTime startTime, CMTime endTime, CMTime interval))handler;
+ (void)ghoastAuidoLoopWithSourceAudioFilePath:(NSString *)sourceAudioFilePath repeatCount:(NSInteger)repeatCount startTime:(CMTime)startTime endTime:(CMTime)endTime interval:(CMTime)interval completionHandler:(void (^)(NSString *filePath))handler;

+ (void)checkProceessAudioProgressWithRepeatCount:(NSInteger)repeatCount completionHandler:(void (^)(NSString *filePath))handler;

@end

//
//  GhoastMediaUtil.m
//  ghoastLoopDemo
//
//  Created by lieyunye on 1/12/16.
//  Copyright © 2016 lieyunye. All rights reserved.
//

#import "GhoastMediaUtil.h"

typedef enum : NSUInteger {
    FrameTypeUnkown,
    FrameTypeIFrame,
    FrameTypeNonIFrame,
} FrameType;

static NSInteger alreadyAudioRepeatedCount = 0;

@interface GhoastMediaUtil ()
{
    NSMutableArray *_array;
}
@end

@implementation GhoastMediaUtil

+ (instancetype)sharedClient
{
    static GhoastMediaUtil *_sharedClient = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedClient = [[GhoastMediaUtil alloc] init];
    });
    return _sharedClient;
}
- (instancetype)init
{
    self = [super init];
    if (self) {
        _array = [NSMutableArray array];//解决finishWritingWithCompletionHandler无回调的问题，writter得retain
    }
    return self;
}

- (void)addItem:(id)item
{
    if (item) {
        [_array addObject:item];
    }
}

- (void)removeAllItem
{
    [_array removeAllObjects];
}

+ (NSString *)ghoastAudioDirectory
{
    NSString *audioDirectoryName = @"ghoastAudio";
    NSString *audioDirectoryPath = [NSTemporaryDirectory() stringByAppendingPathComponent:audioDirectoryName];
    return audioDirectoryPath;
}

+ (void)ghoastAuidoLoopWithSourceAudioFilePath:(NSString *)sourceAudioFilePath repeatCount:(NSInteger)repeatCount startTime:(CMTime)startTime endTime:(CMTime)endTime interval:(CMTime)interval completionHandler:(void (^)(NSString *filePath))handler
{
    alreadyAudioRepeatedCount = 0;
    NSString *audioDirectoryPath = [[self class] ghoastAudioDirectory];
    if ([[NSFileManager defaultManager] fileExistsAtPath:audioDirectoryPath]) {
        [[NSFileManager defaultManager] removeItemAtPath:audioDirectoryPath error:nil];
    }
    [[NSFileManager defaultManager] createDirectoryAtPath:audioDirectoryPath withIntermediateDirectories:YES attributes:nil error:nil];
    
    NSString *firstFilePath = [NSString stringWithFormat:@"%@/%@.m4a", audioDirectoryPath, @"0"];
    NSLog(@"read file 0");
    [[self class] readAuidoFileWithSourceAudioFilePath:sourceAudioFilePath repeatCount:repeatCount startTime:kCMTimeZero duration:startTime fileName:firstFilePath completionHandler:^(NSString *filePath) {
        if (handler) {
            handler(filePath);
        }
    }];
    NSInteger n = repeatCount + 1;
    for (NSInteger i = 0; i < n; i++) {
        NSLog(@"read file %d",i + 1);
        NSString *filePath = [NSString stringWithFormat:@"%@/%@.m4a", audioDirectoryPath, [NSString stringWithFormat:@"%d", (i + 1)]];
        [[self class] readAuidoFileWithSourceAudioFilePath:sourceAudioFilePath repeatCount:repeatCount startTime:startTime duration:interval fileName:filePath completionHandler:^(NSString *filePath) {
            if (handler) {
                handler(filePath);
            }
        }];
    }
    NSLog(@"read file %d", n + 1);
    NSString *lastFilePath = [NSString stringWithFormat:@"%@/%@.m4a", audioDirectoryPath, [NSString stringWithFormat:@"%d",n + 1]];
    [[self class] readAuidoFileWithSourceAudioFilePath:sourceAudioFilePath repeatCount:repeatCount startTime:endTime duration:kCMTimePositiveInfinity fileName:lastFilePath completionHandler:^(NSString *filePath) {
        if (handler) {
            handler(filePath);
        }
    }];
}

+ (void)readAuidoFileWithSourceAudioFilePath:(NSString *)sourceAudioFilePath repeatCount:(NSInteger)repeatCount startTime:(CMTime)startTime duration:(CMTime)duration fileName:(NSString *)filePath completionHandler:(void (^)(NSString *filePath))handler
{
    
    NSLog(@"+++++++++++%f", CMTimeGetSeconds(startTime));
    NSLog(@"+++++++++++%f", CMTimeGetSeconds(duration));
    
    NSLog(@"%s",__FUNCTION__);
    CFMutableArrayRef _cfArray = NULL;
    _cfArray = CFArrayCreateMutable(NULL, 0, NULL);
    __block CMTime _writterStartTime = kCMTimeInvalid;
    __block CMTime _writterEndTime = kCMTimeInvalid;
    NSError* error = nil;
    NSURL *audioURL = [NSURL fileURLWithPath:sourceAudioFilePath];
    AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:audioURL options:nil];
    AVAssetReader* reader = [[AVAssetReader alloc] initWithAsset:asset error:&error];
    AVAssetTrack* songTrack = [asset.tracks firstObject];
    if (songTrack == nil) {
        return;
    }
    NSURL *exportUrl = [NSURL fileURLWithPath:filePath];
    AVAssetWriter *_assetWriter = [[AVAssetWriter alloc] initWithURL:exportUrl
                                             fileType:AVFileTypeQuickTimeMovie
                                                error:&error];
    [[GhoastMediaUtil sharedClient] addItem:_assetWriter];
    
    AVAssetWriterInput *_assetWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:nil];
    [_assetWriter addInput:_assetWriterInput];
    
    AVAssetReaderTrackOutput* trackOutput = [[AVAssetReaderTrackOutput alloc] initWithTrack:songTrack outputSettings:nil];
    
    [reader addOutput:trackOutput];
    NSLog(@"asset.duration ++ %f",CMTimeGetSeconds(asset.duration));
    reader.timeRange = CMTimeRangeMake(startTime, duration);
    
    [reader startReading];
    
    [_assetWriter startWriting];
    
    [_assetWriterInput requestMediaDataWhenReadyOnQueue:dispatch_get_main_queue() usingBlock:^{
        CMSampleBufferRef buffer = NULL;
        AVAssetReaderStatus status = [reader status];
        switch (status) {
            case AVAssetReaderStatusReading:
            {
                if ([_assetWriterInput isReadyForMoreMediaData]) {
                    buffer = [trackOutput copyNextSampleBuffer];
                    if (buffer) {
                        if (CMTIME_IS_INVALID(_writterStartTime)) {
                            _writterStartTime = CMSampleBufferGetPresentationTimeStamp(buffer);
                            [_assetWriter startSessionAtSourceTime:_writterStartTime];
                        }
                        if (_assetWriter.status == AVAssetWriterStatusUnknown){
                        }
                        if ([_assetWriterInput appendSampleBuffer:buffer] ){
                            NSLog(@"already write audio");
                        }else {
                            NSLog(@"Unable to write to audio input");
                        }
                        _writterEndTime = CMSampleBufferGetPresentationTimeStamp(buffer);
                        NSLog(@"_writterEndTime +++ %f",CMTimeGetSeconds(_writterEndTime));
                        CMSampleBufferInvalidate(buffer);
                        CFRelease(buffer);
                        buffer = NULL;
                    }
                }
            }
                break;
            case AVAssetReaderStatusCompleted:
            {
                NSLog(@"audio AVAssetReaderStatusCompleted");
                [_assetWriterInput markAsFinished];
                [_assetWriter endSessionAtSourceTime:_writterEndTime];
                
                
                [_assetWriter finishWritingWithCompletionHandler:^{
                    NSLog(@"finishWritingWithCompletionHandler");
                    [GhoastMediaUtil checkProceessAudioProgressWithRepeatCount:repeatCount completionHandler:^(NSString *filePath) {
                        if (handler) {
                            handler(filePath);
                        }
                    }];
                }];
            }
                break;
            default:
                break;
        }
    }];
}

+ (void)checkProceessAudioProgressWithRepeatCount:(NSInteger)repeatCount completionHandler:(void (^)(NSString *filePath))handler
{
    alreadyAudioRepeatedCount++;
    NSLog(@"_alreadyAudioRepeatedCount +++ %ld",(long)alreadyAudioRepeatedCount);
    if (alreadyAudioRepeatedCount >= repeatCount + 3) {
        NSLog(@"audio repeat process done");
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSURL *directoryURL = [NSURL fileURLWithPath:[self ghoastAudioDirectory]]; // URL pointing to the directory you want to browse
        NSArray *keys = [NSArray arrayWithObject:NSURLIsDirectoryKey];
        
        NSDirectoryEnumerator *enumerator = [fileManager enumeratorAtURL:directoryURL includingPropertiesForKeys:keys options:0 errorHandler:^(NSURL *url, NSError *error) {
            // Handle the error.
            // Return YES if the enumeration should continue after the error.
            return YES;
        }];
        NSString *finalAduioPath = [NSString stringWithFormat:@"%@/finalAudio.m4a",[self ghoastAudioDirectory]];
        [[self class] mergeVideoFilesWith:enumerator.allObjects toDestinationFilePath:finalAduioPath completionHandler:^{
            NSLog(@"merge done");
            
            NSString *videoFileName = [NSString stringWithFormat:@"%@.mp4", @"finalVideo"];
            NSString *videoPath = [NSString stringWithFormat:@"%@%@",[self ghoastAudioDirectory], videoFileName];
            NSString *destinationFilePath = [NSString stringWithFormat:@"%@/final.mp4",[[self class] ghoastAudioDirectory]];
            [[self class] mergeVideoAndAudioToDestinationUrl:[NSURL fileURLWithPath:destinationFilePath] audioUrl:[NSURL fileURLWithPath:finalAduioPath] videoUrl:[NSURL fileURLWithPath:videoPath] completionHandler:^{
                if (handler) {
                    handler(destinationFilePath);
                }
            }];
        }];
    }
}

+ (void)ghoastVideoLoopWithSourceVideoPath:(NSString *)sourceVideoPath repeatCount:(NSInteger)repeatCount repeatFrameCpoyCount:(NSInteger)repeatFrameCpoyCount handler:(void (^)(CMTime startTime, CMTime endTime, CMTime interval))handler
{
    if (repeatFrameCpoyCount > 30) {
        NSLog(@"超过关键帧之间的最大帧数");
        return;
    }
    
    NSLog(@"%s",__FUNCTION__);
    NSError *error = nil;
    NSURL *videoURL = [NSURL fileURLWithPath:sourceVideoPath];
    AVURLAsset* asset = [[AVURLAsset alloc]initWithURL:videoURL options:nil];
    AVAssetReader *reader = [[AVAssetReader alloc] initWithAsset:asset error:&error];
    if (error) {
        return;
    }
    
    NSArray *videoTracks = [asset tracksWithMediaType:AVMediaTypeVideo];
    if (!videoTracks.count) {
        error = [NSError errorWithDomain:@"AVFoundation error" code:-1 userInfo:@{ NSLocalizedDescriptionKey : @"Can't read video track" }];
        return;
    }
    AVAssetTrack *videoTrack = videoTracks.firstObject;
    AVAssetReaderTrackOutput *videoTrackOutput = [[AVAssetReaderTrackOutput alloc] initWithTrack:videoTrack outputSettings:nil];
    [reader addOutput:videoTrackOutput];
    [reader startReading];
    
    AVAssetWriter *_assetWriter = nil;
    AVAssetWriterInput *_videoAssetWriterInput = nil;
    CFMutableArrayRef _cfArray = NULL;
    _cfArray = CFArrayCreateMutable(NULL, 0, NULL);
    
    NSString *outputFile = [NSString stringWithFormat:@"%@.mp4", @"finalVideo"];
    NSString *exportPath = [NSString stringWithFormat:@"%@%@",[[self class]ghoastAudioDirectory], outputFile];
    NSURL *exportUrl = [NSURL fileURLWithPath:exportPath];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:exportPath]) {
        [[NSFileManager defaultManager] removeItemAtURL:exportUrl error:nil];
    }
    
    __block CMTime _writterStartTime = kCMTimeInvalid;
    
    _assetWriter = [[AVAssetWriter alloc] initWithURL:exportUrl
                                             fileType:AVFileTypeQuickTimeMovie
                                                error:&error];
    _videoAssetWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:nil];
    [_assetWriter addInput:_videoAssetWriterInput];
    
#if 0
    [_assetWriter startWriting];
    [_assetWriterInput requestMediaDataWhenReadyOnQueue:dispatch_get_main_queue() usingBlock:^{
        CMSampleBufferRef buffer = NULL;
        AVAssetReaderStatus status = [reader status];
        switch (status) {
            case AVAssetReaderStatusReading:
            {
                if ([_assetWriterInput isReadyForMoreMediaData]) {
                    buffer = [trackOutput copyNextSampleBuffer];
                    if (buffer) {
                        if (CMTIME_IS_INVALID(startTime)) {
                            startTime = CMSampleBufferGetPresentationTimeStamp(buffer);
                            [_assetWriter startSessionAtSourceTime:startTime];
                        }
                        if (_assetWriter.status == AVAssetWriterStatusUnknown){
                        }
                        if ([_assetWriterInput appendSampleBuffer:buffer] ){
                            NSLog(@"already write vidio");
                        }else {
                            NSLog(@"Unable to write to video input");
                        }
                        CMSampleBufferInvalidate(buffer);
                        CFRelease(buffer);
                        buffer = NULL;
                    }
                }
            }
                break;
            case AVAssetReaderStatusCompleted:
            {
                [_assetWriterInput markAsFinished];
                [_assetWriter finishWritingWithCompletionHandler:^{
                    NSLog(@"finishWritingWithCompletionHandler");
                }];
            }
                break;
            default:
                break;
        }
    }];
#else
    CMSampleBufferRef buffer = NULL;
    BOOL continueReading = YES;
    while (continueReading) {
        AVAssetReaderStatus status = [reader status];
        switch (status) {
            case AVAssetReaderStatusUnknown: {
            } break;
            case AVAssetReaderStatusReading: {
                buffer = [videoTrackOutput copyNextSampleBuffer];
                
                if (!buffer) {
                    break;
                }
                
                if (_assetWriter.status == AVAssetWriterStatusUnknown) {
                    if (CMTIME_IS_INVALID(_writterStartTime)) {
                        _writterStartTime = CMSampleBufferGetPresentationTimeStamp(buffer);
                    }
                }
                CMSampleBufferRef copySampleBuffer;
                CMSampleBufferCreateCopy(NULL, buffer, &copySampleBuffer);
                CFArrayAppendValue(_cfArray, copySampleBuffer);
                //                [self detectSampleBufferIsIFrame:copySampleBuffer];
                
            } break;
            case AVAssetReaderStatusCompleted: {
                
                NSLog(@"AVAssetReaderStatusCompleted%s",__FUNCTION__);
                
                if (_assetWriter.status == AVAssetWriterStatusUnknown) {
                    [_assetWriter startWriting];
                    [_assetWriter startSessionAtSourceTime:_writterStartTime];
                    
                }
                
                //找出关键帧的位置，然后存在数组中备用
                NSMutableArray *IFrameIndexArray = [[NSMutableArray alloc] init];
                
                NSInteger lastNonFrameCount = 0;
                for (NSInteger i = 0; i < CFArrayGetCount(_cfArray); i++) {
                    CMSampleBufferRef sampleBufferRef = (CMSampleBufferRef)CFArrayGetValueAtIndex(_cfArray, i);
                    switch ([[self class] detectSampleBufferIsIFrame:sampleBufferRef]) {
                        case FrameTypeIFrame:
                            lastNonFrameCount = 0;
                            [IFrameIndexArray addObject:@(i)];
                            break;
                        case FrameTypeNonIFrame:
                            lastNonFrameCount++;
                            break;
                        default:
                            break;
                    }
                }
                
                if (IFrameIndexArray.count == 0) {
                    NSLog(@"wtf no I Frame !!!");
                    return;
                }
                
                if (IFrameIndexArray.count <= 1) {
                    NSLog(@"不可以鬼畜");
                    return;
                }
                if (IFrameIndexArray.count == 2) {
                    if (lastNonFrameCount < repeatFrameCpoyCount) {
                        NSLog(@"最后剩余的帧数不够用来鬼畜");
                        return;
                    }
                }
                
                if (lastNonFrameCount < repeatFrameCpoyCount) {
                    [IFrameIndexArray removeLastObject];
                }
                
                [IFrameIndexArray removeObjectAtIndex:0];

                
                //随机取出关键帧的位置
                NSUInteger indexOfiFrameIndex = arc4random() % IFrameIndexArray.count;
                NSInteger copyStartIndex = ((NSNumber *)IFrameIndexArray[indexOfiFrameIndex]).integerValue;
                
                NSLog(@"copyStartIndex ++++ %ld",(long)copyStartIndex);
                
                //copy关键帧之前的帧
                CFMutableArrayRef newTotalArray = CFArrayCreateMutable(NULL, 0, NULL);
                for (NSInteger i = 0; i < copyStartIndex; i++) {
                    CFArrayAppendValue(newTotalArray, CFArrayGetValueAtIndex(_cfArray, i));
                }
                
                //鬼畜帧
                CFMutableArrayRef repeatCopyArray = CFArrayCreateMutable(NULL, 0, NULL);
                const void* values[repeatFrameCpoyCount];
                CFArrayGetValues(_cfArray, CFRangeMake(copyStartIndex, repeatFrameCpoyCount), values);
                for (NSInteger i = 0; i < repeatFrameCpoyCount; i++) {
                    CFArrayAppendValue(repeatCopyArray, values[i]);
                }
                
                CFArrayAppendArray(newTotalArray, repeatCopyArray, CFRangeMake(0, CFArrayGetCount(repeatCopyArray)));
                
                //计算鬼畜时间间隔
                CMTime startCopyTime = kCMTimeZero;
                NSInteger startIndex = copyStartIndex;
                NSInteger endIndex = copyStartIndex + repeatFrameCpoyCount;
                CMSampleBufferRef startCopySampleBufferRef = (CMSampleBufferRef)CFArrayGetValueAtIndex(_cfArray, startIndex);
                startCopyTime = CMSampleBufferGetPresentationTimeStamp(startCopySampleBufferRef);
                
                CMSampleBufferRef endCopySampleBufferRef = (CMSampleBufferRef)CFArrayGetValueAtIndex(_cfArray, endIndex);
                CMTime endCopyTime = CMSampleBufferGetPresentationTimeStamp(endCopySampleBufferRef);
                CMTime intervalTime = CMTimeSubtract(endCopyTime, startCopyTime);
                
                //将鬼畜插入数组copyCount次，
                for (NSInteger j = 0; j < repeatCount; j++) {
                    CFMutableArrayRef repeatSubArray = CFArrayCreateMutable(NULL, 0, NULL);
                    for (NSInteger i = 0; i < CFArrayGetCount(repeatCopyArray); i++) {
                        CMSampleBufferRef sampleBufferRef = (CMSampleBufferRef)CFArrayGetValueAtIndex(repeatCopyArray, i);
                        CMSampleBufferRef newSampleBufferRef = [self createOffsetSampleBufferWithSampleBuffer:sampleBufferRef withTimeOffset:CMTimeMultiply(intervalTime, (int32_t)(j + 1))];
                        if (newSampleBufferRef != NULL) {
                            CFArrayAppendValue(repeatSubArray, newSampleBufferRef);
                        }
                    }
                    CFArrayAppendArray(newTotalArray, repeatSubArray, CFRangeMake(0, CFArrayGetCount(repeatSubArray)));
                    CFRelease(repeatSubArray);
                }
                
                //将剩余的帧数copy到newTotalArray
                CFMutableArrayRef remainSubArray = CFArrayCreateMutable(NULL, 0, NULL);
                NSInteger startRepeatIndex = CFArrayGetCount(repeatCopyArray);
                NSInteger count = CFArrayGetCount(_cfArray);
                for (NSInteger i = startRepeatIndex + copyStartIndex; i < count; i++) {
                    CMSampleBufferRef sampleBufferRef = (CMSampleBufferRef)CFArrayGetValueAtIndex(_cfArray, i);
                    CMSampleBufferRef newSampleBufferRef = [self createOffsetSampleBufferWithSampleBuffer:sampleBufferRef withTimeOffset:CMTimeMultiply(intervalTime, (int32_t)repeatCount)];
                    if (newSampleBufferRef != NULL) {
                        CFArrayAppendValue(remainSubArray, newSampleBufferRef);
                    }
                }
                CFArrayAppendArray(newTotalArray, remainSubArray, CFRangeMake(0, CFArrayGetCount(remainSubArray)));
                CFRelease(remainSubArray);
                
                //将处理后的所有视频帧写入文件
                [_videoAssetWriterInput requestMediaDataWhenReadyOnQueue:dispatch_get_main_queue() usingBlock:^{
                    while ([_videoAssetWriterInput isReadyForMoreMediaData] && CFArrayGetCount(newTotalArray) > 0) {
                        
                        CMSampleBufferRef sampleBufferRef = (CMSampleBufferRef)CFArrayGetValueAtIndex(newTotalArray, 0);
                        if ([_videoAssetWriterInput appendSampleBuffer:sampleBufferRef] ){
                            NSLog(@"already write vidio");
                            CMSampleBufferInvalidate(sampleBufferRef);
                            CFRelease(sampleBufferRef);
                            sampleBufferRef = NULL;
                        }else {
                            NSLog(@"Unable to write to video input");
                        }
                        CFArrayRemoveValueAtIndex(newTotalArray, 0);
                    }
                    if (CFArrayGetCount(newTotalArray) == 0) {
                        [_videoAssetWriterInput markAsFinished];
                        [_assetWriter finishWritingWithCompletionHandler:^{
                            NSLog(@"finishWritingWithCompletionHandler");
                            CFRelease(newTotalArray);
                            CFRelease(repeatCopyArray);
                            if (handler) {
                                handler(startCopyTime, endCopyTime, intervalTime);
                            }
                        }];
                    }
                }];                
                continueReading = NO;
            } break;
            case AVAssetReaderStatusFailed: {
                
                [reader cancelReading];
                continueReading = NO;
            } break;
            case AVAssetReaderStatusCancelled: {
                continueReading = NO;
            } break;
        }
        if (buffer) {
            CMSampleBufferInvalidate(buffer);
            CFRelease(buffer);
            buffer = NULL;
        }
    }
#endif
}

+ (FrameType)detectSampleBufferIsIFrame:(CMSampleBufferRef)sampleBuffer
{
    BOOL isIFrame = NO;
    CFArrayRef attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, YES);
    if (attachmentsArray != NULL) {
        if (CFArrayGetCount(attachmentsArray)) {
            CFBooleanRef notSync;
            CFDictionaryRef dict = CFArrayGetValueAtIndex(attachmentsArray, 0);
            BOOL keyExists = CFDictionaryGetValueIfPresent(dict,
                                                           kCMSampleAttachmentKey_NotSync,
                                                           (const void **)&notSync);
            // An I-Frame is a sync frame
            isIFrame = !keyExists || !CFBooleanGetValue(notSync);
        }
        
        if (isIFrame) {
            NSLog(@"IFrame");
            return FrameTypeIFrame;
        }else {
            NSLog(@"not IFrame");
            return FrameTypeNonIFrame;
        }
    }else {
        NSLog(@"no attachmentsArray");
        return FrameTypeUnkown;
    }
}

+ (CMSampleBufferRef)createOffsetSampleBufferWithSampleBuffer:(CMSampleBufferRef)sampleBuffer withTimeOffset:(CMTime)timeOffset
{
    CMItemCount itemCount;
    
    OSStatus status = CMSampleBufferGetSampleTimingInfoArray(sampleBuffer, 0, NULL, &itemCount);
    if (status) {
        return NULL;
    }
    
    CMSampleTimingInfo *timingInfo = (CMSampleTimingInfo *)malloc(sizeof(CMSampleTimingInfo) * (unsigned long)itemCount);
    if (!timingInfo) {
        return NULL;
    }
    
    status = CMSampleBufferGetSampleTimingInfoArray(sampleBuffer, itemCount, timingInfo, &itemCount);
    if (status) {
        free(timingInfo);
        timingInfo = NULL;
        return NULL;
    }
    
    for (CMItemCount i = 0; i < itemCount; i++) {
        timingInfo[i].presentationTimeStamp = CMTimeAdd(timingInfo[i].presentationTimeStamp, timeOffset);
        timingInfo[i].decodeTimeStamp = CMTimeAdd(timingInfo[i].decodeTimeStamp, timeOffset);
    }
    
    CMSampleBufferRef offsetSampleBuffer;
    CMSampleBufferCreateCopyWithNewTiming(kCFAllocatorDefault, sampleBuffer, itemCount, timingInfo, &offsetSampleBuffer);
    
    if (timingInfo) {
        free(timingInfo);
        timingInfo = NULL;
    }
    
    return offsetSampleBuffer;
}

+ (void)mergeVideoFilesWith:(NSArray *)array toDestinationFilePath:(NSString *)destinationFilePath completionHandler:(void (^)(void))handler
{
    AVMutableComposition* mixComposition = [AVMutableComposition composition];
    AVMutableCompositionTrack *compositionVideoTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeAudio
                                                                                   preferredTrackID:kCMPersistentTrackID_Invalid];
    
    for (NSURL *filePath in array) {
        NSURL *videoURL = filePath;
        AVURLAsset* videoAsset = [[AVURLAsset alloc]initWithURL:videoURL options:nil];
        AVAssetTrack *assetVideoTrack = [videoAsset tracksWithMediaType:AVMediaTypeAudio].lastObject;
        [compositionVideoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, videoAsset.duration)
                                       ofTrack:assetVideoTrack
                                        atTime:kCMTimeInvalid error:nil];
        [compositionVideoTrack setPreferredTransform:assetVideoTrack.preferredTransform];
    }
    
    AVAssetExportSession* _assetExport = [[AVAssetExportSession alloc] initWithAsset:mixComposition
                                                                          presetName:AVAssetExportPresetPassthrough];
    
    
    _assetExport.outputFileType = @"public.mpeg-4";
    _assetExport.outputURL = [NSURL fileURLWithPath:destinationFilePath];
    _assetExport.shouldOptimizeForNetworkUse = YES;
    
    [_assetExport exportAsynchronouslyWithCompletionHandler:^(void ) {
        //        for (NSString *filePath in array) {
        //            [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
        //        }
        dispatch_async(dispatch_get_main_queue(), ^{
            handler();
        });
    }];
}

+ (void)mergeVideoAndAudioToDestinationUrl:(NSURL *)destinationUrl audioUrl:(NSURL *)audioUrl videoUrl:(NSURL *)videoUrl completionHandler:(void (^)(void))handler
{
    AVURLAsset* audioAsset = [[AVURLAsset alloc]initWithURL:audioUrl options:nil];
    AVURLAsset* videoAsset = [[AVURLAsset alloc]initWithURL:videoUrl options:nil];
    
    AVMutableComposition* mixComposition = [AVMutableComposition composition];
    
    AVMutableCompositionTrack *compositionCommentaryTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeAudio
                                                                                        preferredTrackID:kCMPersistentTrackID_Invalid];
    [compositionCommentaryTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, audioAsset.duration)
                                        ofTrack:[[audioAsset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0]
                                         atTime:kCMTimeZero error:nil];
    
    AVMutableCompositionTrack *compositionVideoTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo
                                                                                   preferredTrackID:kCMPersistentTrackID_Invalid];
    [compositionVideoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, videoAsset.duration)
                                   ofTrack:[[videoAsset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0]
                                    atTime:kCMTimeZero error:nil];
    
    AVAssetExportSession* _assetExport = [[AVAssetExportSession alloc] initWithAsset:mixComposition
                                                                          presetName:AVAssetExportPresetPassthrough];
    
    
    _assetExport.outputFileType = @"public.mpeg-4";
    NSLog(@"file type %@",_assetExport.outputFileType);
    _assetExport.outputURL = destinationUrl;
    _assetExport.shouldOptimizeForNetworkUse = YES;
    
    [_assetExport exportAsynchronouslyWithCompletionHandler:^(void ) {
        dispatch_async(dispatch_get_main_queue(), ^{
            handler();
        });
    }];
}
@end

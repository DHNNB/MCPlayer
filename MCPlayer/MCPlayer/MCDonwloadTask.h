//
//  MCDonwloadTask.h
//  MCPlayer
//
//  Created by M_Code on 2017/6/15.
//  Copyright © 2017年 MC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@class MCDonwloadTask;
@protocol MCDonwloadTaskDelegate <NSObject>

- (void)didReceiveResponseWithtask:(MCDonwloadTask *)task length:(NSUInteger)ideoLength mimeType:(NSString *)mimeType;
- (void)didReceiveVideoDataWithTask:(MCDonwloadTask *)task cacheProgress:(CGFloat)progress;
- (void)didFinishLoadingWithTask:(MCDonwloadTask *)task;
- (void)didFailLoadingWithTask:(MCDonwloadTask *)task WithErrorStr:(NSString *  )errorStr;
- (void)taskCancelWithTask:(MCDonwloadTask * )task;
@end

@interface MCDonwloadTask : NSObject
@property (assign, nonatomic) long long offset;
@property (assign, nonatomic) long long  videoLength;
@property (assign, nonatomic) long long downLoadingOffset;
@property (copy, nonatomic) NSString * mimeType;
@property (assign, nonatomic) BOOL isDownloadFinished;
@property (weak, nonatomic) id <MCDonwloadTaskDelegate> delegate;

- (instancetype)initWithTempPath:(NSString * )tempPath desPath:(NSString * )desPath;
- (void)setUrl:(NSURL *)url offset:(NSUInteger)offset;
- (void)cancel;
@end

@interface KKDownloadOperationQueue : NSObject

@property (retain, nonatomic) NSOperationQueue * queue;
+ (KKDownloadOperationQueue * )shareQueue;
@end


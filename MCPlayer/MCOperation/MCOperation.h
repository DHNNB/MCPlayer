//
//  MCOperation.h
//  MCPlayer
//
//  Created by M_Code on 2017/3/30.
//  Copyright © 2017年 MC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
@class MCOperation;
@protocol MCDownloadDelegate <NSObject>

@optional

// 下载成功
- (void)downloadSuccessDesPath:(NSString * )desPath withOperation:(MCOperation * )operation;
// 下载失败
- (void)downloadFailMsg:(NSString *)msg withOperation:(MCOperation * )operation;
// 下载进度
- (void)donwloadProgress:(CGFloat)progress withOperation:(MCOperation * )operation;
// 下载暂停
- (void)downloadPause:(MCOperation * )operation;
// 下载开始
- (void)downloadStart:(MCOperation * )operation;
// 下载取消
- (void)downloadCancel:(MCOperation * )operation;
// 下载等待
- (void)downloadWaiting:(MCOperation * )operation;
@end

@interface MCOperation : NSOperation
@property (copy, nonatomic) NSString * url;// 下载地址
@property (copy, nonatomic) NSString * desPath;//最终路径
@property (copy, nonatomic) NSString * tempPath;//临时路径
@property (weak, nonatomic) id<MCDownloadDelegate> delegate;
@property (assign,nonatomic) BOOL movePathSuccess;// 缓存文件是否移动了
@property (assign, nonatomic) CGFloat progress;
@property (assign, nonatomic) BOOL isAgain;
@property (assign, nonatomic) BOOL isCopy;
@property (assign, nonatomic) BOOL isCancel;
@property (assign, nonatomic, getter = isExecuting) BOOL executing;
@property (assign, nonatomic, getter = isFinished) BOOL finished;
//都是完整的路径 / 最终路径desPath  / 临时路径 tempPath / isAgain 重新下载 不继续 / isCopy下载完成 是复制到目标路径不是移动
- (instancetype)initWithUrl:(NSString * )url tempPath:(NSString * )tempPath desPath:(NSString * )desPath delegate:(id)delegate isAgain:(BOOL)isAgain isCopy:(BOOL)isCopy;
-(void)pauseDownload;
-(void)cancleDownload;
//当前长度
- (long long)getCurrentLength;
//最大长度
- (long long)getTotalLength;
@end

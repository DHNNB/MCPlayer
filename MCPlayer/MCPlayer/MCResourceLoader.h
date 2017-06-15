//
//  MCResourceLoader.h
//  MCPlayer
//
//  Created by M_Code on 2017/3/30.
//  Copyright © 2017年 MC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@protocol MCResourceLoadDelegate <NSObject>

@optional
/**
 取消网络播放
 */
- (void)taskCancel;
/**
 滑动slider 之后设置加载状态（只在使用网络播放的时候调用）
 
 @param showLoading 是否显示loading
 */
- (void)mediaDownloadTaskStateForShowLoading:(BOOL)showLoading;

/**
 下载进度
 @param progress progress
 */
- (void)downloadProgress:(CGFloat)progress;
/**
 下载成功
 
 @param desPath 路径
 */
- (void)downloadSuccessWithDesPath:(NSString * )desPath;

/**
 下载失败
 
 @param msg 失败信息
 */
- (void)downloadFailMsg:(NSString * )msg;
@end
static NSString * KKScheme = @"MCStreaming";

@interface MCResourceLoader : NSObject <AVAssetResourceLoaderDelegate>
@property (weak, nonatomic) id<MCResourceLoadDelegate> delegate;
/**
 创建 流供给对象
 
 @param url 播放地址
 @param desPath 目标文件
 @param cachePath 缓存文件
 @param isLocal 是否在本地
 @return -
 */
- (instancetype)initWithUrl:(NSString * )url
                    desPath:(NSString * )desPath
                  cachePath:(NSString * )cachePath
                    isLocal:(BOOL)isLocal;
- (void)cancel;

@end

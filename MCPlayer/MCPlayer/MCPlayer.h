//
//  MCPlayer.h
//  MCPlayer
//
//  Created by M_Code on 2017/3/30.
//  Copyright © 2017年 MC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "MCCost.h"
@protocol MCPlayerDelegate <NSObject>
@optional
/**
 缓冲进度
 
 @param cache 缓冲进度
 @param duration 音频总时间
 */
- (void)playerLoadingValue:(CGFloat)cache
                  duration:(CGFloat)duration;

/**
 播放时间更新
 
 @param seconds 当前播放时间
 */
- (void)playerPlayTimeSecond:(CGFloat)seconds;
/**
 缓冲
 */
- (void)playerBuffer;

/**
 缓存结束
 */
- (void)playerBufferFull;

/**
 播放
 */
- (void)playerPlay;

/**
 播放结束
 */
- (void)playerEnd;

/**
 播放暂停
 */
- (void)playerPause;

/**
 停止播放
 */
- (void)playerStop;

/**
 播放失败
 
 @param msg 失败信息
 */
- (void)playerFailWithMsg:(NSString * )msg;

/**
 音频下载成功
 */
- (void)downloadSuccess;
@end
// 播放器状态
typedef NS_ENUM(NSInteger, MCPlayerState) {
    MCPlayerStateStopped = 0,     // 停止播放
    MCPlayerStateBuffering,  // 缓冲中
    MCPlayerStatePlaying,    // 播放中
    MCPlayerStateFailed,    // 播放失败
    MCPlayerStatePause       // 暂停播放
};
@interface MCPlayer : NSObject

@property (retain, nonatomic) AVPlayer * player;

@property (weak, nonatomic) id<MCPlayerDelegate> delegate;
/**
 记录播放状态
 */
@property (assign, nonatomic) MCPlayerState playerState;
/**
 播放结束 状态 （防止 播放结束 playbackLikelyToKeepUp 调用在此播放）
 */
@property (assign, nonatomic) BOOL isPlayEnd;

/**
 进入后台是否暂停播放 默认 NO  进入后台暂停
 */
@property (assign, nonatomic) BOOL backgroundPlay;

/**
 是否播放
 */
@property (assign, nonatomic) BOOL isPlaying;

/**
 是否暂停
 */
@property (assign, nonatomic) BOOL isPause;

/**
 没有播放 或者播放失败
 */
@property (assign, nonatomic) BOOL isStop;

/**
 设置播放器音量
 */
@property (assign, nonatomic) CGFloat volume;

/**
 音频总时间
 */
@property (assign, nonatomic) CGFloat duration;

/**
 音频当前时间
 */
@property (assign, nonatomic) CGFloat currentTime;


/**
 创建播放器
 
 @return 返回的不是单例
 */
+(MCPlayer * )makePlayer;
/**
 可播放 本地 和在线音频 视频  此方法播放在线音频  视频 会 边下边播
 @param url 地址 本地可空
 @param tempPath 临时文件可空
 @param desPath 缓存完成的文件可空
 @param delegate 代理
 */
- (void)playMediaWithUrl:(NSString *)url
                tempPath:(NSString * )tempPath
                 desPath:(NSString * )desPath
                delegate:(id)delegate;
/**
 音频播放
 */
- (void)playMedia;

/**
 音频暂停
 */
- (void)pauseMedia;

/**
 音频停止
 */
- (void)stopMedia;

/**
 设置播放速率
 @param value 值
 */
- (void)setPlayerRate:(CGFloat)value;


/**
 设置播放时间
 
 @param seconds 秒
 */
- (void)seekToTime:(CGFloat)seconds;
@end

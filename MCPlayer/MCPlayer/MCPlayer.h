//
//  MCPlayer.h
//  MCPlayer
//
//  Created by M_Code on 2017/3/30.
//  Copyright © 2017年 MC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
@protocol MCPlayerDelegate <NSObject>
@optional
/**
 缓冲进度
 
 @param cache 缓冲进度
 @param duration 音频总时间
 */
- (void)playerLoadingValue:(double)cache
                  duration:(CGFloat)duration;

/**
 播放时间更新
 
 @param seconds 当前播放时间
 @param currentString 当前时间 字符串
 @param residueStr 剩余时间字符串
 */
- (void)playerPlayTimeSecond:(CGFloat)seconds
                  currentStr:(NSString *)currentString
              withResidueStr:(NSString *)residueStr;
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
/**
 本类 存在两个播放器 一个是avplayer 边播变下 一个是 AVAudioPlayer 为了实现慢速播放音质问题而创建
 当音频下载完成之后 切换到avaudioplayer 播放😂
 */
@interface MCPlayer : NSObject
@property (weak, nonatomic) id<MCPlayerDelegate> delegate;
/**
 记录播放状态
 */
@property (assign, nonatomic) MCPlayerState playerState;
/**
 是否 支持rate  如果支持 变速播放 为了保证播放质量 如果是本地数据 直接使用avaudioplayer 播放 如果是网络数据 当数据下载完成之后 自动切换到 avaudioplayer 播放~
 */
@property (assign, nonatomic) BOOL supportRate;

/**
 是否播放
 */
@property (assign, nonatomic) BOOL isPlaying;

/**
 是否暂停
 */
@property (assign, nonatomic) BOOL isPause;

/**
 创建播放器
 
 @return 返回的不是单例
 */
+(MCPlayer * )makeMCPlayer;
/**
 节目详播放 里边有些文件是否存在的判断
 @param url 地址
 @param delegate 代理
 */
- (void)playerWithUrl:(NSString *  )url delegate:(id)delegate;

/**
 可播放 本地 和在线音频  此方法播放在线音频会 边下边播
 @param url 地址 本地可空
 @param tempPath 临时文件 本地可空
 @param desPath 缓存完成的文件 在线离线这个参数都不能为空
 @param delegate 代理
 @param isLocal 是否是本地音频
 */
- (void)playMediaWithUrl:(NSString *)url
                tempPath:(NSString * )tempPath
                 desPath:(NSString * )desPath
                delegate:(id)delegate
                 isLocal:(BOOL)isLocal;

/**
 播放本地音频
 
 @param path 文件路径
 @param seconds 开始时间
 @param isSuccess 是否为下载成功时候调用 单独使用传入NO即可
 @param delegate 代理 只会调用 播放结束 失败 暂停 播放 这几个代理
 */
- (void)playLocalWithPath:(NSString * )path
                startTime:(CGFloat)seconds
          downloadSuccess:(BOOL)isSuccess
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
 
 @param millisecond 单位是毫秒
 */
- (void)seekToTime:(CGFloat)millisecond;

/**
 获取音频总时间
 
 @return-
 */
- (CGFloat)getDuration;

/**
 获取音频当前时间
 
 @return-
 */
- (CGFloat)getCurrentTime;
@end

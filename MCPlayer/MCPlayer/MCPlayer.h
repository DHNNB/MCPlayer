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
// 缓冲进度
- (void)playerLoadingValue:(double)cache duration:(CGFloat)duration;
- (void)playerPlayTimeSecond:(CGFloat)seconds currentStr:(NSString *)currentString withResidueStr:(NSString *)residueStr;
// 缓冲中
- (void)playerBuffer;
//缓冲结束
- (void)playerBufferFull;

//开始播放
- (void)playerPlay;
// 播放完成
- (void)playerEnd;
// 暂停
- (void)playerPause;
// 停止播放
- (void)playerStop;
// 播放失败
- (void)playerFailWithMsg:(NSString * )msg;
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
@property (weak, nonatomic) id<MCPlayerDelegate> delegate;
@property (assign, nonatomic) MCPlayerState playerState;
@property (assign, nonatomic) BOOL isPlaying;
@property (assign, nonatomic) BOOL isPause;
+(MCPlayer * )makeMCPlayer;
- (void)playerWithUrl:(NSString * )url delegate:(id)delegate;
- (void)playMedia;
- (void)pauseMedia;
- (void)stopMedia;
//设置播放速率
- (void)setPlayerRate:(CGFloat)value;
//跳到某一时间
- (void)seekToTime:(CGFloat)millisecond;
- (CGFloat)getDuration;
- (CGFloat)getCurrentTime;

@end

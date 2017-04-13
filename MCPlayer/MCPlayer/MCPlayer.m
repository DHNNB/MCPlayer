//
//  MCPlayer.m
//  MCPlayer
//
//  Created by M_Code on 2017/3/30.
//  Copyright © 2017年 MC. All rights reserved.
//
#define main_queue      dispatch_get_main_queue()

#import "MCPlayer.h"
#import "MCResourceLoader.h"
#import <AVFoundation/AVFoundation.h>
#import "MCPath.h"
@interface MCPlayer() <NSURLSessionDelegate,MCResourceLoadDelegate>
@property (retain, nonatomic) AVPlayer * player;
@property (assign, nonatomic) id timeObserver;
/**
 *  播放速率
 */
@property (assign, nonatomic) CGFloat playRate;
@property (assign, nonatomic) CGFloat historyTime;
@property (assign, nonatomic) BOOL stopRefresh;
@property (retain, nonatomic) MCResourceLoader * resourceLoader;
@property (copy, nonatomic) NSString * currentUrl;
@end

@implementation MCPlayer
- (void)dealloc
{
    [self cancleDownload];
    if(self.player)
    {
        [self removePlayerKVO];
    }
    [[NSNotificationCenter defaultCenter]removeObserver:self];
    NSLog(@"MCAVPlayer 销毁了");
}
+(MCPlayer * )makeMCPlayer
{
    MCPlayer * player = [[MCPlayer alloc] init];
    
    return player;
}
- (instancetype)init
{
    self = [super init];
    if (self) {
        _playRate = 1.0;
        _timeObserver = nil;
        _historyTime = 0;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(audioRouteChangeListenerCallback:) name:AVAudioSessionRouteChangeNotification object:nil];
    }
    return self;
}
- (void)setAudioSession
{
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryPlayback error:nil];
    [audioSession setActive:YES error:nil];
}
#pragma mark - 播放
- (void)playerWithUrl:(NSString * )url delegate:(id)delegate
{
    if (!url)
    {
        [self failMediaWithMsg:@"播放地址有误"];
        return;
    }
    self.currentUrl = url;
    [self playerBuffer];
    [self setAudioSession];
    NSFileManager * fileManager = [NSFileManager defaultManager];
    //本地服务器 目录 临时存储
    NSString *webPath =[MCPath getOfflineMediaTempPathWithUrl:url];
    //缓存完成后的最终目录
    NSString  * desPath=[MCPath getOfflineMediaDesPathWithUrl:url];
    BOOL loacl = NO;
    //如果最终目录中有 证明已经缓存完成直接播放
    if ([fileManager fileExistsAtPath:desPath])
    {
        loacl = YES;
    }
    [self playMediaWithUrl:url TempPath:webPath desPath:desPath delegate:delegate isLocal:loacl];
}
- (void)playMediaWithUrl:(NSString *)url TempPath:(NSString * )tempPath desPath:(NSString * )desPath delegate:(id)delegate isLocal:(BOOL)isLocal
{
    if(self.player){
        [self removePlayerKVO];
    }
    [self cancleDownload];
    self.stopRefresh = NO;
    self.historyTime = 0;
    self.delegate = delegate;
    NSURLComponents * components = nil;
    if(isLocal){
        components = [[NSURLComponents alloc] initWithURL:[NSURL fileURLWithPath:desPath] resolvingAgainstBaseURL:NO];
    }else{
        components = [[NSURLComponents alloc] initWithURL:[NSURL URLWithString:url] resolvingAgainstBaseURL:NO];
    }
    components.scheme = KKScheme;
    self.resourceLoader = [[MCResourceLoader alloc]initWithUrl:url DesPath:desPath cachePath:tempPath isLocal:isLocal];
    AVURLAsset * asset = [AVURLAsset URLAssetWithURL:components.URL options:nil];
    self.resourceLoader.delegate = self;
    [asset.resourceLoader setDelegate:self.resourceLoader queue:dispatch_get_main_queue()];
    AVPlayerItem * playerItem = [AVPlayerItem playerItemWithAsset:asset];
    if ([[[UIDevice currentDevice]systemVersion] floatValue] >= 9.0){
        playerItem.canUseNetworkResourcesForLiveStreamingWhilePaused = YES;
    }
    self.player = [AVPlayer playerWithPlayerItem:playerItem];
    if ([[[UIDevice currentDevice]systemVersion] floatValue] >= 10.0){
        self.player.automaticallyWaitsToMinimizeStalling = NO;
    }
    [self addPlayerKVO];
    [self addTimerObserver];
}
#pragma mark - KKResourceLoadDelegate
- (void)downloadFailMsg:(NSString * )msg;
{
    [self failMediaWithMsg:msg];
}
#pragma mark -  拔出事件
- (void)audioRouteChangeListenerCallback:(NSNotification*)notification
{
    NSDictionary *interuptionDict = notification.userInfo;
    NSInteger routeChangeReason = [[interuptionDict valueForKey:AVAudioSessionRouteChangeReasonKey] integerValue];
    switch (routeChangeReason)
    {
        case AVAudioSessionRouteChangeReasonNewDeviceAvailable:
            // 耳机插入
            break;
        case AVAudioSessionRouteChangeReasonOldDeviceUnavailable:                      {
            // 耳机拔掉
            [self pauseMedia];
        }
            break;
        case AVAudioSessionRouteChangeReasonCategoryChange:
            // called at start - also when other audio wants to play
            NSLog(@"AVAudioSessionRouteChangeReasonCategoryChange");
            break;
    }
}
#pragma mark - KVO
- (void)addPlayerKVO
{
    [self.player.currentItem addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
    [self.player.currentItem addObserver:self forKeyPath:@"loadedTimeRanges" options:NSKeyValueObservingOptionNew context:nil];
    [self.player.currentItem addObserver:self forKeyPath:@"playbackBufferEmpty" options:NSKeyValueObservingOptionNew context:nil];
    [self.player.currentItem addObserver:self forKeyPath:@"playbackBufferFull" options:NSKeyValueObservingOptionNew context:nil];
    [self.player.currentItem addObserver:self forKeyPath:@"playbackLikelyToKeepUp" options:NSKeyValueObservingOptionNew context:nil];
    [self.player addObserver:self forKeyPath:@"rate" options:NSKeyValueObservingOptionNew context:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(moviePlayDidEnd:) name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
}
- (void)removePlayerKVO
{
    [self.player pause];
    [self.player.currentItem removeObserver:self forKeyPath:@"status"];
    [self.player.currentItem removeObserver:self forKeyPath:@"loadedTimeRanges"];
    [self.player.currentItem removeObserver:self forKeyPath:@"playbackBufferEmpty"];
    [self.player.currentItem removeObserver:self forKeyPath:@"playbackBufferFull"];
    [self.player.currentItem removeObserver:self forKeyPath:@"playbackLikelyToKeepUp"];
    [self.player removeObserver:self forKeyPath:@"rate"];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.player removeTimeObserver:self.timeObserver];
    [self.player replaceCurrentItemWithPlayerItem:nil];
    self.player = nil;
    self.timeObserver = nil;
}
- (void)moviePlayDidEnd:(NSNotification * )notification
{
    CGFloat duration = CMTimeGetSeconds(self.player.currentItem.duration);
    CGFloat currentTime = CMTimeGetSeconds(self.player.currentItem.currentTime);
    NSLog(@"播放结束 %f >>%f",duration,currentTime);
    if (currentTime + 3 >= duration)
    {
        dispatch_async(main_queue, ^{
            if (_delegate && [_delegate respondsToSelector:@selector(playerEnd)])
            {
                [_delegate playerEnd];
            }
        });
    }else
    {
        [self failMediaWithMsg:@"播放失败"];
    }
}

- (void)observeValueForKeyPath:(nullable NSString *)keyPath ofObject:(nullable id)object change:(nullable NSDictionary<NSString*, id> *)change context:(nullable void *)context
{
    BOOL play = NO;
    if ([keyPath isEqualToString:@"status"])
    {
        AVPlayerItemStatus status = self.player.currentItem.status;
        switch (status) {
            case AVPlayerItemStatusReadyToPlay:
            {
                NSLog(@"准备好了 开始播放");
                play = YES;
            }
                break;
            case AVPlayerItemStatusUnknown:
            {
                NSLog(@"AVPlayerItemStatusUnknown");
                [self failMediaWithMsg:@"播放失败"];
            }
                break;
            case AVPlayerItemStatusFailed:
            {
                NSLog(@"AVPlayerItemStatusFailed");
                [self failMediaWithMsg:@"播放失败"];
            }
                break;
            default:
                break;
        }
    } else if ([keyPath isEqualToString:@"loadedTimeRanges"])
    {
        NSTimeInterval timeInterval = [self availableDuration];
        CGFloat duration = [self getDuration];
        CGFloat currentTime = 0;
        if (self.historyTime)
        {
            currentTime = self.historyTime / 1000.0f;
        }else
        {
            currentTime = [self getCurrentTime];
        }
        if ( (self.playerState == MCPlayerStateBuffering) &&  (timeInterval + 8 >= duration || timeInterval - 10 >= currentTime)) //预防网速慢 无法播放 加减时间自己设置
        {
            play = YES;
            NSLog(@"缓冲播放了！！！");
        }
        dispatch_async(main_queue, ^{
            if (_delegate && [_delegate respondsToSelector:@selector(playerLoadingValue:duration:)])
            {
                [_delegate playerLoadingValue:timeInterval duration:CMTimeGetSeconds(self.player.currentItem.duration)];
            }
        });
    } else if ([keyPath isEqualToString:@"playbackBufferEmpty"])
    {
        if(self.player.currentItem.playbackBufferEmpty)
        {
            [self playerBuffer];
            NSLog(@"playbackBufferEmpty");
        }
        
    }else if ([keyPath isEqualToString:@"playbackLikelyToKeepUp"])
    {
        if (self.player.currentItem.playbackLikelyToKeepUp &&self.playerState == MCPlayerStateBuffering)
        {
            [self playerBufferFull];
            play = YES;
            NSLog(@"playbackLikelyToKeepUp");
        }
    }else if ([keyPath isEqualToString:@"playbackBufferFull"])
    {
        if(self.player.currentItem.playbackBufferFull)
        {
            [self playerBufferFull];
        }
        NSLog(@"playbackBufferFull");
    }else if ([keyPath isEqualToString:@"rate"])
    {
        if (self.player.rate > 0 && self.player)
        {
            if (self.player.rate != self.playRate)
            {
                [self.player setRate:self.playRate];
            }
            self.playerState = MCPlayerStatePlaying;
        }
    }
    if (play)
    {
        if(self.playerState == MCPlayerStatePause)
        {
            [self.player pause];
        }else
        {
            [self playMedia];
        }
    }
}
- (NSTimeInterval)availableDuration
{
    NSArray *loadedTimeRanges = [[self.player currentItem] loadedTimeRanges];
    CMTimeRange timeRange = [loadedTimeRanges.firstObject CMTimeRangeValue];// 获取缓冲区域
    double startSeconds = CMTimeGetSeconds(timeRange.start);
    double durationSeconds = CMTimeGetSeconds(timeRange.duration);
    NSTimeInterval result = startSeconds + durationSeconds;// 计算缓冲总进度
    return result;
}
- (void)addTimerObserver
{
    __weak typeof (self)weakSelf = self;
    self.timeObserver = [self.player addPeriodicTimeObserverForInterval:CMTimeMake(1, 4) queue:NULL usingBlock:^(CMTime time) {
        
        if (weakSelf.stopRefresh)
        {
            return ;
        }
        CGFloat currentTimeValue = CMTimeGetSeconds(weakSelf.player.currentItem.currentTime);
        CGFloat  durationValue = CMTimeGetSeconds(weakSelf.player.currentItem.duration);
        NSString *currentString = [weakSelf getTimeMinStr:currentTimeValue];
        //剩余时间
        NSString * residueTimeSting=[weakSelf getTimeMinStr:durationValue -currentTimeValue];
        dispatch_async(main_queue, ^{
            if (weakSelf.delegate && [weakSelf.delegate respondsToSelector:@selector(playerPlayTimeSecond:currentStr:withResidueStr:)])
            {
                [weakSelf.delegate playerPlayTimeSecond:currentTimeValue currentStr:currentString withResidueStr:residueTimeSting];
            }
        });
    }];
}
- (void)setStopRefresh
{
    self.stopRefresh = NO;
}
#pragma mark - 播放控制
- (void)playMedia
{
    self.stopRefresh = NO;
    [self mediaPlayerResumeWithZero:NO];
}
- (void)pauseMedia
{
    self.playerState = MCPlayerStatePause;
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(setStopRefresh) object:nil];
    self.stopRefresh = YES;
    [self.player pause];
    dispatch_async(main_queue, ^{
        if (_delegate && [_delegate respondsToSelector:@selector(playerPause)])
        {
            [_delegate playerPause];
        }
    });
}
- (void)stopMedia
{
    [self cancleDownload];
    self.historyTime = 0;
    self.stopRefresh = NO;
    if(self.player)
    {
        [self removePlayerKVO];
    }
    self.playerState = MCPlayerStateStopped;
    dispatch_async(main_queue, ^{
        if (_delegate && [_delegate respondsToSelector:@selector(playerStop)])
        {
            [_delegate playerStop];
        }
    });
}
- (void)failMediaWithMsg:(NSString * )msg
{
    self.historyTime = 0;
    self.stopRefresh = NO;
    [self cancleDownload];
    if(self.player)
    {
        [self removePlayerKVO];
    }
    dispatch_async(main_queue, ^{
        if (_delegate && [_delegate respondsToSelector:@selector(playerFailWithMsg:)])
        {
            [_delegate playerFailWithMsg:msg];
        }
    });
    self.playerState = MCPlayerStateStopped;
    if (self.currentUrl) //播放失败删除 缓存 数据
    {
        NSString *webPath =[MCPath getOfflineMediaTempPathWithUrl:self.currentUrl];
        NSString  * desPath=[MCPath getOfflineMediaDesPathWithUrl:self.currentUrl];
        NSFileManager * fileManager = [NSFileManager defaultManager];
        if ([fileManager fileExistsAtPath:webPath])
        {
            [fileManager removeItemAtPath:webPath error:nil];
        }else if ([fileManager fileExistsAtPath:desPath]) //已下载
        {
            [fileManager removeItemAtPath:desPath error:nil];
        }
    }
}
- (void)playerBuffer
{
    dispatch_async(main_queue, ^{
        if (_delegate && [_delegate respondsToSelector:@selector(playerBuffer)])
        {
            [_delegate playerBuffer];
        }
    });
    self.playerState = MCPlayerStateBuffering;
}
- (void)playerBufferFull
{
    dispatch_async(main_queue, ^{
        if (_delegate && [_delegate respondsToSelector:@selector(playerBufferFull)])
        {
            [_delegate playerBufferFull];
        }
    });
}
//设置播放速率
- (void)setPlayerRate:(CGFloat)value
{
    self.playRate=value;
    
    if(self.playerState == MCPlayerStatePlaying && self.player)
    {
        [self.player setRate:value];
    }
}
//跳到某一时间
- (void)seekToTime:(CGFloat)millisecond
{
    self.historyTime = millisecond;
    if (!self.player)
    {
        return;
    }
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(setStopRefresh) object:nil];
    self.stopRefresh = YES;
    if(millisecond == 0)
    {
        [self mediaPlayerResumeWithZero:YES];
    }else
    {
        [self mediaPlayerResumeWithZero:NO];
    }
    [self performSelector:@selector(setStopRefresh) withObject:nil afterDelay:0.5];
}
-(void)mediaPlayerResumeWithZero:(BOOL)isZero
{
    if (isZero)
    {
        [self.player seekToTime:kCMTimeZero];
    }else if (self.historyTime > 0)
    {
        [self.player seekToTime:CMTimeMake(self.historyTime,1000.0f)];
        self.historyTime = 0;
    }
    //开始播放
    [self.player play];
    
    dispatch_async(main_queue, ^{
        if (_delegate && [_delegate respondsToSelector:@selector(playerPlay)])
        {
            [_delegate playerPlay];
        }
    });
    if (self.playerState == MCPlayerStateBuffering)
    {
        dispatch_async(main_queue, ^{
            if (_delegate && [_delegate respondsToSelector:@selector(playerBuffer)])
            {
                [_delegate playerBuffer];
            }
        });
    }
}
- (CGFloat)getDuration
{
    return CMTimeGetSeconds(self.player.currentItem.duration);
}
- (CGFloat)getCurrentTime
{
    return CMTimeGetSeconds(self.player.currentItem.currentTime);
}
- (void)cancleDownload
{
    if(self.resourceLoader)
    {
        [self.resourceLoader cancel];
        self.resourceLoader = nil;
    }
}

- (BOOL)isPlaying
{
    return self.playerState == MCPlayerStatePlaying || self.playerState == MCPlayerStateBuffering;
}
- (BOOL)isPause
{
    return self.playerState == MCPlayerStatePause;
}
- (NSString *)getTimeMinStr:(NSInteger)second
{
    NSInteger minute =second/60;
    NSString *minuteStr=nil;
    if (minute>=100)
    {
        minuteStr = [NSString stringWithFormat:@"%03d",minute];
    }else
    {
        minuteStr = [NSString stringWithFormat:@"%02d",minute];
    }
    NSString *secondStr = [NSString stringWithFormat:@"%02d",second%60];
    NSString *timeStr = [NSString stringWithFormat:@"%@:%@",minuteStr,secondStr];
    return timeStr;
}

@end

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
#import "MCPath.h"
@interface MCPlayer() <NSURLSessionDelegate,MCResourceLoadDelegate>

/**
 AVPlayer 的时间观察者
 */
@property (weak, nonatomic) id timeObserver;
/**
 本地播放 主要是区分 都是avplayer使用  在线就是下载进度
 */
@property (assign, nonatomic) BOOL isLocal;
/**
 *  播放速率
 */
@property (assign, nonatomic) CGFloat playRate;
@property (assign, nonatomic) BOOL stopRefresh;
@property (retain, nonatomic) MCResourceLoader * resourceLoader;
@property (assign, nonatomic) CGFloat downloadProgress;
@end

@implementation MCPlayer
- (void)dealloc
{
    _delegate = nil;
    [self cancleDownload];
    if(self.player){
        [self removePlayerKVO];
    }
    [[NSNotificationCenter defaultCenter]removeObserver:self];
    NSLog(@"MCAVPlayer 销毁了");
}
+(MCPlayer * )makePlayer
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
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(audioRouteChangeListenerCallback:) name:AVAudioSessionRouteChangeNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterBackground) name:UIApplicationWillResignActiveNotification object:nil];
    }
    return self;
}
- (void)setAudioSession
{
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryPlayback error:nil];
    [audioSession setActive:YES error:nil];
}
- (void)appDidEnterBackground
{
    if (self.backgroundPlay) {
        return;
    }
    if (self.isPlaying) {
        [self pauseMedia];
    }
}

- (void)playMediaWithUrl:(NSString *)url tempPath:(NSString * )tempPath desPath:(NSString * )desPath delegate:(id)delegate
{
    url = [url stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    BOOL isLocal = NO;
    NSFileManager * fileManager = [NSFileManager defaultManager];
    if(!tempPath){
        tempPath =[MCPath getOfflineMediaTempPathWithUrl:url];
    }
    if (!desPath) {
        desPath=[MCPath getOfflineMediaDesPathWithUrl:url];
    }
    if([fileManager fileExistsAtPath:desPath]){
        isLocal = YES;
    }
    [self removePlayerKVO];
    [self cancleDownload];
    [self playerBuffer];
    self.stopRefresh = NO;
    self.delegate = delegate;
    NSURLComponents * components = nil;
    if(isLocal){
        components = [[NSURLComponents alloc] initWithURL:[NSURL fileURLWithPath:desPath] resolvingAgainstBaseURL:NO];
    }else{
        components = [[NSURLComponents alloc] initWithURL:[NSURL URLWithString:url] resolvingAgainstBaseURL:NO];
    }
    components.scheme = KKScheme;
    self.resourceLoader = [[MCResourceLoader alloc]initWithUrl:url desPath:desPath cachePath:tempPath isLocal:isLocal];
    AVURLAsset * asset = [AVURLAsset URLAssetWithURL:components.URL options:nil];
    self.resourceLoader.delegate = self;
    [asset.resourceLoader setDelegate:self.resourceLoader queue:dispatch_get_main_queue()];
    AVPlayerItem * playerItem = [AVPlayerItem playerItemWithAsset:asset];
    if ([[[UIDevice currentDevice]systemVersion] floatValue] >= 9.0){
        playerItem.canUseNetworkResourcesForLiveStreamingWhilePaused = YES;
    }
    playerItem.audioTimePitchAlgorithm = AVAudioTimePitchAlgorithmSpectral;
    self.player = [AVPlayer playerWithPlayerItem:playerItem];
    if ([[[UIDevice currentDevice]systemVersion] floatValue] >= 10.0){
        self.player.automaticallyWaitsToMinimizeStalling = NO;
    }
    //子类使用 - 视频
    [self setPlayerLayer];
    [self addPlayerKVO];
    [self addTimerObserver];
}
- (void)setPlayerLayer{}
#pragma mark - KKResourceLoadDelegate
- (void)downloadProgress:(CGFloat)progress
{
    self.downloadProgress = progress;
}
//拖动slider
- (void)mediaDownloadTaskStateForShowLoading:(BOOL)showLoading
{
    if (showLoading) {
        [self playerBuffer];
    }else{
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(loadingAfterPlayMedia) object:nil];
        [self performSelector:@selector(loadingAfterPlayMedia) withObject:nil afterDelay:0.5];
    }
}
/**
 下载完成
 */
- (void)downloadSuccessWithDesPath:(NSString *)desPath
{
    if (_delegate && [_delegate respondsToSelector:@selector(downloadSuccess)]){
        [_delegate downloadSuccess];
    }
}
- (void)downloadFailMsg:(NSString * )msg;
{
    [self failMediaWithMsg:msg];
}
- (void)loadingAfterPlayMedia
{
    if (self.isPlaying) {
        [self playMedia];
    }
}
- (void)taskCancel
{
    [self failMediaWithMsg:@"播放取消"];
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
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(moviePlayDidEnd:) name:AVPlayerItemDidPlayToEndTimeNotification object:self.player.currentItem];
}
- (void)removePlayerKVO
{
    if(self.player){
    [self.player pause];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:self.player.currentItem];
    [self.player.currentItem removeObserver:self forKeyPath:@"status"];
    [self.player.currentItem removeObserver:self forKeyPath:@"loadedTimeRanges"];
    [self.player.currentItem removeObserver:self forKeyPath:@"playbackBufferEmpty"];
    [self.player.currentItem removeObserver:self forKeyPath:@"playbackBufferFull"];
    [self.player.currentItem removeObserver:self forKeyPath:@"playbackLikelyToKeepUp"];
    [self.player removeObserver:self forKeyPath:@"rate"];
    [self.player removeTimeObserver:self.timeObserver];
    [self.player replaceCurrentItemWithPlayerItem:nil];
    self.player = nil;
    self.timeObserver = nil;
    }
}
- (void)moviePlayDidEnd:(NSNotification * )notification
{
    AVPlayerItem * playerItem = notification.object;
    if(playerItem != self.player.currentItem || self.isPlayEnd) return; //别的播放器调用  self.isPlayEnd 防止调用多次
    CGFloat duration = CMTimeGetSeconds(self.player.currentItem.duration);
    if (duration) {
        dispatch_async(main_queue, ^{
            if (_delegate && [_delegate respondsToSelector:@selector(playerEnd)]){
                [_delegate playerEnd];
            }
        });
    }else{
        [self failMediaWithMsg:@"播放失败"];
    }
    self.isPlayEnd = YES;
    NSLog(@"播放结束 %f",duration);
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
    } else if ([keyPath isEqualToString:@"loadedTimeRanges"]){
        NSTimeInterval timeInterval = [self availableDuration];
        CGFloat currentTime = self.currentTime;
        CGFloat duration = self.duration;
        if ( (self.playerState == MCPlayerStateBuffering) &&  (timeInterval + 8 >= duration || timeInterval - 10 >= currentTime)) //预防网速慢 无法播放 加减时间自己设置
        {
            play = YES;
            NSLog(@"缓冲播放了！！！");
        }
        if (!self.isLocal) { //不是本地
            timeInterval = self.downloadProgress * duration;
        }else{ //本地
            timeInterval = duration;
        }
        dispatch_async(main_queue, ^{
            if (_delegate && [_delegate respondsToSelector:@selector(playerLoadingValue:duration:)]){
                [_delegate playerLoadingValue:timeInterval duration:CMTimeGetSeconds(self.player.currentItem.duration)];
            }
        });
    } else if ([keyPath isEqualToString:@"playbackBufferEmpty"]){
        if(self.player.currentItem.playbackBufferEmpty){
            [self playerBuffer];
            NSLog(@"playbackBufferEmpty");
        }
        
    }else if ([keyPath isEqualToString:@"playbackLikelyToKeepUp"]){
        if (self.player.currentItem.playbackLikelyToKeepUp &&self.playerState == MCPlayerStateBuffering){
            [self playerBufferFull];
            if (self.isPlaying && !self.isPlayEnd) {
                play = YES;
            }
            NSLog(@"playbackLikelyToKeepUp");
        }
    }else if ([keyPath isEqualToString:@"playbackBufferFull"]){
        if(self.player.currentItem.playbackBufferFull){
            [self playerBufferFull];
        }
        NSLog(@"playbackBufferFull");
    }else if ([keyPath isEqualToString:@"rate"]){
        CGFloat rate = self.player.rate;
        if (rate > 0 && self.player){
            if (rate + 0.1 < self.playRate || rate - 0.1 > self.playRate){//播放视频的时候有问题 允许有0.1的误差
                [self.player setRate:self.playRate];
            }
            self.playerState = MCPlayerStatePlaying;
        }    }
    if (play){
        if(self.playerState == MCPlayerStatePause){
            [self.player pause];
        }else{
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
        if (weakSelf.stopRefresh){
            return ;
        }
        dispatch_async(main_queue, ^{
            if (weakSelf.delegate && [weakSelf.delegate respondsToSelector:@selector(playerPlayTimeSecond:)]){
                [weakSelf.delegate playerPlayTimeSecond:weakSelf.currentTime];
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
    if (self.isStop) return;
    self.stopRefresh = NO;
    if (self.player) {
        [self.player play];
    }else{
        return;
    }
    dispatch_async(main_queue, ^{
        if (_delegate && [_delegate respondsToSelector:@selector(playerPlay)]){
            [_delegate playerPlay];
        }
    });
}
- (void)pauseMedia
{
    if(self.isStop) return;
    self.playerState = MCPlayerStatePause;
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(setStopRefresh) object:nil];
    self.stopRefresh = YES;
    if (self.player) {
        [self.player pause];
    }
    dispatch_async(main_queue, ^{
        if (_delegate && [_delegate respondsToSelector:@selector(playerPause)]){
            [_delegate playerPause];
        }
    });
}
- (void)stopMedia
{
    [self cancleDownload];
    [self.player.currentItem cancelPendingSeeks];
    [self.player.currentItem.asset cancelLoading];
    self.stopRefresh = NO;
    [self removePlayerKVO];
    self.playerState = MCPlayerStateStopped;
    dispatch_async(main_queue, ^{
        if (_delegate && [_delegate respondsToSelector:@selector(playerStop)]){
            [_delegate playerStop];
        }
    });
}
- (void)failMediaWithMsg:(NSString * )msg
{
    self.stopRefresh = NO;
    [self cancleDownload];
    if(self.player){
        [self removePlayerKVO];
    }
    dispatch_async(main_queue, ^{
        if (_delegate && [_delegate respondsToSelector:@selector(playerFailWithMsg:)]){
            [_delegate playerFailWithMsg:msg];
        }
    });
    self.playerState = MCPlayerStateStopped;
}
- (void)playerBuffer
{
    dispatch_async(main_queue, ^{
        if (_delegate && [_delegate respondsToSelector:@selector(playerBuffer)]){
            [_delegate playerBuffer];
        }
    });
    self.playerState = MCPlayerStateBuffering;
}
- (void)playerBufferFull
{
    dispatch_async(main_queue, ^{
        if (_delegate && [_delegate respondsToSelector:@selector(playerBufferFull)]){
            [_delegate playerBufferFull];
        }
    });
}
//设置播放速率
- (void)setPlayerRate:(CGFloat)value
{
    self.playRate=value;
    if(self.playerState == MCPlayerStatePlaying){
        if (self.player) {
            [self.player setRate:value];
        }
    }
}
//跳到某一时间
- (void)seekToTime:(CGFloat)seconds
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(setStopRefresh) object:nil];
    self.stopRefresh = YES;
    if (self.player) {
        if (self.player.currentItem.status != AVPlayerItemStatusReadyToPlay) {
            
        }else {
            [self.player seekToTime:CMTimeMakeWithSeconds(seconds,self.player.currentTime.timescale) toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero completionHandler:^(BOOL finished) {
                if (self.stopRefresh) {
                    [self performSelector:@selector(setStopRefresh) withObject:nil afterDelay:0.1];
                }
                self.isPlayEnd = NO;
            }];
        }
        //开始播放
        [self.player play];
    }else{
        return;
    }
    dispatch_async(main_queue, ^{
        if (_delegate && [_delegate respondsToSelector:@selector(playerPlay)]){
            [_delegate playerPlay];
        }
    });
}
- (CGFloat)duration
{
    return CMTimeGetSeconds(self.player.currentItem.duration);
}
- (CGFloat)currentTime
{
    return CMTimeGetSeconds(self.player.currentItem.currentTime);
}
- (void)cancleDownload
{
    if(self.resourceLoader){
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
- (BOOL)isStop
{
    return self.playerState == MCPlayerStateStopped;
}


@end

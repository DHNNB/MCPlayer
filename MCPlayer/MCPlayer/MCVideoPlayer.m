//
//  MCVideoPlayer.m
//  MCPlayer
//
//  Created by M_Code on 2017/6/15.
//  Copyright © 2017年 MC. All rights reserved.
//

#import "MCVideoPlayer.h"
#import <MediaPlayer/MediaPlayer.h>
#import <AVFoundation/AVFoundation.h>

@interface MCVideoPlayer () <UIGestureRecognizerDelegate>
@property (retain, nonatomic) AVPlayerLayer * playerLayer;

/**
 点击手势
 */
@property (retain, nonatomic) UITapGestureRecognizer * tap;
@property (retain, nonatomic) UITapGestureRecognizer * doubleTap;
@property (retain, nonatomic) UIPanGestureRecognizer * pan;
/**
 滑动方向
 */
@property (assign, nonatomic) MCPanDirection panDirection;

/**
 控制音量
 */
@property (retain, nonatomic) UISlider  * volumeViewSlider;

/**
 是音量还是 亮度
 */
@property (assign, nonatomic) BOOL isVolume;

/**
 快进之后的时间
 */
@property (assign, nonatomic) CGFloat sumTime;
@end
@implementation MCVideoPlayer
+(MCVideoPlayer * )makeVideoPlayer
{
    MCVideoPlayer *  media = [[MCVideoPlayer alloc] init];
    return media;
}
- (void)setPlayerLayer
{
    dispatch_async(dispatch_get_main_queue(), ^{
        AVPlayerLayer * layer = [AVPlayerLayer playerLayerWithPlayer:self.player];
        layer.videoGravity = AVLayerVideoGravityResizeAspect;
        layer.frame = self.playerView.bounds;
        [self.playerView.layer insertSublayer:layer atIndex:0];
        if (self.playerLayer) {
            [self.playerLayer removeFromSuperlayer];
            self.playerLayer = nil;
        }
        self.playerLayer = layer;
        if (!_tap && !self.nonuseTap) {
            // 单击
            self.tap = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(oneTapAction:)];
            self.tap.delegate = self.playerView;
            [self.playerView addGestureRecognizer:self.tap];
            // 双击(播放/暂停) 代理都给view  让处理方式在view 中进行
            self.doubleTap = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(doubleTapAction:)];
            self.doubleTap.delegate = self.playerView;
            [self.doubleTap setNumberOfTapsRequired:2];
            [self.playerView addGestureRecognizer:self.doubleTap];
            [self.tap requireGestureRecognizerToFail:self.doubleTap];
            self.pan = [[UIPanGestureRecognizer alloc]initWithTarget:self action:@selector(panDirection:)];
            self.pan.delegate = self.playerView;
            [self.playerView addGestureRecognizer:self.pan];
            [self configureVolume];
        }
        [self.playerView setNeedsLayout];
        [self.playerView layoutIfNeeded];
    });
}
- (void)setPlayerView:(UIView *)playerView
{
    _playerView = playerView;
    if (self.playerLayer) {
        self.playerLayer.frame = self.playerView.bounds;
        [self.playerView.layer insertSublayer:self.playerLayer atIndex:0];
    }
}
/**
 *  获取系统音量
 */
- (void)configureVolume
{
    MPVolumeView *volumeView = [[MPVolumeView alloc] init];
    for (UIView *view in [volumeView subviews]){
        if ([view.class.description isEqualToString:@"MPVolumeSlider"]){
            _volumeViewSlider = (UISlider *)view;
            break;
        }
    }
}
#pragma mark - UIPanGestureRecognizer手势方法
- (void)panDirection:(UIPanGestureRecognizer *)pan
{
    if (self.nonuseTap) {
        return;
    }
    CGPoint locationPoint = [pan locationInView:self.playerView];
    CGPoint veloctyPoint = [pan velocityInView:self.playerView];
    // 判断是垂直移动还是水平移动
    switch (pan.state) {
        case UIGestureRecognizerStateBegan:{ // 开始移动
            // 使用绝对值来判断移动的方向
            CGFloat x = fabs(veloctyPoint.x);
            CGFloat y = fabs(veloctyPoint.y);
            if (x > y) { // 水平移动
                self.panDirection = MCPanDirectionHorizontal;
                // 给sumTime初值
                CMTime time     = self.player.currentTime;
                self.sumTime    = time.value/time.timescale;
                // 暂停
                [self pauseMedia];
            }else if (x < y){ // 垂直移动
                self.panDirection = MCPanDirectionVertical;
                //控制音量
                if (locationPoint.x > self.playerView.bounds.size.width / 2) {
                    self.isVolume = YES;
                }else { //亮度调节
                    self.isVolume = NO;
                }
            }
            break;
        }
        case UIGestureRecognizerStateChanged:{ // 正在移动
            switch (self.panDirection) {
                case MCPanDirectionHorizontal:{
                    [self horizontalMoved:veloctyPoint.x];
                    break;
                }
                case MCPanDirectionVertical:{
                    [self verticalMoved:veloctyPoint.y];
                    break;
                }
                default:
                    break;
            }
            break;
        }
        case UIGestureRecognizerStateEnded:{ // 移动停止
            switch (self.panDirection) {
                case MCPanDirectionHorizontal:{
                    [self seekToTime:self.sumTime];
                    break;
                }
                case MCPanDirectionVertical:{
                    self.isVolume = NO;
                    break;
                }
                default:
                    break;
            }
            break;
        }
        default:
            break;
    }
    if (_playerView && [self.viewDelegate respondsToSelector:@selector(panAction:direciton:withSliderValue:)]) {
        [self.viewDelegate panAction:pan direciton:self.panDirection withSliderValue:self.sumTime];
    }
}
- (void)oneTapAction:(UITapGestureRecognizer * )tap
{
    if (self.nonuseTap) {
        return;
    }
    if (_playerView && [self.viewDelegate respondsToSelector:@selector(oneTapAction:)]) {
        [self.viewDelegate oneTapAction:tap];
    }
}
- (void)doubleTapAction:(UITapGestureRecognizer * )tap
{
    if (self.nonuseTap) {
        return;
    }
    if (_playerView && [self.viewDelegate respondsToSelector:@selector(doubleTapAction:)]) {
        [self.viewDelegate doubleTapAction:tap];
    }
    if (self.lockScreen) {
        return;
    }
    if (self.isPlaying) {
        [self pauseMedia];
    }else if(self.isPause){
        [self playMedia];
    }
}
/**
 *  pan垂直移动的方法
 *
 *  @param value void
 */
- (void)verticalMoved:(CGFloat)value
{
    self.isVolume ? (self.volumeViewSlider.value -= value / 10000) : ([UIScreen mainScreen].brightness -= value / 10000);
}

/**
 *  pan水平移动的方法
 *
 *  @param value void
 */
- (void)horizontalMoved:(CGFloat)value
{
    if (value == 0) {
        return;
    }
    self.sumTime += value / 300.0f;
    CGFloat duration  = [self getDuration];
    if (self.sumTime > duration) {
        self.sumTime = duration;
    }
    if (self.sumTime < 0) {
        self.sumTime = 0;
    }
    NSLog(@"%f",value);
}

- (id)viewDelegate
{
    return _playerView;
}

@end

//
//  MCVideoPlayer.h
//  MCPlayer
//
//  Created by M_Code on 2017/6/15.
//  Copyright © 2017年 MC. All rights reserved.
//

#import "MCPlayer.h"

typedef NS_ENUM(NSInteger, MCPanDirection){
    MCPanDirectionHorizontal, // 横向移动
    MCPanDirectionVertical    // 纵向移动
};


/**
 
 */
@protocol MCVideoPlayerDelegate <NSObject>
@optional
- (void)oneTapAction:(UITapGestureRecognizer * )tap;
- (void)doubleTapAction:(UITapGestureRecognizer * )tap;

/**
 滑动手势
 @param pan 根据滑动状态做些操作
 @param panDiretion 滑动方向
 */
- (void)panAction:(UIPanGestureRecognizer *)pan direciton:(MCPanDirection)panDiretion withSliderValue:(CGFloat)value;
@end
/**
 继承于 KKAVPlayer 来播放视频
 */
@interface MCVideoPlayer : MCPlayer

/**
 将视频放在这个view上边(相关操作也在view上这样灵活)  必须传入
 */
@property (retain , nonatomic) UIView * playerView;
/**
 一些 UI操作
 */
@property (weak, nonatomic) id<MCVideoPlayerDelegate> viewDelegate;

/**
 是否禁用手势 默认NO
 */
@property (assign, nonatomic) BOOL nonuseTap;

/**
 锁屏了 手势操作
 */
@property (assign, nonatomic) BOOL lockScreen;
+(MCVideoPlayer * )makeVideoPlayer;
@end

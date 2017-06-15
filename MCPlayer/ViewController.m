//
//  ViewController.m
//  MCPlayer
//
//  Created by M_Code on 2017/3/30.
//  Copyright © 2017年 MC. All rights reserved.
//

#import "ViewController.h"
#import "MCPlayer.h"
#import "MCVideoPlayer.h"
@interface ViewController () <MCPlayerDelegate>
@property (weak, nonatomic) IBOutlet UISlider *slider;
@property (weak, nonatomic) IBOutlet UILabel *currentTimeLabel;
@property (weak, nonatomic) IBOutlet UILabel *durationLabel;
@property (weak, nonatomic) IBOutlet UIView *playerView;
@property (retain, nonatomic) MCPlayer * palyer;
@property (retain, nonatomic) MCVideoPlayer * videoPlayer;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
- (IBAction)play:(id)sender {
    NSString * url = @"https://891622172.wodemo.net/down/20170330/435289/胡歌－忘记时间【仙剑奇侠传三片尾曲】.mp3" ;
    [self.palyer playMediaWithUrl:url tempPath:nil desPath:nil delegate:self];
}
- (IBAction)playVideo:(id)sender {
    NSString * url = @"https://he.yinyuetai.com/uploads/videos/common/52CB015AA5D0A2330C59C0600469CA8F.mp4?sc=79307a33525dba42&br=3149&vid=2809987&aid=7744&area=ML&vst=0" ;
    [self.videoPlayer playMediaWithUrl:url tempPath:nil desPath:nil delegate:nil];
}
- (void)playerPlayTimeSecond:(CGFloat)seconds currentStr:(NSString *)currentString withResidueStr:(NSString *)residueStr
{
    self.currentTimeLabel.text = currentString;
    self.durationLabel.text = residueStr;
    self.slider.value = seconds;
}
- (void)playerLoadingValue:(double)cache duration:(CGFloat)duration
{
    self.slider.maximumValue = duration;
}
- (MCPlayer *)palyer
{
    if (!_palyer){
        _palyer = [MCPlayer makePlayer];
        _palyer.supportRate = NO; // 音频 支持这个 会在下载完成之后马上换个本地播放器播放
        _palyer.backgroundPlay = NO;//后台播放
    }
    return _palyer;
}
- (MCVideoPlayer * )videoPlayer
{
    if (!_videoPlayer) {
        _videoPlayer = [MCVideoPlayer makeVideoPlayer];
        _videoPlayer.playerView = self.playerView;
    }
    return _videoPlayer;
}
@end

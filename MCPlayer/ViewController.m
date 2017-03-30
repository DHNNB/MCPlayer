//
//  ViewController.m
//  MCPlayer
//
//  Created by M_Code on 2017/3/30.
//  Copyright © 2017年 MC. All rights reserved.
//

#import "ViewController.h"
#import "MCPlayer.h"
@interface ViewController () <MCPlayerDelegate>
@property (weak, nonatomic) IBOutlet UISlider *slider;
@property (weak, nonatomic) IBOutlet UILabel *currentTimeLabel;
@property (weak, nonatomic) IBOutlet UILabel *durationLabel;
@property (retain, nonatomic) MCPlayer * palyer;
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
    [self.palyer playerWithUrl:[url stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]delegate:self];
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
    if (!_palyer)
    {
        _palyer = [MCPlayer makeMCPlayer];
    }
    return _palyer;
}
@end

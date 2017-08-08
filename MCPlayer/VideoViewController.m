//
//  VideoViewController.m
//
//
//  Created by M_Code on 2017/6/15.
//
//

#import "VideoViewController.h"
#import "MCVideoPlayer.h"
#import "VideoCell.h"
#import "MCVideoModel.h"
@interface VideoViewController ()
@property (retain, nonatomic) MCVideoPlayer * videoPlayer;
@property (weak, nonatomic) IBOutlet UITableView *videoTableView;
@property (retain, nonatomic) NSMutableArray * dataArray;
@property (retain, nonatomic) AVAssetImageGenerator * generator;
@property (assign, nonatomic) NSInteger currentIndex;
@property (retain, nonatomic) UIView * playView;
@end

@implementation VideoViewController
- (void)dealloc
{
    
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self fetchData];
}

- (void)fetchData
{
    NSString *path = [[NSBundle mainBundle] pathForResource:@"data" ofType:@"plist"];
    NSArray * array = [NSArray arrayWithContentsOfFile:path];
    for (NSDictionary * dict in array) {
        MCVideoModel * model = [[MCVideoModel alloc]init];
        for (NSString * key in dict) {
            [model setValue:dict[key] forKey:key];
        }
        [self.dataArray addObject:model];
    }
    [self.videoTableView reloadData];
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 180;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.dataArray.count;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString * cellID = @"VideoCell";
    VideoCell * cell = [tableView dequeueReusableCellWithIdentifier:cellID];
    if (!cell){
        UINib * xib = [UINib nibWithNibName:cellID bundle:nil];
        [tableView registerNib:xib forCellReuseIdentifier:cellID];
        cell = [tableView dequeueReusableCellWithIdentifier:cellID];
    }
    MCVideoModel * model = self.dataArray[indexPath.row];
    cell.videoName.text = model.name;
    cell.playerImg.image = model.image;
    if (indexPath.row == self.currentIndex) {
        self.videoPlayer.playerView = cell.playerView;
    }else{
        for ( CALayer * layer  in  cell.playerView.layer.sublayers) {
            if ([layer isKindOfClass:[AVPlayerLayer class]]) {
                [layer removeFromSuperlayer];
                break;
            }
        }
    }
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    MCVideoModel  * model = self.dataArray[indexPath.row];
    VideoCell * cell = [tableView cellForRowAtIndexPath:indexPath];
    cell.playerImg.hidden = YES;
    self.videoPlayer.playerView = cell.playerView;
    self.currentIndex = indexPath.row;
    [self.videoPlayer playMediaWithUrl:model.url tempPath:nil desPath:nil delegate:nil];
    
}
- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (self.videoPlayer.isStop) {
        return;
    }
    VideoCell * cell = [self.videoTableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:self.currentIndex inSection:0]];
    BOOL visble = [self.videoTableView.visibleCells containsObject:cell];
    if (!visble) {
        self.videoPlayer.playerView = self.playView;
        self.playView.hidden = NO;
    }else{
        self.videoPlayer.playerView = cell.playerView;
        self.playView.hidden = YES;
    }
}
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
- (void)playViewPan:(UIPanGestureRecognizer * )pan
{
    CGPoint location = [pan locationInView:pan.view.superview];
    self.playView.center = location;
}

- (MCVideoPlayer * )videoPlayer
{
    if (!_videoPlayer) {
        _videoPlayer = [MCVideoPlayer makeVideoPlayer];
        _videoPlayer.nonuseTap = YES;//是否禁用手势
    }
    return _videoPlayer;
}
- (NSMutableArray * )dataArray
{
    if (!_dataArray) {
        _dataArray = [[NSMutableArray alloc]init];
    }
    return _dataArray;
}
- (UIView * )playView
{
    if (!_playView) {
        _playView = [[UIView alloc]initWithFrame:CGRectMake(0, 0, 200, 200)];
        _playView.hidden = YES;
        [self.view addSubview:_playView];
        UIPanGestureRecognizer * pan = [[UIPanGestureRecognizer alloc]initWithTarget:self action:@selector(playViewPan:)];
        [_playView addGestureRecognizer:pan];
    }
    return _playView;
}
@end

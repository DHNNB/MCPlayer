//
//  MCResourceLoader.h
//  MCPlayer
//
//  Created by M_Code on 2017/3/30.
//  Copyright © 2017年 MC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@protocol MCResourceLoadDelegate <NSObject>

@optional
- (void)downloadFailMsg:(NSString * )msg;
@end
static NSString * KKScheme = @"MCStreaming";

@interface MCResourceLoader : NSObject <AVAssetResourceLoaderDelegate>
@property (weak, nonatomic) id<MCResourceLoadDelegate> delegate;
- (instancetype)initWithUrl:(NSString * )url DesPath:(NSString * )desPath cachePath:(NSString * )cachePath;
- (void)cancel;

@end

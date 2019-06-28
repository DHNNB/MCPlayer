//
//  MCPath.h
//  MCPlayer
//
//  Created by M_Code on 2017/3/30.
//  Copyright © 2017年 MC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MCPath : NSObject
+ (NSString *)getOfflineMediaTempPathWithUrl:(NSString *)url;
+ (NSString *)getOfflineMediaDesPathWithUrl:(NSString *)url;

@end

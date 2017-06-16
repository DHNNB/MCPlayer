//
//  MCPath.m
//  MCPlayer
//
//  Created by M_Code on 2017/3/30.
//  Copyright © 2017年 MC. All rights reserved.
//

#import "MCPath.h"
#import "NSString+MD5.h"
@implementation MCPath
+ (NSString *)documentPath
{
    return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
}

+ (NSString *)documentPath:(NSString *)fileName
{
    return [[self documentPath] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@",fileName]];
}
//临时 缓存路径
+ (NSString *)getOfflineMediaTempPathWithUrl:(NSString *)url
{
    NSString * fileName =  [NSString stringWithFormat:@"%@.%@",[url MD5],[url pathExtension]];
    NSString * path = [self documentPath:@"tmpFile"];
    NSFileManager * fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:path])
    {
        [fileManager createDirectoryAtPath:path withIntermediateDirectories:TRUE attributes:nil error:nil];
    }
    return [path stringByAppendingPathComponent:fileName];
}
//  缓存最终文件夹
+ (NSString *)getOfflineMediaDesPathWithUrl:(NSString *)url
{
    NSString * fileName =  [NSString stringWithFormat:@"%@.%@",[url MD5],[url pathExtension]];
    NSString * path =[self documentPath:@"MediaFile"];
    NSFileManager * fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:path])
    {
        [fileManager createDirectoryAtPath:path withIntermediateDirectories:TRUE attributes:nil error:nil];
    }
    return [path stringByAppendingPathComponent:fileName];
}

@end

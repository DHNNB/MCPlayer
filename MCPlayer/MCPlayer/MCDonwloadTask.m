//
//  MCDonwloadTask.m
//  MCPlayer
//
//  Created by M_Code on 2017/6/15.
//  Copyright © 2017年 MC. All rights reserved.
//

#define global_quque    dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)

#define main_queue      dispatch_get_main_queue()

#import "MCDonwloadTask.h"
#include <sys/param.h>
#include <sys/mount.h>
@interface MCDonwloadTask () <NSURLSessionDelegate>
@property (retain, nonatomic) NSURL * url;
@property (assign, nonatomic) BOOL isOnce;
@property (retain, nonatomic) NSFileHandle * fileHandle;
@property (copy, nonatomic) NSString * tempPath;
@property (copy, nonatomic) NSString * desPath;
@property (retain, nonatomic) NSURLSession * session;
@property (retain, nonatomic) NSURLSessionDataTask * sessionDataTask;
@property (assign, nonatomic) NSInteger taskTimes;
@property (assign, nonatomic) NSInteger limitBuffer;
@end

@implementation MCDonwloadTask
- (void)dealloc
{
    _delegate = nil;
    if (_sessionDataTask) {
        [_sessionDataTask cancel];
    }
    if (_fileHandle) {
        [self.fileHandle closeFile];
    }
    [[NSNotificationCenter defaultCenter]removeObserver:self];
}
- (instancetype)initWithTempPath:(NSString * )tempPath desPath:(NSString * )desPath
{
    self = [super init];
    if (self) {
        _tempPath =  tempPath;
        _desPath = desPath;
        if ([[NSFileManager defaultManager] fileExistsAtPath:tempPath]) {
            [[NSFileManager defaultManager] removeItemAtPath:tempPath error:nil];
            [[NSFileManager defaultManager] createFileAtPath:tempPath contents:nil attributes:nil];
        } else {
            [[NSFileManager defaultManager] createFileAtPath:tempPath contents:nil attributes:nil];
        }
    }
    return self;
}
- (void)setUrl:(NSURL *)url offset:(NSUInteger)offset
{
    if (self.sessionDataTask) {
        [self.sessionDataTask cancel];
        self.sessionDataTask = nil;
    }
    _url = url;
    _offset = offset;
    self.downLoadingOffset = 0;
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:15.0];
    [request addValue:[NSString stringWithFormat:@"bytes=%ld-",(unsigned long)offset] forHTTPHeaderField:@"Range"];
    self.sessionDataTask = [self.session dataTaskWithRequest:request];
    [self.sessionDataTask resume];
}

- (void)cancel
{
    _delegate = nil;
    if (_session) {
        [_session invalidateAndCancel];
        _session = nil;
    }
    if (_sessionDataTask) {
        [self.sessionDataTask cancel];
        self.sessionDataTask = nil;
    }
}
#pragma mark -  NSURLConnectionDelegate
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler
{
    self.isDownloadFinished = NO;
    self.isOnce = NO;
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)response;
    self.videoLength = [[[httpResponse.allHeaderFields[@"Content-Range"] componentsSeparatedByString:@"/"] lastObject] longLongValue];
    if (self.videoLength == 0) {
        self.videoLength = response.expectedContentLength;
    }
    self.mimeType = response.MIMEType;
    if (![self checkDiskFreeSize:self.videoLength]){
        completionHandler(NSURLSessionResponseCancel);
        //设备存储空间不足
        return;
    }
    dispatch_async(main_queue, ^{
        if ([self.delegate respondsToSelector:@selector(didReceiveResponseWithtask:length:mimeType:)]) {
            [self.delegate didReceiveResponseWithtask:self length:self.videoLength mimeType:self.mimeType];
        }
    });
    //如果建立第二次请求，先移除原来文件，再创建新的
    if (self.taskTimes >= 1) {
        [[NSFileManager defaultManager] removeItemAtPath:self.tempPath error:nil];
        [[NSFileManager defaultManager] createFileAtPath:self.tempPath contents:nil attributes:nil];
    }
    self.taskTimes ++;
    self.fileHandle = [NSFileHandle fileHandleForWritingAtPath:self.tempPath];
    self.limitBuffer = 0;
    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
    [self.fileHandle seekToEndOfFile];
    [self.fileHandle writeData:data];
    NSUInteger len = data.length;
    self.downLoadingOffset += len;
    self.limitBuffer += len;
    if (self.limitBuffer > 1024 * 15) { //大于15kb 在调用吧 太频繁 -->
        self.limitBuffer = 0;
        if ([self.delegate respondsToSelector:@selector(didReceiveVideoDataWithTask:cacheProgress:)]) {
            [self.delegate didReceiveVideoDataWithTask:self cacheProgress:(double)(self.downLoadingOffset + self.offset)/self.videoLength];
        }
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionDataTask *)task didCompleteWithError:(nullable NSError *)error
{
    if (error) {
        if (error.code == -999) {//主动取消的
            return;
        }else if (error.code == -1001 && !self.isOnce) {
            self.isOnce = YES;
            [self setUrl:_url offset:_offset];
        }else{
            NSString * str = @"加载失败";
            switch (error.code) {
                case -1001:
                    str = @"连接超时";
                    break;
                case -1009:
                    str = @"网络异常";
                    break;
                case -1003:
                    str = @"找不到服务器";
                    break;
                case -1004:
                    str = @"服务器错误";
                    break;
                default:
                    break;
            }
            dispatch_async(main_queue, ^{
                if ([self.delegate respondsToSelector:@selector(didFailLoadingWithTask:WithErrorStr:)]) {
                    [self.delegate didFailLoadingWithTask:self WithErrorStr:str];
                }
            });
        }
    }else{
        NSDictionary *fileAttributes=[[NSFileManager defaultManager] attributesOfItemAtPath:self.tempPath error:nil];
        long long len =[[fileAttributes objectForKey:NSFileSize] longLongValue];
        if (self.videoLength == len && len && self.videoLength) {
            BOOL isSuccess = [[NSFileManager defaultManager] copyItemAtPath:self.tempPath toPath:self.desPath error:nil];
            if (isSuccess) {
                self.isDownloadFinished = YES;
                NSLog(@"下载完成");
                dispatch_async(main_queue, ^{
                    if ([self.delegate respondsToSelector:@selector(didFinishLoadingWithTask:)]) {
                        [self.delegate didFinishLoadingWithTask:self];
                    }
                });
            }else{
                NSLog(@"移动失败");
            }
        }
    }
    if (self.limitBuffer > 0) {
        self.limitBuffer = 0;
        if ([self.delegate respondsToSelector:@selector(didReceiveVideoDataWithTask:cacheProgress:)]) {
            [self.delegate didReceiveVideoDataWithTask:self cacheProgress:(double)(self.downLoadingOffset + self.offset)/self.videoLength];
        }
    }
}
#pragma mark - 剩余空间
- (BOOL)checkDiskFreeSize:(long long)length{
    unsigned long long freeDiskSize = [self getDiskFreeSize];
    if (freeDiskSize < length + 1024 * 1024 * 100){
        return NO;
    }
    return YES;
}
- (unsigned long long)getDiskFreeSize
{
    struct statfs buf;
    unsigned long long freespace = -1;
    if(statfs("/var", &buf) >= 0){
        freespace = (long long)(buf.f_bsize * buf.f_bavail);
    }
    return freespace;
}
- (NSURLSession *)session {
    if (!_session) {
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
        _session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:[KKDownloadOperationQueue shareQueue].queue];
    }
    return _session;
}
@end
@implementation KKDownloadOperationQueue

+ (KKDownloadOperationQueue * )shareQueue
{
    static dispatch_once_t onceToken;
    static KKDownloadOperationQueue * queue;
    dispatch_once(&onceToken, ^{
        queue = [[KKDownloadOperationQueue alloc]init];
    });
    return queue;
}
- (instancetype)init
{
    self = [super init];
    if (self) {
        _queue = [[NSOperationQueue alloc]init];
    }
    return self;
}
@end

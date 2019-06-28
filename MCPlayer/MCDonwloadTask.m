//
//  MCDonwloadTask.m
//  MCPlayer
//
//  Created by M_Code on 2017/6/15.
//  Copyright © 2017年 MC. All rights reserved.
//

#import "MCDonwloadTask.h"
#include <sys/param.h>
#include <sys/mount.h>
#import "MCConst.h"
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
/**
 失败的 第-次  第二次不删除文件 数据是连续的
 */
@property (assign, nonatomic) NSInteger isContinue;

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
    }else{
        dispatch_async(main_queue, ^{
            [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(requestAgain) object:nil];
        });
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
    if (self.limitBuffer > 1024 * 30) { //大于30kb 在调用吧 太频繁 -->
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
            dispatch_async(main_queue, ^{
                [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(requestAgain) object:nil];
            });
            return;
        }else{
            dispatch_async(main_queue, ^{
                [self performSelector:@selector(requestAgain) withObject:nil afterDelay:5];
            });
            dispatch_async(main_queue, ^{
                if ([self.delegate respondsToSelector:@selector(didFailLoadingWithTask:WithError:)]) {
                    [self.delegate didFailLoadingWithTask:self WithError:error];
                }
            });
        }
    }else{
        dispatch_async(main_queue, ^{
            [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(requestAgain) object:nil];
        });
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
- (void)requestAgain
{
    if (self.downLoadingOffset) {
        NSLog(@"连续的");
        self.taskTimes = 0;//不删除 临时文件 因为上次请求成功 下载数据是连接的
        self.isContinue = YES;
        [self setUrl:_url offset:self.downLoadingOffset + self.offset + 1];
    }else{
        // 这个有两种情况 1.数据不连续的 不做处理 2.数据连续的（走完上边的downLoadingOffset 不为0 失败 来的下边）
        if (self.isContinue) {
            self.taskTimes = 0;
            NSLog(@"连续的isContinue");
        }else{
            NSLog(@"不连续的");
        }
        [self setUrl:_url offset:self.offset];
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
        _session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:[MCDownloadOperationQueue shareQueue].queue];
    }
    return _session;
}
@end
@implementation MCDownloadOperationQueue

+ (MCDownloadOperationQueue * )shareQueue
{
    static dispatch_once_t onceToken;
    static MCDownloadOperationQueue * queue;
    dispatch_once(&onceToken, ^{
        queue = [[MCDownloadOperationQueue alloc]init];
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

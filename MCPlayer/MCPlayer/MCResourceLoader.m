//
//  MCResourceLoader.m
//  MCPlayer
//
//  Created by M_Code on 2017/3/30.
//  Copyright © 2017年 MC. All rights reserved.
//
#define global_quque    dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
#define main_queue      dispatch_get_main_queue()

#import "MCResourceLoader.h"
#import "MCOperation.h"
#import <MobileCoreServices/MobileCoreServices.h>
@interface MCResourceLoader () <MCDownloadDelegate>
@property (retain, nonatomic) NSMutableArray * loadingRequestArray;
@property (retain, nonatomic) MCOperation * operation;
@property (copy, nonatomic) NSString * cachePath;
@property (copy, nonatomic) NSString * url;
@property (copy, nonatomic) NSString * desPath;
@property (assign, nonatomic) BOOL isLocal;
@property (assign, nonatomic) long long localCurrentLength;

@end
@implementation MCResourceLoader
- (instancetype)initWithUrl:(NSString * )url DesPath:(NSString * )desPath cachePath:(NSString * )cachePath isLocal:(BOOL)isLocal
{
    self = [super init];
    if (self) {
        _cachePath = cachePath;
        _desPath = desPath;
        _url = url;
        _isLocal = isLocal;
        if (isLocal) {
            _localCurrentLength = [[NSData dataWithContentsOfFile:desPath] length];
        }
    }
    return self;
}
- (void)start
{
    dispatch_async(global_quque, ^{
        if(!self.operation)
        {
            self.operation = [[MCOperation alloc]initWithUrl:self.url tempPath:self.cachePath desPath:self.desPath delegate:self isAgain:NO isCopy:NO];
            [self.operation start];
        }
    });
}
- (void)cancel
{
    [self.operation cancleDownload];
    self.operation = nil;
    self.delegate = nil;
    [self.loadingRequestArray removeAllObjects];
}
#pragma mark - AVAssetResourceLoaderDelegate
- (BOOL)resourceLoader:(AVAssetResourceLoader *)resourceLoader shouldWaitForLoadingOfRequestedResource:(AVAssetResourceLoadingRequest *)loadingRequest
{
    NSURL *resourceURL = [loadingRequest.request URL];
    if ([resourceURL.scheme isEqualToString:KKScheme] && loadingRequest)
    {
        NSLog(@"找到了");
        [self.loadingRequestArray addObject:loadingRequest];
        if (self.isLocal) {
            [self setResourceLoadingRequest:loadingRequest currentLength:self.localCurrentLength withTotalLength:self.localCurrentLength];
        }else{
            if (self.operation) {
                //只开一条线程下载 （如果大音频有需求 支持seek 可根据Offset 完善，小音频这样很简单 直接下载完成 不用过多的处理）
                if ([self.operation getCurrentLength] >0 && [self.operation getTotalLength]>0){
                    [self resourceLoadingRequestForDataWith:self.operation];
                }
            }
            [self start];
        }
    }
    return YES;
}

- (void)resourceLoader:(AVAssetResourceLoader *)resourceLoader didCancelLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest
{
    NSLog(@"didCancelLoadingRequest");
    [self.loadingRequestArray removeObject:loadingRequest];
}
#pragma mark - KKDownloadDelegate

- (void)donwloadProgress:(CGFloat)progress withOperation:(MCOperation * )operation
{
    [self resourceLoadingRequestForDataWith:operation];
}

- (void)resourceLoadingRequestForDataWith:(MCOperation * )operation
{
    @synchronized (self.loadingRequestArray)
    {
        [self.loadingRequestArray enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            AVAssetResourceLoadingRequest * loadingRequest = obj;
            [self setResourceLoadingRequest:loadingRequest currentLength:[operation getCurrentLength] withTotalLength:[operation getTotalLength]];
        }];
    }
}

- (void)setResourceLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest currentLength:(long long)currentLength withTotalLength:(long long)totalLength
{
    NSString *fileExtension = [self.desPath pathExtension];
    NSString *UTI = (__bridge_transfer NSString *)UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)fileExtension, NULL);
    //文件类型
    CFStringRef contentType = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, (__bridge CFStringRef)(UTI), NULL);
    loadingRequest.contentInformationRequest.contentType = CFBridgingRelease(contentType);
    //数据处理
    loadingRequest.contentInformationRequest.byteRangeAccessSupported = YES;
    loadingRequest.contentInformationRequest.contentLength = totalLength;
    NSUInteger startOffset = loadingRequest.dataRequest.requestedOffset;
    if (loadingRequest.dataRequest.currentOffset != 0)
    {
        startOffset = loadingRequest.dataRequest.currentOffset;
    }
    NSUInteger canReadLength = currentLength - startOffset;
    NSUInteger respondLength = MIN(canReadLength, loadingRequest.dataRequest.requestedLength);
    [loadingRequest.dataRequest respondWithData:[self readTempFileDataWithOffset:startOffset length:respondLength]];
    NSUInteger endOffset = loadingRequest.dataRequest.requestedOffset + loadingRequest.dataRequest.requestedLength;
    if (currentLength >= endOffset)
    {
        [loadingRequest finishLoading];
        [self.loadingRequestArray removeObject:loadingRequest];
        NSLog(@"完成了  ");
    }
}
#pragma mark - KKDownloadDelegate
- (void)downloadFailMsg:(NSString *)msg withOperation:(MCOperation * )operation;
{
    if (_delegate && [_delegate respondsToSelector:@selector(downloadFailMsg:)])
    {
        [_delegate downloadFailMsg:msg];
    }
    [self.loadingRequestArray removeAllObjects];
    self.operation = nil;
}
- (void)downloadSuccessDesPath:(NSString * )desPath withOperation:(MCOperation * )operation;
{
    [self resourceLoadingRequestForDataWith:operation];
}
- (NSData *)readTempFileDataWithOffset:(NSUInteger)offset length:(NSUInteger)length
{
    NSString * path = self.cachePath;
    if (self.operation.movePathSuccess || self.isLocal) //下载完成 - 文件移动完成 获取剩余数据
    {
        path = self.desPath;
    }
    NSFileHandle * handle = [NSFileHandle fileHandleForReadingAtPath:path];
    [handle seekToFileOffset:offset];
    return [handle readDataOfLength:length];
}

- (NSMutableArray * )loadingRequestArray
{
    if (!_loadingRequestArray)
    {
        _loadingRequestArray = [[NSMutableArray alloc]init];
    }
    return _loadingRequestArray;
}

@end

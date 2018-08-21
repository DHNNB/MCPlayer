//
//  MCResourceLoader.m
//  MCPlayer
//
//  Created by M_Code on 2017/3/30.
//  Copyright © 2017年 MC. All rights reserved.
//

#import "MCResourceLoader.h"
#import "MCDonwloadTask.h"
#import <MobileCoreServices/MobileCoreServices.h>
@interface MCResourceLoader () <MCDonwloadTaskDelegate>
@property (retain, nonatomic) NSMutableArray * loadingRequestArray;
@property (retain, nonatomic) MCDonwloadTask * task;
@property (copy, nonatomic) NSString * cachePath;
@property (copy, nonatomic) NSString * url;
@property (copy, nonatomic) NSString * desPath;
@property (assign, nonatomic) BOOL isLocal;
@property (retain, nonatomic) NSFileHandle * readFileHandle;
/**
 二次加载是否显示loading
 */
@property (assign, nonatomic) BOOL showLoading;

@end
@implementation MCResourceLoader
- (void)dealloc
{
    _delegate = nil;
    NSLog(@"KKResourceLoader 销毁了");
    if(_task){
        [self.task cancel];
    }
    [self.loadingRequestArray removeAllObjects];
}
- (instancetype)initWithUrl:(NSString * )url desPath:(NSString * )desPath cachePath:(NSString * )cachePath isLocal:(BOOL)isLocal
{
    self = [super init];
    if (self) {
        _cachePath = cachePath;
        _desPath = desPath;
        _url = url;
        _isLocal = isLocal;
    }
    return self;
}
- (void)fillInContentInformation:(AVAssetResourceLoadingContentInformationRequest *)contentInformationRequest
{
    NSString *mimeType = self.task.mimeType;
    CFStringRef contentType = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, (__bridge CFStringRef)(mimeType), NULL);
    contentInformationRequest.byteRangeAccessSupported = YES;
    contentInformationRequest.contentType = CFBridgingRelease(contentType);
    contentInformationRequest.contentLength = self.task.videoLength;
}

- (void)processPendingRequests
{
    @synchronized (self.loadingRequestArray) {
        [self.loadingRequestArray   enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            AVAssetResourceLoadingRequest *loadingRequest = obj;
            [self fillInContentInformation:loadingRequest.contentInformationRequest];        BOOL didRespondCompletely = [self respondWithDataForRequest:loadingRequest.dataRequest];
            if (didRespondCompletely) {
                [loadingRequest finishLoading];
                [self.loadingRequestArray removeObject:obj];
            }
        }];
    }
}

- (BOOL)respondWithDataForRequest:(AVAssetResourceLoadingDataRequest *)dataRequest
{
    long long startOffset = dataRequest.requestedOffset;
    if (dataRequest.currentOffset != 0) {
        startOffset = dataRequest.currentOffset;
    }
    if ((self.task.offset +self.task.downLoadingOffset) < startOffset){
        return NO;
    }
    if (startOffset < self.task.offset) {
        return NO;
    }
    NSInteger offset = (NSInteger)startOffset - self.task.offset;
    NSUInteger canReadLength = self.task.downLoadingOffset - ((NSInteger)startOffset - self.task.offset);
    NSUInteger respondLength = MIN((NSUInteger)dataRequest.requestedLength, canReadLength);
        NSData * filedata = [NSData dataWithContentsOfURL:[NSURL fileURLWithPath:self.cachePath] options:NSDataReadingMappedIfSafe error:nil];
    NSRange range = NSMakeRange(offset,respondLength);
    long long len = filedata.length;
    if (len <= offset){
        return NO;
    }else if (len < offset + respondLength) {
        range = NSMakeRange(offset,len - offset);
    }
    NSData * data = [filedata subdataWithRange:range];
    [dataRequest respondWithData:data];
    long long endOffset = startOffset + dataRequest.requestedLength;
    BOOL didRespondFully = (self.task.offset + self.task.downLoadingOffset) >= endOffset;
    return didRespondFully;
    
}
- (BOOL)resourceLoader:(AVAssetResourceLoader *)resourceLoader shouldWaitForLoadingOfRequestedResource:(AVAssetResourceLoadingRequest *)loadingRequest
{
    NSURL *resourceURL = [loadingRequest.request URL];
    if ([resourceURL.scheme isEqualToString:KKScheme]) {
        [self.loadingRequestArray addObject:loadingRequest];
        [self dealWithLoadingRequest:loadingRequest];
        return YES;
    }
    return NO;
}
- (void)dealWithLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest
{
    @synchronized (self) {
        NSRange range = NSMakeRange((NSUInteger)loadingRequest.dataRequest.currentOffset, NSUIntegerMax);
        if (self.isLocal || self.task.isDownloadFinished) {
            NSDictionary *fileAttributes=[[NSFileManager defaultManager] attributesOfItemAtPath:self.desPath error:nil];
            long long localCurrentLength =[[fileAttributes objectForKey:NSFileSize] longLongValue];
            @try {
                [self setResourceLoadingRequest:loadingRequest currentLength:localCurrentLength withTotalLength:localCurrentLength];
            } @catch (NSException *exception) {
                NSLog(@"setResourceLoadingRequest crash");
            }
        }else{
            if (self.task.downLoadingOffset > 0) {
                [self processPendingRequests];
            }
            NSURL * URL = [NSURL URLWithString:self.url];
            if (!self.task) {
                self.task = [[MCDonwloadTask alloc] initWithTempPath:self.cachePath desPath:self.desPath];
                self.task.delegate = self;
                [self.task setUrl:URL offset:0];
            } else {
                // 如果新的rang的起始位置比当前缓存的位置还大380k，则重新按照range请求数据
                if (self.task.offset + self.task.downLoadingOffset + 1024 * 380 < range.location || range.location < self.task.offset) {
                    dispatch_async(main_queue, ^{
                        self.showLoading = YES;
                        if([self.delegate respondsToSelector:@selector(mediaDownloadTaskStateForShowLoading:)]){
                            [self.delegate mediaDownloadTaskStateForShowLoading:YES];
                        }
                    });
                    [self.task setUrl:URL offset:range.location];
                }
            }
        }
    }
}

- (BOOL)setResourceLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest currentLength:(long long)currentLength withTotalLength:(long long)totalLength
{
    NSString *fileExtension = [self.desPath pathExtension];
    NSString *UTI = (__bridge_transfer NSString *)UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)fileExtension, NULL);
    CFStringRef contentType = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, (__bridge CFStringRef)(UTI), NULL);
    loadingRequest.contentInformationRequest.contentType = CFBridgingRelease(contentType);
    loadingRequest.contentInformationRequest.byteRangeAccessSupported = YES;
    loadingRequest.contentInformationRequest.contentLength = totalLength;
    long long startOffset = loadingRequest.dataRequest.requestedOffset;
    if (currentLength <= startOffset) {
        return NO;
    }
    if (loadingRequest.dataRequest.currentOffset != 0){
        startOffset = loadingRequest.dataRequest.currentOffset;
    }
    long long canReadLength = currentLength - startOffset;
    long long respondLength = MIN(canReadLength, loadingRequest.dataRequest.requestedLength);
    long long endOffset = loadingRequest.dataRequest.requestedOffset + loadingRequest.dataRequest.requestedLength;
    NSData * filedata = [NSData dataWithContentsOfURL:[NSURL fileURLWithPath:self.desPath] options:NSDataReadingMappedIfSafe error:nil];
    NSRange range = NSMakeRange((NSUInteger)startOffset,respondLength);
    NSData * data = [filedata subdataWithRange:range];
    [loadingRequest.dataRequest respondWithData:data];
    if (currentLength >= endOffset){
        [loadingRequest finishLoading];
        @synchronized (self.loadingRequestArray) {
            [self.loadingRequestArray removeObject:loadingRequest];
        }
        return YES;
    }
    return NO;
}

- (void)resourceLoader:(AVAssetResourceLoader *)resourceLoader didCancelLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest
{
    @synchronized (self.loadingRequestArray) {
        [self.loadingRequestArray removeObject:loadingRequest];
    }
}
#pragma mark - KKMediaDownloadTaskDelegate
- (void)didReceiveResponseWithtask:(MCDonwloadTask *)task length:(NSUInteger)ideoLength mimeType:(NSString *)mimeType
{
    dispatch_async(main_queue, ^{
        if([self.delegate respondsToSelector:@selector(mediaDownloadTaskStateForShowLoading:)] && self.showLoading){
            [self.delegate mediaDownloadTaskStateForShowLoading:NO];
            self.showLoading = NO;
        }
    });
}
- (void)didReceiveVideoDataWithTask:(MCDonwloadTask *)task cacheProgress:(CGFloat)progress
{
    [self processPendingRequests];
    if ([self.delegate respondsToSelector:@selector(downloadProgress:)] && self.delegate) {
        [self.delegate downloadProgress:progress];
    }
}
- (void)didFinishLoadingWithTask:(MCDonwloadTask *)task
{
    if ([self.delegate respondsToSelector:@selector(downloadSuccessWithDesPath:)] && self.delegate) {
        [self.delegate downloadSuccessWithDesPath:self.desPath];
    }
}
- (void)didFailLoadingWithTask:(MCDonwloadTask *)task WithError:(NSError * )error;
{
  
}
- (void)taskCancelWithTask:(MCDonwloadTask * )task
{
    if ([self.delegate respondsToSelector:@selector(taskCancel)] && self.delegate) {
        [self.delegate taskCancel];
    }
}
- (void)cancel
{
    [self.task cancel];
    self.delegate = nil;
    @synchronized (self.loadingRequestArray) {
        [self.loadingRequestArray removeAllObjects];
    }
}

- (NSMutableArray * )loadingRequestArray
{
    if (!_loadingRequestArray){
        _loadingRequestArray = [[NSMutableArray alloc]init];
    }
    return _loadingRequestArray;
}
@end

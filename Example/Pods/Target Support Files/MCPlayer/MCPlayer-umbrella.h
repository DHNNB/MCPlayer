#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "MCConst.h"
#import "MCDonwloadTask.h"
#import "MCPath.h"
#import "MCPlayer.h"
#import "MCResourceLoader.h"
#import "MCVideoPlayer.h"
#import "NSString+MD5.h"

FOUNDATION_EXPORT double MCPlayerVersionNumber;
FOUNDATION_EXPORT const unsigned char MCPlayerVersionString[];


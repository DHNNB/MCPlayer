//
//  MCCacheRecord.h
//  MCPlayer
//
//  Created by M_Code on 2017/7/6.
//  Copyright © 2017年 MC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MCCacheRecord : NSObject

+ (void)saveRecordFileWithRange:(NSRange)range;
@end


// 文件 写入 参数 0 - 20  40 - 60  10 - 50

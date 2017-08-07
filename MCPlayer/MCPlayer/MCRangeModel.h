//
//  MCRangeModel.h
//  MCPlayer
//
//  Created by M_Code on 2017/7/6.
//  Copyright © 2017年 MC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MCRangeModel : NSObject <NSCoding>
@property (retain, nonatomic) NSMutableArray *rangeArray;
- (void)save;
@end

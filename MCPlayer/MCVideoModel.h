//
//  MCVideoModel.h
//  MCPlayer
//
//  Created by M_Code on 2017/6/15.
//  Copyright © 2017年 MC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
@interface MCVideoModel : NSObject
@property (copy, nonatomic) NSString * name;
@property (copy, nonatomic) NSString * url;
@property (assign, nonatomic) NSInteger row;
@property (retain, nonatomic) UIImage * image;
@end

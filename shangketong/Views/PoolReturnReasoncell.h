//
//  PoolReturnReasoncell.h
//  shangketong
//
//  Created by sungoin-zbs on 15/11/12.
//  Copyright (c) 2015年 sungoin. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface PoolReturnReasoncell : UITableViewCell

@property (copy, nonatomic) void(^textValueChangedBlock)(NSString*);

+ (CGFloat)cellHeight;
@end

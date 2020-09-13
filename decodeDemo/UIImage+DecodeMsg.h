//
//  UIImage+HideMsg.h
//  DecodeDemo
//
//  Created by 冯立海 on 2018/12/4.
//  Copyright © 2018年 xiehaili. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIImage (DecodeMsg)

- (NSString *)decodeImage;
- (UIImage *) encodeMessage:(NSString *)message;
@end

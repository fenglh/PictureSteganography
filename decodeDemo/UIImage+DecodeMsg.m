//
//  UIImage+HideMsg.m
//  DecodeDemo
//
//  Created by 冯立海 on 2018/12/4.
//  Copyright © 2018年 xiehaili. All rights reserved.
//

#import "UIImage+DecodeMsg.h"

#define FlagString @"ITX@"

@implementation UIImage (DecodeMsg)

- (NSArray *)bitsForByte:(Byte)byte {
    NSMutableArray *arr = [NSMutableArray arrayWithObjects:@(0),@(0),@(0),@(0),@(0),@(0),@(0),@(0), nil];
    for (int i = 7; i >= 0; i--) {
        
        arr[i] =  [NSNumber numberWithUnsignedInt:(Byte)(byte & 1)];
        byte = (Byte)byte >> 1;
    }
    return arr;
}





- (NSString *)decodeImage {
    CGImageRef  imageRef;
    CGImageSourceRef source;
    
    
    NSData *imageData  = UIImagePNGRepresentation(self);
    
    source = CGImageSourceCreateWithData((__bridge CFDataRef)imageData, NULL);
    imageRef =  CGImageSourceCreateImageAtIndex(source, 0, NULL);
    
    size_t width  = CGImageGetWidth(imageRef);
    size_t height = CGImageGetHeight(imageRef);
    
    
    CGBitmapInfo bitmapInfo = CGImageGetBitmapInfo(imageRef);
    // 位图每行的字节信息
    size_t bytesPerRow = CGImageGetBytesPerRow(imageRef);
    // 图片数据源提供者
    CGDataProviderRef dataProvider = CGImageGetDataProvider(imageRef);
    
    // 拿到图片的字节数据
    CFDataRef   data;
    UInt8*      buffer;
    data = CGDataProviderCopyData(dataProvider);
    buffer = (UInt8*)CFDataGetBytePtr(data);
    
    
    // 开始做处理
    int index = 0;
    NSUInteger  x, y;
    
    
    
    
    NSInteger holdMaxLength = (height * width * 3) / 8;
    NSInteger msgBufferIndex = 0;
    
    NSMutableArray *bitsArr = [NSMutableArray array];
    
    for (y = 0; y < height; y++) {
        for (x = 0; x < width; x++) {
            
            
            
            UInt8*  tmp;  //字符串指针
            tmp = buffer + y * bytesPerRow + x * 4; // RGBA四个颜色分量，tmp指针指向需要处理的像素
            
            UInt8 red,green,blue;
            red = *(tmp + 0);
            green = *(tmp + 1);
            blue = *(tmp + 2);
            //取最后一位的值
            UInt8 lastbitRedValue = red & 1;
            UInt8 lastbitGreenValue = green & 1;
            UInt8 lastbitBlueValue = blue & 1;
            
            [bitsArr addObject:[NSNumber numberWithUnsignedChar:lastbitRedValue]];
            [bitsArr addObject:[NSNumber numberWithUnsignedChar:lastbitGreenValue]];
            [bitsArr addObject:[NSNumber numberWithUnsignedChar:lastbitBlueValue]];
            
            index++;
        }
    }
    
    char * msgBuffer=(char*)malloc(holdMaxLength * sizeof(char));
    UInt8 tmpValue = 0;
    for (int i = 0; i < bitsArr.count; i++) {
        int bitIndex = i % 8 ;
        
        if(bitIndex == 0){
            tmpValue = 0;
        }
        tmpValue = tmpValue |  ([bitsArr[i] unsignedIntValue] << (7 -bitIndex));
        if (bitIndex == 7) {
            msgBuffer[msgBufferIndex] = tmpValue;
            msgBufferIndex++;
        }
    }
    NSString *msg = [NSString stringWithCString:msgBuffer encoding:NSUTF8StringEncoding];
    
    
    
    CFRelease(dataProvider);
    CFRelease(data);
    free(msgBuffer);
    if (msg.length < FlagString.length || ![[msg substringToIndex:FlagString.length] isEqualToString:FlagString]) {
        return nil;
    }
    return [msg substringFromIndex:FlagString.length];
}



@end

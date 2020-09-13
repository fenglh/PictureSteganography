//
//  NSImage+HideMsg.m
//  图片隐藏信息
//
//  Created by 冯立海 on 2018/12/4.
//  Copyright © 2018年 xiehaili. All rights reserved.
//

#import "NSImage+HideMsg.h"

#define FlagString @"ITX@"
@implementation NSImage (HideMsg)


- (NSArray *)bitsForByte:(Byte)byte {
    NSMutableArray *arr = [NSMutableArray arrayWithObjects:@(0),@(0),@(0),@(0),@(0),@(0),@(0),@(0), nil];
    for (int i = 7; i >= 0; i--) {
        
        arr[i] =  [NSNumber numberWithUnsignedInt:(Byte)(byte & 1)];
        byte = (Byte)byte >> 1;
    }
    return arr;
}

- (NSImage *) encodeMessage:(NSString *)message{
    
    //插入标记头部,用户判断该图片是否是标记图片
    NSString *encodeMsg =FlagString;
    encodeMsg = [encodeMsg stringByAppendingString:message];
    CGImageRef  imageRef = ITXCGImageCreateWithImage(self);
    size_t width  = CGImageGetWidth(imageRef);
    size_t height = CGImageGetHeight(imageRef);
    
    // rgb位构成
    size_t bitsPerComponent = CGImageGetBitsPerComponent(imageRef);
    
    // 像素的颜色位数
    size_t bitsPerPixel = CGImageGetBitsPerPixel(imageRef);
    
    // 位图每行的字节信息
    size_t bytesPerRow = CGImageGetBytesPerRow(imageRef);
    
    // 图片的颜色空间
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(imageRef);
    
    // 位图的bitmap信息
//    CGBitmapInfo bitmapInfo = kCGImageByteOrder32Big | kCGImageAlphaPremultipliedLast ;
//    CGBitmapInfo bitmapInfo = CGImageGetBitmapInfo(imageRef);
    CGBitmapInfo bitmapInfo = kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big;
    
    
    // 图像是否抗锯齿
    bool shouldInterpolate = CGImageGetShouldInterpolate(imageRef);
    
    CGColorRenderingIntent intent = CGImageGetRenderingIntent(imageRef);
    
    // 图片数据源提供者
    CGDataProviderRef dataProvider = CGImageGetDataProvider(imageRef);
    
    // 拿到图片的字节数据
    CFDataRef   data;
    UInt8*      buffer;
    data = CGDataProviderCopyData(dataProvider);
    
    
    buffer = (UInt8*)CFDataGetBytePtr(data);
    
    //字符串
    
    NSData *msgData =[encodeMsg dataUsingEncoding:NSUTF8StringEncoding];
    NSUInteger len = [msgData length];
    Byte *byteData = (Byte*)malloc(len);
    memcpy(byteData, [msgData bytes], len);
    
    NSMutableArray *messageBits = [NSMutableArray array];
    for (int i = 0; i< len; i++) {
        Byte byte = byteData[i];
        NSArray *bitsPerBytes = [self bitsForByte:byte];
        [messageBits addObjectsFromArray:bitsPerBytes];
    }
    //插入结束符'\0'的每一bit位的值
    for (int i = 0; i < 8; i++) {
        [messageBits addObject:@(0)];
    }
    
    
    if ((height * width * 3)  < messageBits.count) {
        NSLog(@"图片太小，不足以容纳要要隐藏的信息!");
        return nil;
    }
    
    // 开始做处理
    int index = 0;
    NSUInteger  x, y;
    for (y = 0; y < height; y++) {
        for (x = 0; x < width; x++) {
            
            UInt8*  tmp;  //字符串指针
            tmp = buffer + y * bytesPerRow + x * 4; // RGBA四个颜色分量，tmp指针指向需要处理的像素
            
            // 拿到rgba值
            UInt8 red,green,blue,alpha;
            red = *(tmp + 0);
            green = *(tmp + 1);
            blue = *(tmp + 2);
            alpha = *(tmp + 3);
            
            //rbg的末位作为信息位，a字节不用做信心存储。
            // 透明度如果为0，那么保存图片的时候，rgb都会被重置为0，所以a字节不作信心存储
            // 如果alpha = 0,那么必须要将alpha = 0重置为1
            if (alpha == 0) {
                *(tmp + 3) = 1;
            }

            if (index+3 > messageBits.count) {
                break;
            }
            
            UInt8  redBit = (UInt8)[messageBits[index] unsignedCharValue];
            UInt8  greenBit = (UInt8)[messageBits[index+1] unsignedCharValue];
            UInt8  blueBit = (UInt8)[messageBits[index+2] unsignedCharValue];
            if (redBit & 1) {//1
                *tmp  = red | 0x01; //末位重置为1
            }else{//0
                *tmp = red &  0xfe; //末位重置为0
            }
            if (greenBit & 1) {
                *(tmp+1)  = green | 0x01 ;
            }else{
                *(tmp + 1) = green &  0xfe;

            }
            if (blueBit & 1) {
                *(tmp+2)  = blue | 0x01 ;
            }else{
                *(tmp + 2) = blue &  0xfe;
            }
            index += 3;
            
            
        }
    }
    
    // 生成处理后的图片
    CFDataRef effectedData = CFDataCreate(NULL, buffer, CFDataGetLength(data));
    CGDataProviderRef effectedDataProvider = CGDataProviderCreateWithCFData(effectedData);
    CGImageRef effectedCgImage = CGImageCreate(width, height,bitsPerComponent, bitsPerPixel, bytesPerRow,colorSpace, bitmapInfo, effectedDataProvider,NULL, shouldInterpolate, intent);
    NSImage *newImage = [[NSImage alloc] initWithCGImage:effectedCgImage size:CGSizeMake(width, height)];
    // 一定要释放！！
    
    CGImageRelease(effectedCgImage);
    CFRelease(effectedDataProvider);
    CFRelease(effectedData);
    CFRelease(data);
    free(byteData);
    
    return newImage;
}

- (NSString *)decodeImage {
    
    CGImageRef inputCGImage = ITXCGImageCreateWithImage(self);
    NSUInteger width = CGImageGetWidth(inputCGImage);
    NSUInteger height = CGImageGetHeight(inputCGImage);
    
    NSUInteger size = height * width * 4;
    UInt8 *buffer;
    buffer = (UInt8 *) calloc(size, sizeof(UInt32));
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    size_t bytesPerRow = CGImageGetBytesPerRow(inputCGImage);
    size_t bitsPerComponent = CGImageGetBitsPerComponent(inputCGImage);

    
    CGContextRef context = CGBitmapContextCreate(buffer,
                                                 width,
                                                 height,
                                                 bitsPerComponent,
                                                 bytesPerRow,
                                                 colorSpace,
                                                 kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), inputCGImage);
    
//    CGImageRef  imageRef;
//    CGImageSourceRef source;
//
//    source = CGImageSourceCreateWithData((CFDataRef)[self TIFFRepresentation], NULL);
//    imageRef =  CGImageSourceCreateImageAtIndex(source, 0, NULL);
//
//    size_t width  = CGImageGetWidth(imageRef);
//    size_t height = CGImageGetHeight(imageRef);
//
//
//    CGBitmapInfo bitmapInfo = CGImageGetBitmapInfo(imageRef);
//    // 位图每行的字节信息
//    size_t bytesPerRow = CGImageGetBytesPerRow(imageRef);
//    // 图片数据源提供者
//    CGDataProviderRef dataProvider = CGImageGetDataProvider(imageRef);
    
    // 拿到图片的字节数据

    
    
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
            
            // 拿到rgba值 ,注意，透明度如果为0，那么保存图片的时候，rgb都会被重置为0
            // alpha的末位不做信息存储位
            
            
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
    
    free(buffer);
    CGColorSpaceRelease(colorSpace);
    CGContextRelease(context);
    CGImageRelease(inputCGImage);
    
    free(msgBuffer);
    if (msg.length < FlagString.length || ![[msg substringToIndex:FlagString.length] isEqualToString:FlagString]) {
        return nil;
    }
    return [msg substringFromIndex:FlagString.length];
}


CGImageRef ITXCGImageCreateWithImage(id image) {
    CGImageRef imageRef = nil;
    
#if TARGET_OS_IPHONE
    NSCAssert([image isKindOfClass:UIImage.class], @"image must be kind of UIImage");
    imageRef = (CGImageRef)CFRetain([image CGImage]);
#else
    NSCAssert([image isKindOfClass:NSImage.class], @"image must be kind of NSImage");
    NSData *data = [image TIFFRepresentation];
    CFDataRef dataRef = (CFDataRef)CFBridgingRetain(data);
    CGImageSourceRef source = CGImageSourceCreateWithData(dataRef, NULL);
    imageRef = CGImageSourceCreateImageAtIndex(source, 0, NULL);
    CFRelease(dataRef);
    CFRelease(source);
#endif
    
    return imageRef;
}


@end

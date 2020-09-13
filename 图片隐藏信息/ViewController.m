//
//  ViewController.m
//  图片隐藏信息
//
//  Created by 冯立海 on 2018/12/4.
//  Copyright © 2018年 xiehaili. All rights reserved.
//

#import "ViewController.h"
#import "DragInView.h"
#import "DragOutView.h"
#import "NSImage+HideMsg.h"
#import "PictographImageCoder.h"



@interface ViewController()
@property (weak) IBOutlet NSTextField *resultLabel;
@property (weak) IBOutlet NSTextField *tipsLabel;
@property (weak) IBOutlet DragInView *dragInView;
@property (weak) IBOutlet NSImageView *sourceImageView;
@property (weak) IBOutlet DragOutView *destinationImageView;
@property (unsafe_unretained) IBOutlet NSTextView *textView;
@property (nonatomic, strong) NSString *sourceImageFilePath;
@property (nonatomic, strong) NSString *destinationFilePath;

@property (weak) IBOutlet NSTextField *sourceSizeLabel;
@property (weak) IBOutlet NSTextField *textSizeLabel;
@property (weak) IBOutlet NSTextField *destinationSizeLabel;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    //注册拖放
    [self.sourceImageView unregisterDraggedTypes];
    self.view.layer.backgroundColor = [NSColor whiteColor].CGColor;
    self.dragInView.dropInBlock = ^(NSString *filePath) {

        self.resultLabel.stringValue = @"";
        NSImage *image =  [[NSImage alloc] initWithContentsOfFile:filePath];
        self.sourceImageView.image = image;
        self.sourceImageFilePath = filePath;
        self.tipsLabel.hidden = YES;
        
        
        NSError *error;
        NSString *msg = [self.sourceImageView.image decodeImage:&error];
        
        
        self.sourceSizeLabel.stringValue = [NSString stringWithFormat:@"%@ x %@ = %@",@(image.size.width), @(image.size.height), @(image.size.width * image.size.height)];
        self.textView.string  = msg ? msg :@"";
        self.textSizeLabel.stringValue = [NSString stringWithFormat:@"%lu", (unsigned long)msg.length];

    };

    
}

- (IBAction)onClick:(id)sender {
    if (self.sourceImageView.image == nil) {
        return;
    }
    NSError *error;

    
    if (error == nil) {
        
    
        NSData *data = [self.sourceImageView.image encodeMessage:self.textView.string error:&error];
        
        NSImage *newImaeg = [[NSImage alloc] initWithData:data];
        self.destinationImageView.image = newImaeg;
        
        //设定好文件路径后进行存储就ok了
        NSString *fileNmae = [self.sourceImageFilePath lastPathComponent];
        NSString *documentPath = [NSSearchPathForDirectoriesInDomains(NSDownloadsDirectory, NSUserDomainMask, YES) lastObject];
        NSString *newPath = [NSString stringWithFormat:@"%@/code_%@",documentPath, fileNmae];
        BOOL success = [self saveImage:newImaeg file:newPath];
        if (success) {
            self.resultLabel.textColor = [NSColor systemGreenColor];
            self.resultLabel.stringValue = [NSString stringWithFormat:@"图片保存成功：%@", newPath];
            self.destinationFilePath = newPath;
            self.destinationImageView.destinationImageFile  = newPath;
            
            
        }else {
            self.resultLabel.textColor = [NSColor systemRedColor];
            self.resultLabel.stringValue = @"图片保存失败";
        }
        
    }else{
        NSLog(@"%@", error);
    }


}



#pragma mark - 图片隐藏信息算法

- (void)textDidChange:(NSNotification *)notification {
    NSLog(@"文字改变");
}

- (BOOL)saveImage:(id)image file:(NSString *)path {
    CGImageRef cgRef = [image CGImageForProposedRect:NULL
                                             context:nil
                                               hints:nil];
    
    NSBitmapImageRep *newRep = [[NSBitmapImageRep alloc] initWithCGImage:cgRef];
    
    [newRep setSize:[image size]];
    
    NSData *pngData = [newRep representationUsingType:NSPNGFileType
                                           properties:nil];
    
    return [pngData writeToFile:path atomically:YES];
}




- (void )saveImage:(NSImage *)image
{
    
//    //设定好文件路径后进行存储就ok了
//    NSString *fileNmae = [self.sourceImageFilePath lastPathComponent];
//
//    NSString *documentPath = [NSSearchPathForDirectoriesInDomains(NSDownloadsDirectory, NSUserDomainMask, YES) lastObject];
//
//    NSString *newPath = [NSString stringWithFormat:@"%@/_encode_%@",documentPath, fileNmae];
//
//
//    CGImageRef cgRef = [image CGImageForProposedRect:NULL
//                                             context:nil
//                                               hints:nil];
//    NSBitmapImageRep *newRep = [[NSBitmapImageRep alloc] initWithCGImage:cgRef];
//    [newRep setSize:[image size]];   // if you want the same resolution
//    NSData *pngData = [newRep representationUsingType:NSPNGFileType properties:@{}];
//    BOOL y = [pngData writeToFile:newPath atomically:YES];
//
//
//
//    if (y) {
//        self.resultLabel.textColor = [NSColor systemGreenColor];
//        self.resultLabel.stringValue = [NSString stringWithFormat:@"图片保存成功：%@", newPath];
//        self.destinationFilePath = newPath;
//        self.destinationImageView.destinationImageFile  = newPath;
//
//
//    }else {
//        self.resultLabel.textColor = [NSColor systemRedColor];
//        self.resultLabel.stringValue = @"图片保存失败";
//    }
}


//通过图片Data数据第一个字节 来获取图片扩展名
- (NSString *)contentTypeForImageData:(NSData *)data{
    uint8_t c;
    [data getBytes:&c length:1];
    switch (c) {
        case 0xFF:
            return @"jpeg";
        case 0x89:
            return @"png";
        case 0x47:
            return @"gif";
        case 0x49:
        case 0x4D:
            return @"tiff";
        case 0x52:
            if ([data length] < 12) {
                return nil;
            }
            NSString *testString = [[NSString alloc] initWithData:[data subdataWithRange:NSMakeRange(0, 12)] encoding:NSASCIIStringEncoding];
            if ([testString hasPrefix:@"RIFF"] && [testString hasSuffix:@"WEBP"]) {
                return @"webp";
            }
            return nil;
    }
    return nil;
}


-(void)imageDump:(NSImage*)image
{
    CGImageRef  cgimage;
    
    CGImageSourceRef source;
    
    source = CGImageSourceCreateWithData((CFDataRef)[image TIFFRepresentation], NULL);
    cgimage =  CGImageSourceCreateImageAtIndex(source, 0, NULL);
    
    size_t width  = CGImageGetWidth(cgimage);
    size_t height = CGImageGetHeight(cgimage);
    
    size_t bpr = CGImageGetBytesPerRow(cgimage);
    size_t bpp = CGImageGetBitsPerPixel(cgimage);
    size_t bpc = CGImageGetBitsPerComponent(cgimage);
    size_t bytes_per_pixel = bpp / bpc;
    
    CGBitmapInfo info = CGImageGetBitmapInfo(cgimage);
    
    NSLog(
          @"\n"
          "CGImageGetHeight: %d\n"
          "CGImageGetWidth:  %d\n"
          "CGImageGetColorSpace: %@\n"
          "CGImageGetBitsPerPixel:     %d\n"
          "CGImageGetBitsPerComponent: %d\n"
          "CGImageGetBytesPerRow:      %d\n"
          "CGImageGetBitmapInfo: 0x%.8X\n"
          "  kCGBitmapAlphaInfoMask     = %s\n"
          "  kCGBitmapFloatComponents   = %s\n"
          "  kCGBitmapByteOrderMask     = %s\n"
          "  kCGBitmapByteOrderDefault  = %s\n"
          "  kCGBitmapByteOrder16Little = %s\n"
          "  kCGBitmapByteOrder32Little = %s\n"
          "  kCGBitmapByteOrder16Big    = %s\n"
          "  kCGBitmapByteOrder32Big    = %s\n",
          (int)width,
          (int)height,
          CGImageGetColorSpace(cgimage),
          (int)bpp,
          (int)bpc,
          (int)bpr,
          (unsigned)info,
          (info & kCGBitmapAlphaInfoMask)     ? "YES" : "NO",
          (info & kCGBitmapFloatComponents)   ? "YES" : "NO",
          (info & kCGBitmapByteOrderMask)     ? "YES" : "NO",
          (info & kCGBitmapByteOrderDefault)  ? "YES" : "NO",
          (info & kCGBitmapByteOrder16Little) ? "YES" : "NO",
          (info & kCGBitmapByteOrder32Little) ? "YES" : "NO",
          (info & kCGBitmapByteOrder16Big)    ? "YES" : "NO",
          (info & kCGBitmapByteOrder32Big)    ? "YES" : "NO"
          );
    
    CGDataProviderRef provider = CGImageGetDataProvider(cgimage);
    NSData* data = (id)CFBridgingRelease(CGDataProviderCopyData(provider));

    const uint8_t* bytes = [data bytes];
    
    printf("Pixel Data:\n");
    for(size_t row = 0; row < height; row++)
    {
        for(size_t col = 0; col < width; col++)
        {
            const uint8_t* pixel =
            &bytes[row * bpr + col * bytes_per_pixel];
            
            printf("(");
            for(size_t x = 0; x < bytes_per_pixel; x++)
            {
                printf("%.2X", pixel[x]);
                if( x < bytes_per_pixel - 1 )
                    printf(",");
            }
            
            printf(")");
            if( col < width - 1 )
                printf(", ");
        }
        
        printf("\n");
    }
}


@end

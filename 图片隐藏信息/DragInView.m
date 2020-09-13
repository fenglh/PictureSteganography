//
//  DragInView.m
//  图片隐藏信息
//
//  Created by 冯立海 on 2018/12/4.
//  Copyright © 2018年 xiehaili. All rights reserved.
//

#import "DragInView.h"

@implementation DragInView

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        //注册拖放
        [self registerForDraggedTypes:[NSArray arrayWithObjects:NSFilenamesPboardType, NSTIFFPboardType,nil]];
    }
    return self;
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    // Drawing code here.
}

#pragma mark - NSResponder

- (BOOL)canBecomeKeyView {
    return YES;
}

- (BOOL)acceptsFirstResponder {
    return YES;
}

#pragma mark - NSDraggingDestination 接收方

//拖放进入目标区
- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender {
    NSLog(@"拖放进入目标区");
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSCursor dragCopyCursor] set];
    });
    
    [self setNeedsDisplay:YES];
    
    NSDragOperation sourceDragMask = [sender draggingSourceOperationMask];
    NSPasteboard *pboard = [sender draggingPasteboard];
    if ( [[pboard types] containsObject:NSFilenamesPboardType] ) {
        if (sourceDragMask & NSDragOperationLink) {
            return NSDragOperationCopy;//可被拷贝
        }
    }
    return NSDragOperationNone;
}


//拖放预处理,一般是根据拖放类型type，决定是否接受拖放。
- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender {
    
    if ( [sender draggingSource] != self ) {
        BOOL canInit = [NSImage canInitWithPasteboard: [sender draggingPasteboard]];
        //例如是否可以初始化为图片
        return canInit;
    }
    return NO;
    
    
}


//允许接收拖放，开始接收处理拖放数据
- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender {
    NSLog(@"执行拖放处理");
    NSPasteboard *pboard = [sender draggingPasteboard];
    //文件包含Pboard 类型
    if ( [[pboard types] containsObject:NSFilenamesPboardType] ) {
        NSArray *files = [pboard propertyListForType:NSFilenamesPboardType];
        NSInteger numberOfFiles = [files count];
        if(numberOfFiles>0)
        {
            NSString *filePath = [files firstObject];

            NSLog(@"拖入文件:%@", filePath);
            if (self.dropInBlock) {
                self.dropInBlock(filePath);
            }
            
            return YES;
        }
        
    }
    return YES;
    
}

//拖放退出目标区,拖放的图像会弹回到拖放源
- (void)draggingExited:(nullable id <NSDraggingInfo>)sender {
    NSLog(@"拖放退出");
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSCursor arrowCursor] set];
    });
    
}


- (void)draggingEnded:(id <NSDraggingInfo>)sender {
    NSLog(@"拖放结束");
    NSPasteboard *pasteboard = [sender draggingPasteboard];
    [pasteboard clearContents];
}



@end

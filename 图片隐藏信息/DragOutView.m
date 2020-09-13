//
//  DragOutView.m
//  图片隐藏信息
//
//  Created by 冯立海 on 2018/12/4.
//  Copyright © 2018年 xiehaili. All rights reserved.
//

#import "DragOutView.h"

@interface DragOutView()<NSPasteboardItemDataProvider, NSDraggingSource>

@property (nonatomic, assign) BOOL mouseHasDraged;  ///< 鼠标已经拖拽选中item
@property (nonatomic, assign) CGPoint mouseDownPoint; ///< 鼠标按下坐标
@end
@implementation DragOutView


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


#pragma mark - 鼠标 左键 按下

- (void)mouseDown:(NSEvent *)theEvent {
    
    NSPoint location = [theEvent locationInWindow];
    self.mouseDownPoint = location;

    NSLog(@"点击");
}


- (void)mouseMoved:(NSEvent *)theEvent {
    NSLog(@"移动");
}

- (void)mouseDragged:(NSEvent *)theEvent {
    
    [NSCursor closedHandCursor];
    
    //准备拖拽
    NSPasteboardItem *pbItem = [NSPasteboardItem new];
    [pbItem setDataProvider:self forTypes:[NSArray arrayWithObjects:@"public.file-url", nil]];
    
    NSDraggingItem *dragItem = [[NSDraggingItem alloc] initWithPasteboardWriter:pbItem];
    
    CGFloat width = self.bounds.size.width;
    CGFloat height  = self.image.size.height * (width/self.image.size.width );
    CGFloat y = self.bounds.size.height / 2.f - height / 2.f;
    
    NSRect draggingRect = CGRectMake(0, y, width, height);
    [dragItem setDraggingFrame:draggingRect contents:self.image];
    
    NSDraggingSession *draggingSession = [self beginDraggingSessionWithItems:@[dragItem] event:theEvent source:self];
    draggingSession.animatesToStartingPositionsOnCancelOrFail = YES;
    draggingSession.draggingFormation = NSDraggingFormationNone;
    

}

- (void)mouseUp:(NSEvent *)theEvent {
    [NSCursor arrowCursor];


    
}

- (BOOL)acceptsFirstMouse:(NSEvent *)event{
    return YES;
}

//拖出
- (void)pasteboard:(nullable NSPasteboard *)pasteboard item:(NSPasteboardItem *)item provideDataForType:(NSString *)type {
    [pasteboard clearContents];
    [pasteboard writeObjects:@[[NSURL fileURLWithPath:self.destinationImageFile]]];
}



//发送方：定义允许的拖放操作
- (NSDragOperation)draggingSession:(NSDraggingSession *)session sourceOperationMaskForDraggingContext:(NSDraggingContext)context {
    switch (context) {
        case NSDraggingContextOutsideApplication:
            return NSDragOperationCopy;
        case NSDraggingContextWithinApplication:
        default:
            return NSDragOperationCopy;
            break;
    }
}



@end

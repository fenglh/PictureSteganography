//
//  PictographImageCoder.h
//  Pictograph
//
//  Created by Adam on 2015-10-04.
//  Copyright © 2015 Adam Boyd. All rights reserved.
//

#import "TargetConditionals.h"
#import <Foundation/Foundation.h>
#import "EncodingErrors.h"
#import "PictographImage+Reconciliation.h"
#import "Global.h"


@interface PictographImage(Coder)



- (NSString *_Nullable)decodeImage:(NSError * _Nullable * _Nullable)error;

- (NSData * _Nullable)encodeMessage:(NSString * _Nullable)message error:(NSError * _Nullable * _Nullable)error;


@end

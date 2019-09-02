//
//  KFB_EdgeDetectionDisplayLayer.m
//  DemoWithStaticLib
//
//  Created by sealedace on 2019/8/31.
//  Copyright © 2019 fengjian. All rights reserved.
//

#import "KFB_EdgeDetectionDisplayLayer.h"
@import UIKit;

@interface KFB_EdgeDetectionDisplayLayer ()
@property (nonatomic, readwrite, copy) NSArray<NSValue *> *points;
@end

@implementation KFB_EdgeDetectionDisplayLayer

- (void)drawInContext:(CGContextRef)ctx
{
    CGContextClearRect(ctx, self.bounds);
    
    CGContextSetFillColorWithColor(ctx, [UIColor greenColor].CGColor);
    
    for (NSValue *value in self.points)
    {
        CGPoint p = [value CGPointValue];
        CGRect circleRect = CGRectMake(p.x-5.f,
                                       p.y-5.f, 10.f, 10.f);
        CGContextFillEllipseInRect(ctx, circleRect);
    }
}

- (void)showPoints:(NSArray<NSValue *> *)points
{
    self.points = points;
    
    [self setNeedsDisplay];
}

@end

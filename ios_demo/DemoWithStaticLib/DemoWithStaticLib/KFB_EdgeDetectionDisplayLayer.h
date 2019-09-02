//
//  KFB_EdgeDetectionDisplayLayer.h
//  DemoWithStaticLib
//
//  Created by sealedace on 2019/8/31.
//  Copyright © 2019 fengjian. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>

NS_ASSUME_NONNULL_BEGIN

@interface KFB_EdgeDetectionDisplayLayer : CALayer

- (void)showPoints:(NSArray<NSValue *> *)points;

@end

NS_ASSUME_NONNULL_END

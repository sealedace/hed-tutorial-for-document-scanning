//
//  OpenCVUtil.m
//  DemoWithStaticLib
//
//  Created by fengjian on 2018/4/11.
//  Copyright © 2018年 fengjian. All rights reserved.
//

#import "OpenCVUtil.h"

@implementation OpenCVUtil
+ (UIImage *)UIImageFromCVMat:(cv::Mat)cvMat {
    NSData *data = [NSData dataWithBytes:cvMat.data length:cvMat.elemSize()*cvMat.total()];
    CGColorSpaceRef colorSpace;
    
    if (cvMat.elemSize() == 1) {
        colorSpace = CGColorSpaceCreateDeviceGray();
    } else {
        colorSpace = CGColorSpaceCreateDeviceRGB();
    }
    
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    
    // Creating CGImage from cv::Mat
    CGImageRef imageRef = CGImageCreate(cvMat.cols,                                 //width
                                        cvMat.rows,                                 //height
                                        8,                                          //bits per component
                                        8 * cvMat.elemSize(),                       //bits per pixel
                                        cvMat.step[0],                            //bytesPerRow
                                        colorSpace,                                 //colorspace
                                        kCGImageAlphaNone|kCGBitmapByteOrderDefault,// bitmap info
                                        provider,                                   //CGDataProviderRef
                                        NULL,                                       //decode
                                        false,                                      //should interpolate
                                        kCGRenderingIntentDefault                   //intent
                                        );
    
    
    // Getting UIImage from CGImage
    UIImage *finalImage = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);
    
    return finalImage;
}

+ (cv::Mat)cvMatFromUIImage:(UIImage *)image {
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(image.CGImage);
    CGFloat cols = image.size.width;
    CGFloat rows = image.size.height;
    
    cv::Mat cvMat(rows, cols, CV_8UC4); // 8 bits per component, 4 channels (color channels + alpha)
    
    CGContextRef contextRef = CGBitmapContextCreate(cvMat.data,                 // Pointer to  data
                                                    cols,                       // Width of bitmap
                                                    rows,                       // Height of bitmap
                                                    8,                          // Bits per component
                                                    cvMat.step[0],              // Bytes per row
                                                    colorSpace,                 // Colorspace
                                                    kCGImageAlphaNoneSkipLast |
                                                    kCGBitmapByteOrderDefault); // Bitmap info flags
    
    CGContextDrawImage(contextRef, CGRectMake(0, 0, cols, rows), image.CGImage);
    CGContextRelease(contextRef);
    
    return cvMat;
}

+ (cv::Mat)cvMatGrayFromUIImage:(UIImage *)image {
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(image.CGImage);
    CGFloat cols = image.size.width;
    CGFloat rows = image.size.height;
    
    cv::Mat cvMat(rows, cols, CV_8UC1); // 8 bits per component, 1 channels
    
    CGContextRef contextRef = CGBitmapContextCreate(cvMat.data,                 // Pointer to data
                                                    cols,                       // Width of bitmap
                                                    rows,                       // Height of bitmap
                                                    8,                          // Bits per component
                                                    cvMat.step[0],              // Bytes per row
                                                    colorSpace,                 // Colorspace
                                                    kCGImageAlphaNoneSkipLast |
                                                    kCGBitmapByteOrderDefault); // Bitmap info flags
    
    CGContextDrawImage(contextRef, CGRectMake(0, 0, cols, rows), image.CGImage);
    CGContextRelease(contextRef);
    
    return cvMat;
}

//+ (cv::Mat)cvMatFromPixelBuffer:(CVPixelBufferRef)pixelBuffer
//{
//    OSType format = CVPixelBufferGetPixelFormatType(pixelBuffer);
//
//    // Set the following dict on AVCaptureVideoDataOutput's videoSettings to get YUV output
//    // @{ kCVPixelBufferPixelFormatTypeKey : kCVPixelFormatType_420YpCbCr8BiPlanarFullRange }
//
//    NSAssert(format == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, @"Only YUV is supported");
//
//    // The first plane / channel (at index 0) is the grayscale plane
//    // See more infomation about the YUV format
//    // http://en.wikipedia.org/wiki/YUV
//    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
//    void *baseaddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
//
//    CGFloat width = CVPixelBufferGetWidth(pixelBuffer);
//    CGFloat height = CVPixelBufferGetHeight(pixelBuffer);
//
//    cv::Mat mat(height, width, CV_8UC4, baseaddress, 0);
//
//    // Use the mat here
//
//    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
//}

+ (cv::Mat)cvMatFromImageRef:(CGImageRef)image withOrientation:(UIImageOrientation)orientation
{
    CGSize imageSize = CGSizeMake(CGImageGetWidth(image), CGImageGetHeight(image));
    CGRect imageRect = CGRectMake(0.f, 0.f, imageSize.width, imageSize.height);
    
    CGAffineTransform transform = CGAffineTransformIdentity;

    switch (orientation)
    {
        case UIImageOrientationLeftMirrored:
        {
            transform = CGAffineTransformMakeTranslation(imageSize.height, 0.f);
            transform = CGAffineTransformScale(transform, -1.0, 1.0);
            transform = CGAffineTransformTranslate(transform, 0.f, imageSize.width);
            transform = CGAffineTransformRotate(transform, M_PI_2);
            transform = CGAffineTransformTranslate(transform, -imageSize.width, -imageSize.height);
            
            CGFloat tempWidth = imageSize.width;
            imageSize.width = imageSize.height;
            imageSize.height = tempWidth;
        }
            break;
        case UIImageOrientationDown: { // rotate 180 deg
            transform = CGAffineTransformTranslate(transform, imageRect.size.width, imageRect.size.height);
            transform = CGAffineTransformRotate(transform, M_PI);
        } break;

        case UIImageOrientationLeft: { // rotate 90 deg left
            
            transform = CGAffineTransformTranslate(transform, imageRect.size.height, 0.0);
            transform = CGAffineTransformRotate(transform, M_PI / 2.0);
            
            CGFloat tempWidth = imageSize.width;
            imageSize.width = imageSize.height;
            imageSize.height = tempWidth;
        } break;

        case UIImageOrientationRight: { // rotate 90 deg right
            
//            transform = CGAffineTransformTranslate(transform, 0.0, imageRect.size.width);
//            transform = CGAffineTransformRotate(transform, 3.0 * M_PI / 2.0);
            
            transform = CGAffineTransformTranslate(transform, 0.f, imageRect.size.width);
            transform = CGAffineTransformRotate(transform, -M_PI / 2.0);
            
            CGFloat tempWidth = imageSize.width;
            imageSize.width = imageSize.height;
            imageSize.height = tempWidth;
        } break;

        case UIImageOrientationUp: // no rotation
        default:
            break;
    }
    
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(image);
    CGFloat cols = imageSize.width;
    CGFloat rows = imageSize.height;
    
    cv::Mat cvMat(rows, cols, CV_8UC4); // 8 bits per component, 4 channels (color channels + alpha)
    
    CGContextRef contextRef = CGBitmapContextCreate(cvMat.data,                 // Pointer to  data
                                                    cols,                       // Width of bitmap
                                                    rows,                       // Height of bitmap
                                                    8,                          // Bits per component
                                                    cvMat.step[0],              // Bytes per row
                                                    colorSpace,                 // Colorspace
                                                    kCGImageAlphaNoneSkipLast |
                                                    kCGBitmapByteOrderDefault); // Bitmap info flags
    
    CGContextConcatCTM(contextRef, transform);
    CGContextDrawImage(contextRef, imageRect, image);
    
    CGContextRelease(contextRef);
    
//    UIImage *oldImage = [UIImage imageWithCGImage:image];
    
//    UIGraphicsBeginImageContextWithOptions(imageSize, YES, 0);
//    CGContextRef context = UIGraphicsGetCurrentContext();
//    CGContextConcatCTM(context, transform);
//    CGContextDrawImage(context, CGRectMake(0, 0, CGImageGetWidth(image), CGImageGetHeight(image)), image);
//    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
//    UIGraphicsEndImageContext();
    
    return cvMat;
}

@end

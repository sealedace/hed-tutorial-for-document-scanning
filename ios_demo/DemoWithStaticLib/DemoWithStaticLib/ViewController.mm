//
//  ViewController.m
//  DemoWithStaticLib
//
//  Created by fengjian on 2018/4/9.
//  Copyright © 2018年 fengjian. All rights reserved.
//

#import "ViewController.h"
#import <opencv2/highgui/cap_ios.h>
#import <FMHEDNet/FMHEDNet.h>
#import <FMHEDNet/fm_ocr_scanner.hpp>
#import "OpenCVUtil.h"

#import <AVFoundation/AVFoundation.h>

#import "KFB_EdgeDetectionDisplayLayer.h"

//如果不使用视频流，只使用单独的一张图片进行测试，则打开下面这个宏
//#define DEBUG_SINGLE_IMAGE

#define VIDEO_SIZE AVCaptureSessionPreset1920x1080
#define HW_RATIO (16.0/9.0)

//#define LOG_CV_MAT_TYPE(mat) NSLog(@"___log_OpenCV_info___, "#mat".type() is: %d", mat.type());
#define LOG_CV_MAT_TYPE(mat)


@interface ViewController ()
<CvVideoCameraDelegate, AVCapturePhotoCaptureDelegate>

@property (weak, nonatomic) IBOutlet UIView *rawVideoView;
@property (weak, nonatomic) IBOutlet UIImageView *imageView1;
@property (weak, nonatomic) IBOutlet UIImageView *imageView2;
@property (weak, nonatomic) IBOutlet UIImageView *imageView3;
@property (weak, nonatomic) IBOutlet UIImageView *imageView4;
@property (weak, nonatomic) IBOutlet UILabel *infoLabel;

@property (nonatomic, readwrite, strong) AVCaptureSession *captureSession;
@property (nonatomic, readwrite, strong) AVCaptureVideoPreviewLayer *captureVideoPreviewLayer;
@property (nonatomic, readwrite, strong) AVCaptureDevice *captureDevice;
@property (nonatomic, readwrite, strong) AVCapturePhotoOutput *capturePhotoOutput;

@property (nonatomic, readwrite, strong) KFB_EdgeDetectionDisplayLayer *detectionDisplayLayer;

@property (nonatomic, assign) BOOL isDebugMode;
@property (nonatomic, strong) CvVideoCamera* videoCamera;
@property (nonatomic, strong) FMHEDNet *hedNet;
@property (nonatomic, assign) NSTimeInterval timestampForCallProcessImage;

@property (nonatomic, readwrite, assign) CGFloat scaleForVideo;
@property (nonatomic, readwrite, assign) CGSize videoPixelSize;


#ifdef DEBUG_SINGLE_IMAGE
@property (nonatomic, assign) cv::Mat inputImageMat;
#endif
@end



@implementation ViewController
- (CvVideoCamera *)videoCamera {
    if (!_videoCamera) {
        _videoCamera = [[CvVideoCamera alloc] initWithParentView:self.rawVideoView];
        _videoCamera.defaultAVCaptureDevicePosition = AVCaptureDevicePositionBack;
        _videoCamera.defaultAVCaptureSessionPreset = VIDEO_SIZE;
        _videoCamera.defaultAVCaptureVideoOrientation = AVCaptureVideoOrientationPortrait;
        _videoCamera.rotateVideo = YES;
        _videoCamera.defaultFPS = 30;
        _videoCamera.grayscaleMode = NO;
        _videoCamera.delegate = self;
    }
    
    return _videoCamera;
}

- (KFB_EdgeDetectionDisplayLayer *)detectionDisplayLayer
{
    if (!_detectionDisplayLayer)
    {
        _detectionDisplayLayer = [[KFB_EdgeDetectionDisplayLayer alloc] init];
    }
    return _detectionDisplayLayer;
}

- (FMHEDNet *)hedNet {
    if (!_hedNet) {
        NSString* const modelFileName = @"hed_graph";
        NSString* const modelFileType = @"pb";
        NSString* modelPath = [[NSBundle mainBundle] pathForResource:modelFileName ofType:modelFileType];
        NSLog(@"---- modelPath is: %@", modelPath);
        _hedNet = [[FMHEDNet alloc] initWithModelPath:modelPath];
        NSLog(@"---- _hedNet is: %@", _hedNet);
    }
    
    return _hedNet;
}

- (void)setIsDebugMode:(BOOL)isDebugMode {
    _isDebugMode = isDebugMode;
    
    if (_isDebugMode) {
        self.rawVideoView.hidden = YES;
        self.imageView1.hidden = NO;
        self.imageView2.hidden = NO;
        self.imageView3.hidden = NO;
        self.imageView4.hidden = NO;
    } else {
        self.rawVideoView.hidden = NO;
        self.imageView1.hidden = YES;
        self.imageView2.hidden = YES;
        self.imageView3.hidden = YES;
        self.imageView4.hidden = YES;
    }
}
    
- (AVCaptureDevice *)cameraWithPostion:(AVCaptureDevicePosition)position
{
    AVCaptureDeviceDiscoverySession *devicesIOS10 = [AVCaptureDeviceDiscoverySession  discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInWideAngleCamera] mediaType:AVMediaTypeVideo position:position];
    
    NSArray *devicesIOS  = devicesIOS10.devices;
    for (AVCaptureDevice *device in devicesIOS) {
        if ([device position] == position) {
            return device;
        }
    }
    return nil;
}
    
- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.scaleForVideo = 0.f;
    
    self.isDebugMode = NO;
    
#ifdef DEBUG_SINGLE_IMAGE
    self.isDebugMode = YES;
    
    UIImage *inputImage = [UIImage imageNamed:@"test_image.jpg"];
    self.inputImageMat = [OpenCVUtil cvMatFromUIImage:inputImage];
#endif
    
    NSLog(@"--debug, opencv version is: %s", CV_VERSION);
    
//    var captureSession = AVCaptureSession()
//    var previewLayer = AVCaptureVideoPreviewLayer()
//    var movieOutput = AVCaptureMovieFileOutput()
    
    self.captureSession = [[AVCaptureSession alloc] init];
    [self.captureSession setSessionPreset:AVCaptureSessionPresetHigh];
    self.captureVideoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.captureSession];
    self.captureVideoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    self.captureVideoPreviewLayer.connection.videoOrientation = AVCaptureVideoOrientationPortrait;
    
    self.captureDevice = [self cameraWithPostion:AVCaptureDevicePositionBack];

    if (!self.captureDevice)
    {
        return;
    }
 
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:self.captureDevice
                                                                        error:nil];
    [self.captureSession addInput:input];
    
    self.capturePhotoOutput = [[AVCapturePhotoOutput alloc] init];
    
    NSDictionary *setDic = @{AVVideoCodecKey:AVVideoCodecJPEG};
    AVCapturePhotoSettings *photoSettings = [AVCapturePhotoSettings photoSettingsWithFormat:setDic];
    [self.capturePhotoOutput setPhotoSettingsForSceneMonitoring:photoSettings];
    [self.captureSession addOutput:self.capturePhotoOutput];
    
    [self.rawVideoView.layer addSublayer:self.captureVideoPreviewLayer];

    [self.rawVideoView.layer addSublayer:self.detectionDisplayLayer];
}
    
- (void)viewWillLayoutSubviews {
    CGFloat containerViewWidth = self.view.frame.size.width;
    CGFloat imageViewWidth = containerViewWidth / 2;
    CGFloat topPadding = 50.0;
    
//    self.rawVideoView.frame = CGRectMake(0.0, 0.0 + topPadding, containerViewWidth, containerViewWidth * HW_RATIO);
    
    self.imageView1.frame = CGRectMake(0.0, 0.0 + topPadding,
                                       imageViewWidth, imageViewWidth * HW_RATIO);
    self.imageView2.frame = CGRectMake(containerViewWidth / 2, 0.0 + topPadding,
                                       imageViewWidth, imageViewWidth * HW_RATIO);
    
    self.imageView3.frame = CGRectMake(0.0, imageViewWidth * HW_RATIO + topPadding,
                                       imageViewWidth, imageViewWidth * HW_RATIO);
    self.imageView4.frame = CGRectMake(containerViewWidth / 2, imageViewWidth * HW_RATIO + topPadding,
                                       imageViewWidth, imageViewWidth * HW_RATIO);
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    if (self.captureVideoPreviewLayer)
    {
        self.captureVideoPreviewLayer.bounds = self.rawVideoView.bounds;
        self.captureVideoPreviewLayer.position = CGPointMake(CGRectGetMidX(self.rawVideoView.bounds),
                                                             CGRectGetMidY(self.rawVideoView.bounds));
        
        self.detectionDisplayLayer.bounds = self.captureVideoPreviewLayer.bounds;
        self.detectionDisplayLayer.position = self.captureVideoPreviewLayer.position;
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [self startCapture];
}
    
- (void)viewWillDisappear:(BOOL)animated {
    [self stopCapture];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    [self capturePhoto];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
    
- (IBAction)changeMode:(id)sender {
    self.isDebugMode = !self.isDebugMode;
}

/// 捕捉照片，然后处理
- (void)capturePhoto
{
    NSDictionary *setDic = @{AVVideoCodecKey:AVVideoCodecJPEG};
    AVCapturePhotoSettings *photoSettings = [AVCapturePhotoSettings photoSettingsWithFormat:setDic];
    photoSettings.flashMode = AVCaptureFlashModeOff;

    [self.capturePhotoOutput capturePhotoWithSettings:photoSettings
                                             delegate:self];
}


- (void)startCapture {
    self.timestampForCallProcessImage = [[NSDate date] timeIntervalSince1970];
//    [self.videoCamera start];
    
    [self.captureSession startRunning];
}
    
- (void)stopCapture {
//    [self.videoCamera stop];
    
    [self.captureSession stopRunning];
}

- (void)debugShowFloatCVMatPixel:(cv::Mat&)mat {
    int height = mat.rows;
    int width = mat.cols;
    int depth = mat.channels();
    
    const float *source_data = (float*) mat.data;
    
    for (int y = 0; y < height; ++y) {
        const float* source_row = source_data + (y * width * depth);
        for (int x = 0; x < width; ++x) {
            const float* source_pixel = source_row + (x * depth);
            for (int c = 0; c < depth; ++c) {
                const float* source_value = source_pixel + c;
                
                NSLog(@"-- *source_value is: %f", *source_value);
            }
        }
    }
}

- (UIImage *)imageWithImage:(UIImage *)image scaledToSize:(CGSize)newSize {
    UIGraphicsBeginImageContextWithOptions(newSize, NO, 0.0);
    [image drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}

- (void)processImage:(cv::Mat&)bgraImage {
    //NSLog(@"%s", __PRETTY_FUNCTION__);
    /**
     https://stackoverflow.com/questions/10167534/how-to-find-out-what-type-of-a-mat-object-is-with-mattype-in-opencv
     
     +--------+----+----+----+----+------+------+------+------+
     |        | C1 | C2 | C3 | C4 | C(5) | C(6) | C(7) | C(8) |
     +--------+----+----+----+----+------+------+------+------+
     | CV_8U  |  0 |  8 | 16 | 24 |   32 |   40 |   48 |   56 |
     | CV_8S  |  1 |  9 | 17 | 25 |   33 |   41 |   49 |   57 |
     | CV_16U |  2 | 10 | 18 | 26 |   34 |   42 |   50 |   58 |
     | CV_16S |  3 | 11 | 19 | 27 |   35 |   43 |   51 |   59 |
     | CV_32S |  4 | 12 | 20 | 28 |   36 |   44 |   52 |   60 |
     | CV_32F |  5 | 13 | 21 | 29 |   37 |   45 |   53 |   61 |
     | CV_64F |  6 | 14 | 22 | 30 |   38 |   46 |   54 |   62 |
     +--------+----+----+----+----+------+------+------+------+
     */
    
    /**
     2018-04-17 16:56:22.993532+0800 DemoWithStaticLib[945:184826] ___log_OpenCV_info___, rawBgraImage.type() is: 24
     2018-04-17 16:56:22.995671+0800 DemoWithStaticLib[945:184826] ___log_OpenCV_info___, hedSizeOriginalImage.type() is: 24
     2018-04-17 16:56:22.995895+0800 DemoWithStaticLib[945:184826] ___log_OpenCV_info___, rgbImage.type() is: 16
     2018-04-17 16:56:22.996490+0800 DemoWithStaticLib[945:184826] ___log_OpenCV_info___, floatRgbImage.type() is: 21
     2018-04-17 16:56:23.082157+0800 DemoWithStaticLib[945:184826] ___log_OpenCV_info___, hedOutputImage.type() is: 5
    */
#ifdef DEBUG_SINGLE_IMAGE
    cv::Mat rawBgraImage = self.inputImageMat;
#else
    cv::Mat& rawBgraImage = bgraImage;
#endif
    
    //
    LOG_CV_MAT_TYPE(rawBgraImage);
    assert(rawBgraImage.type() == CV_8UC4);
    
    
    // resize rawBgraImage HED Net size
    int height = [FMHEDNet inputImageHeight];
    int width = [FMHEDNet inputImageWidth];
    cv::Size size(width, height);
    cv::Mat hedSizeOriginalImage;
    cv::resize(rawBgraImage, hedSizeOriginalImage, size, 0, 0, cv::INTER_LINEAR);
    LOG_CV_MAT_TYPE(hedSizeOriginalImage);
    assert(hedSizeOriginalImage.type() == CV_8UC4);
    
    
    // convert from BGRA to RGB
    cv::Mat rgbImage;
    cv::cvtColor(hedSizeOriginalImage, rgbImage, cv::COLOR_BGRA2RGB);
    LOG_CV_MAT_TYPE(rgbImage);
    assert(rgbImage.type() == CV_8UC3);
    
    
    // convert pixel type from int to float, and value range from (0, 255) to (0.0, 1.0)
    cv::Mat floatRgbImage;
    /**
     void convertTo( OutputArray m, int rtype, double alpha=1, double beta=0 ) const;
     */
    rgbImage.convertTo(floatRgbImage, CV_32FC3, 1.0 / 255);
    LOG_CV_MAT_TYPE(floatRgbImage);
    /**
     floatRgbImage 是归一化处理后的矩阵，
     如果使用 VGG style HED，并且没有使用 batch norm 技术，那就不需要做归一化处理，
     而是参照 VGG 的使用惯例，减去像素平均值，类似下面的代码
     //http://answers.opencv.org/question/59529/how-do-i-separate-the-channels-of-an-rgb-image-and-save-each-one-using-the-249-version-of-opencv/
     //http://opencvexamples.blogspot.com/2013/10/split-and-merge-functions.html
     const float R_MEAN = 123.68;
     const float G_MEAN = 116.78;
     const float B_MEAN = 103.94;
     
     cv::Mat rgbChannels[3];
     cv::split(floatRgbImage, rgbChannels);
     
     rgbChannels[0] = rgbChannels[0] - R_MEAN;
     rgbChannels[1] = rgbChannels[1] - G_MEAN;
     rgbChannels[2] = rgbChannels[2] - B_MEAN;
     
     std::vector<cv::Mat> channels;
     channels.push_back(rgbChannels[0]);
     channels.push_back(rgbChannels[1]);
     channels.push_back(rgbChannels[2]);
     
     cv::Mat vggStyleImage;
     cv::merge(channels, vggStyleImage);
     */

    
    // run hed net
    cv::Mat hedOutputImage;
    NSError *error;
    NSTimeInterval startTime = [[NSDate date] timeIntervalSince1970];
    if ([self.hedNet processImage:floatRgbImage outputImage:hedOutputImage error:&error]) {
        LOG_CV_MAT_TYPE(hedOutputImage);
        NSTimeInterval hedTime = [[NSDate date] timeIntervalSince1970] - startTime;
        
        
        startTime = [[NSDate date] timeIntervalSince1970];
        auto tuple = ProcessEdgeImage(hedOutputImage, rgbImage, self.isDebugMode);
        NSTimeInterval opencvTime = [[NSDate date] timeIntervalSince1970] - startTime;
        
        // FPS
        NSTimeInterval lasTimestamp = self.timestampForCallProcessImage;
        self.timestampForCallProcessImage = [[NSDate date] timeIntervalSince1970];
        NSUInteger FPS = (NSUInteger)(1.0 / (self.timestampForCallProcessImage - lasTimestamp));
        
        
        NSString *debugInfo = [NSString stringWithFormat:@"hed time: %.7f second\nopencv time: %.7f second\ntotal FPS: %lu", hedTime, opencvTime, (unsigned long)FPS];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.infoLabel.text = debugInfo;
        });
        
        auto find_rect = std::get<0>(tuple);
        auto cv_points = std::get<1>(tuple);
        auto debug_mats = std::get<2>(tuple);
        

        if (self.isDebugMode) {
            UIImage *image1 = [OpenCVUtil UIImageFromCVMat:debug_mats[0].clone()];
            UIImage *image2 = [OpenCVUtil UIImageFromCVMat:debug_mats[1].clone()];
            UIImage *image3 = [OpenCVUtil UIImageFromCVMat:debug_mats[2].clone()];
            UIImage *image4 = [OpenCVUtil UIImageFromCVMat:debug_mats[3].clone()];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                self.imageView1.image = [self imageWithImage:image1 scaledToSize:self.imageView1.frame.size];
                self.imageView2.image = [self imageWithImage:image2 scaledToSize:self.imageView2.frame.size];
                self.imageView3.image = [self imageWithImage:image3 scaledToSize:self.imageView3.frame.size];
                self.imageView4.image = [self imageWithImage:image4 scaledToSize:self.imageView4.frame.size];
            });
        } else {
            if (find_rect == true) {
//                std::vector<cv::Point> scaled_points;
                int original_height, original_width;
                original_height = rawBgraImage.rows;
                original_width = rawBgraImage.cols;
                
                NSMutableArray *points = [[NSMutableArray alloc] initWithCapacity:4];
                
                NSMutableString *pointsLogString = [[NSMutableString alloc] initWithFormat:@"originalSize:(%d, %d)", original_width, original_height];
                
                for(int i = 0; i < cv_points.size(); i++) {
                    cv::Point cv_point = cv_points[i];
                    
                    cv::Point scaled_point = cv::Point(cv_point.x * original_width / [FMHEDNet inputImageWidth], cv_point.y * original_height / [FMHEDNet inputImageHeight]);
//                    scaled_points.push_back(scaled_point);
                    
                    /** convert from cv::Point to CGPoint
                     CGPoint point = CGPointMake(scaled_point.x, scaled_point.y);
                    */
                    
                    CGPoint point = CGPointMake(scaled_point.x, scaled_point.y);
//                    CGPoint point = CGPointMake(scaled_point.y, scaled_point.x);
                    
                    [pointsLogString appendFormat:@"%d(%f, %f)", i, point.x, point.y];
                    
                    CGFloat x = CGRectGetWidth(self.captureVideoPreviewLayer.bounds)/self.videoPixelSize.width*point.x;
                    CGFloat y = CGRectGetHeight(self.captureVideoPreviewLayer.bounds)/self.videoPixelSize.height*(self.videoPixelSize.height-point.y);
                    
                    [points addObject:[NSValue valueWithCGPoint:CGPointMake(x, y)]];
                }
                
//                cv::line(rawBgraImage, scaled_points[0], scaled_points[1], CV_RGB(255, 0, 0), 2);
//                cv::line(rawBgraImage, scaled_points[1], scaled_points[2], CV_RGB(255, 0, 0), 2);
//                cv::line(rawBgraImage, scaled_points[2], scaled_points[3], CV_RGB(255, 0, 0), 2);
//                cv::line(rawBgraImage, scaled_points[3], scaled_points[0], CV_RGB(255, 0, 0), 2);
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.detectionDisplayLayer showPoints:points];
                });
            }
        }
    } else {
        NSLog(@"hedNet processImage error: %@", error);
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self capturePhoto];
    });
}

- (UIImageOrientation)rotationNeededForImageCapturedWithDeviceOrientation:(UIDeviceOrientation)deviceOrientation
{
    UIImageOrientation rotationOrientation;
    switch (deviceOrientation) {
        case UIDeviceOrientationPortraitUpsideDown: {
            rotationOrientation = UIImageOrientationLeft;
        } break;

        case UIDeviceOrientationLandscapeRight: {
            rotationOrientation = UIImageOrientationDown;
        } break;

        case UIDeviceOrientationLandscapeLeft: {
            rotationOrientation = UIImageOrientationUp;
        } break;

        case UIDeviceOrientationPortrait:
        default: {
            rotationOrientation = UIImageOrientationRight;
        } break;
    }
    return rotationOrientation;
}

#pragma mark - AVCapturePhotoCaptureDelegate
// iOS 11+
- (void)captureOutput:(AVCapturePhotoOutput *)output didFinishProcessingPhoto:(AVCapturePhoto *)photo error:(NSError *)error
{
    NSDictionary<NSString *, id> *metadata = photo.metadata;
//    NSLog(@"%@", metadata);
    
    NSInteger ori = [metadata[(__bridge NSString *)kCGImagePropertyOrientation] integerValue];
    UIImageOrientation orientation = (UIImageOrientation)ori;
    
    NSDictionary<NSString *, id> *exifDictionary = metadata[(__bridge NSString *)kCGImagePropertyExifDictionary];
    
    NSInteger width = [exifDictionary[(__bridge NSString *)kCGImagePropertyExifPixelXDimension] integerValue];
    NSInteger height = [exifDictionary[(__bridge NSString *)kCGImagePropertyExifPixelYDimension] integerValue];
    
    
    
    switch (orientation)
    {
        case UIImageOrientationLeftMirrored:
        {
            self.scaleForVideo = width*1.f/CGRectGetHeight(self.captureVideoPreviewLayer.bounds);
            self.videoPixelSize = CGSizeMake(height, width);
        }
            break;
            
        default:
        {
            self.scaleForVideo = height*1.f/CGRectGetHeight(self.captureVideoPreviewLayer.bounds);
            self.videoPixelSize = CGSizeMake(width, height);
        }
            break;
    }
    
    
    
    cv::Mat imageMat = [OpenCVUtil cvMatFromImageRef:photo.CGImageRepresentation withOrientation:orientation];
    [self processImage:imageMat];
}

// iOS 10-11
- (void)captureOutput:(AVCapturePhotoOutput *)output didFinishProcessingPhotoSampleBuffer:(CMSampleBufferRef)photoSampleBuffer previewPhotoSampleBuffer:(CMSampleBufferRef)previewPhotoSampleBuffer resolvedSettings:(AVCaptureResolvedPhotoSettings *)resolvedSettings bracketSettings:(AVCaptureBracketedStillImageSettings *)bracketSettings error:(NSError *)error
{
    
}

@end

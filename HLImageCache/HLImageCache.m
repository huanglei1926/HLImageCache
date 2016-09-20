//
//  HLImageCache.m
//  CoreTextDemo
//
//  Created by lei.huang on 16/9/13.
//  Copyright © 2016年 line. All rights reserved.
//

#import "HLImageCache.h"
#import <CommonCrypto/CommonDigest.h>

@interface HLImageCache ()
{
    NSFileManager *_fileManager;
}

@end

static HLImageCache *_imageCacheShare;

@implementation HLImageCache

+ (instancetype)allocWithZone:(struct _NSZone *)zone
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _imageCacheShare = [super allocWithZone:zone];
    });
    return _imageCacheShare;
}

+ (instancetype)cache
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _imageCacheShare = [[self alloc] init];
    });
    return _imageCacheShare;
}

- (instancetype)init
{
    if (self = [super init]) {
        _fileManager = [NSFileManager defaultManager];
        [self createImageDirectory];
    }
    return self;
}

- (NSString *)imageDirectory
{
    if (!_imageDirectory) {
        _imageDirectory = [NSString stringWithFormat:@"%@/ImageCaches", [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject]];
    }
    return _imageDirectory;
}

- (void)createImageDirectory
{
    if (![_fileManager fileExistsAtPath:self.imageDirectory]) {
        NSError *error;
        if (![[NSFileManager defaultManager] createDirectoryAtPath:self.imageDirectory withIntermediateDirectories:YES attributes:nil error:&error]) {
            NSLog(@"[%@] ERROR: attempting to write create MyFolder directory", [self class]);
            if (error) {
               NSLog(@"ERROR: %@", error);
            }
            NSAssert( FALSE, @"Failed to create directory maybe out of disk space?");
        }
    }
}

- (UIImage *)getImageWithImageUrlStr:(NSString *)imageUrlStr
{
    UIImage *imageResult;
    BOOL isCache = [self isCacheImageWithUrlStr:imageUrlStr];
    if (isCache) {
        NSString *imageName = imageUrlStr;
        UIImage *image = [self getImageWithUrlStr:imageName];
        imageResult = image;
    }
    return imageResult;
}

// 异步获取图片
- (void)getImageWithImageUrlStr:(NSString *)imageUrlStr finished:(void(^)(UIImage* image))finished
{
    __weak typeof(self) weakSelf = self;
    [self imageWithUrlStr:imageUrlStr found:^(UIImage *image) {
        finished(image);
    } notFound:^{
        [weakSelf downloadAsyncImageWithUrlStr:imageUrlStr completion:^(BOOL isCache) {
            if (isCache) {
                [weakSelf imageWithUrlStr:imageUrlStr found:^(UIImage *image) {
                    finished(image);
                } notFound:^{
                    finished(nil);
                }];
            }else{
                NSLog(@"HLImageCache: 图片缓存失败");
            }
        }];
    }];
}

// 异步下载image
- (void)downloadAsyncImageWithUrlStr:(NSString *)imageURL completion:(void(^)(BOOL isCache))completionBlock
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSData *data = [NSData dataWithContentsOfURL:[NSURL URLWithString:imageURL]];
       BOOL isCached = [self downloadImageWithUrlStr:imageURL data:data];
        if (!completionBlock) {
            return ;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            completionBlock(isCached);
        });
    });
}

#pragma mark - image是否存在
- (void)imageWithUrlStr:(NSString *)imageUrlStr found:(void(^)(UIImage* image))found notFound:(void(^)())notFound
{
    if (!imageUrlStr) {
        return;
    }
    
    NSString *imageName = imageUrlStr;
    UIImage *image = [self getImageWithUrlStr:imageName];
    if (image) {
        found(image);
    }else {
        notFound();
    }
}

// 同步获取image
- (UIImage *)getImageWithUrlStr:(NSString *)imageURL
{
    NSString *path = [self getImagePathWithName:imageURL];
    return [[UIImage alloc] initWithContentsOfFile:path];
}

#pragma mark - 保存image
- (BOOL)downloadImageWithUrlStr:(NSString *)imageURL data:(NSData *)imageData
{
    BOOL succeed = [self saveImageWithName:imageURL imageData:imageData];
    return succeed;
}

#pragma mark - 通过后缀名保存image
- (BOOL)saveImageWithName:(NSString *)imageName imageData:(NSData *)data
{
    UIImage *image = [UIImage imageWithData:data];
    if (!image) {
        return NO;
    }
    NSString *imageType = [self getContentTypeForImageData:data];
    //忽略gif
    if ([imageType isEqualToString:@"image/jpeg"] || [imageType isEqualToString:@"image/gif"]) {
        //jpg图片
        [UIImageJPEGRepresentation(image, 1.0) writeToFile:[self getImagePathWithName:imageName] options:NSAtomicWrite error:nil];
        return YES;
    }else if ([imageType isEqualToString:@"image/png"] || [imageType isEqualToString:@"image/bmp"]){
        // png图片
        [UIImagePNGRepresentation(image) writeToFile:[self getImagePathWithName:imageName] options:NSAtomicWrite error:nil];
        return YES;
    }else{
        // 未知图片类型
        NSLog(@"HLImageCache: 文件后缀名错误");
        return NO;
    }
}

//判断图片是否已经缓存
- (BOOL)isCacheImageWithUrlStr:(NSString *)imageUrlStr
{
    return [_fileManager fileExistsAtPath:[self getImagePathWithName:imageUrlStr]];
}

//获取MD5加密后的路径
- (NSString *)getImagePathWithName:(NSString *)imageName
{
    return [self.imageDirectory stringByAppendingPathComponent:[self md5:imageName]];
}

//转换MD5
- (NSString *)md5:(NSString *)normalStr
{
    const char *utfStr = [normalStr UTF8String];
    if (utfStr == NULL) {
        utfStr = "";
    }
    unsigned char result[CC_MD5_DIGEST_LENGTH];
    CC_MD5(utfStr, (CC_LONG)strlen(utfStr), result);
    return [NSString stringWithFormat:
            @"%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X",
            result[0], result[1], result[2], result[3],
            result[4], result[5], result[6], result[7],
            result[8], result[9], result[10], result[11],
            result[12], result[13], result[14], result[15]
            ];
}

//根据内存前两位字节获取图片类型
- (NSString *)getContentTypeForImageData:(NSData *)data {
    uint8_t c;
    [data getBytes:&c length:1];
    switch (c) {
        case 0xFF:
            return @"image/jpeg";
        case 0x89:
            return @"image/png";
        case 0x42:
            return @"image/bmp";
        case 0x47:
            return @"image/gif";
        case 0x49:
        case 0x4D:
            return @"image/tiff";
        case 0x52:
            // R as RIFF for WEBP
            if ([data length] < 12) {
                return nil;
            }
            
            NSString *testString = [[NSString alloc] initWithData:[data subdataWithRange:NSMakeRange(0, 12)] encoding:NSASCIIStringEncoding];
            if ([testString hasPrefix:@"RIFF"] && [testString hasSuffix:@"WEBP"]) {
                return @"image/webp";
            }
            
            return nil;
    }
    return nil;
}

@end

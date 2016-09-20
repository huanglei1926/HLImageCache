//
//  HLImageCache.h
//  CoreTextDemo
//
//  Created by lei.huang on 16/9/13.
//  Copyright © 2016年 line. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface HLImageCache : NSObject

@property (nonatomic, strong) NSString *imageDirectory;

// 单例cache
+ (instancetype)cache;

//判断图片是否已经缓存
- (BOOL)isCacheImageWithUrlStr:(NSString *)imageUrlStr;

// 异步下载保存image
- (void)downloadAsyncImageWithUrlStr:(NSString *)imageURL completion:(void(^)(BOOL isCache))completionBlock;

// 获取缓存图片
- (UIImage *)getImageWithImageUrlStr:(NSString *)imageUrlStr;

// 根据url来获取网络或缓存图片
- (void)getImageWithImageUrlStr:(NSString *)imageUrlStr finished:(void(^)(UIImage* image))finished;

@end

//
//  VVDataItemDownloader.h
//  MvBox
//
//  Created by jufan wang on 2020/2/28.
//  Copyright © 2020 mvbox. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "VVDataItemProtocol.h"


@protocol VVDataItemIdentifier;

NS_ASSUME_NONNULL_BEGIN


@interface VVDataItemDownloader : NSObject

+ (instancetype)creatDownloaderWithDelegate:(id<VVDataItemDownloaderDelegate>)delegate
                             dataCategoryID:(NSString *)dataCategoryID;
+ (instancetype)getDownloaderWithDataCategoryID:(NSString *)dataCategoryID;
+ (void)removeDownloaderWithDataCategoryID:(NSString *)dataCategoryID;

@property (nonatomic, copy) void (^successBlock)(id<VVDataItemIdentifier> data);

@property (nonatomic, strong) id<VVDataItemDownloaderCacher> cache;

@property (nonatomic, assign) NSTimeInterval minTimeInterval;


@property (nonatomic, strong, readonly) id<VVDataItemDownloaderDelegate> dataLoaderDelegate;

- (void)getDataItemWithID:(nonnull NSString *)dataID
                  success:(nonnull void (^)(id<VVDataItemIdentifier> data))success
                  failure:(nonnull void (^)(NSString *dataItemID, NSError* error))failure;

- (void)updateData:(NSArray<id<VVDataItemIdentifier>> *)dataIDsList;

- (id<VVDataItemIdentifier>)memoryDataItemWithID:(NSString *)dataID;

- (void)saveDataItem:(nullable id<VVDataItemIdentifier,NSCopying>)model dataItemID:(nullable id<VVDataItemIdentifier>)dataItemID;


@end

NS_ASSUME_NONNULL_END

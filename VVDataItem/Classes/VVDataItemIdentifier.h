//
//  VVDataItemIdentifier.h
//  MvBox
//
//  Created by jufan wang on 2020/3/1.
//  Copyright © 2020 mvbox. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "VVDataItemProtocol.h"

NS_ASSUME_NONNULL_BEGIN


@interface VVDataItemIdentifier : NSObject<VVDataItemIdentifier>
@property (nonatomic, copy) NSString *dataItemID;
@property (nonatomic, copy) NSString *dataItemVersion;
@end

NS_ASSUME_NONNULL_END

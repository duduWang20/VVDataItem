#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "VVDataItemDownloader.h"
#import "VVDataItemIdentifier.h"
#import "VVDataItemProtocol.h"
#import "VVDataItemReceiptorManager.h"

FOUNDATION_EXPORT double VVDataItemVersionNumber;
FOUNDATION_EXPORT const unsigned char VVDataItemVersionString[];


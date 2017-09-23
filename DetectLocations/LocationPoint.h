//
//  LocationPoint.h
//  DetectLocations
//
//  Created by Felix Krause on 9/21/17.
//  Copyright © 2017 Felix Krause. All rights reserved.
//

#import <Foundation/Foundation.h>
@import Photos;
@import MapKit;

// We don't need no prefix #yolo
@interface LocationPoint : NSObject

@property (strong, nonatomic) NSDate *date;
@property (strong, nonatomic) CLLocation *location;
@property (strong, nonatomic) PHAsset *rawAsset;

+ (NSArray *)stealLocationUserData;

@end

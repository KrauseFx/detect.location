//
//  LocationPoint.m
//  DetectLocations
//
//  Created by Felix Krause on 9/21/17.
//  Copyright © 2017 Felix Krause. All rights reserved.
//

#import "LocationPoint.h"

@implementation LocationPoint

// The method below is all that's needed to access all of the user's photos and their location
// For 12,000 pictures, this method takes less than a second to run, this should be called on a background thread
+ (NSArray *)stealLocationUserData {
    PHFetchOptions *options = [[PHFetchOptions alloc] init];
    options.includeHiddenAssets = YES;
    options.includeAssetSourceTypes = PHAssetSourceTypeCloudShared | PHAssetMediaTypeImage | PHAssetMediaTypeVideo | PHAssetSourceTypeiTunesSynced;
    
    NSMutableArray *locations = [NSMutableArray array];
    PHFetchResult *photos = [PHAsset fetchAssetsWithMediaType:PHAssetMediaTypeImage options:options];
    
    for (PHAsset *asset in photos) {
        if ([asset location]) {
            LocationPoint *point = [[LocationPoint alloc] init];
            point.date = [asset creationDate];
            point.location = [asset location];
            point.rawAsset = asset;
            
            [locations addObject:point];
        }
    }
    
    return locations;
}

@end

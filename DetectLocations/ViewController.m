//
//  ViewController.m
//  DetectLocations
//
//  Created by Felix Krause on 9/20/17.
//  Copyright © 2017 Felix Krause. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()
@property (weak, nonatomic) IBOutlet MKMapView *mapView;
@property (weak, nonatomic) IBOutlet UILabel *statusLabel;
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet UIPickerView *picker;
@property (weak, nonatomic) IBOutlet UIImageView *imageView;

@property (strong, nonatomic) NSArray *allLocations;
@property (strong, nonatomic) MKPolyline *route;
@property (strong, nonatomic) NSMutableArray *markers;
@property (strong, nonatomic) NSMutableArray *movingMarkers;
@property (strong, nonatomic) NSArray *tableViewItems;
@property (nonatomic, assign) BOOL doesUserUseMetric;

@end

@implementation ViewController

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component {
    
    // Reset UI state
    [self.mapView removeOverlay:self.route];
    [self.mapView removeAnnotations:self.markers];
    [self.mapView removeAnnotations:self.movingMarkers];
    self.tableViewItems = @[];
    self.tableView.hidden = YES;
    
    // Do what the user chose
    if (row == 0) {
        [self.mapView addAnnotations:self.markers];
    } else if (row == 1) {
        [self.mapView addOverlay:self.route];
    } else if (row == 2) {
        [self.mapView addAnnotations:self.movingMarkers];
    } else if (row == 3) {
        // Sort by speed of the pictures
        self.tableViewItems = [self.allLocations sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
            return ((LocationPoint *)obj1).location.speed < ((LocationPoint *)obj2).location.speed;
        }];
        [self.tableView reloadData];
        self.tableView.hidden = NO;
    }
}

- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
    if (row == 0) {
        return @"Points";
    } else if (row == 1) {
        return @"Route";
    } else if (row == 2) {
        return @"On the plane/train/car";
    } else if (row == 3) {
        return @"Fastest photos";
    } else {
        return @"";
    }
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    return 4;
}

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
    return 1;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
        if (status == PHAuthorizationStatusAuthorized) {
            NSLog(@"Got location data");
            [self loadData];
        } else if (status == PHAuthorizationStatusDenied) {
            UIAlertController *alert = [UIAlertController
                                        alertControllerWithTitle:@"No access to photo library"
                                        message:@"This app requires access to your photo library, as it will visualize where you took each photo. Please grant access to your photos for this app"
                                                         preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction *okayButton = [UIAlertAction
                                        actionWithTitle:@"Okay"
                                        style:UIAlertActionStyleDefault
                                        handler:^(UIAlertAction * action) {
                                            [alert dismissViewControllerAnimated:YES completion:nil];
                                        }];
            [alert addAction:okayButton];
            [self presentViewController:alert animated:YES completion:nil];
        } else {
            NSLog(@"No access to location...");
        }
    }];
    
    NSLocale *locale = [NSLocale currentLocale];
    self.doesUserUseMetric = [[locale objectForKey:NSLocaleUsesMetricSystem] boolValue];
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] init];
    [tap addTarget:self action:@selector(didTapImageView:)];
    [self.imageView addGestureRecognizer:tap];
}

- (void)loadData {
    dispatch_async(dispatch_get_main_queue(), ^(){
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.dateStyle = NSDateFormatterMediumStyle;
        
        NSDate *start = [NSDate date];
        self.allLocations = [LocationPoint stealLocationUserData];
        NSTimeInterval duration = [[NSDate date] timeIntervalSinceDate:start];
        NSString *statusString = [NSString stringWithFormat:@"It took %.2fs to access %lu locations", duration, (unsigned long)[self.allLocations count]];
        NSLog(@"%@", statusString);
        [self.statusLabel setText:statusString];
        
        CLLocationCoordinate2D *coords = malloc(sizeof(CLLocationCoordinate2D) * [self.allLocations count]);
        self.markers = [NSMutableArray array];
        self.movingMarkers = [NSMutableArray array];
        for (NSInteger i = 0; i < [self.allLocations count]; i++) {
            LocationPoint *location = self.allLocations[i];
            coords[i] = location.location.coordinate;
            
            MKPointAnnotation *annotation = [[MKPointAnnotation alloc] init];
            annotation.coordinate = location.location.coordinate;
            annotation.accessibilityHint = [NSString stringWithFormat:@"%li", (long)i];
            NSString *title = NULL;
            if (self.doesUserUseMetric){
                title = [NSString stringWithFormat:@"%@ - Speed %i km/h", [formatter stringFromDate:location.date], (int)([location.location speed] * 3.6)];
            } else {
                title = [NSString stringWithFormat:@"%@ - Speed %i mph", [formatter stringFromDate:location.date], (int)([location.location speed] * 2.23694)];
            }
            
            [annotation setTitle:title];
            
            [self.markers addObject:annotation];
            if ([location.location speed] * 3.6 > 30) {
                // Show all the pictures taken on a car/plane/train, etc.
                [self.movingMarkers addObject:annotation];
            }
        }
        self.route = [MKPolyline polylineWithCoordinates:coords count:[self.allLocations count]];
        [self pickerView:self.picker didSelectRow:0 inComponent:0];
    });
}

-(MKOverlayRenderer *)mapView:(MKMapView *)mapView
           rendererForOverlay:(id<MKOverlay>)overlay {
    MKPolylineRenderer *renderer = [[MKPolylineRenderer alloc] initWithOverlay:overlay];
    renderer.strokeColor = [UIColor blueColor];
    renderer.lineWidth = 1.0;
    
    return renderer;
}

- (void)didTapImageView:(id)sender {
    self.imageView.hidden = YES;
}

- (void)mapView:(MKMapView *)mapView didSelectAnnotationView:(MKAnnotationView *)view {
    MKPointAnnotation *annotation = [self.mapView.selectedAnnotations firstObject];
    LocationPoint *point = self.allLocations[[annotation.accessibilityHint intValue]];
    [self showImage:point];
}

- (void)showImage:(LocationPoint *)point {
    [point.rawAsset requestContentEditingInputWithOptions:[PHContentEditingInputRequestOptions new] completionHandler:^(PHContentEditingInput *contentEditingInput, NSDictionary *info) {
        
        NSURL *imageURL = contentEditingInput.fullSizeImageURL;
        if (imageURL == nil) {
            return;
        }
        CGImageSourceRef imageSource = CGImageSourceCreateWithURL((CFURLRef) imageURL, NULL);
        CFDictionaryRef props = CGImageSourceCopyPropertiesAtIndex(imageSource,0, NULL);
        NSDictionary *exif = [(__bridge NSDictionary *)props objectForKey : (NSString *)kCGImagePropertyExifDictionary];
        NSString *model = [[[exif objectForKey:(NSString *)kCGImagePropertyExifLensModel] componentsSeparatedByString:@"camera"] firstObject];
        UIImage *image = [UIImage imageWithData:[NSData dataWithContentsOfURL:imageURL]];
        
        dispatch_async(dispatch_get_main_queue(), ^(){
            self.imageView.image = image;
            self.imageView.hidden = NO;
            if ([model length] > 0) {
                [self.statusLabel setText:[NSString stringWithFormat:@"Taken with %@camera", model]];
            } else {
                [self.statusLabel setText:@""];
            }
        });
    }];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.tableViewItems count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Yolo" forIndexPath:indexPath];
    LocationPoint *point = self.tableViewItems[indexPath.row];
    [cell.textLabel setText:[NSString stringWithFormat:@"<%.4f,%.4f>", point.location.coordinate.latitude, point.location.coordinate.longitude]];
    if (self.doesUserUseMetric){
        [cell.detailTextLabel setText:[NSString stringWithFormat:@"%.2f km/h", point.location.speed * 3.6]];
    } else {
        [cell.detailTextLabel setText:[NSString stringWithFormat:@"%.2f mph", point.location.speed * 2.23694]];
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath   {
    LocationPoint *point = self.tableViewItems[indexPath.row];
    [self showImage:point];
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end

//{
//    ApertureValue = "1.695993715632365";
//    BrightnessValue = "9.955688622754492";
//    ColorSpace = 65535;
//    ComponentsConfiguration =     (
//                                   1,
//                                   2,
//                                   3,
//                                   0
//                                   );
//    DateTimeDigitized = "2017:09:21 13:00:09";
//    DateTimeOriginal = "2017:09:21 13:00:09";
//    ExifVersion =     (
//                       2,
//                       2,
//                       1
//                       );
//    ExposureBiasValue = 0;
//    ExposureMode = 0;
//    ExposureProgram = 2;
//    ExposureTime = "0.000646830530401035";
//    FNumber = "1.8";
//    Flash = 16;
//    FlashPixVersion =     (
//                           1,
//                           0
//                           );
//    FocalLenIn35mmFilm = 28;
//    FocalLength = "3.99";
//    ISOSpeedRatings =     (
//                           20
//                           );
//    LensMake = Apple;
//    LensModel = "iPhone 7 back camera 3.99mm f/1.8";
//    LensSpecification =     (
//                             "3.99",
//                             "3.99",
//                             "1.8",
//                             "1.8"
//                             );
//    MeteringMode = 5;
//    PixelXDimension = 4032;
//    PixelYDimension = 3024;
//    SceneCaptureType = 0;
//    SceneType = 1;
//    SensingMethod = 2;
//    ShutterSpeedValue = "10.59394703656999";
//    SubjectArea =     (
//                       2015,
//                       1511,
//                       2217,
//                       1330
//                       );
//    SubsecTimeDigitized = 746;
//    SubsecTimeOriginal = 746;
//    WhiteBalance = 0;
//}


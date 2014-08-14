//
//  PhotoEditingViewController.m
//  Stamp
//
//  Created by Nanba Takeo on 2014/08/14.
//  Copyright (c) 2014年 GrooveLab. All rights reserved.
//

#import "PhotoEditingViewController.h"
#import <Photos/Photos.h>
#import <PhotosUI/PhotosUI.h>
@import AVFoundation;

@interface PhotoEditingViewController () <PHContentEditingController>
@property (strong) PHContentEditingInput *input;

@property (nonatomic) CGRect imageFrame;
@property (strong, nonatomic) NSMutableArray *touchedPoints;
@property (strong, nonatomic) UIImage *stamp;

@property (weak, nonatomic) IBOutlet UIImageView *editedImageView;

@end

@implementation PhotoEditingViewController

@synthesize input;
@synthesize imageFrame;
@synthesize touchedPoints;
@synthesize stamp;
@synthesize editedImageView;

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.editedImageView.userInteractionEnabled = YES;
    [self.editedImageView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self
                                                                                       action:@selector(touchAction:)]];
    
    self.touchedPoints = [NSMutableArray array];
    self.stamp = [UIImage imageNamed:@"stamp.gif"];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - PHContentEditingController

- (BOOL)canHandleAdjustmentData:(PHAdjustmentData *)adjustmentData {
    // Inspect the adjustmentData to determine whether your extension can work with past edits.
    // (Typically, you use its formatIdentifier and formatVersion properties to do this.)
//    return NO;
    NSBundle *bundle = [NSBundle mainBundle];
    NSDictionary *dic = [bundle infoDictionary];
    BOOL result = [adjustmentData.formatIdentifier isEqualToString:[bundle bundleIdentifier]];
    result &= [adjustmentData.formatVersion isEqualToString:[dic valueForKey:@"CFBundleShortVersionString"]];
    return result;
}

- (void)startContentEditingWithInput:(PHContentEditingInput *)contentEditingInput placeholderImage:(UIImage *)placeholderImage {
    // Present content for editing, and keep the contentEditingInput for use when closing the edit session.
    // If you returned YES from canHandleAdjustmentData:, contentEditingInput has the original image and adjustment data.
    // If you returned NO, the contentEditingInput has past edits "baked in".
    self.input = contentEditingInput;
    self.editedImageView.image = self.input.displaySizeImage;
    
    CGRect frame = AVMakeRectWithAspectRatioInsideRect(self.editedImageView.image.size, self.editedImageView.bounds);
    CGRect imageViewFrame = self.editedImageView.frame;
    self.imageFrame = CGRectMake( (imageViewFrame.size.width - frame.size.width) / 2.0,
                                  (imageViewFrame.size.height - frame.size.height) / 2.0,
                                  frame.size.width,
                                  frame.size.height );
    NSLog( @"%f %f", self.imageFrame.origin.x, self.imageFrame.origin.y );
    
    // Load adjustment data, if any
    @try {
        PHAdjustmentData *adjustmentData = self.input.adjustmentData;
        if (adjustmentData) {
            self.touchedPoints = [NSKeyedUnarchiver unarchiveObjectWithData:adjustmentData.data];
            
            CGFloat scale = self.input.displaySizeImage.size.height / self.imageFrame.size.height;
            NSArray *positions = [self scalePositions:self.touchedPoints scale:scale];
            UIImage *image = [self compositeImages:self.editedImageView.image
                                          addImage:self.stamp
                                       addPosition:positions];
            self.editedImageView.image = image;
        }
    }
    @catch (NSException *exception) {
        NSLog(@"Exception decoding adjustment data: %@", exception);
    }
}

- (void)finishContentEditingWithCompletionHandler:(void (^)(PHContentEditingOutput *))completionHandler {
    // Update UI to reflect that editing has finished and output is being rendered.
    
    // Render and provide output on a background queue.
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // Create editing output from the editing input.
        PHContentEditingOutput *output = [[PHContentEditingOutput alloc] initWithContentEditingInput:self.input];
        
        // Adjustment data
        NSBundle *bundle = [NSBundle mainBundle];
        NSDictionary *dic = [bundle infoDictionary];
        NSData *archivedData = [NSKeyedArchiver archivedDataWithRootObject:self.touchedPoints];
        PHAdjustmentData *adjustmentData = [[PHAdjustmentData alloc]
                                            initWithFormatIdentifier:[bundle bundleIdentifier]
                                            formatVersion:[dic valueForKey:@"CFBundleShortVersionString"]
                                            data:archivedData];
        output.adjustmentData = adjustmentData;
        
        // Get full size image
        NSURL *url = self.input.fullSizeImageURL;
        UIImage *image = [UIImage imageWithContentsOfFile:url.path];
        
        //  resize stamp
        CGFloat scale = image.size.height / self.input.displaySizeImage.size.height;
        UIImage* resizedAddImage = [self resizeImage:self.stamp scale:scale];
        
        //  render full size image
        scale = image.size.height / self.imageFrame.size.height;
        NSArray *positions = [self scalePositions:self.touchedPoints scale:scale];
        UIImage *transformedImage = [self compositeImages:image
                                                 addImage:resizedAddImage
                                              addPosition:positions];
        NSData *renderedJPEGData = UIImageJPEGRepresentation(transformedImage, 1.0f);
        
        // Save JPEG data
        NSError *error = nil;
        BOOL success = [renderedJPEGData writeToURL:output.renderedContentURL options:NSDataWritingAtomic error:&error];
        if (success) {
            NSLog(@"success");
            completionHandler(output);
        } else {
            NSLog(@"An error occured: %@", error);
            completionHandler(nil);
        }
        
        // Call completion handler to commit edit to Photos.
        //        completionHandler(output);
        
        // Clean up temporary files, etc.
    });
}

- (UIImage*)resizeImage:(UIImage*)originalImage scale:(CGFloat)scale {
    CGSize resizedSize = CGSizeMake(originalImage.size.width * scale, originalImage.size.height * scale);

    UIGraphicsBeginImageContext(resizedSize);
    [originalImage drawInRect:CGRectMake(0, 0, resizedSize.width, resizedSize.height)];
    UIImage* resizedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    return resizedImage;
}

- (BOOL)shouldShowCancelConfirmation {
    // Returns whether a confirmation to discard changes should be shown to the user on cancel.
    // (Typically, you should return YES if there are any unsaved changes.)
    return NO;
}

- (void)cancelContentEditing {
    // Clean up temporary files, etc.
    // May be called after finishContentEditingWithCompletionHandler: while you prepare output.
}

#pragma mark Action Methods
- (void)touchAction:(UITapGestureRecognizer*)sender {
    
    CGPoint touchedPoint = [sender locationInView:self.editedImageView];
    if ( !CGRectContainsPoint(self.imageFrame, touchedPoint) ) {
        return;
    }
    
    touchedPoint = CGPointMake( touchedPoint.x - self.imageFrame.origin.x,
                                touchedPoint.y - self.imageFrame.origin.y );
    NSLog(@"touched %f %f", touchedPoint.x, touchedPoint.y);
    
    NSValue *val = [NSValue valueWithBytes:&touchedPoint objCType:@encode(CGPoint)];
    [self.touchedPoints addObject:val];
    
    CGFloat scale = self.input.displaySizeImage.size.height / self.imageFrame.size.height;
    NSArray *positions = [self scalePositions:@[val] scale:scale];
    UIImage *image = [self compositeImages:self.editedImageView.image
                                  addImage:self.stamp
                               addPosition:positions];
    self.editedImageView.image = image;
}

#pragma mark Private Methods
- (NSArray*)scalePositions:(NSArray*)originalPositions scale:(CGFloat)scale {
    NSMutableArray *positions = [NSMutableArray array];
    
    for ( NSValue *value in originalPositions ) {
        CGPoint oroginalPosition;
        [value getValue:&oroginalPosition];
        CGPoint position = CGPointMake( oroginalPosition.x * scale, oroginalPosition.y * scale );
        [positions addObject:[NSValue valueWithBytes:&position objCType:@encode(CGPoint)]];
    }

    return positions;
}

- (UIImage *)compositeImages:(UIImage*)baseImage addImage:(UIImage*)addImage addPosition:(NSArray*)addPositions {
    UIImage *image = nil;
    
    UIGraphicsBeginImageContext(CGSizeMake(baseImage.size.width, baseImage.size.height));
    [baseImage drawAtPoint:CGPointMake(0, 0)];
    
    NSLog( @"addPositons count : %ld", addPositions.count );
    for (NSValue *val in addPositions) {
        CGPoint point;
        [val getValue:&point];
        
        point = CGPointMake( point.x - (addImage.size.width)/2 , point.y - (addImage.size.height)/2);
        [addImage drawAtPoint:point];
    }
    
    image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}
@end

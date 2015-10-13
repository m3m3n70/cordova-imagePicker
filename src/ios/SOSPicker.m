//
//  SOSPicker.m
//  SyncOnSet
//
//  Created by Christopher Sullivan on 10/25/13.
//
//

#import "SOSPicker.h"
#import "ELCAlbumPickerController.h"
#import "ELCImagePickerController.h"
#import "ELCAssetTablePicker.h"

#define CDV_PHOTO_PREFIX @"cdv_photo_"

@implementation SOSPicker

@synthesize callbackId;

- (void) getPictures:(CDVInvokedUrlCommand *)command {
	NSDictionary *options = [command.arguments objectAtIndex: 0];

	NSInteger maximumImagesCount = [[options objectForKey:@"maximumImagesCount"] integerValue];
	self.width = [[options objectForKey:@"width"] integerValue];
	self.height = [[options objectForKey:@"height"] integerValue];
	self.quality = [[options objectForKey:@"quality"] integerValue];

	// Create the an album controller and image picker
	ELCAlbumPickerController *albumController = [[ELCAlbumPickerController alloc] init];
	
	if (maximumImagesCount == 1) {
      albumController.immediateReturn = true;
      albumController.singleSelection = true;
   } else {
      albumController.immediateReturn = false;
      albumController.singleSelection = false;
   }
   
   ELCImagePickerController *imagePicker = [[ELCImagePickerController alloc] initWithRootViewController:albumController];
   imagePicker.maximumImagesCount = maximumImagesCount;
   imagePicker.returnsOriginalImage = 1;
   imagePicker.imagePickerDelegate = self;

   albumController.parent = imagePicker;
	self.callbackId = command.callbackId;
	// Present modally
	[self.viewController presentViewController:imagePicker
	                       animated:YES
	                     completion:nil];
}


- (void)elcImagePickerController:(ELCImagePickerController *)picker didFinishPickingMediaWithInfo:(NSArray *)info {
	CDVPluginResult* result = nil;
	NSMutableArray *resultStrings = [[NSMutableArray alloc] init];
    NSData* data = nil;
    NSString* docsPath = [NSTemporaryDirectory()stringByStandardizingPath];
    NSError* err = nil;
    NSFileManager* fileMgr = [[NSFileManager alloc] init];
    NSString* filePath;
    ALAsset* asset = nil;
    CGSize targetSize = CGSizeMake(self.width, self.height);
	for (NSDictionary *dict in info) {
        asset = [dict objectForKey:@"ALAsset"];
        // From ELCImagePickerController.m

        int i = 1;
        do {
            filePath = [NSString stringWithFormat:@"%@/%@%03d/%@.%@", docsPath, CDV_PHOTO_PREFIX, i++,@"original", @"jpg"];
        } while ([fileMgr fileExistsAtPath:filePath]);
        
        @autoreleasepool {
            [[NSFileManager defaultManager] createDirectoryAtPath:[filePath stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil];
            ALAssetRepresentation *representation = [asset defaultRepresentation];
            
            [[NSFileManager defaultManager] createFileAtPath:filePath contents:nil attributes:nil];
            NSOutputStream *outPutStream = [NSOutputStream outputStreamToFileAtPath:filePath append:YES];
            [outPutStream open];
            
            long long offset = 0;
            long long bytesRead = 0;
            
            NSError *error;
            uint8_t * buffer = malloc(131072);
            while (offset<[representation size] && [outPutStream hasSpaceAvailable]) {
                bytesRead = [representation getBytes:buffer fromOffset:offset length:131072 error:&error];
                [outPutStream write:buffer maxLength:bytesRead];
                offset = offset+bytesRead;
            }
            [outPutStream close];
            free(buffer);
            
    
            
            UIImage* image = [UIImage imageWithContentsOfFile:filePath];
   
            if (self.width == 0 && self.height == 0) {
                data = UIImageJPEGRepresentation(image, self.quality/100.0f);
            } else {
                UIImage* scaledImage = [self imageByScalingNotCroppingForSize:image toSize:targetSize];
                data = UIImageJPEGRepresentation(scaledImage, self.quality/100.0f);
            }
             NSString *newPath = [[filePath stringByDeletingLastPathComponent] stringByAppendingString:[NSString stringWithFormat:@"/thumbnail.%@",@"jpg"]];
            if (![data writeToFile:newPath options:NSAtomicWrite error:&err]) {
                result = [CDVPluginResult resultWithStatus:CDVCommandStatus_IO_EXCEPTION messageAsString:[err localizedDescription]];
                break;
            } else {
                [resultStrings addObject:[[NSURL fileURLWithPath:[filePath stringByDeletingLastPathComponent]] absoluteString]];
            }
            
        }

	}
	
	if (nil == result) {
		result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:resultStrings];
	}

	[self.viewController dismissViewControllerAnimated:YES completion:nil];
	[self.commandDelegate sendPluginResult:result callbackId:self.callbackId];
}

- (void)elcImagePickerControllerDidCancel:(ELCImagePickerController *)picker {
	[self.viewController dismissViewControllerAnimated:YES completion:nil];
	CDVPluginResult* pluginResult = nil;
    NSArray* emptyArray = [NSArray array];
	pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:emptyArray];
	[self.commandDelegate sendPluginResult:pluginResult callbackId:self.callbackId];
}

- (UIImage*)imageByScalingNotCroppingForSize:(UIImage*)anImage toSize:(CGSize)frameSize
{
    UIImage* sourceImage = anImage;
    UIImage* newImage = nil;
    CGSize imageSize = sourceImage.size;
    CGFloat width = imageSize.width;
    CGFloat height = imageSize.height;
    CGFloat targetWidth = frameSize.width;
    CGFloat targetHeight = frameSize.height;
    CGFloat scaleFactor = 0.0;
    CGSize scaledSize = frameSize;

    if (CGSizeEqualToSize(imageSize, frameSize) == NO) {
        CGFloat widthFactor = targetWidth / width;
        CGFloat heightFactor = targetHeight / height;

        // opposite comparison to imageByScalingAndCroppingForSize in order to contain the image within the given bounds
        if (widthFactor == 0.0) {
            scaleFactor = heightFactor;
        } else if (heightFactor == 0.0) {
            scaleFactor = widthFactor;
        } else if (widthFactor > heightFactor) {
            scaleFactor = heightFactor; // scale to fit height
        } else {
            scaleFactor = widthFactor; // scale to fit width
        }
        scaledSize = CGSizeMake(width * scaleFactor, height * scaleFactor);
    }

    UIGraphicsBeginImageContext(scaledSize); // this will resize

    [sourceImage drawInRect:CGRectMake(0, 0, scaledSize.width, scaledSize.height)];

    newImage = UIGraphicsGetImageFromCurrentImageContext();
    if (newImage == nil) {
        NSLog(@"could not scale image");
    }

    // pop the context to get back to the default
    UIGraphicsEndImageContext();
    return newImage;
}

@end
//
//  PictographImageCoder.m
//  Pictograph
//
//  Created by Adam on 2015-10-04.
//  Copyright © 2015 Adam Boyd. All rights reserved.
//

#import "PictographImageCoder.h"



#define bitCountForCharacter 8
#define bitsChangedPerPixel 2
#define bitCountForInfo 16
#define bitCountForHiddenDataSize 64 //Number of bits needed, NOT pixels
#define bytesPerPixel 4
#define componentsPerPixel 4
#define maxIntFor8Bits 255
#define maxFloatFor8Bits 255.0
#define blueComponentIndex 2

#define extraImageShrinkingFactor 2 //Would make image 2x smaller for both height and width (4x less pixels)

typedef NS_ENUM(NSInteger, PictographEncodingOptions)
{
    PictographEncodingOptionsNone = -1,
    PictographEncodingOptionsUnencryptedMessage,
    PictographEncodingOptionsEncryptedMessage,
    PictographEncodingOptionsUnencryptedImage,
    PictographEncodingOptionsUnencryptedMessageWithImage,
    PictographEncodingOptionsEncryptedMessageWithImage
};

@implementation PictographImage(Coder)




#pragma mark Decoding a messages and images hidden in an image

//Decodes a string from an image. Returns nil if there is no message in the image or if there was an error
- (NSString *)decodeImage:(NSError * _Nullable * _Nullable)error {
    
    
    NSData *hiddenMessageData = [self decodeDataInImage:self error:error];
    
    if (hiddenMessageData) {
        //In addition to converting the string back to a readable version, this converts any unicode scalars back to readable format (like emoji)
       NSString *hiddenString = [[NSString alloc] initWithData:hiddenMessageData encoding:NSNonLossyASCIIStringEncoding];
    return hiddenString;
        
    }
    return nil;
    
}

//Decodes UIImage image. Returns the encoded data in the image
//Password handler has no parameters and returns an NSString *
- (NSData *)decodeDataInImage:(PictographImage * _Nonnull)image  error:(NSError * _Nullable * _Nullable)error {
    
    
    NSMutableArray *infoArrayInBits = [[NSMutableArray alloc] init];
    
    //Getting information about the encoded message
    unsigned char *first8PixelsBlueComponents = [self getBlueComponentsFromImage:image atX:0 andY:0 count:[self pixelCountForBit:bitCountForInfo]];
    for (int i = 0; i < [self pixelCountForBit:bitCountForInfo]; i++) {
        //Going through each color that contains information about the message
        [self addLastBitsFromBlueComponent:first8PixelsBlueComponents[i] toArray:infoArrayInBits];
    }
    
    free(first8PixelsBlueComponents);
    

    return [self dataFromImage:image  error:error];
}

//Returns the message from the image given an optional password
- (NSData *)dataFromImage:(PictographImage *)image  error:(NSError *_Nullable*_Nullable)error {
    
    
    //Getting the size of the string
    NSMutableArray *messageSizeArrayInBits = [[NSMutableArray alloc] init];
    unsigned char *blueComponentsContainingSizeOfMessage = [self getBlueComponentsFromImage:image atX:[self pixelCountForBit:bitCountForInfo] andY:0 count:[self pixelCountForBit:bitCountForHiddenDataSize]];
    
    for (int i = 0; i < [self pixelCountForBit:bitCountForHiddenDataSize]; i++) {
        //Going through each color that contains the size of the message
        [self addLastBitsFromBlueComponent:blueComponentsContainingSizeOfMessage[i] toArray:messageSizeArrayInBits];
    }
    
    free(blueComponentsContainingSizeOfMessage);
    long numberOfBitsNeededForMessage = [self longFromBits:messageSizeArrayInBits];
    
    //Getting the size of any hidden image
    NSMutableArray *imageSizeArrayInBits = [[NSMutableArray alloc] init];
    unsigned char *blueComponentsContainingSizeOfImage = [self getBlueComponentsFromImage:image atX:[self pixelCountForBit:bitCountForInfo + bitCountForHiddenDataSize] andY:0 count:[self pixelCountForBit:bitCountForHiddenDataSize]];
    
    for (int i = 0; i < [self pixelCountForBit:bitCountForHiddenDataSize]; i++) {
        //Going through each color that contains the size of the message
        [self addLastBitsFromBlueComponent:blueComponentsContainingSizeOfImage[i] toArray:imageSizeArrayInBits];
    }
    
    free(blueComponentsContainingSizeOfImage);
    long numberOfBitsNeededForImage = [self longFromBits:imageSizeArrayInBits];
    
    if (numberOfBitsNeededForMessage > 0) {
        NSData *hiddenMessageData = [self getDataFromPixlesWithBitCountOffset:0 fromImage:image numberOfBitsToGet:numberOfBitsNeededForMessage totalBitsForLogging:(numberOfBitsNeededForMessage + numberOfBitsNeededForImage) error:error];
        return hiddenMessageData;
    }
    
    return nil;


}

//This goes through a range of pixels and transforms the last two bits from each blue value into a usable NSData reference. Makes the delegate call for logging
-(NSData *_Nullable)getDataFromPixlesWithBitCountOffset:(long)bitCountOffset fromImage:(PictographImage *_Nonnull)image numberOfBitsToGet:(long)numberOfBitsToGet totalBitsForLogging:(long)totalBitCount  error:(NSError * _Nullable * _Nullable)error {
    
    //Going through all the pixels to get the char value
    NSMutableArray *arrayOfBitsForMessage = [[NSMutableArray alloc] init];
    NSMutableData *dataFromImage = [[NSMutableData alloc] init];
    NSData *toReturn;
    
    int firstPixelWithHiddenData = [self pixelCountForBit:(bitCountForInfo + bitCountForHiddenDataSize + bitCountForHiddenDataSize + (int)bitCountOffset)];
    unsigned char *arrayOfBlueComponents = [self getBlueComponentsFromImage:image atX:firstPixelWithHiddenData andY:0 count:[self pixelCountForBit:(int)numberOfBitsToGet]];
    
    for (int i = 0; i < [self pixelCountForBit:(int)numberOfBitsToGet]; i++) {
        
        //Going through each pixel
        unsigned char blueComponent = arrayOfBlueComponents[i];
        [self addLastBitsFromBlueComponent:blueComponent toArray:arrayOfBitsForMessage];
        
        DLog(@"Reading pixel value at index %i", i);
        

        
        if ([arrayOfBitsForMessage count] == bitCountForCharacter) {
            //If there are now enough bits to make a char
            
            long longChar = [self longFromBits:arrayOfBitsForMessage];
            
            char curChar = (char)longChar;
            
            [dataFromImage appendBytes:&curChar length:1];
            
            [arrayOfBitsForMessage removeAllObjects]; //Reset the array for the next char
        }
    }
    
    free(arrayOfBlueComponents);
    toReturn = dataFromImage;
    
    return toReturn;
}

//Adds the last 2 bits of the blue value from PictographColor color to the NSMutableArray array
- (void)addLastBitsFromBlueComponent:(unsigned char)blueComponent toArray:(NSMutableArray *)array {
    NSArray *arrayOfBitsFromBlue = [self binaryStringFromInteger:blueComponent withSpaceFor:bitCountForCharacter];
    
    [array addObject:[arrayOfBitsFromBlue objectAtIndex:6]];
    [array addObject:[arrayOfBitsFromBlue objectAtIndex:7]];
}

#pragma mark Encoding messages and images

//Encodes UIImage image with message message. Returns the modified UIImage or NSImage
- (NSData * _Nullable)encodeMessage:(NSString * _Nullable)message error:(NSError * _Nullable * _Nullable)error {
    
    NSData *unicodeMessageData;
    if (message && ![message isEqualToString:@""]) {
        //Converting emoji to the unicode scalars
        unicodeMessageData = [message dataUsingEncoding:NSNonLossyASCIIStringEncoding];
    }
    
    return [self encodeMessageData:unicodeMessageData inImage:self error:error];
    
}

#pragma mark Helper methods for encoding a message in an image

//Encodes UIImage image with the data. Returns modified UIImage or NSImage
- (NSData * _Nullable)encodeMessageData:(NSData * _Nonnull)messageData  inImage:(PictographImage * _Nonnull)image error:(NSError * _Nullable * _Nullable)error {
    
    NSData *messageDataToEncode;
    
    
    messageDataToEncode = messageData;
    
    //Calculating the number of bits needed to store the message and hidden image
    long bitsNeededForMessageData = 0;
    if (messageDataToEncode) {
        bitsNeededForMessageData = [messageDataToEncode length] * bitCountForCharacter;
    }
    
    long bitsNeededForImageData = 0;
    
    long bitsNeededForAllData = bitsNeededForMessageData + bitsNeededForImageData;
    long numberOfPixelsNeeded = [self pixelCountForBit:(bitCountForInfo + bitCountForHiddenDataSize + bitCountForHiddenDataSize + (int)bitsNeededForAllData)];
    
    if (([image getReconciledImageHeight] * [image getReconciledImageWidth]) <= numberOfPixelsNeeded) {
        //Makes sure the image is large enough to handle the message
        DLog(@"User's selected image was too small");
        
        NSDictionary *userInfo = @{NSLocalizedDescriptionKey: @"Image was too small, please select a larger image."};
        
        *error = [NSError errorWithDomain:PictographErrorDomain code:ImageTooSmallError userInfo:userInfo];
        
        return nil;
    }
    
    /* Adding the size of the message here. Always using 16 bits for the size, even though it might only require 8,
     giving a maximum size of 2^16 bits, or 65536 chars. Preceded by 8 bits of information regarding message */
    NSMutableArray *arrayOfBits = [[NSMutableArray alloc] init];
    
    /*
     NOTE: See function definiton for determineSettingsBitsForMessageData to see how this works
     */
    int settingsBit = [self determineSettingsBitsForMessageData:messageDataToEncode];
    
    [arrayOfBits addObjectsFromArray:[self binaryStringFromInteger:settingsBit withSpaceFor:bitCountForInfo]]; //16 bits for future proofing
    
    [arrayOfBits addObjectsFromArray:[self binaryStringFromInteger:(int)bitsNeededForMessageData withSpaceFor:bitCountForHiddenDataSize]]; //64 bits for message size
    
    [arrayOfBits addObjectsFromArray:[self binaryStringFromInteger:(int)bitsNeededForImageData withSpaceFor:bitCountForHiddenDataSize]]; //64 bits for image size
    
    NSMutableArray *arrayOfDataToEncode = [[NSMutableArray alloc] init];
    if (messageDataToEncode) {
        [arrayOfDataToEncode addObject:messageDataToEncode];
    }

    
    //Going through the data and adding the bits that need to be encoded
    for (NSData *data in arrayOfDataToEncode) {
        const char *bytes = [data bytes];
        for (int charIndex = 0; charIndex < [data length]; charIndex++) {
            //Going through each character
            
            char curChar = bytes[charIndex];
            [arrayOfBits addObjectsFromArray:[self binaryStringFromInteger:curChar withSpaceFor:bitCountForCharacter]]; //Only 8 bits needed for chars
        }
    }
    
    return [self saveImageToGraphicsContextAndEncodeBitsInImage:image arrayOfBits:arrayOfBits];
}


//Saves the image to the graphics context and starts encoding the bits in that image
- (NSData *)saveImageToGraphicsContextAndEncodeBitsInImage:(PictographImage *)image arrayOfBits:(NSMutableArray *)arrayOfBits {
    //Right here we have all the bits that are needed to encode the data in the image
    
    #if TARGET_OS_IPHONE
    image = [self rotatedUIImageFromImage:image];
    #endif
    
    NSUInteger imageWidth = [image getReconciledImageWidth];
    NSUInteger imageHeight = [image getReconciledImageHeight];
    
    CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceRGB();
    size_t bitsPerComponent = 8;
    size_t bytesPerRow = bytesPerPixel * imageWidth;
    
    unsigned char *pixelBuffer = [self pixelBufferWithBlueComponentsChangedFrom:image arrayOfBits:arrayOfBits];
    
    CGContextRef editedBitmap = CGBitmapContextCreate(pixelBuffer, imageWidth, imageHeight, bitsPerComponent, bytesPerRow, colorspace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Little);
    
    //Getting the image from the bitmap
    NSData *dataRepresentationOfModifiedImage;
    CGImageRef outputImage = CGBitmapContextCreateImage(editedBitmap);
    
    //CGImageRef to NSData
#if TARGET_OS_IPHONE
    UIImage *encodedImage = [[UIImage alloc] initWithCGImage:outputImage];
    dataRepresentationOfModifiedImage = UIImagePNGRepresentation(encodedImage);
#else
    CFMutableDataRef newImageData = CFDataCreateMutable(NULL, 0);
    CGImageDestinationRef destination = CGImageDestinationCreateWithData(newImageData, kUTTypePNG, 1, NULL);
    CGImageDestinationAddImage(destination, outputImage, nil);
    CGImageDestinationFinalize(destination);
    dataRepresentationOfModifiedImage = (__bridge_transfer NSData *)newImageData;
    
    CFRelease(destination);
#endif
    
    //Freeing the memory
    CGColorSpaceRelease(colorspace);
    CGContextRelease(editedBitmap);
    CGImageRelease(outputImage);
    free(pixelBuffer);
    
    return dataRepresentationOfModifiedImage;
    
}

//Returns the pixel buffer for the entire image with all the necessary pixels changed for encoding the image or message
-(unsigned char *)pixelBufferWithBlueComponentsChangedFrom:(PictographImage *)image arrayOfBits:(NSMutableArray *)arrayOfBits {
    unsigned char *pixelBuffer = [self getRawPixelDataForImage:image];
    
    int numberOfPixelsNeeded = [self pixelCountForBit:(int)[arrayOfBits count]];
    int encodeCounter = 0; //Counter which bit we are encoding, goes up 2 with each pixel

    
    //Need numberOfPixelsNeeded * 4 due to this array counting by components of each pixel (RGBA)
    for (int i = 0; i < (numberOfPixelsNeeded * 4); i += 4) {
        //Get the current blue value, change out the last bits, and then put the new value in the buffer again
        unsigned char currentBlueValue = pixelBuffer[i+blueComponentIndex];
        unsigned char newBlueValue = [self newBlueComponentValueFrom:currentBlueValue encodeCounter:encodeCounter arrayOfBits:arrayOfBits];
        pixelBuffer[i+blueComponentIndex] = newBlueValue;
        
        DLog(@"Changing pixel value at index %i", (i / 4));

        encodeCounter += 2;
    }
    
    return pixelBuffer;
}

//Gets the color that the specified pixel should be
-(UInt8)newBlueComponentValueFrom:(unsigned char)currentBlueComponent encodeCounter:(int)encodeCounter  arrayOfBits:(NSArray *)arrayOfBits {
    
    //Changing the value of the blue byte
    NSMutableArray *arrayOfBitsFromBlue = [[NSMutableArray alloc] initWithArray:[self binaryStringFromInteger:currentBlueComponent withSpaceFor:bitCountForCharacter]];
    
    //Changing the least significant bits of the blue byte
    [arrayOfBitsFromBlue replaceObjectAtIndex:6 withObject:arrayOfBits[encodeCounter]];
    [arrayOfBitsFromBlue replaceObjectAtIndex:7 withObject:arrayOfBits[encodeCounter + 1]];
    
    long newBlueLong = [self longFromBits:arrayOfBitsFromBlue];

    return (UInt8)newBlueLong;
}

# pragma mark Helper methods used for hiding an image within another image

#if TARGET_OS_IPHONE
/**
UIImages taken with the iPhone camera have an orientation of right even though they are straight up. This causes the image to be distored when restored from the bitmap. This corrects the image orientation.

 @param image image to rotate
 @return rotated image
 */
- (UIImage *)rotatedUIImageFromImage:(UIImage *)image {
    NSUInteger imageWidth = [image getReconciledImageWidth];
    NSUInteger imageHeight = [image getReconciledImageHeight];
    
    UIGraphicsBeginImageContext(CGSizeMake(imageWidth, imageHeight));
    [image drawAtPoint:CGPointMake(0,0)];
    return UIGraphicsGetImageFromCurrentImageContext();
}
#endif

/**
 Determines the size that the hidden image will need to be in order to fit in the original image. Instead of figuring out the exact size that will make the image fit, it cuts the scale factor in half each time. Starting with 1, then 1/2, then 1/4 etc
 
 @param image image that the hiddenImage will be hidden in
 @return factor that hiddenImage needs to be scaled by
 */
- (CGSize)determineSizeForHidingImage:(PictographImage *)hiddenImage withinImage:(PictographImage *)image{
    const NSUInteger numberOfPixelsInMainImage = [image getReconciledImageWidth] * [image getReconciledImageHeight];
    CGFloat scaleFactor = 1;
    
    CGSize hiddenImageSize = CGSizeMake([hiddenImage getReconciledImageWidth] * scaleFactor, [hiddenImage getReconciledImageHeight] * scaleFactor);
    NSUInteger pixelsNeededForHiddenImage = [self numberOfPixelsNeededToHideImageOfSize:hiddenImageSize];
    
    while (pixelsNeededForHiddenImage >= numberOfPixelsInMainImage) {
        //Cut the width and height of the image in half each time
        scaleFactor = scaleFactor / 2;
        
        hiddenImageSize = CGSizeMake([hiddenImage getReconciledImageWidth] * scaleFactor, [hiddenImage getReconciledImageHeight] * scaleFactor);
        pixelsNeededForHiddenImage = [self numberOfPixelsNeededToHideImageOfSize:hiddenImageSize];
    }
    
    
    return hiddenImageSize;
}

/**
 This is the number of pixels that it would take to hide the specified image, including the information bits about the image
 
 @param imageSize size of the image not counting retina displays
 @return number of pixels it would take to encode all information
 */
- (NSUInteger)numberOfPixelsNeededToHideImageOfSize:(CGSize)imageSize {
    
    //Number of bits needed to encode a single pixel worth of information
    NSUInteger bitsNeededPerPixel = bitCountForCharacter * bytesPerPixel;
    NSUInteger bitsNeededToEncodeEntireImage = bitsNeededPerPixel * imageSize.width * imageSize.height;
    
    //16 bits for info about image, 64 bits for number of bits needed
    NSUInteger totalBitsToEncode = bitCountForInfo + bitCountForHiddenDataSize + bitCountForHiddenDataSize + bitsNeededToEncodeEntireImage;
    
    return totalBitsToEncode / bitsChangedPerPixel;
}

#pragma mark Methods used for both encoding and decoding

/* Returns the binary representation of a character */
//http://stackoverflow.com/questions/655792/how-to-convert-nsinteger-to-a-binary-string-value
//Used the above link as information, but instead decided to use an int array and remove spacing
-(NSArray *)binaryStringFromInteger:(int)number withSpaceFor:(int)numberOfBits{
    NSMutableArray *bitArray = [[NSMutableArray alloc] init];
    int binaryDigit = 0;
    int integer = number;
    
    while(binaryDigit < numberOfBits) {
        //Going through each binary digit
        binaryDigit++;
        
        [bitArray insertObject:((integer & 1) ? @1 : @0) atIndex:0];
        
        integer = integer >> 1;
    }
    
    return bitArray;
}

/* Returns the long representation of a bit array
   For example (["1", "1", "0", "1"] -> 13) */
-(long)longFromBits:(NSArray *)bitArray {
    
    NSMutableString *singleCharacterArrayInBits = [[NSMutableString alloc] init];
    
    for (int singleCharCounter = 0; singleCharCounter < [bitArray count]; singleCharCounter++) {
        //Creating a string of the bits that make up this one character, this is easily convertible to a char
        [singleCharacterArrayInBits appendString:[NSString stringWithFormat:@"%@", [bitArray objectAtIndex:singleCharCounter]]];
    }
    
    long longRep = strtol([singleCharacterArrayInBits UTF8String], NULL, 2);
    
    return longRep;
}

/* Returns an array of PictographColors for the pixels starting at x, y for count number of pixels
   http://stackoverflow.com/questions/448125/how-to-get-pixel-data-from-a-uiimage-cocoa-touch-or-cgimage-core-graphics
   Used the above link as inspiration, but heavily modified */
-(unsigned char *)getBlueComponentsFromImage:(PictographImage*)image atX:(int)x andY:(int)y count:(int)count {
    
    //Getting the raw data
    unsigned char *rawData = [self getRawPixelDataForImage:image];
    
    unsigned char *blueComponentArray = (unsigned char*)malloc(count * sizeof(unsigned char));
    
    NSUInteger width = [image getReconciledImageWidth];
    
    NSUInteger bytesPerRow = bytesPerPixel * width;
    NSUInteger byteIndex = (bytesPerRow * y) + x * bytesPerPixel;
    
    for (int counter = 0; counter < count; counter++) {
        //Getting the bits for each color space red, green, blue, and alpha
        unsigned char blueComponent = rawData[byteIndex + 2];
        
        blueComponentArray[counter] = blueComponent;
        byteIndex += bytesPerPixel;
    }
    
    free(rawData);
    
    return blueComponentArray;
}

/* Returns the raw pixel data for a UIImage image */
//This returns a (void *) of the pixel data from this image. By casting it as an array of unsigned char, we can easily access the RGBA values of each pixel. This also makes it easy to iterate over the entire image as well.
//  (assuming i % 4 == 0)
//  pixelBuffer[i] is the red
//  pixelBuffer[i+1] is the green
//  pixelBuffer[i+2] is the blue
//  pixelBuffer[i+3] is the alpha
-(unsigned char *)getRawPixelDataForImage:(PictographImage *)image {
    // First get the image into your data buffer
    
    CGImageRef imageRef = [image getReconciledCGImageRef];
    
    NSUInteger width = [image getReconciledImageWidth];
    NSUInteger height = [image getReconciledImageHeight];
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    unsigned char *rawData = (unsigned char*) malloc(height * width * componentsPerPixel * sizeof(unsigned char));
    NSUInteger bytesPerRow = bytesPerPixel * width;
    NSUInteger bitsPerComponent = 8;
    CGContextRef context = CGBitmapContextCreate(rawData, width, height, bitsPerComponent, bytesPerRow, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Little);
    
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), imageRef);
    
    //Freeing the memory
    CGColorSpaceRelease(colorSpace);
    CGContextRelease(context);
    
    return rawData;
}

#pragma mark Settings bits

/**
 Pictograph uses a 16 bit settings number to determine how to encrypt/decrypt a message
 
 (0) 00000000 00000000 - Unencrypted message
 (1) 00000000 00000001 - Encrypted message
 (2) 00000000 00000010 - Unencrypted image
 (3) 00000000 00000011 - Unencrypted message with hidden image
 (4) 00000000 00000100 - Encrypted message with hidden image
 
 @param messageData message data if any is being encoded
 @return correct settings bit
 */
- (int)determineSettingsBitsForMessageData:(NSData * _Nullable)messageData  {
    int bit = -1;
    
    if (messageData) {
        bit++;
    }
    return bit;
}

#pragma mark Dealing with bits

/**
 Returns the corresponding pixel for the specified bit
 
 @param bit bit number that we're looking at
 @return pixel that count be changed
 */
- (int)pixelCountForBit:(int)bit {
    return bit / bitsChangedPerPixel;
}

@end

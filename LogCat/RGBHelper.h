//
//  RGBHelper.h
//  RGB565Test
//
//  Created by Chris Wilson on 12/18/12.
//

#import <Foundation/Foundation.h>


#define RGB565toRGBA_FORMAT 3
#define RGB555toRGBA_FORMAT 2
#define RGB444toRGBA_FORMAT 1
#define RGB332toRGBA_FORMAT 0


@interface RGBHelper : NSObject

- (NSImage *) convertRGBtoNSImage:(unsigned const char *)data width:(int)width height:(int)height format:(int)format;
- (NSImage *) convertRGB32toNSImage:(unsigned const char *)data width:(int)width height:(int)height;


@end

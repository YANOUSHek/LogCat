//
//  RGBHelper.m
//  RGB565Test
//
//  Created by Chris Wilson on 12/18/12.
//

#import "RGBHelper.h"

@interface RGBHelper () {
    
}
uint32_t RGB332toRGBA(uint16_t rgb332);
uint32_t RGB444toRGBA(uint16_t rgb444);
uint32_t RGB555toRGBA(uint16_t rgb555);
uint32_t RGB565toRGBA(uint16_t rgb565);
uint32_t RemapColor(uint32_t value);

@end


@implementation RGBHelper

/**
 References:
 https://github.com/MatthewCallis/S3DTEX-Viewer/blob/master/GUIControl.m
 http://cocoadev.com/w190/index.php?title=ConvertRGBPixelFormats&action=edit
 
 On rooted devices:
 adb shell /system/bin/screencap -p /sdcard/screenshot.png
 adb pull /sdcard/screenshot.png screenshot.png
 
**/
uint32_t RGB332toRGBA(uint16_t rgb332) {
	uint16_t temp = CFSwapInt16LittleToHost(rgb332);	// swap bytes. may not be needed depending on your RGB565 data
	uint32_t red, green, blue;						    // Assuming >=32-bit long int. uint32_t, where art thou?
	red = temp & 0xe0;
	red |= red >> 3 | red >> 6;
    
	green = (temp << 3) & 0xe0;
	green |= green >> 3 | green >> 6;
    
	blue = temp & 0x3;
	blue |= blue << 2;
	blue |= blue << 4;
    
	return (blue << 16) | (green << 8) | red | 0xFF000000;
	//	return (red << 24) | (green << 16) | (blue << 8) | 0xFF;
}

uint32_t RGB444toRGBA(uint16_t rgb444) {
	uint16_t temp = CFSwapInt16LittleToHost(rgb444);	// swap bytes. may not be needed depending on your RGB565 data
	uint32_t red, green, blue;						    // Assuming >=32-bit long int. uint32_t, where art thou?
    
	red = (temp & 0xf) << 4;
	green = ((temp >> 4) & 0xf) << 4;
	blue = ((temp >> 8) & 0xf) << 4;
    
	return (red << 16) | (green << 8) | blue | 0xFF000000;
    //	return (red << 24) | (green << 16) | (blue << 8) | 0xFF;
}

uint32_t RGB555toRGBA(uint16_t rgb555) {
	uint16_t temp = CFSwapInt16LittleToHost(rgb555);	// swap bytes. may not be needed depending on your RGB565 data
	uint32_t red, green, blue;						    // Assuming >=32-bit long int. uint32_t, where art thou?
	red = (temp >> 7) & 0xF8;
	green = (temp >> 2) & 0xF8;
	blue = (temp << 3) & 0xF8;
	return (blue << 16) | (green << 8) | red | 0xFF000000;
    //	return (red << 24) | (green << 16) | (blue << 8) | 0xFF;
}

uint32_t RGB565toRGBA(uint16_t rgb565) {
	uint16_t temp = CFSwapInt16LittleToHost(rgb565);	// swap bytes. may not be needed depending on your RGB565 data
	uint32_t red, green, blue;						    // Assuming >=32-bit long int. uint32_t, where art thou?
    
	red = (temp >> 11) & 0x1F;
	green = (temp >> 5) & 0x3F;
	blue = (temp & 0x001F);
    
    //	red = (temp & 0xF800) >> 11;
    //	green = (temp & 0x7E0) >> 5;
    //	blue = (temp & 0x1F);
    
	red = (red << 3) | (red >> 2);
	green = (green << 2) | (green >> 4);
	blue = (blue << 3) | (blue >> 2);
    
    //	NSLog(@"RGBA Real: %02x%02x%02x", red, green, blue);
    //	NSLog(@"RGBA Fake: %x", ((red << 24) | (green << 16) | (blue << 8) | 0xFF));
    
	return (blue << 16) | (green << 8) | red | 0xFF000000;
    //	return (red << 24) | (green << 16) | (blue << 8) | 0xFF;
}

uint32_t RemapColor(uint32_t value) {
    // Remapt to color format A  B G R
    return  (value & 0x000000FFU) << 16 |
    (value & 0x0000FF00U) >> 0  |
    (value & 0x00FF0000U) >> 16 |
    (value & 0xFF000000U) >> 0 ;
    
}

- (NSImage *) convertRGBtoNSImage:(unsigned const char *)data width:(int)width height:(int)height format:(int)format {
	uint16_t *src;
	uint32_t *dest;
	
	NSInteger dstRowBytes;
    
	NSBitmapImageRep* bitmap = [[NSBitmapImageRep alloc]
                                initWithBitmapDataPlanes: nil
                                pixelsWide: width
                                pixelsHigh: height
                                bitsPerSample: 8
                                samplesPerPixel: 4
                                hasAlpha: YES
                                isPlanar: NO
                                colorSpaceName: NSDeviceRGBColorSpace
                                bytesPerRow: width * 4
                                bitsPerPixel: 32];
    
	src = (uint16_t *) (data);
	dest = (uint32_t *) [bitmap bitmapData];
    
	dstRowBytes = [bitmap bytesPerRow];
    
	int i, end = width * height;
    
    NSLog(@"End=%d, bytesPerRow=%ld", end, dstRowBytes);
    
    
	for(i = 0; i < end; i++){
		uint16_t *pixel = src;
		uint32_t destPixel;
        
		if(format == 3)			destPixel = RGB565toRGBA(*pixel);
		else if(format == 2)	destPixel = RGB555toRGBA(*pixel);
		else if(format == 1)	destPixel = RGB444toRGBA(*pixel);
		else if(format == 0)	destPixel = RGB332toRGBA(*pixel);
		else if(format == 5)	destPixel = *pixel;
		else					destPixel = RGB565toRGBA(*pixel);
        
		*dest = destPixel;
		dest++;
		src++;
	}
    
    NSImage* image;
	image = [[NSImage alloc] initWithSize:NSMakeSize(width, height)];
	[image addRepresentation:bitmap];
    
	return image;
}

- (NSImage *) convertRGB32toNSImage:(unsigned const char *)data width:(int)width height:(int)height {
	uint32_t *src;
	uint32_t *dest;
	
//	NSInteger dstRowBytes;
    
	NSBitmapImageRep* bitmap = [[NSBitmapImageRep alloc]
                                initWithBitmapDataPlanes: nil
                                pixelsWide: width
                                pixelsHigh: height
                                bitsPerSample: 8
                                samplesPerPixel: 4
                                hasAlpha: YES
                                isPlanar: NO
                                colorSpaceName: NSDeviceRGBColorSpace
                                bytesPerRow: width * 4
                                bitsPerPixel: 32];
    
	src = (uint32_t *) (data);
	dest = (uint32_t *) [bitmap bitmapData];
    
//	dstRowBytes = [bitmap bytesPerRow];
    
	int i, end = width * height;
    
	for(i = 0; i < end; i++){
		uint32_t *pixel = src;
		uint32_t destPixel;
        
		destPixel = RemapColor(*pixel);
        
		*dest = destPixel;
		dest++;
		src++;
	}
    
    NSImage* image;
	image = [[NSImage alloc] initWithSize:NSMakeSize(width, height)];
	[image addRepresentation:bitmap];
    
	return image;
}

@end

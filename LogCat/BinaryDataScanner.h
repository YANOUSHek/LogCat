//
//  BinaryDataScanner.m
//
//  Copyright 2009 Dave Peck <davepeck [at] davepeck [dot] org>. All rights reserved.
//  http://davepeck.org/
//
//  This class makes it quite a bit easier to read sequential binary files in Objective-C.
//
//  This code is released under the BSD license. If you use it in your product, please
//  let me know and, if possible, please put me in your credits.
//

#import <Foundation/Foundation.h>

@interface BinaryDataScanner : NSObject {
	BOOL littleEndian;
	NSStringEncoding encoding;
	NSData *data;
	const uint8_t *current;
	NSUInteger scanRemain;
}

+(id)binaryDataScannerWithData:(NSData*)data littleEndian:(BOOL)littleEndian defaultEncoding:(NSStringEncoding)defaultEncoding;

-(NSUInteger) remainingBytes;
-(const uint8_t *) currentPointer;

-(void) skipBytes:(NSUInteger)count;
-(uint8_t) readByte;
-(uint16_t) readWord;
-(uint32_t) readDoubleWord;
-(NSString*) readNullTerminatedString;
-(NSString*) readNullTerminatedStringWithEncoding:(NSStringEncoding)overrideEncoding;
-(NSString*) readStringUntilDelimiter:(uint8_t)delim;
-(NSString*) readStringUntilDelimiter:(uint8_t)delim encoding:(NSStringEncoding)overrideEncoding;
-(NSString*) readStringOfLength:(NSUInteger)count handleNullTerminatorAfter:(BOOL)handleNull;
-(NSString*) readStringOfLength:(NSUInteger)count handleNullTerminatorAfter:(BOOL)handleNull encoding:(NSStringEncoding)overrideEncoding;
-(NSArray*) readArrayOfNullTerminatedStrings:(NSUInteger)count;
-(NSArray*) readArrayOfNullTerminatedStrings:(NSUInteger)count encoding:(NSStringEncoding)overrideEncoding;

@end
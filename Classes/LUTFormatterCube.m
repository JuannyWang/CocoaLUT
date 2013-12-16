//
//  LUTFormatterCube.m
//  DropLUT
//
//  Created by Wil Gieseler on 12/15/13.
//  Copyright (c) 2013 Wil Gieseler. All rights reserved.
//

#import "LUTFormatterCube.h"

@implementation LUTFormatterCube

+ (LUT *)LUTFromLines:(NSArray *)lines {
    
    NSUInteger __block cubeSize = 0;
    NSUInteger __block sizeLineIndex = 0;
    
    // Find the size
    [lines enumerateObjectsUsingBlock:^(NSString *line, NSUInteger i, BOOL *stop) {
        if ([line rangeOfString:@"LUT_3D_SIZE"].location != NSNotFound) {
            NSString *sizeString = [line componentsSeparatedByString:@" "][1];
            cubeSize = sizeString.integerValue;
            sizeLineIndex = i;
            *stop = YES;
        }
    }];
    
    if (cubeSize == 0) {
        NSException *exception = [NSException exceptionWithName:@"LUTParseError" reason:@"Couldn't find LUT size in file" userInfo:nil];
        @throw exception;
    }
    
    LUTLattice *lattice = [[LUTLattice alloc] initWithSize:cubeSize];
    
    NSUInteger currentCubeIndex = 0;
    for (NSString *line in [lines subarrayWithRange:NSMakeRange(sizeLineIndex + 1, lines.count - sizeLineIndex - 1)]) {

        if (line.length > 0 && [line rangeOfString:@"#"].location == NSNotFound) {
            NSArray *splitLine = [line componentsSeparatedByString:@" "];
            if (splitLine.count == 3) {
                
                // Valid cube line
                LUTColorValue redValue = ((NSString *)splitLine[0]).doubleValue;
                LUTColorValue greenValue = ((NSString *)splitLine[1]).doubleValue;
                LUTColorValue blueValue = ((NSString *)splitLine[2]).doubleValue;
                
                LUTColor *color = [LUTColor colorWithRed:redValue green:greenValue blue:blueValue];
                
                NSUInteger redIndex = currentCubeIndex % cubeSize;
				NSUInteger greenIndex = ( (currentCubeIndex % (cubeSize * cubeSize)) / (cubeSize) );
				NSUInteger blueIndex = currentCubeIndex / (cubeSize * cubeSize);
                
                [lattice setColor:color r:redIndex g:greenIndex b:blueIndex];

//                NSLog(@"Set color (%@) for index (%lu) at %lu R %lu G %lu B", color, (unsigned long)currentCubeIndex, redIndex, greenIndex, blueIndex);

                currentCubeIndex++;
            }
        }
    }
    
    return [LUT LUTWithLattice:lattice];
}

@end

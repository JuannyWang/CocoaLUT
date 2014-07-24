//
//  LUTWhitePoint.h
//  Pods
//
//  Created by Greg Cotten on 6/24/14.
//
//

#import <Foundation/Foundation.h>
#import <GLKit/GLKit.h>
#import <M13OrderedDictionary/M13OrderedDictionary.h>

@interface LUTColorSpaceWhitePoint : NSObject <NSCopying>

@property (assign) double whiteChromaticityX;
@property (assign) double whiteChromaticityY;
@property (strong) NSString *name;

+ (instancetype)whitePointWithWhiteChromaticityX:(double)whiteChromaticityX
                              whiteChromaticityY:(double)whiteChromaticityY
                                            name:(NSString *)name;
- (GLKVector3)tristimulusValues;

+ (NSArray *)knownWhitePoints;

+ (instancetype)d65WhitePoint;
+ (instancetype)d60WhitePoint;
+ (instancetype)d55WhitePoint;
+ (instancetype)dciWhitePoint;


@end


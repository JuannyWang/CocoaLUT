//
//  LUTFormatterArriLook.m
//  Pods
//
//  Created by Greg Cotten on 5/16/14.
//
//

#import "LUTFormatterArriLook.h"
#import <XMLDictionary/XMLDictionary.h>



@implementation LUTFormatterArriLook

+ (void)load{
    [super load];
}

+ (LUT *)LUTFromData:(NSData *)data{
    NSDictionary *xml = [NSDictionary dictionaryWithXMLData:data];

    if(![[xml attributes][@"version"] isEqualToString:@"1.0"]){
        @throw [NSException exceptionWithName:@"ArriLookParserError" reason:@"Arri Look Version not 1.0" userInfo:nil];
    }
    
    LUT1D *toneMapLUT;
    if ([xml valueForKeyPath:@"ToneMapLut"]) {
        NSArray *toneMapLines = arrayWithComponentsSeperatedByNewlineAndWhitespaceWithEmptyElementsRemoved([[xml valueForKeyPath:@"ToneMapLut"] innerText]);
        
        NSMutableArray *curve1D = [NSMutableArray array];
        
        for (NSString *line in toneMapLines){
            if([line componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]].count > 1){
                @throw [NSException exceptionWithName:@"ArriLookParserError" reason:@"Tone Map Value invalid" userInfo:nil];
            }
            
            if(stringIsValidNumber(line) == NO){
                @throw [NSException exceptionWithName:@"ArriLookParserError" reason:[NSString stringWithFormat:@"NaN detected in LUT: \"%@\"", line] userInfo:nil];
            }
            
            [curve1D addObject:@((double)[line integerValue]/4095.0)];
        }
        
        if(curve1D.count !=  [[xml valueForKeyPath:@"ToneMapLut._rows"] integerValue]){
            @throw [NSException exceptionWithName:@"ArriLookParserError" reason:@"Number of tonemap lines != rows value!" userInfo:nil];
        }
        
        toneMapLUT = [LUT1D LUT1DWith1DCurve:curve1D lowerBound:0.0 upperBound:1.0];
    }
    else{
        toneMapLUT = [self k1s1ToneMap];
    }

    



    double saturation;
    if (![xml valueForKeyPath:@"Saturation"]) {
        saturation = 1.0;
    }
    else{
        saturation = [[xml valueForKeyPath:@"Saturation"] doubleValue];
    }
    

    //NSLog(@"saturation %f", saturation);
    LUTColor *printerLight;
    if (![xml valueForKeyPath:@"PrinterLight"]) {
        printerLight = [LUTColor colorWithZeroes];
    }
    else{
        NSArray *printerLightSplitLine = arrayWithComponentsSeperatedByNewlineAndWhitespaceWithEmptyElementsRemoved([xml valueForKeyPath:@"PrinterLight"]);
        printerLight = [LUTColor colorWithRed:[printerLightSplitLine[0] doubleValue] green:[printerLightSplitLine[1] doubleValue] blue:[printerLightSplitLine[2] doubleValue]];
    }
    

    //NSLog(@"PrinterLight %@", printerLight);
    double redSlope;
    double greenSlope;
    double blueSlope;
    

    double redOffset;
    double greenOffset;
    double blueOffset;
    

    double redPower;
    double greenPower;
    double bluePower;
    
    if (![xml valueForKeyPath:@"SOPNode"]) {
        redSlope = 1;
        greenSlope = 1;
        blueSlope = 1;
        
        redOffset = 0;
        greenOffset = 0;
        blueOffset = 0;
        
        redPower = 1;
        greenPower = 1;
        bluePower = 1;
    }
    else{
        NSArray *slopeSplitLine = arrayWithComponentsSeperatedByNewlineAndWhitespaceWithEmptyElementsRemoved([xml valueForKeyPath:@"SOPNode.Slope"]);
        redSlope = [slopeSplitLine[0] doubleValue];
        greenSlope = [slopeSplitLine[1] doubleValue];
        blueSlope = [slopeSplitLine[2] doubleValue];
        
        NSArray *offsetSplitLine = arrayWithComponentsSeperatedByNewlineAndWhitespaceWithEmptyElementsRemoved([xml valueForKeyPath:@"SOPNode.Offset"]);
        redOffset = [offsetSplitLine[0] doubleValue];
        greenOffset = [offsetSplitLine[1] doubleValue];
        blueOffset = [offsetSplitLine[2] doubleValue];
        
        NSArray *powerSplitLine = arrayWithComponentsSeperatedByNewlineAndWhitespaceWithEmptyElementsRemoved([xml valueForKeyPath:@"SOPNode.Power"]);
        redPower = [powerSplitLine[0] doubleValue];
        greenPower = [powerSplitLine[1] doubleValue];
        bluePower = [powerSplitLine[2] doubleValue];
    }

    

    //NSLog(@"slope %@\noffset %@\npower %@", slopeSplitLine, offsetSplitLine, powerSplitLine);

    LUT3D *lut3D = [LUT3D LUTIdentityOfSize:64 inputLowerBound:0.0 inputUpperBound:1.0];


    //apply in order: Printer Lights -> Tonemap -> g24_to_linear -> Alexa tonemap color matrix -> Saturation w/ destination coefficients -> linear_to_g24 -> clamp01 -> CDL -> clamp01
    [lut3D LUTLoopWithBlock:^(size_t r, size_t g, size_t b) {
        LUTColor *color = [lut3D colorAtR:r g:g b:b];
        //  AlexaWideGamut Luma from NPM: 0.291948669899 R + 0.823830265984 G + -0.115778935883 B
        color = [color colorByAddingColor:printerLight];
        
        color = [toneMapLUT colorAtColor:color];
        color = [LUTColor colorWithRed:pow(color.red, 2.4) green:pow(color.green, 2.4) blue:pow(color.blue, 2.4)];
        color = [color colorByApplyingColorMatrixColumnMajorM00:1.485007
                                                            m01:-0.033732
                                                            m02:0.010776
                                                            m10:-0.401216
                                                            m11:1.282887
                                                            m12:-0.122018
                                                            m20:-0.083791
                                                            m21:-0.249155
                                                            m22:1.111242];
        color = [color colorByChangingSaturation:saturation usingLumaR:0.2126 lumaG:0.7152 lumaB:0.0722];
        
        color = [LUTColor colorWithRed:pow(color.red, 1.0/2.4) green:pow(color.green, 1.0/2.4) blue:pow(color.blue, 1.0/2.4)];
        color = [color clamped01];
        
        color = [color colorByApplyingRedSlope:redSlope
                                     redOffset:redOffset
                                      redPower:redPower
                                    greenSlope:greenSlope
                                   greenOffset:greenOffset
                                    greenPower:greenPower
                                     blueSlope:blueSlope
                                    blueOffset:blueOffset
                                     bluePower:bluePower];
        
        color = [color clamped01];

        [lut3D setColor:color r:r g:g b:b];
    }];

    lut3D.passthroughFileOptions = @{[self formatterID]:@{@"fileTypeVariant":@"Arri"
                                                          }};

    return lut3D;
}

+ (NSString *)stringFromLUT:(LUT *)lut withOptions:(NSDictionary *)options{
    NSMutableString *string = [[NSMutableString alloc] init];

    [string appendString:@"<!-- ARRI Digital Camera Look File -->\n<!-- This XML format is used to import color settings into the camera(\"look file\")-->\n<adicam version=\"1.0\" camera=\"alexa\">\n\t<Saturation>\n\t\t1.000000\n\t</Saturation>\n\t<PrinterLight>\n\t\t0.000000 0.000000 0.000000\n\t</PrinterLight>\n\t<SOPNode>\n\t\t<Slope>1.000000 1.000000 1.000000</Slope>\n\t\t<Offset>0.000000 0.000000 0.000000</Offset>\n\t\t<Power>1.000000 1.000000 1.000000</Power>\n\t</SOPNode>\n\t<ToneMapLut rows=\"4096\" cols=\"1\">\n"];

    LUT1D *lut1D = (LUT1D *)lut;

    NSArray *redCurve = [lut1D rgbCurveArray][0];

    for (int i = 0; i < 4096; i++) {
        [string appendString:[NSString stringWithFormat:@"\t%i\n", (int)([redCurve[i] doubleValue]*4095.0)]];
    }

    [string appendString:@"\t</ToneMapLut>\n</adicam>"];

    return string;
}


+ (LUTFormatterOutputType)outputType{
    return LUTFormatterOutputType1D;
}

+ (BOOL)isDestructiveWithOptions:(NSDictionary *)options{
    return YES;
}

+ (BOOL)isValidReaderForURL:(NSURL *)fileURL{
    if ([super isValidReaderForURL:fileURL] == NO) {
        return NO;
    }
    NSDictionary *xml = [NSDictionary dictionaryWithXMLFile:[fileURL path]];
    if([[xml attributes][@"version"] isEqualToString:@"1.0"] || [[xml attributes][@"camera"] isEqualToString:@"alexa"]){
        return YES;
    }
    return NO;
}

+ (NSArray *)conformanceLUTActionsForLUT:(LUT *)lut options:(NSDictionary *)options{
    NSMutableArray *actions = [NSMutableArray arrayWithArray:[super conformanceLUTActionsForLUT:lut options:options]];

    if (actions == nil) {
        actions = [[NSMutableArray alloc] init];
    }

    NSDictionary *exposedOptions = options[[self formatterID]];

    LUT1DSwizzleChannelsMethod method = [[LUT1D LUT1DSwizzleChannelsMethods][exposedOptions[@"mixCurvesMethod"]] integerValue];

    [actions addObject:[LUTAction actionWithLUTBySwizzlingWithMethod:method]];

    return actions;
}

+ (NSDictionary *)constantConstraints{
    return @{@"inputBounds":@[@0, @1],
             @"outputBounds":@[@0, @1]};
}

+ (NSArray *)allOptions{

    NSDictionary *arriOptions =
    @{@"fileTypeVariant":@"Arri",
      @"mixCurvesMethod": [LUT1D LUT1DSwizzleChannelsMethods],
      @"lutSize":M13OrderedDictionaryFromOrderedArrayWithDictionaries(@[@{@"4096": @(4096)}])};


    return @[arriOptions];
}

+ (NSDictionary *)defaultOptions{
    NSDictionary *dictionary = @{@"fileTypeVariant": @"Arri",
                                 @"mixCurvesMethod": @(LUT1DSwizzleChannelsMethodAverageRGB),
                                 @"lutSize":@4096};

    return @{[self formatterID]: dictionary};
}

+ (NSString *)formatterName{
    return @"Arri Look";
}

+ (NSString *)formatterID{
    return @"arriLook";
}

+ (BOOL)canRead{
    return YES;
}

+ (BOOL)canWrite{
    return YES;
}

+ (NSString *)utiString{
    return @"public.xml";
}

+ (NSArray *)fileExtensions{
    return @[@"xml"];
}

+ (NSBundle *)transferFunctionsLUTResourceBundle{
    static NSBundle *transferFunctionsBundle = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        transferFunctionsBundle = [NSBundle bundleWithURL:[[NSBundle bundleForClass:self.class] URLForResource:@"ManufacturerLUTs" withExtension:@"bundle"]];
    });
    
    return transferFunctionsBundle;
}

+ (NSURL *)lutFromBundleWithName:(NSString *)name extension:(NSString *)extension{
    return [[self.class transferFunctionsLUTResourceBundle] URLForResource:name withExtension:extension];
}

+ (LUT1D *)k1s1ToneMap{
    static LUT1D *k1s1 = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSURL *lutURL = [self lutFromBundleWithName:@"AlexaV3_K1S1_LogC2Video_TonemapOnly_EE_cube1d_4096" extension:@"cube"];
        k1s1 = (LUT1D *)[LUT LUTFromURL:lutURL error:nil];
    });
    
    return k1s1;
}

@end

//
//  BTSLissajousLayer.m
//  CoreAnimationFunHouse
//
//  Created by Brian Coyner on 10/28/11.
//  Copyright (c) 2011 Brian Coyner. All rights reserved.
//

#import "BTSLissajousLayer.h"

#define USE_CADISPLAY_LINK 1

static NSString *const kBTSLissajouseLayerAmplitude = @"amplitude";
static NSString *const kBTSLissajouseLayerA = @"a";
static NSString *const kBTSLissajouseLayerB = @"b";
static NSString *const kBTSLissajouseLayerDelta = @"delta";

static const CGFloat TWO_PI = (CGFloat)(M_PI * 2.0f);

#ifdef USE_CADISPLAY_LINK

// NOTE: Sometimes the 'needsDisplayForKey:' (as described in 'BTSSineWaveLayer.m') can produce undesired 'flickering' effects.
//       I have yet to see any undesired 'flickering' effects using the CADisplayLink approach.

@interface BTSLissajousLayer ()<CAAnimationDelegate> {
    CADisplayLink *_displayLink;
    NSMutableArray *_currentAnimations;
}
@end

#endif

@implementation BTSLissajousLayer

@dynamic amplitude;
@dynamic a;
@dynamic b;
@dynamic delta;

+ (NSSet *)keyPathsForDynamicProperties
{
    static NSSet *keys = nil;
    if (keys == nil) {
        keys = [[NSSet alloc] initWithObjects:kBTSLissajouseLayerAmplitude, kBTSLissajouseLayerA, kBTSLissajouseLayerB, kBTSLissajouseLayerDelta, nil];
    }
    return keys;
}

#pragma mark - Object Life Cycle

- (id)init
{
    self = [super init];
    if (self) {
        _currentAnimations = [[NSMutableArray alloc] initWithCapacity:3];
    }
    return self;
}

#pragma mark - Layer Drawing

- (void)drawInContext:(CGContextRef)context
{
    [super drawInContext:context];

    CGRect bounds = [self bounds];

    CGContextTranslateCTM(context, (CGFloat)(CGRectGetWidth(bounds) / 2.0), (CGFloat)(CGRectGetHeight(bounds) / 2.0));

    BTSDrawCoordinateAxes(context);
    CGContextSetStrokeColorWithColor(context, [[UIColor blackColor] CGColor]);
    CGContextSetLineWidth(context, 2.0);

    // The layer redraws the curve using the current animation's interpolated values. The interpolated
    // values are retrieved from the layer's "presentationLayer".
    id presentationLayer = [self presentationLayer];
    CGFloat amplitude = [[presentationLayer valueForKey:kBTSLissajouseLayerAmplitude] floatValue];
    CGFloat a = [[presentationLayer valueForKey:kBTSLissajouseLayerA] floatValue];
    CGFloat b = [[presentationLayer valueForKey:kBTSLissajouseLayerB] floatValue];
    CGFloat delta = [[presentationLayer valueForKey:kBTSLissajouseLayerDelta] floatValue];

    CGFloat increment = TWO_PI / (a * b * 100.0f);
    CGMutablePathRef path = CGPathCreateMutable();

    BOOL shouldMoveToPoint = YES;

    for (CGFloat t = 0.0; t < TWO_PI + increment; t = t + increment) {
        CGFloat x = (CGFloat)(amplitude * sin(a * t + delta));
        CGFloat y = (CGFloat)(amplitude * sin(b * t));
        if (shouldMoveToPoint) {
            CGPathMoveToPoint(path, NULL, x, y);
            shouldMoveToPoint = NO;
        } else {
            CGPathAddLineToPoint(path, NULL, x, y);
        }
    }

    CGContextAddPath(context, path);
    CGContextSetLineJoin(context, kCGLineJoinBevel);
    CGContextStrokePath(context);
    CFRelease(path);
}

#pragma mark - CALayer Delegate

- (id<CAAction>)actionForKey:(NSString *)event
{
    // Called when a property changes.

    if ([[BTSLissajousLayer keyPathsForDynamicProperties] containsObject:event]) {

        CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:event];
        NSValue *valueForKey = [[self presentationLayer] valueForKey:event];

        [animation setFromValue:valueForKey];
        [animation setDelegate:self];
        [animation setDuration:1.0];

        return animation;

    } else {
        return [super actionForKey:event];
    }
}

#pragma mark - Animation Delegate Callbacks

- (void)animationDidStart:(CAAnimation *)animation
{
    if ([animation isKindOfClass:[CAPropertyAnimation class]]) {
        NSSet *internalKeys = [BTSLissajousLayer keyPathsForDynamicProperties];
        if ([internalKeys containsObject:[(CAPropertyAnimation *)animation keyPath]]) {

            [_currentAnimations addObject:animation];
            if (_displayLink == nil) {
                _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(animationTimerFired:)];
                [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
            }
        }
    }
}

- (void)animationDidStop:(CAAnimation *)animation finished:(BOOL)flag
{
    [_currentAnimations removeObject:animation];
    if ([_currentAnimations count] == 0) {
        [_displayLink invalidate];
        _displayLink = nil;

        // hmmm... the use of CADisplayLink seems to miss the final set of interpolated values... let's force a final paint.
        // note... this was not necessary when using an explicit NSTimer (need to investigate more).
        [self setNeedsDisplay];
    }
}

#pragma mark - Timer Callback

- (void)animationTimerFired:(CADisplayLink *)displayLink
{
    [self setNeedsDisplay];
}

@end

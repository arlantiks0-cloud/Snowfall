#import <UIKit/UIKit.h>

@interface SnowfallOverlay : UIView
@property (nonatomic, strong) NSMutableArray<UILabel *> *particles;
@property (nonatomic, strong) NSTimer *spawnTimer;
@end

@implementation SnowfallOverlay

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];

    if (self) {
        self.backgroundColor = UIColor.clearColor;
        self.userInteractionEnabled = NO;
        self.clipsToBounds = YES;
        self.particles = [NSMutableArray array];

        self.spawnTimer =
        [NSTimer scheduledTimerWithTimeInterval:0.15
                                        repeats:YES
                                          block:^(NSTimer *timer) {
            [self spawnParticle];
        }];
    }

    return self;
}

- (void)spawnParticle {
    if (self.particles.count >= 50) return;

    CGFloat size = 24.0;
    CGFloat x = arc4random_uniform(
        MAX(1, (uint32_t)self.bounds.size.width)
    );

    UILabel *particle = [[UILabel alloc]
        initWithFrame:CGRectMake(x, -size, size, size)];

    particle.text = @"❄";
    particle.font = [UIFont systemFontOfSize:size];
    particle.textAlignment = NSTextAlignmentCenter;
    particle.backgroundColor = UIColor.clearColor;

    [self addSubview:particle];
    [self.particles addObject:particle];

    CGFloat duration = 5.0 + arc4random_uniform(400) / 100.0;
    CGFloat drift = (CGFloat)arc4random_uniform(101) - 50.0;

    [UIView animateWithDuration:duration
                          delay:0
                        options:UIViewAnimationOptionCurveLinear
                     animations:^{
        particle.frame = CGRectMake(
            x + drift,
            self.bounds.size.height + size,
            size,
            size
        );
    } completion:^(BOOL finished) {
        [self.particles removeObject:particle];
        [particle removeFromSuperview];
    }];
}

@end

static SnowfallOverlay *snowfallOverlay;

%hook SpringBoard

- (void)applicationDidFinishLaunching:(id)application {
    %orig;

    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = UIApplication.sharedApplication.keyWindow;

        if (!window || snowfallOverlay) return;

        snowfallOverlay = [[SnowfallOverlay alloc]
            initWithFrame:window.bounds];

        snowfallOverlay.autoresizingMask =
            UIViewAutoresizingFlexibleWidth |
            UIViewAutoresizingFlexibleHeight;

        [window addSubview:snowfallOverlay];
    });
}

%end

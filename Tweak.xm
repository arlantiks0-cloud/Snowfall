
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

static NSString * const SnowfallDomain = @"com.ilya.snowfall";

@interface SnowfallOverlay : UIView
@property (nonatomic, strong) NSMutableArray<UIView *> *particles;
@property (nonatomic, strong) NSTimer *spawnTimer;
@property (nonatomic, assign) NSTimeInterval lastSpawnTime;
@end

@implementation SnowfallOverlay

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];

    if (self) {
        self.backgroundColor = UIColor.clearColor;
        self.opaque = NO;
        self.userInteractionEnabled = NO;
        self.clipsToBounds = YES;
        self.particles = [NSMutableArray array];
        self.lastSpawnTime = 0;

        __weak SnowfallOverlay *weakSelf = self;
        self.spawnTimer =
            [NSTimer scheduledTimerWithTimeInterval:0.05
                                            repeats:YES
                                              block:^(NSTimer *timer) {
            [weakSelf spawnParticle];
        }];
    }

    return self;
}

- (NSDictionary *)prefs {
    NSDictionary *domain = [[NSUserDefaults standardUserDefaults]
        persistentDomainForName:SnowfallDomain];
    return domain ?: @{};
}

- (CGFloat)valueForKey:(NSString *)key
               fallback:(CGFloat)fallback {
    id value = [self prefs][key];
    if (![value respondsToSelector:@selector(floatValue)]) {
        return fallback;
    }
    return [value floatValue];
}

- (UIBezierPath *)smoothPathFromPoints:(NSArray *)points {
    UIBezierPath *path = [UIBezierPath bezierPath];

    if (points.count < 2) return path;

    CGPoint first = [points[0] CGPointValue];
    [path moveToPoint:first];

    if (points.count == 2) {
        [path addLineToPoint:[points[1] CGPointValue]];
        return path;
    }

    for (NSUInteger i = 1; i < points.count - 1; i++) {
        CGPoint current = [points[i] CGPointValue];
        CGPoint next = [points[i + 1] CGPointValue];

        CGPoint midpoint = CGPointMake(
            (current.x + next.x) / 2.0,
            (current.y + next.y) / 2.0
        );

        [path addQuadCurveToPoint:midpoint controlPoint:current];
    }

    [path addLineToPoint:[points.lastObject CGPointValue]];
    return path;
}

- (NSArray<NSValue *> *)screenPointsFromPrefs:(NSDictionary *)prefs
                                         size:(CGFloat)size {
    NSArray *saved = prefs[@"PathPoints"];
    CGFloat width = CGRectGetWidth(self.bounds);
    CGFloat height = CGRectGetHeight(self.bounds);

    NSMutableArray<NSValue *> *points = [NSMutableArray array];

    if ([saved isKindOfClass:NSArray.class] && saved.count >= 2) {
        for (NSArray *pair in saved) {
            if (![pair isKindOfClass:NSArray.class] || pair.count < 2) {
                continue;
            }

            CGFloat x = [pair[0] floatValue] * width;
            CGFloat y = [pair[1] floatValue] * height;

            x = MAX(size / 2.0, MIN(width - size / 2.0, x));
            y = MAX(size / 2.0, MIN(height - size / 2.0, y));

            [points addObject:[NSValue valueWithCGPoint:
                CGPointMake(x, y)]];
        }
    }

    if (points.count >= 2) return points;

    // Если редактор ещё не использовался, применяем старую траекторию.
    NSInteger direction =
        [prefs[@"FallDirection"] respondsToSelector:@selector(integerValue)]
        ? [prefs[@"FallDirection"] integerValue] : 0;

    CGPoint start = CGPointMake(width * 0.15, size / 2.0);
    CGPoint end = CGPointMake(width * 0.85, height - size / 2.0);

    switch (direction) {
        case 1:
            start = CGPointMake(width * 0.85, size / 2.0);
            end = CGPointMake(width * 0.15, height - size / 2.0);
            break;
        case 2:
            start = CGPointMake(width / 2.0, size / 2.0);
            end = CGPointMake(width / 2.0, height - size / 2.0);
            break;
        case 3:
            start = CGPointMake(size / 2.0, size / 2.0);
            end = CGPointMake(size / 2.0, height - size / 2.0);
            break;
        case 4:
            start = CGPointMake(width - size / 2.0, size / 2.0);
            end = CGPointMake(width - size / 2.0,
                              height - size / 2.0);
            break;
        case 5:
            start = CGPointMake(width / 2.0, size / 2.0);
            end = CGPointMake(size / 2.0, height - size / 2.0);
            break;
        case 6:
            start = CGPointMake(width / 2.0, size / 2.0);
            end = CGPointMake(width - size / 2.0,
                              height - size / 2.0);
            break;
        default:
            break;
    }

    CGPoint control = CGPointMake(
        (start.x + end.x) / 2.0 + width * 0.12,
        height * 0.5
    );

    return @[
        [NSValue valueWithCGPoint:start],
        [NSValue valueWithCGPoint:control],
        [NSValue valueWithCGPoint:end]
    ];
}

- (void)spawnParticle {
    NSDictionary *prefs = [self prefs];

    CGFloat size = [self valueForKey:@"ParticleSize" fallback:24.0];
    NSInteger limit = (NSInteger)[self valueForKey:@"ParticleCount"
                                             fallback:20.0];
    CGFloat rate = [self valueForKey:@"SpawnRate" fallback:3.0];
    CGFloat speed = [self valueForKey:@"FallSpeed" fallback:5.0];

    size = MAX(10.0, MIN(size, 50.0));
    limit = MAX(1, MIN(limit, 100));
    rate = MAX(1.0, MIN(rate, 20.0));
    speed = MAX(1.0, MIN(speed, 10.0));

    if (CGRectGetWidth(self.bounds) <= 0 ||
        CGRectGetHeight(self.bounds) <= 0) {
        return;
    }

    for (UIView *view in [self.particles copy]) {
        if (view.superview != self) {
            [self.particles removeObject:view];
        }
    }

    if (self.particles.count >= limit) return;

    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    if (self.lastSpawnTime > 0 &&
        now - self.lastSpawnTime < (1.0 / rate)) {
        return;
    }
    self.lastSpawnTime = now;

    NSArray<NSValue *> *points =
        [self screenPointsFromPrefs:prefs size:size];

    if (points.count < 2) return;

    CGPoint first = points.firstObject.CGPointValue;
    UIBezierPath *path = [self smoothPathFromPoints:points];

    UIView *particle = nil;
    NSString *encoded = prefs[@"CustomImagePNG"];

    if ([encoded isKindOfClass:NSString.class] && encoded.length > 0) {
        NSData *data = [[NSData alloc] initWithBase64EncodedString:encoded
                                                           options:0];
        UIImage *image = data ? [UIImage imageWithData:data] : nil;

        if (image) {
            UIImageView *imageView =
                [[UIImageView alloc] initWithImage:image];
            imageView.backgroundColor = UIColor.clearColor;
            imageView.opaque = NO;
            imageView.contentMode = UIViewContentModeScaleAspectFit;
            particle = imageView;
        }
    }

    if (!particle) {
        UILabel *label = [[UILabel alloc] init];
        label.text = @"❄";
        label.font = [UIFont systemFontOfSize:size];
        label.textAlignment = NSTextAlignmentCenter;
        label.backgroundColor = UIColor.clearColor;
        label.opaque = NO;
        particle = label;
    }

    particle.frame = CGRectMake(first.x - size / 2.0,
                                first.y - size / 2.0,
                                size, size);
    particle.userInteractionEnabled = NO;

    [self addSubview:particle];
    [self.particles addObject:particle];

    CGFloat duration = 15.0 / speed;
    duration = MAX(1.5, MIN(duration, 15.0));

    CAKeyframeAnimation *animation =
        [CAKeyframeAnimation animationWithKeyPath:@"position"];
    animation.path = path.CGPath;
    animation.duration = duration;
    animation.calculationMode = kCAAnimationPaced;
    animation.rotationMode = nil;
    animation.removedOnCompletion = YES;

    [particle.layer addAnimation:animation forKey:@"snowfall.path"];

    __weak UIView *weakParticle = particle;
    __weak SnowfallOverlay *weakSelf = self;

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
        (int64_t)(duration * NSEC_PER_SEC)),
        dispatch_get_main_queue(), ^{
            UIView *finished = weakParticle;
            SnowfallOverlay *overlay = weakSelf;

            if (finished && overlay) {
                [overlay.particles removeObject:finished];
                [finished removeFromSuperview];
            }
        });
}

- (void)dealloc {
    [self.spawnTimer invalidate];
}

@end

static SnowfallOverlay *homeSnowfall;
static SnowfallOverlay *lockSnowfall;

static SnowfallOverlay *SnowfallAttach(
    UIViewController *controller,
    SnowfallOverlay *overlay
) {
    if (!controller.isViewLoaded || !controller.view) return overlay;

    UIView *parent = controller.view;

    if (!overlay) {
        overlay = [[SnowfallOverlay alloc] initWithFrame:parent.bounds];
        overlay.autoresizingMask =
            UIViewAutoresizingFlexibleWidth |
            UIViewAutoresizingFlexibleHeight;
    }

    if (overlay.superview != parent) {
        [overlay removeFromSuperview];
        [parent insertSubview:overlay atIndex:0];
    }

    overlay.frame = parent.bounds;
    [parent sendSubviewToBack:overlay];

    return overlay;
}

%hook SBHomeScreenViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    homeSnowfall = SnowfallAttach((UIViewController *)self, homeSnowfall);
}

%end

%hook CSCoverSheetViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    lockSnowfall = SnowfallAttach((UIViewController *)self, lockSnowfall);
}

%end

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
    NSDictionary *domain =
        [[NSUserDefaults standardUserDefaults]
         persistentDomainForName:SnowfallDomain];
    return domain ?: @{};
}

- (CGFloat)valueForKey:(NSString *)key fallback:(CGFloat)fallback {
    id value = [self prefs][key];
    if (![value respondsToSelector:@selector(floatValue)]) {
        return fallback;
    }
    return [value floatValue];
}

- (void)spawnParticle {
    NSDictionary *prefs = [self prefs];

    CGFloat width = CGRectGetWidth(self.bounds);
    CGFloat height = CGRectGetHeight(self.bounds);
    if (width <= 0 || height <= 0) return;

    CGFloat size = MAX(10, MIN(
        [self valueForKey:@"ParticleSize" fallback:24], 50));

    NSInteger limit = MAX(1, MIN(
        (NSInteger)[self valueForKey:@"ParticleCount" fallback:20], 100));

    CGFloat rate = MAX(1, MIN(
        [self valueForKey:@"SpawnRate" fallback:3], 20));

    CGFloat speed = MAX(1, MIN(
        [self valueForKey:@"FallSpeed" fallback:5], 10));

    for (UIView *view in [self.particles copy]) {
        if (!view.superview) {
            [self.particles removeObject:view];
        }
    }

    if (self.particles.count >= limit) return;

    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    if (self.lastSpawnTime > 0 &&
        now - self.lastSpawnTime < 1.0 / rate) {
        return;
    }
    self.lastSpawnTime = now;

    // Начинаем под статус-баром, а не с самой верхней границы.
    CGFloat topInset = 0;
    if (self.window) {
        topInset = self.window.safeAreaInsets.top;
    }
    if (topInset <= 0) {
        topInset = MAX(self.safeAreaInsets.top, 44);
    }

    CGFloat topY = MIN(topInset + 2, height * 0.25);
    CGFloat bottomY = height + size;

    NSInteger direction =
        [prefs[@"FallDirection"] respondsToSelector:@selector(integerValue)]
        ? [prefs[@"FallDirection"] integerValue] : 0;

    CGPoint start;
    CGPoint end;

    switch (direction) {
        case 1: // Верхний правый -> нижний левый
            start = CGPointMake(width - size / 2, topY);
            end = CGPointMake(size / 2, bottomY);
            break;

        case 2: // По центру сверху вниз
            start = CGPointMake(width / 2, topY);
            end = CGPointMake(width / 2, bottomY);
            break;

        case 5: // Сверху по центру -> нижний левый
            start = CGPointMake(width / 2, topY);
            end = CGPointMake(size / 2, bottomY);
            break;

        case 6: // Сверху по центру -> нижний правый
            start = CGPointMake(width / 2, topY);
            end = CGPointMake(width - size / 2, bottomY);
            break;

        case 0:
        default: // Верхний левый -> нижний правый
            start = CGPointMake(size / 2, topY);
            end = CGPointMake(width - size / 2, bottomY);
            break;
    }

    // Мягкая дуга траектории.
    CGPoint control = CGPointMake(
        (start.x + end.x) / 2.0 +
        (end.x - start.x) * 0.12,
        height * 0.5
    );

    UIBezierPath *path = [UIBezierPath bezierPath];
    [path moveToPoint:start];
    [path addQuadCurveToPoint:end controlPoint:control];

    UIView *particle = nil;
    NSString *encoded = prefs[@"CustomImagePNG"];

    if ([encoded isKindOfClass:NSString.class] &&
        encoded.length > 0) {

        NSData *data =
            [[NSData alloc] initWithBase64EncodedString:encoded options:0];

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

    particle.frame = CGRectMake(
        start.x - size / 2,
        start.y - size / 2,
        size,
        size
    );

    particle.alpha = 0;
    particle.userInteractionEnabled = NO;

    [self addSubview:particle];
    [self.particles addObject:particle];

    CGFloat duration = MAX(1.5, MIN(15.0 / speed, 15.0));

    CAKeyframeAnimation *position =
        [CAKeyframeAnimation animationWithKeyPath:@"position"];
    position.path = path.CGPath;
    position.duration = duration;
    position.calculationMode = kCAAnimationPaced;
    position.removedOnCompletion = YES;

    CAKeyframeAnimation *opacity =
        [CAKeyframeAnimation animationWithKeyPath:@"opacity"];
    opacity.values = @[@0.0, @1.0, @1.0, @0.0];
    opacity.keyTimes = @[@0.0, @0.12, @0.78, @1.0];
    opacity.duration = duration;
    opacity.removedOnCompletion = YES;

    CAAnimationGroup *group = [CAAnimationGroup animation];
    group.animations = @[position, opacity];
    group.duration = duration;
    group.removedOnCompletion = YES;

    [particle.layer addAnimation:group forKey:@"snowfall.particle"];

    __weak UIView *weakParticle = particle;
    __weak SnowfallOverlay *weakSelf = self;

    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW,
                      (int64_t)(duration * NSEC_PER_SEC)),
        dispatch_get_main_queue(), ^{
            UIView *finished = weakParticle;
            SnowfallOverlay *overlay = weakSelf;

            if (finished && overlay) {
                [overlay.particles removeObject:finished];
                [finished removeFromSuperview];
            }
        }
    );
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

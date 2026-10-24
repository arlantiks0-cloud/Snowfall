
#import <UIKit/UIKit.h>

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

- (NSDictionary *)snowfallPrefs {
    NSDictionary *prefs = [[NSUserDefaults standardUserDefaults]
        persistentDomainForName:@"com.ilya.snowfall"];

    return prefs ?: @{};
}

- (void)spawnParticle {
    NSDictionary *prefs = [self snowfallPrefs];

    CGFloat size = [prefs[@"ParticleSize"] respondsToSelector:@selector(floatValue)]
        ? [prefs[@"ParticleSize"] floatValue] : 24.0;

    NSInteger maxParticles =
        [prefs[@"ParticleCount"] respondsToSelector:@selector(integerValue)]
        ? [prefs[@"ParticleCount"] integerValue] : 20;

    CGFloat spawnRate =
        [prefs[@"SpawnRate"] respondsToSelector:@selector(floatValue)]
        ? [prefs[@"SpawnRate"] floatValue] : 3.0;

    CGFloat fallSpeed =
        [prefs[@"FallSpeed"] respondsToSelector:@selector(floatValue)]
        ? [prefs[@"FallSpeed"] floatValue] : 5.0;

    NSInteger direction =
        [prefs[@"FallDirection"] respondsToSelector:@selector(integerValue)]
        ? [prefs[@"FallDirection"] integerValue] : 0;

    size = MAX(10.0, MIN(size, 50.0));
    maxParticles = MAX(1, MIN(maxParticles, 100));
    spawnRate = MAX(1.0, MIN(spawnRate, 20.0));
    fallSpeed = MAX(1.0, MIN(fallSpeed, 10.0));

    // Удаляем завершившиеся частицы, если они ещё числятся в массиве.
    for (UIView *view in [self.particles copy]) {
        if (view.superview != self) {
            [self.particles removeObject:view];
        }
    }

    // Строгий общий лимит для этого слоя.
    if (self.particles.count >= maxParticles ||
        self.bounds.size.width <= 0 ||
        self.bounds.size.height <= 0) {
        return;
    }

    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    NSTimeInterval spawnInterval = 1.0 / spawnRate;

    if (self.lastSpawnTime > 0 &&
        now - self.lastSpawnTime < spawnInterval) {
        return;
    }

    self.lastSpawnTime = now;

    CGFloat width = self.bounds.size.width;
    CGFloat height = self.bounds.size.height;

    CGFloat startX = 0;
    CGFloat endX = 0;

    // 0: слева направо
    // 1: справа налево
    // 2: по центру вертикально
    // 3: слева вниз в левый угол
    // 4: справа вниз в правый угол
    // 5: из центра в нижний левый угол
    // 6: из центра в нижний правый угол
    switch (direction) {
        case 1:
            startX = width - size;
            endX = 0;
            break;
        case 2:
            startX = (width - size) / 2.0;
            endX = startX;
            break;
        case 3:
            startX = 0;
            endX = 0;
            break;
        case 4:
            startX = width - size;
            endX = width - size;
            break;
        case 5:
            startX = (width - size) / 2.0;
            endX = 0;
            break;
        case 6:
            startX = (width - size) / 2.0;
            endX = width - size;
            break;
        default:
            startX = arc4random_uniform(MAX(1, (uint32_t)width));
            endX = width - size;
            break;
    }

    // Если выбрано направление с разбросом, сохраняем естественное движение.
    if (direction == 0) {
        startX = arc4random_uniform(MAX(1, (uint32_t)width));
        endX = MIN(width - size, startX + width * 0.25);
    } else if (direction == 1) {
        startX = width - size;
        endX = 0;
    }

    NSString *encoded = prefs[@"CustomImagePNG"];
    NSData *imageData = nil;
    UIImage *customImage = nil;

    if ([encoded isKindOfClass:NSString.class] && encoded.length > 0) {
        imageData = [[NSData alloc] initWithBase64EncodedString:encoded
                                                       options:0];
        if (imageData) {
            customImage = [UIImage imageWithData:imageData];
        }
    }

    UIView *particle;

    if (customImage) {
        UIImageView *imageView =
            [[UIImageView alloc] initWithImage:customImage];
        imageView.contentMode = UIViewContentModeScaleAspectFit;
        imageView.frame = CGRectMake(startX, -size, size, size);
        particle = imageView;
    } else {
        UILabel *label =
            [[UILabel alloc] initWithFrame:CGRectMake(startX, -size, size, size)];
        label.text = @"❄";
        label.font = [UIFont systemFontOfSize:size];
        label.textAlignment = NSTextAlignmentCenter;
        label.backgroundColor = UIColor.clearColor;
        particle = label;
    }

    particle.userInteractionEnabled = NO;
    [self addSubview:particle];
    [self.particles addObject:particle];

    // Чем выше FallSpeed, тем быстрее падение.
    CGFloat duration = 12.0 / fallSpeed;
    duration = MAX(0.8, MIN(duration, 12.0));

    [UIView animateWithDuration:duration
                          delay:0
                        options:UIViewAnimationOptionCurveLinear
                     animations:^{
        particle.frame = CGRectMake(
            endX,
            height + size,
            size,
            size
        );
    } completion:^(BOOL finished) {
        [self.particles removeObject:particle];
        [particle removeFromSuperview];
    }];
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
    if (!controller.isViewLoaded || !controller.view) {
        return overlay;
    }

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

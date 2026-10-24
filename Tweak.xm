
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

        __weak SnowfallOverlay *weakSelf = self;

        self.spawnTimer =
        [NSTimer scheduledTimerWithTimeInterval:0.15
                                        repeats:YES
                                          block:^(NSTimer *timer) {
            [weakSelf spawnParticle];
        }];
    }

    return self;
}

- (void)spawnParticle {
    NSDictionary *prefs = [[NSUserDefaults standardUserDefaults]
        persistentDomainForName:@"com.ilya.snowfall"];

    CGFloat size = [prefs[@"ParticleSize"] respondsToSelector:@selector(floatValue)]
        ? [prefs[@"ParticleSize"] floatValue] : 24.0;

    NSInteger maxParticles = [prefs[@"ParticleCount"] respondsToSelector:@selector(integerValue)]
        ? [prefs[@"ParticleCount"] integerValue] : 50;

    size = MAX(10.0, MIN(size, 50.0));
    maxParticles = MAX(10, MIN(maxParticles, 100));

    if (self.particles.count >= maxParticles ||
        self.bounds.size.width <= 0) {
        return;
    }

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

    CGFloat duration =
        5.0 + arc4random_uniform(400) / 100.0;

    CGFloat drift =
        (CGFloat)arc4random_uniform(101) - 50.0;

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
        overlay = [[SnowfallOverlay alloc]
            initWithFrame:parent.bounds];

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

    homeSnowfall = SnowfallAttach(
        (UIViewController *)self,
        homeSnowfall
    );
}

%end

%hook CSCoverSheetViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;

    lockSnowfall = SnowfallAttach(
        (UIViewController *)self,
        lockSnowfall
    );
}

%end

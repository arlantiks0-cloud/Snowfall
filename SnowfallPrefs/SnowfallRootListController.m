
#import <UIKit/UIKit.h>
#import <PhotosUI/PhotosUI.h>
#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>

static NSString * const SnowfallDomain = @"com.ilya.snowfall";

@interface SnowfallPathCanvas : UIView
@property (nonatomic, strong) NSMutableArray<NSValue *> *points;
@property (nonatomic, assign) BOOL hasSavedPath;
- (void)clearPath;
- (NSArray *)normalizedPoints;
@end

@implementation SnowfallPathCanvas

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor colorWithWhite:0.08 alpha:1.0];
        self.points = [NSMutableArray array];
        self.multipleTouchEnabled = NO;
    }
    return self;
}

- (void)drawRect:(CGRect)rect {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (!ctx) return;

    CGFloat w = CGRectGetWidth(self.bounds);
    CGFloat h = CGRectGetHeight(self.bounds);

    CGContextSetStrokeColorWithColor(ctx,
        [UIColor colorWithWhite:0.25 alpha:1.0].CGColor);
    CGContextSetLineWidth(ctx, 1.0);

    for (NSInteger i = 1; i < 4; i++) {
        CGFloat x = w * i / 4.0;
        CGContextMoveToPoint(ctx, x, 0);
        CGContextAddLineToPoint(ctx, x, h);

        CGFloat y = h * i / 4.0;
        CGContextMoveToPoint(ctx, 0, y);
        CGContextAddLineToPoint(ctx, w, y);
    }
    CGContextStrokePath(ctx);

    CGContextSetStrokeColorWithColor(ctx,
        [UIColor systemBlueColor].CGColor);
    CGContextSetLineWidth(ctx, 4.0);
    CGContextSetLineCap(ctx, kCGLineCapRound);
    CGContextSetLineJoin(ctx, kCGLineJoinRound);

    if (self.points.count > 0) {
        UIBezierPath *path = [UIBezierPath bezierPath];
        path.lineWidth = 4.0;
        path.lineCapStyle = kCGLineCapRound;
        path.lineJoinStyle = kCGLineJoinRound;

        CGPoint first = self.points.firstObject.CGPointValue;
        [path moveToPoint:first];

        for (NSUInteger i = 1; i < self.points.count; i++) {
            CGPoint p = self.points[i].CGPointValue;
            [path addLineToPoint:p];
        }

        [path stroke];

        for (NSValue *value in @[self.points.firstObject,
                                  self.points.lastObject]) {
            CGPoint p = value.CGPointValue;
            UIBezierPath *dot = [UIBezierPath bezierPathWithOvalInRect:
                CGRectMake(p.x - 5, p.y - 5, 10, 10)];
            [[UIColor whiteColor] setFill];
            [dot fill];
        }
    } else {
        NSDictionary *attributes = @{
            NSFontAttributeName: [UIFont systemFontOfSize:16],
            NSForegroundColorAttributeName:
                [UIColor colorWithWhite:0.8 alpha:1.0]
        };
        NSString *hint = @"Рисуй сверху вниз";
        CGSize size = [hint sizeWithAttributes:attributes];
        [hint drawAtPoint:CGPointMake((w - size.width) / 2.0,
                                      (h - size.height) / 2.0)
           withAttributes:attributes];
    }
}

- (void)clearPath {
    [self.points removeAllObjects];
    [self setNeedsDisplay];
}

- (void)appendTouch:(NSSet<UITouch *> *)touches {
    UITouch *touch = touches.anyObject;
    if (!touch) return;

    CGPoint p = [touch locationInView:self];
    p.x = MAX(0, MIN(CGRectGetWidth(self.bounds), p.x));
    p.y = MAX(0, MIN(CGRectGetHeight(self.bounds), p.y));

    if (self.points.count == 0) {
        [self.points addObject:[NSValue valueWithCGPoint:p]];
    } else {
        CGPoint last = self.points.lastObject.CGPointValue;
        CGFloat dx = p.x - last.x;
        CGFloat dy = p.y - last.y;

        if ((dx * dx + dy * dy) >= 9.0) {
            [self.points addObject:[NSValue valueWithCGPoint:p]];
        }
    }

    [self setNeedsDisplay];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches
           withEvent:(UIEvent *)event {
    [self clearPath];
    [self appendTouch:touches];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches
           withEvent:(UIEvent *)event {
    [self appendTouch:touches];
}

- (NSArray *)normalizedPoints {
    CGFloat w = CGRectGetWidth(self.bounds);
    CGFloat h = CGRectGetHeight(self.bounds);

    if (w <= 0 || h <= 0 || self.points.count < 2) {
        return @[];
    }

    NSMutableArray *result = [NSMutableArray array];

    for (NSValue *value in self.points) {
        CGPoint p = value.CGPointValue;
        [result addObject:@[
            @(MAX(0.0, MIN(1.0, p.x / w))),
            @(MAX(0.0, MIN(1.0, p.y / h)))
        ]];
    }

    return result;
}

@end

@interface SnowfallPathEditorController : UIViewController
@property (nonatomic, strong) SnowfallPathCanvas *canvas;
@end

@implementation SnowfallPathEditorController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"Редактор траектории";
    self.view.backgroundColor = UIColor.systemBackgroundColor;

    UILabel *description = [[UILabel alloc] init];
    description.translatesAutoresizingMaskIntoConstraints = NO;
    description.numberOfLines = 0;
    description.textAlignment = NSTextAlignmentCenter;
    description.font = [UIFont systemFontOfSize:14];
    description.text = @"Нарисуй пальцем путь снежинок сверху вниз. Чем плавнее линия, тем плавнее движение.";

    self.canvas = [[SnowfallPathCanvas alloc] initWithFrame:CGRectZero];
    self.canvas.translatesAutoresizingMaskIntoConstraints = NO;
    self.canvas.layer.cornerRadius = 12;
    self.canvas.clipsToBounds = YES;

    UIButton *clear = [UIButton buttonWithType:UIButtonTypeSystem];
    clear.translatesAutoresizingMaskIntoConstraints = NO;
    [clear setTitle:@"Очистить" forState:UIControlStateNormal];
    [clear addTarget:self action:@selector(clearPath)
    forControlEvents:UIControlEventTouchUpInside];

    UIButton *save = [UIButton buttonWithType:UIButtonTypeSystem];
    save.translatesAutoresizingMaskIntoConstraints = NO;
    [save setTitle:@"Сохранить траекторию"
          forState:UIControlStateNormal];
    save.titleLabel.font = [UIFont boldSystemFontOfSize:17];
    [save addTarget:self action:@selector(savePath)
    forControlEvents:UIControlEventTouchUpInside];

    UIStackView *buttons = [[UIStackView alloc]
        initWithArrangedSubviews:@[clear, save]];
    buttons.translatesAutoresizingMaskIntoConstraints = NO;
    buttons.axis = UILayoutConstraintAxisHorizontal;
    buttons.distribution = UIStackViewDistributionFillEqually;
    buttons.spacing = 12;

    [self.view addSubview:description];
    [self.view addSubview:self.canvas];
    [self.view addSubview:buttons];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;

    [NSLayoutConstraint activateConstraints:@[
        [description.topAnchor constraintEqualToAnchor:safe.topAnchor
                                             constant:12],
        [description.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor
                                                  constant:16],
        [description.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor
                                                   constant:-16],

        [self.canvas.topAnchor constraintEqualToAnchor:description.bottomAnchor
                                              constant:14],
        [self.canvas.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor
                                                  constant:12],
        [self.canvas.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor
                                                   constant:-12],
        [self.canvas.heightAnchor constraintEqualToAnchor:safe.heightAnchor
                                                multiplier:0.62],

        [buttons.topAnchor constraintEqualToAnchor:self.canvas.bottomAnchor
                                          constant:16],
        [buttons.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor
                                              constant:16],
        [buttons.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor
                                               constant:-16],
        [buttons.heightAnchor constraintEqualToConstant:48]
    ]];

    NSArray *saved = [[NSUserDefaults standardUserDefaults]
        persistentDomainForName:SnowfallDomain][@"PathPoints"];

    if ([saved isKindOfClass:NSArray.class] && saved.count >= 2) {
        dispatch_async(dispatch_get_main_queue(), ^{
            CGFloat w = CGRectGetWidth(self.canvas.bounds);
            CGFloat h = CGRectGetHeight(self.canvas.bounds);

            for (NSArray *pair in saved) {
                if (![pair isKindOfClass:NSArray.class] ||
                    pair.count < 2) continue;

                CGPoint p = CGPointMake(
                    [pair[0] doubleValue] * w,
                    [pair[1] doubleValue] * h
                );
                [self.canvas.points addObject:
                    [NSValue valueWithCGPoint:p]];
            }
            [self.canvas setNeedsDisplay];
        });
    }

    self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:
            UIBarButtonSystemItemCancel
            target:self action:@selector(closeEditor)];
}

- (void)clearPath {
    [self.canvas clearPath];
}

- (void)closeEditor {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)savePath {
    NSArray *points = [self.canvas normalizedPoints];

    if (points.count < 2) {
        UIAlertController *alert = [UIAlertController
            alertControllerWithTitle:@"Нарисуй траекторию"
            message:@"Проведи пальцем линию сверху вниз, затем сохрани её."
            preferredStyle:UIAlertControllerStyleAlert];

        [alert addAction:[UIAlertAction
            actionWithTitle:@"Понятно"
            style:UIAlertActionStyleDefault handler:nil]];

        [self presentViewController:alert animated:YES completion:nil];
        return;
    }

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *domain = [[defaults
        persistentDomainForName:SnowfallDomain] mutableCopy];

    if (!domain) domain = [NSMutableDictionary dictionary];

    domain[@"PathPoints"] = points;
    [defaults setPersistentDomain:domain forName:SnowfallDomain];
    [defaults synchronize];

    [self dismissViewControllerAnimated:YES completion:nil];
}

@end

@interface SnowfallRootListController : PSListController
    <PHPickerViewControllerDelegate>
@end

@implementation SnowfallRootListController

- (NSMutableArray *)specifiers {
    if (!_specifiers) {
        NSArray *loaded = [self loadSpecifiersFromPlistName:@"Root"
                                                      target:self];
        _specifiers = loaded ? [loaded mutableCopy] : [NSMutableArray array];
    }
    return _specifiers;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Snowfall";
}

- (void)openPathEditor {
    SnowfallPathEditorController *editor =
        [[SnowfallPathEditorController alloc] init];

    UINavigationController *navigation =
        [[UINavigationController alloc] initWithRootViewController:editor];

    navigation.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:navigation animated:YES completion:nil];
}

- (void)chooseImage {
    PHPickerConfiguration *config = [[PHPickerConfiguration alloc]
        init];
    config.filter = PHPickerFilter.imagesFilter;
    config.selectionLimit = 1;

    PHPickerViewController *picker =
        [[PHPickerViewController alloc] initWithConfiguration:config];
    picker.delegate = self;

    [self presentViewController:picker animated:YES completion:nil];
}

- (void)picker:(PHPickerViewController *)picker
didFinishPicking:(NSArray<PHPickerResult *> *)results {
    [picker dismissViewControllerAnimated:YES completion:nil];

    NSItemProvider *provider = results.firstObject.itemProvider;
    if (!provider) return;

    if ([provider canLoadObjectOfClass:UIImage.class]) {
        [provider loadObjectOfClass:UIImage.class
                  completionHandler:^(UIImage *image, NSError *error) {
            if (!image || error) return;

            // PNG сохраняет альфа-канал, в отличие от JPEG.
            NSData *png = UIImagePNGRepresentation(image);
            if (!png) return;

            NSString *encoded =
                [png base64EncodedStringWithOptions:0];

            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            NSMutableDictionary *domain = [[defaults
                persistentDomainForName:SnowfallDomain] mutableCopy];

            if (!domain) domain = [NSMutableDictionary dictionary];

            domain[@"CustomImagePNG"] = encoded;
            [defaults setPersistentDomain:domain forName:SnowfallDomain];
            [defaults synchronize];
        }];
    }
}

- (void)resetImage {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *domain = [[defaults
        persistentDomainForName:SnowfallDomain] mutableCopy];

    if (!domain) domain = [NSMutableDictionary dictionary];

    [domain removeObjectForKey:@"CustomImagePNG"];
    [defaults setPersistentDomain:domain forName:SnowfallDomain];
    [defaults synchronize];
}

@end

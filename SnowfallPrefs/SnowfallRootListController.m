
#import <UIKit/UIKit.h>
#import <PhotosUI/PhotosUI.h>
#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>

static NSString * const SnowfallDomain = @"com.ilya.snowfall";

@interface SnowfallPathEditorController : UIViewController
@end

@interface SnowfallRootListController : PSListController
    <PHPickerViewControllerDelegate>
@end

@implementation SnowfallRootListController

- (NSMutableArray *)specifiers {
    if (!_specifiers) {
        NSArray *loaded = [self loadSpecifiersFromPlistName:@"Root"
                                                      target:self];
        _specifiers = loaded
            ? [loaded mutableCopy]
            : [NSMutableArray array];
    }
    return _specifiers;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Snowfall";
}

- (void)openPathEditor {
    UIViewController *editor =
        [[NSClassFromString(@"SnowfallPathEditorController") alloc] init];

    if (!editor) {
        UIAlertController *alert = [UIAlertController
            alertControllerWithTitle:@"Редактор недоступен"
            message:@"Не удалось загрузить редактор траектории."
            preferredStyle:UIAlertControllerStyleAlert];

        [alert addAction:[UIAlertAction
            actionWithTitle:@"OK"
            style:UIAlertActionStyleDefault
            handler:nil]];

        [self presentViewController:alert animated:YES completion:nil];
        return;
    }

    UINavigationController *navigation =
        [[UINavigationController alloc] initWithRootViewController:editor];

    navigation.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:navigation animated:YES completion:nil];
}

- (void)chooseImage {
    PHPickerConfiguration *config =
        [[PHPickerConfiguration alloc] init];
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

    [provider loadDataRepresentationForTypeIdentifier:@"public.png"
        completionHandler:^(NSData *data, NSError *error) {
        if (!data || error) {
            [provider loadObjectOfClass:UIImage.class
                completionHandler:^(UIImage *image, NSError *imageError) {
                if (!image || imageError) return;

                NSData *png = UIImagePNGRepresentation(image);
                if (!png) return;

                [self savePNGData:png];
            }];
            return;
        }

        [self savePNGData:data];
    }];
}

- (void)savePNGData:(NSData *)data {
    // Сохраняем PNG без JPEG-перекодирования.
    NSString *encoded = [data base64EncodedStringWithOptions:0];

    dispatch_async(dispatch_get_main_queue(), ^{
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSMutableDictionary *domain = [[defaults
            persistentDomainForName:SnowfallDomain] mutableCopy];

        if (!domain) domain = [NSMutableDictionary dictionary];

        domain[@"CustomImagePNG"] = encoded;
        [defaults setPersistentDomain:domain forName:SnowfallDomain];
        [defaults synchronize];
    });
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

@interface SnowfallPathCanvas : UIView
@property (nonatomic, strong) NSMutableArray<NSValue *> *points;
@end

@implementation SnowfallPathCanvas

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor colorWithWhite:0.08 alpha:1];
        self.points = [NSMutableArray array];
        self.multipleTouchEnabled = NO;
    }
    return self;
}

- (void)drawRect:(CGRect)rect {
    if (self.points.count < 2) return;

    UIBezierPath *path = [UIBezierPath bezierPath];
    path.lineWidth = 4;
    path.lineCapStyle = kCGLineCapRound;
    path.lineJoinStyle = kCGLineJoinRound;

    [path moveToPoint:self.points.firstObject.CGPointValue];

    for (NSUInteger i = 1; i < self.points.count; i++) {
        [path addLineToPoint:self.points[i].CGPointValue];
    }

    [UIColor systemBlueColor].setStroke;
    [path stroke];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches
           withEvent:(UIEvent *)event {
    [self.points removeAllObjects];
    [self addTouch:touches];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches
           withEvent:(UIEvent *)event {
    [self addTouch:touches];
}

- (void)addTouch:(NSSet<UITouch *> *)touches {
    UITouch *touch = touches.anyObject;
    if (!touch) return;

    CGPoint p = [touch locationInView:self];
    CGFloat w = MAX(1, CGRectGetWidth(self.bounds));
    CGFloat h = MAX(1, CGRectGetHeight(self.bounds));

    p.x = MAX(0, MIN(w, p.x));
    p.y = MAX(0, MIN(h, p.y));

    if (self.points.count == 0) {
        [self.points addObject:[NSValue valueWithCGPoint:p]];
    } else {
        CGPoint last = self.points.lastObject.CGPointValue;
        if (hypot(p.x - last.x, p.y - last.y) >= 3) {
            [self.points addObject:[NSValue valueWithCGPoint:p]];
        }
    }

    [self setNeedsDisplay];
}

@end

@implementation SnowfallPathEditorController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"Редактор траектории";
    self.view.backgroundColor = UIColor.systemBackgroundColor;

    SnowfallPathCanvas *canvas =
        [[SnowfallPathCanvas alloc] initWithFrame:CGRectZero];
    canvas.translatesAutoresizingMaskIntoConstraints = NO;
    canvas.layer.cornerRadius = 12;
    canvas.clipsToBounds = YES;

    UIButton *save = [UIButton buttonWithType:UIButtonTypeSystem];
    save.translatesAutoresizingMaskIntoConstraints = NO;
    [save setTitle:@"Сохранить траекторию"
          forState:UIControlStateNormal];
    [save addTarget:self action:@selector(savePath)
   forControlEvents:UIControlEventTouchUpInside];

    UIButton *clear = [UIButton buttonWithType:UIButtonTypeSystem];
    clear.translatesAutoresizingMaskIntoConstraints = NO;
    [clear setTitle:@"Очистить" forState:UIControlStateNormal];
    [clear addTarget:self action:@selector(clearPath:)
   forControlEvents:UIControlEventTouchUpInside];

    [self.view addSubview:canvas];
    [self.view addSubview:save];
    [self.view addSubview:clear];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;

    [NSLayoutConstraint activateConstraints:@[
        [canvas.topAnchor constraintEqualToAnchor:safe.topAnchor constant:12],
        [canvas.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:12],
        [canvas.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-12],
        [canvas.heightAnchor constraintEqualToAnchor:safe.heightAnchor multiplier:0.65],

        [clear.topAnchor constraintEqualToAnchor:canvas.bottomAnchor constant:12],
        [clear.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:12],
        [clear.widthAnchor constraintEqualToAnchor:safe.widthAnchor multiplier:0.4],
        [clear.heightAnchor constraintEqualToConstant:48],

        [save.topAnchor constraintEqualToAnchor:canvas.bottomAnchor constant:12],
        [save.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-12],
        [save.widthAnchor constraintEqualToAnchor:safe.widthAnchor multiplier:0.55],
        [save.heightAnchor constraintEqualToConstant:48]
    ]];

    self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:
            UIBarButtonSystemItemCancel
            target:self action:@selector(closeEditor)];
}

- (void)clearPath:(id)sender {
    for (UIView *view in self.view.subviews) {
        if ([view isKindOfClass:SnowfallPathCanvas.class]) {
            [(SnowfallPathCanvas *)view.points removeAllObjects];
            [view setNeedsDisplay];
        }
    }
}

- (void)savePath {
    SnowfallPathCanvas *canvas = nil;

    for (UIView *view in self.view.subviews) {
        if ([view isKindOfClass:SnowfallPathCanvas.class]) {
            canvas = (SnowfallPathCanvas *)view;
            break;
        }
    }

    if (!canvas || canvas.points.count < 2) {
        UIAlertController *alert = [UIAlertController
            alertControllerWithTitle:@"Нарисуй линию"
            message:@"Проведи пальцем линию сверху вниз и нажми сохранить."
            preferredStyle:UIAlertControllerStyleAlert];

        [alert addAction:[UIAlertAction
            actionWithTitle:@"OK"
            style:UIAlertActionStyleDefault handler:nil]];

        [self presentViewController:alert animated:YES completion:nil];
        return;
    }

    CGFloat w = MAX(1, CGRectGetWidth(canvas.bounds));
    CGFloat h = MAX(1, CGRectGetHeight(canvas.bounds));
    NSMutableArray *normalized = [NSMutableArray array];

    for (NSValue *value in canvas.points) {
        CGPoint p = value.CGPointValue;
        [normalized addObject:@[
            @(p.x / w),
            @(p.y / h)
        ]];
    }

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *domain = [[defaults
        persistentDomainForName:SnowfallDomain] mutableCopy];

    if (!domain) domain = [NSMutableDictionary dictionary];

    domain[@"PathPoints"] = normalized;
    [defaults setPersistentDomain:domain forName:SnowfallDomain];
    [defaults synchronize];

    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)closeEditor {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end

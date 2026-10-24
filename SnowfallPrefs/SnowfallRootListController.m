#import <UIKit/UIKit.h>
#import <PhotosUI/PhotosUI.h>
#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>

static NSString * const SnowfallDomain = @"com.ilya.snowfall";

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

    // Удаляем старый путь, созданный редактором.
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *domain =
        [[defaults persistentDomainForName:SnowfallDomain] mutableCopy];

    if (domain && domain[@"PathPoints"]) {
        [domain removeObjectForKey:@"PathPoints"];
        [defaults setPersistentDomain:domain
                              forName:SnowfallDomain];
        [defaults synchronize];
    }
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
                                    completionHandler:
     ^(NSData *data, NSError *error) {
        if (data && !error) {
            [self savePNGData:data];
            return;
        }

        [provider loadObjectOfClass:UIImage.class
                  completionHandler:
         ^(UIImage *image, NSError *imageError) {
            if (!image || imageError) return;

            NSData *png = UIImagePNGRepresentation(image);
            if (png) {
                [self savePNGData:png];
            }
        }];
    }];
}

- (void)savePNGData:(NSData *)data {
    NSString *encoded = [data base64EncodedStringWithOptions:0];

    dispatch_async(dispatch_get_main_queue(), ^{
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSMutableDictionary *domain =
            [[defaults persistentDomainForName:SnowfallDomain] mutableCopy];

        if (!domain) {
            domain = [NSMutableDictionary dictionary];
        }

        domain[@"CustomImagePNG"] = encoded;
        [defaults setPersistentDomain:domain
                              forName:SnowfallDomain];
        [defaults synchronize];
    });
}

- (void)resetImage {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *domain =
        [[defaults persistentDomainForName:SnowfallDomain] mutableCopy];

    if (!domain) {
        domain = [NSMutableDictionary dictionary];
    }

    [domain removeObjectForKey:@"CustomImagePNG"];
    [defaults setPersistentDomain:domain
                          forName:SnowfallDomain];
    [defaults synchronize];
}

@end

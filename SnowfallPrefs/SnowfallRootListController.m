
#import <UIKit/UIKit.h>
#import <PhotosUI/PhotosUI.h>
#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>

@interface SnowfallRootListController : PSListController <PHPickerViewControllerDelegate>
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

- (void)chooseImage {
    PHPickerConfiguration *config = [[PHPickerConfiguration alloc] init];
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

            NSData *data = UIImagePNGRepresentation(image);
            if (!data) return;

            NSString *encoded = [data base64EncodedStringWithOptions:0];

            NSUserDefaults *defaults =
                [[NSUserDefaults alloc] initWithSuiteName:@"com.ilya.snowfall"];

            [defaults setObject:encoded forKey:@"CustomImagePNG"];
            [defaults synchronize];
        }];
    }
}

- (void)resetImage {
    NSUserDefaults *defaults =
        [[NSUserDefaults alloc] initWithSuiteName:@"com.ilya.snowfall"];

    [defaults removeObjectForKey:@"CustomImagePNG"];
    [defaults synchronize];
}

@end

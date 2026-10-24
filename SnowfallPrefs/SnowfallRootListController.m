
#import <UIKit/UIKit.h>
#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>

@interface SnowfallRootListController : PSListController
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
    self.view.backgroundColor = [UIColor systemBackgroundColor];
}

@end

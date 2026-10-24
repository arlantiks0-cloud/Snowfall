#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>

@interface SnowfallRootListController : PSListController
@end

@implementation SnowfallRootListController

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [[self
            loadSpecifiersFromPlistName:@"Root"
            target:self] retain];
    }
    return _specifiers;
}

@end

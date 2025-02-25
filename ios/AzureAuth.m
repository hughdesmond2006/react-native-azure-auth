
#import "AzureAuth.h"

#import <SafariServices/SafariServices.h>
#import <CommonCrypto/CommonCrypto.h>

#if __has_include("RCTUtils.h")
#import "RCTUtils.h"
#else
#import <React/RCTUtils.h>
#endif

@interface AzureAuth () <SFSafariViewControllerDelegate>
@property (weak, nonatomic) SFSafariViewController *last;
@property (copy, nonatomic) RCTResponseSenderBlock sessionCallback;
@property (assign, nonatomic) BOOL closeOnLoad;
@end

@implementation AzureAuth

- (dispatch_queue_t)methodQueue
{
    return dispatch_get_main_queue();
}

RCT_EXPORT_MODULE();

RCT_EXPORT_METHOD(hide) {
    [self terminateWithError:nil dismissing:YES animated:YES];
}

RCT_EXPORT_METHOD(showUrl:(NSString *)urlString closeOnLoad:(BOOL)closeOnLoad callback:(RCTResponseSenderBlock)callback) {
    [self presentSafariWithURL:[NSURL URLWithString:urlString]];
    self.closeOnLoad = closeOnLoad;
    self.sessionCallback = callback;
}

RCT_EXPORT_METHOD(oauthParameters:(RCTResponseSenderBlock)callback) {
    callback(@[[self generateOAuthParameters]]);
}

- (NSDictionary *)constantsToExport {
    return @{ @"bundleIdentifier": [[NSBundle mainBundle] bundleIdentifier] };
}

+ (BOOL)requiresMainQueueSetup {
    return YES;
}

#pragma mark - Internal methods

- (void)presentSafariWithURL:(NSURL *)url {
    UIWindow *window = [[UIApplication sharedApplication] keyWindow];
    SFSafariViewController *controller = [[SFSafariViewController alloc] initWithURL:url];
    controller.delegate = self;
    [self terminateWithError:RCTMakeError(@"Only one Safari can be visible", nil, nil) dismissing:YES animated:NO];
    [[self topViewControllerWithRootViewController:window.rootViewController] presentViewController:controller animated:YES completion:nil];
    self.last = controller;
}

- (void)terminateWithError:(id)error dismissing:(BOOL)dismissing animated:(BOOL)animated {
    RCTResponseSenderBlock callback = self.sessionCallback ? self.sessionCallback : ^void(NSArray *_unused) {};
    if (dismissing) {
        [self.last.presentingViewController dismissViewControllerAnimated:animated
                                                               completion:^{
                                                                   if (error) {
                                                                       callback(@[error]);
                                                                   }
                                                               }];
    } else if (error) {
        callback(@[error]);
    }
    self.sessionCallback = nil;
    self.last = nil;
    self.closeOnLoad = NO;
}

- (NSString *)randomValue {
    NSMutableData *data = [NSMutableData dataWithLength:32];
    int result __attribute__((unused)) = SecRandomCopyBytes(kSecRandomDefault, 32, data.mutableBytes);
    NSString *value = [[[[data base64EncodedStringWithOptions:0]
                         stringByReplacingOccurrencesOfString:@"+" withString:@"-"]
                        stringByReplacingOccurrencesOfString:@"/" withString:@"_"]
                       stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"="]];
    return value;
}

- (NSDictionary *)generateOAuthParameters {
    return @{
             @"nonce": [self randomValue],
             @"state": [self randomValue]
             };
}

#pragma mark - SFSafariViewControllerDelegate

- (void)safariViewControllerDidFinish:(SFSafariViewController *)controller {
    NSDictionary *error = @{
                            @"error": @"a0.session.user_cancelled",
                            @"error_description": @"User cancelled the Auth"
                            };
    [self terminateWithError:error dismissing:NO animated:NO];
}

- (void)safariViewController:(SFSafariViewController *)controller didCompleteInitialLoad:(BOOL)didLoadSuccessfully {
    if (self.closeOnLoad && didLoadSuccessfully) {
        [self terminateWithError:[NSNull null] dismissing:YES animated:YES];
    } else if (!didLoadSuccessfully) {
        NSDictionary *error = @{
                                @"error": @"a0.session.failed_load",
                                @"error_description": @"Failed to load url"
                                };
        [self terminateWithError:error dismissing:YES animated:YES];
    }
}

# pragma mark - Utility

- (UIViewController*)topViewControllerWithRootViewController:(UIViewController*)rootViewController {
    if ([rootViewController isKindOfClass:[UITabBarController class]]) {
        UITabBarController* tabBarController = (UITabBarController*)rootViewController;
        return [self topViewControllerWithRootViewController:tabBarController.selectedViewController];
    } else if ([rootViewController isKindOfClass:[UINavigationController class]]) {
        UINavigationController* navigationController = (UINavigationController*)rootViewController;
        return [self topViewControllerWithRootViewController:navigationController.visibleViewController];
    } else if (rootViewController.presentedViewController) {
        UIViewController* presentedViewController = rootViewController.presentedViewController;
        return [self topViewControllerWithRootViewController:presentedViewController];
    } else {
        return rootViewController;
    }
}

@end

/**
    This file is part of Adguard for iOS (https://github.com/AdguardTeam/AdguardForiOS).
    Copyright © 2015 Performix LLC. All rights reserved.

    Adguard for iOS is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Adguard for iOS is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Adguard for iOS.  If not, see <http://www.gnu.org/licenses/>.
*/
#import "AEUIMainController.h"
#import "ADomain/ADomain.h"
#import "ACommons/ACLang.h"
#import "ACommons/ACSystem.h"
#import "AESharedResources.h"
#import "AppDelegate.h"
#import "AEUIWelcomePagerDataSource.h"
#import "AEService.h"
#import "AESAntibanner.h"
#import "AESSupport.h"
#import "AEUIRulesController.h"
#import "AEUICommons.h"
#import "AEUICustomTextEditorController.h"
#import "ASDFilterObjects.h"
#import "AEUIFilterRuleObject.h"
#import "AEUIUtils.h"
#import "AEUIWhitelistController.h"

#ifdef PRO

#import "APVPNManager.h"
#import "APDnsServerObject.h"
#import "APUIProSectionFooter.h"
#import "APUIDnsServersController.h"

#define PRO_SECTION_INDEX               1
#define NBSP_CODE                       @"\u00A0"
#define LINK_URL_STRING                 @"https://adguard.com/adguard-dns/overview.html#overview"

#endif

/////////////////////////////////////////////////////////////////////
#pragma mark - AEUIMainController Constants
/////////////////////////////////////////////////////////////////////

#define ITUNES_PRO_APP_ID           @"1126386264"

#ifdef PRO
#define ITUNES_APP_ID               ITUNES_PRO_APP_ID
#else
#define ITUNES_APP_ID               @"1047223162"
#endif

#define ITUNES_APP_NAME             @"adguard-adblock-for-ios"
#define RATE_APP_URL_FORMAT         @"itms-apps://itunes.apple.com/WebObjects/MZStore.woa/wa/viewContentsUserReviews?id=%@&onlyLatestVersion=true&pageNumber=0&sortOrdering=1&type=Purple+Software"
#define SHARE_APP_URL_FORMAT        @"https://itunes.apple.com/app/id%@"
#define VIEW_ON_GITHUB              @"https://github.com/AdguardTeam/AdguardForiOS"

#define SHARE_APP_URL_STRING        SHARE_APP_URL_FORMAT, ITUNES_APP_ID

#define RESET_UPDATE_FILTERS_DELAY  3 //seconds

#define TO_USER_FILTER_SEGUE_ID     @"toUserFilter"
#define TO_WHITELIST_SEGUE_ID       @"toWhitelist"

#define EDITOR_TEXT_FONT            [UIFont systemFontOfSize:[UIFont systemFontSize]]

/////////////////////////////////////////////////////////////////////
#pragma mark - AEUIMainController
/////////////////////////////////////////////////////////////////////


@interface AEUIMainController (){
    
    AEUIWelcomePagerDataSource *_welcomePageSource;
    BOOL _inCheckUpdates;
    NSString *_updateButtonTextHolder;
    NSMutableArray *_observers;
    
    NSString *_ruleTextHolderForAddRuleCommand;

    UIBarButtonItem *_cancelNavigationItem;

#ifdef PRO
    APUIProSectionFooter *_proFooter;
#endif
}

@end

@implementation AEUIMainController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = LocalizationNotNeeded(AE_PRODUCT_NAME);
    
    _cancelNavigationItem = [[UIBarButtonItem alloc]
                             initWithTitle:NSLocalizedString(@"Cancel",
                                                             @"(AEUIMainController) Text on the button that cancels an operation.")
                             style:UIBarButtonItemStylePlain target:nil action:nil];
#ifdef PRO
    
    // tunning accessibility
    self.proDnsSettingsCell.accessibilityHint = [self proShortStatusDescription];
    //-----------------
    
    [self proAttachToNotifications];
#else
    self.hideSectionsWithHiddenRows = YES;
    [self cells:self.proSectionCells setHidden:YES];
    
    self.getProButton.enabled = YES;
    self.getProButton.title = @"Get PRO";
#endif
    
    [self reloadDataAnimated:NO];
    
    
    [self.enableAdguardSwitch setOn:[[AESharedResources sharedDefaults] boolForKey:AEDefaultsAdguardEnabled]];
    [[NSNotificationCenter defaultCenter]addObserver:self
                                            selector:@selector(refreshDynamicObjects:)
                                                name:UIApplicationDidBecomeActiveNotification
                                              object:nil];

    self.lastUpdated.text = @"              ";
    _updateButtonTextHolder = self.checkFiltersCell.textLabel.text;

    [self refreshDynamicObjects:nil];

    [self prepareCheckUpdatesButton];

    
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    appDelegate.navigation = self.navigationController;
    
    if ([[AEService singleton] firstRunInProgress]) {
        
        [self showWelcomeScreen];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
    
    _welcomePageSource = nil;
}

- (void)dealloc{
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    for (id observer in _observers) {
        [[NSNotificationCenter defaultCenter] removeObserver:observer];
    }
}

/////////////////////////////////////////////////////////////////////
#pragma mark  Actions
/////////////////////////////////////////////////////////////////////


- (IBAction)toggleAdguard:(id)sender {

    [[AESharedResources sharedDefaults] setBool:[sender isOn] forKey:AEDefaultsAdguardEnabled];
}

- (IBAction)clickTwitter:(id)sender {

    SLComposeViewController *compose = [SLComposeViewController composeViewControllerForServiceType:SLServiceTypeTwitter];
    if (compose) {
        
        [compose setInitialText:NSLocalizedString(@"I like Adguard for iOS - I don't see ads in Safari anymore.", @"(AEUIMainController) Share this app initial text on Twitter")];
        [compose addURL:[NSURL URLWithString:[NSString stringWithFormat:SHARE_APP_URL_STRING]]];
        [compose addImage:[UIImage imageNamed:@"share-logo"]];
        [self presentViewController:compose animated:YES completion:nil];
    }
}

- (IBAction)clickFacebook:(id)sender {
    
    SLComposeViewController *compose = [SLComposeViewController composeViewControllerForServiceType:SLServiceTypeFacebook];
    if (compose) {
        
        BOOL result = [compose setInitialText:[NSString stringWithFormat:@"%@\n", NSLocalizedString(@"I've just installed Adguard ad blocker. If you want to surf the web ad-free as I do, check it out:", @"(AEUIMainController) Share this app initial text on Facebook")]];
        
        DDLogInfo(@"(AEUIMainController) Facebook initial text installed: %@", (result ? @"YES" : @"NO"));
        
        [compose addURL:[NSURL URLWithString:[NSString stringWithFormat:SHARE_APP_URL_STRING]]];
        [compose addImage:[UIImage imageNamed:@"share-logo"]];
        [self presentViewController:compose animated:YES completion:nil];
    }
}

- (IBAction)clickMessage:(id)sender {
    
    if ([MFMessageComposeViewController canSendText]) {
        MFMessageComposeViewController *compose = [MFMessageComposeViewController new];
        NSString *body = [NSString stringWithFormat:@"%@\n%@\n",
                          NSLocalizedString(@"I've just installed Adguard AdBlocker for iOS.", @"(AEUIMainController) Share this app initial text on iMessage (text row)"),
        NSLocalizedString(@"If you want to surf the web ad-free as I do, check it out:", @"(AEUIMainController) Share this app initial text on iMessage (before link row)")];
        body = [body stringByAppendingFormat:SHARE_APP_URL_STRING];
        compose.body = body;
        compose.messageComposeDelegate = self;
        [self presentViewController:compose animated:YES completion:nil];
    }
}

- (IBAction)clickMail:(id)sender {
    if ([MFMailComposeViewController canSendMail]) {
        MFMailComposeViewController *compose = [MFMailComposeViewController new];
        NSString *body = [NSString stringWithFormat:@"%@\n%@\n",
                          NSLocalizedString(@"I've just installed Adguard AdBlocker for iOS.", @"(AEUIMainController) Share this app initial text on Mail Body (text row)"),
                          NSLocalizedString(@"If you want to surf the web ad-free as I do, check it out:", @"(AEUIMainController) Share this app initial text on Mail Body (before link row)")];
        body = [body stringByAppendingFormat:SHARE_APP_URL_STRING];
        [compose setMessageBody:body isHTML:NO];
        [compose setSubject:NSLocalizedString(@"Check this out!", @"(AEUIMainController) Share this app initial text on Mail Subject")];
        compose.mailComposeDelegate = self;
        
        [self presentViewController:compose animated:YES completion:nil];
    }
}

- (IBAction)clickViewOnGitHub:(id)sender {

    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:VIEW_ON_GITHUB]];
}

- (IBAction)clickCheckForUpdates:(id)sender {
    if (!_inCheckUpdates) {
        [(AppDelegate *)[[UIApplication sharedApplication] delegate] invalidateAntibanner:YES interactive:YES];
    }
}

- (IBAction)clickRateThisApp:(id)sender {
    NSURL *theURL =
    [NSURL URLWithString:[NSString stringWithFormat:RATE_APP_URL_FORMAT,
                          ITUNES_APP_ID]];
    [[UIApplication sharedApplication] openURL:theURL];
}

- (IBAction)clickSendBugReport:(id)sender {
    [[AESSupport singleton] sendMailBugReportWithParentController:self];
}

- (IBAction)clickGetPro:(id)sender {
    NSURL *theURL =
    [NSURL URLWithString:[NSString stringWithFormat:SHARE_APP_URL_FORMAT,
                          ITUNES_PRO_APP_ID]];
    [[UIApplication sharedApplication] openURL:theURL];
}

- (void)addRuleToUserFilter:(NSString *)ruleText{

    if ([NSString isNullOrEmpty:ruleText]) {
        return;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
       
        _ruleTextHolderForAddRuleCommand = ruleText;
        [self.navigationController popToRootViewControllerAnimated:YES];
        [self performSegueWithIdentifier:TO_USER_FILTER_SEGUE_ID sender:self];
        _ruleTextHolderForAddRuleCommand = nil;
    });
}

#pragma mark Navigation

- (void)viewWillAppear:(BOOL)animated{
    
    [super viewWillAppear:animated];
    
    [self setToolbar];
#ifdef PRO
    [self proUpdateStatuses];
#endif

}

- (void)viewWillDisappear:(BOOL)animated{
    
    [super viewWillDisappear:animated];
    
    self.navigationController.toolbarHidden = YES;
}


- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender{
    
    return YES;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    
    if ([segue.identifier isEqualToString:@"tutorialRunSegue"]) {
        
        UIPageViewController *destination = [segue destinationViewController];
        [self prepareWelcomeScreenForController:destination];
    }
    else if ([segue.identifier isEqualToString:TO_USER_FILTER_SEGUE_ID]){

        [AEUIRulesController createUserFilterControllerWithSegue:segue ruleTextHolderForAddRuleCommand:_ruleTextHolderForAddRuleCommand];
    }
    else if ([segue.identifier isEqualToString:TO_WHITELIST_SEGUE_ID]){
        
        [AEUIWhitelistController createWhitelistControllerWithSegue:segue];
    }
    
#ifdef PRO
    if([segue.identifier isEqualToString:OpenDnsSettingsSegue]) {
        
        [APUIDnsServersController createDnsSercersControllerWithSegue:segue status:self.startStatus];
        
        self.startStatus = nil;
    }
#endif
}

/////////////////////////////////////////////////////////////////////
#pragma mark Message and Mail Compose Delegate Methods
/////////////////////////////////////////////////////////////////////

- (void)messageComposeViewController:(MFMessageComposeViewController *)controller didFinishWithResult:(MessageComposeResult)result{
    
    [controller dismissViewControllerAnimated:YES completion:nil];
}

- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error{
    
    [controller dismissViewControllerAnimated:YES completion:nil];
}

/////////////////////////////////////////////////////////////////////
#pragma mark Notification
/////////////////////////////////////////////////////////////////////

- (void)refreshDynamicObjects:(NSNotification *)notification {

    NSDate *checkDate = [[AESharedResources sharedDefaults] objectForKey:AEDefaultsCheckFiltersLastDate];
    if (checkDate) {
        self.lastUpdated.text = [NSDateFormatter localizedStringFromDate:checkDate dateStyle:NSDateFormatterShortStyle timeStyle:NSDateFormatterShortStyle];
        // tunning accessibility
        self.lastUpdated.accessibilityLabel = [NSDateFormatter localizedStringFromDate:checkDate dateStyle:NSDateFormatterLongStyle timeStyle:NSDateFormatterShortStyle];
        //------------
    }

    BOOL enabled = NO;
    
    BOOL result = [SLComposeViewController
        isAvailableForServiceType:SLServiceTypeFacebook];
    enabled |= result;
    self.facebookButton.hidden = !result;
    
    enabled |= result = [SLComposeViewController
        isAvailableForServiceType:SLServiceTypeTwitter];
    self.twitterButton.hidden = !result;
    
    enabled |= result = [MFMessageComposeViewController canSendText];
    self.messageButton.hidden = !result;
    [self.messageButton invalidateIntrinsicContentSize];

    enabled |= result = [MFMailComposeViewController canSendMail];
    self.mailButton.hidden = !result;

    [self cell:self.shareCell setHidden:!enabled];
    [self reloadDataAnimated:YES];
}

/////////////////////////////////////////////////////////////////////
#pragma mark Private Methods
/////////////////////////////////////////////////////////////////////

- (void)showWelcomeScreen{

    UIPageViewController *pager = (UIPageViewController *)[self.storyboard instantiateViewControllerWithIdentifier:@"welcomePager"];
    if (pager) {
        
        [self prepareWelcomeScreenForController:pager];
        [self.navigationController pushViewController:pager animated:YES];
    }
}

- (void)prepareWelcomeScreenForController:(UIPageViewController *)pager{
    
    if (pager) {
        
        if (!_welcomePageSource) {
            _welcomePageSource = [[AEUIWelcomePagerDataSource alloc] initWithStoryboard:pager.storyboard];
        }
        if (_welcomePageSource) {
            
            pager.dataSource = _welcomePageSource;
            _welcomePageSource.currentIndex = 0;
            [pager setViewControllers:@[[_welcomePageSource currentControllerForIndex:0 ]] direction:UIPageViewControllerNavigationDirectionForward animated:NO completion:nil];
            
        }
    }
}

- (void)prepareCheckUpdatesButton {

    UIActivityIndicatorView *activity = [[UIActivityIndicatorView alloc]
        initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    activity.hidesWhenStopped = YES;
    activity.hidden = YES;
    //    activity.color = self.view.tintColor;

    self.checkFiltersCell.accessoryView = activity;
    self.checkFiltersCell.textLabel.textColor =
        self.checkFiltersCell.textLabel.tintColor;
    
    // tunning accessibility
    UIAccessibilityTraits checkFiltersCellTraits = self.checkFiltersCell.accessibilityTraits;
    self.checkFiltersCell.accessibilityTraits = checkFiltersCellTraits | UIAccessibilityTraitButton;
    //-----------------
    
    _inCheckUpdates = NO;

    _observers = [NSMutableArray arrayWithCapacity:3];
    
    // When update started
    id observer = [[NSNotificationCenter defaultCenter]
        addObserverForName:AppDelegateStartedUpdateNotification
                    object:nil
                     queue:nil
                usingBlock:^(NSNotification *_Nonnull note) {

                  self.checkFiltersCell.textLabel.enabled = NO;
                    // tunning accessibility
                  self.checkFiltersCell.accessibilityTraits = checkFiltersCellTraits;
                    //------------
                  UIActivityIndicatorView *activity =
                      (UIActivityIndicatorView *)
                          self.checkFiltersCell.accessoryView;
                  activity.hidden = NO;
                  [activity startAnimating];
                  _inCheckUpdates = YES;
                }];

    [_observers addObject:observer];
    
    // When update finished
    observer = [[NSNotificationCenter defaultCenter]
        addObserverForName:AppDelegateFinishedUpdateNotification
                    object:nil
                     queue:nil
                usingBlock:^(NSNotification *_Nonnull note) {

                    // run this only reload json process is finished
                  [[AEService singleton] onReloadContentBlockingJsonComplete:^{

                    dispatch_sync(dispatch_get_main_queue(), ^{

                        UIActivityIndicatorView *activity =
                        (UIActivityIndicatorView *)
                        self.checkFiltersCell.accessoryView;
                        [activity stopAnimating];
                        
                      // setting text of result on "Check Filter Updates"
                      NSArray *updatedMetas =
                          [note userInfo][AppDelegateUpdatedFiltersKey];
                      if (updatedMetas.count) {

                          NSString *format =
                              NSLocalizedString(@"Filters updated: %lu",
                                                @"(AEUIMainController) Button "
                                                @"- Check Filter Updates");
                          self.checkFiltersCell.textLabel.text = [NSString
                              stringWithFormat:format, updatedMetas.count];
                      } else {

                          self.checkFiltersCell.textLabel.text =
                              NSLocalizedString(@"No updates found",
                                                @"(AEUIMainController) Button "
                                                @"- Check Filter Updates");
                      }

                      NSDate *checkDate = [[AESharedResources sharedDefaults]
                          objectForKey:AEDefaultsCheckFiltersLastDate];
                      if (checkDate) {
                          self.lastUpdated.text = [NSDateFormatter
                              localizedStringFromDate:checkDate
                                            dateStyle:NSDateFormatterShortStyle
                                            timeStyle:
                                                NSDateFormatterShortStyle];
                          // tunning accessibility
                          self.lastUpdated.accessibilityLabel = [NSDateFormatter localizedStringFromDate:checkDate dateStyle:NSDateFormatterLongStyle timeStyle:NSDateFormatterShortStyle];
                          //-------
                      }
                    });

                    dispatch_after(
                        dispatch_time(DISPATCH_TIME_NOW,
                                      (int64_t)(RESET_UPDATE_FILTERS_DELAY *
                                                NSEC_PER_SEC)),
                        dispatch_get_main_queue(), ^{
                          [self resetCheckFilterUpdatesButton];
                        });
                  }];
                    
                }];

    [_observers addObject:observer];
    
    // When update failured
    observer = [[NSNotificationCenter defaultCenter]
        addObserverForName:AppDelegateFailuredUpdateNotification
                    object:nil
                     queue:nil
                usingBlock:^(NSNotification *_Nonnull note) {

                  UIActivityIndicatorView *activity =
                      (UIActivityIndicatorView *)
                          self.checkFiltersCell.accessoryView;
                  [activity stopAnimating];

                  dispatch_async(dispatch_get_main_queue(), ^{

                    // setting text of result on "Check Filter Updates"
                    self.checkFiltersCell.textLabel.text = NSLocalizedString(
                        @"Filters update error",
                        @"(AEUIMainController) Button - Check Filter Updates");
                  });

                  dispatch_after(
                      dispatch_time(
                          DISPATCH_TIME_NOW,
                          (int64_t)(RESET_UPDATE_FILTERS_DELAY * NSEC_PER_SEC)),
                      dispatch_get_main_queue(), ^{
                        [self resetCheckFilterUpdatesButton];
                      });

                }];
    [_observers addObject:observer];
}

- (void)resetCheckFilterUpdatesButton{

    self.checkFiltersCell.textLabel.enabled = YES;
    self.checkFiltersCell.textLabel.text = _updateButtonTextHolder;
    // tunning accessibility
    self.checkFiltersCell.accessibilityTraits = self.checkFiltersCell.accessibilityTraits | UIAccessibilityTraitButton;
    //--------
    _inCheckUpdates = NO;
}

/////////////////////////////////////////////////////////////////////
#pragma mark  Table Delegate Methods

#ifdef PRO

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section{
    
    if (section == PRO_SECTION_INDEX) {
        
        return [self proSectionFooter];
    }
    
    return [super tableView:tableView viewForFooterInSection:section];
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section{
    
    if (section == PRO_SECTION_INDEX) {
        
        APUIProSectionFooter *footer = [self proSectionFooter];
        return footer.height;
    }
    
    return [super tableView:tableView heightForFooterInSection:section];
}

/////////////////////////////////////////////////////////////////////
#pragma mark  PRO Helper Methods (Private)

- (APUIProSectionFooter *)proSectionFooter{
    
    if (_proFooter) {
        return _proFooter;
    }
    
    _proFooter = [[APUIProSectionFooter alloc] initWithFrame:self.view.bounds];
    _proFooter.text = [self proTextForProSectionFooter];
    
    return _proFooter;
}

- (NSString *)proShortStatusDescription {
    
    return NSLocalizedString(@"Adguard Pro provides you with advanced capabilities via using custom DNS servers. Parental control, protection from phishing and malware & keeping your DNS traffic safe from intercepting and snooping.", @"(APUIAdguardDNSController) PRO version. On the main screen. It is the description under PRO Status switch.");
}

- (NSAttributedString *)proTextForProSectionFooter{
    
    NSString *message = [self proShortStatusDescription];
    
    NSMutableAttributedString *textString = [[NSMutableAttributedString alloc] initWithString:message];
    
    return textString;
}

- (void)proUpdateStatuses{
    
    APVPNManager *manager = [APVPNManager singleton];
    
    if(manager.enabled)
        self.proDnsSettingsCell.detailTextLabel.text = manager.activeRemoteDnsServer.serverName;
    else
        self.proDnsSettingsCell.detailTextLabel.text = NSLocalizedString(@"Off", @"AEUIMainController on main screen. DNS Settings detail text, when pro mode is off");
    
    if (manager.lastError) {
        [ACSSystemUtils
         showSimpleAlertForController:self
         withTitle:NSLocalizedString(@"Error",
                                     @"(APUIAdguardDNSCon"
                                     @"troller) PRO "
                                     @"version. Alert "
                                     @"title. On error.")
         message:manager.lastError.localizedDescription];
    }
    
    [self reloadDataAnimated:YES];
}

- (void)proAttachToNotifications{
    
    id observer = [[NSNotificationCenter defaultCenter]
                 addObserverForName:APVpnChangedNotification
                 object: nil
                 queue:nil
                 usingBlock:^(NSNotification *_Nonnull note) {
                     
                     // When configuration is changed
                     
                     [self proUpdateStatuses];
                 }];
    
    if (observer) {
        [_observers addObject:observer];
    }
}

#endif

- (void)setToolbar{
    
    static UILabel *warning;
    
    self.navigationController.toolbarHidden = YES;
    
    NSString *warningText;
    
    //Show warning if overlimit of rules was reached.
    if ([[AESharedResources sharedDefaults] boolForKey:AEDefaultsJSONRulesOverlimitReached]) {
        
        NSUInteger limit = [[[AESharedResources sharedDefaults] objectForKey:AEDefaultsJSONMaximumConvertedRules] unsignedIntegerValue];
        NSUInteger totalRulesCount = [[[AESharedResources sharedDefaults] objectForKey:AEDefaultsJSONRulesForConvertion] unsignedIntegerValue];

        warningText = [NSString stringWithFormat:NSLocalizedString(@"Too many filters enabled. Safari cannot use more than %1$lu rules. Enabled rules: %2$lu.", @"(AEUIMainController) Warning text on main screen"), limit, totalRulesCount];
    }
    
    if (warningText) {
        
        UIView *toolbar = self.navigationController.toolbar;
        if (toolbar) {
            
            UIEdgeInsets insets = toolbar.layoutMargins;
            //        UIEdgeInsets rootInsets = self.navigationController.view.layoutMargins;
            CGRect frame = toolbar.bounds;
            frame.origin = CGPointMake(0, 0);
            //            frame.size.height -= insets.top + insets.bottom;
            frame.size.width -= insets.left + insets.right;
            if (!(frame.size.height <= 0 || frame.size.width <= 0)) {

                static dispatch_once_t onceToken;
                dispatch_once(&onceToken, ^{
                    warning = [[UILabel alloc] initWithFrame:frame];
                    warning.textColor = AEUIC_WARNING_COLOR;
                    warning.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
                    warning.textAlignment = NSTextAlignmentCenter;
                    warning.numberOfLines = 2;
                    UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithCustomView:warning];
                    
                    UIBarButtonItem *spacer = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
                    if (item) {
                        self.toolbarItems = @[spacer, item, spacer];
                    }
                });

                //                warning.lineBreakMode = NSLineBreakByWordWrapping;
                warning.text = warningText;
            }
        }
        
        [self.navigationController setToolbarHidden:NO animated:YES];
    }
}

@end

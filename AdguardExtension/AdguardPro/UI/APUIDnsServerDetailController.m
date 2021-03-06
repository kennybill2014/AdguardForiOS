/**
    This file is part of Adguard for iOS (https://github.com/AdguardTeam/AdguardForiOS).
    Copyright © 2015-2017 Performix LLC. All rights reserved.
 
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

#import "APUIDnsServerDetailController.h"
#import "APDnsServerObject.h"
#import "APUIDnsServersController.h"

#define IP_ADDRESSES_SECTION_INDEX          1

/////////////////////////////////////////////////////////////////////
#pragma mark - APUIDnsServerDetailController

@implementation APUIDnsServerDetailController {
    BOOL _editMode;
    
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
    
    APDnsServerObject *obj = self.serverObject;
    if (obj) {
        self.nameTextField.text = obj.serverName;
        self.descriptionTextField.text = obj.serverDescription;
        self.ipAddressesTextView.text = obj.ipAddressesAsString;
        self.removeCell.hidden = NO;
        // tunning accessibility
        self.removeCell.accessibilityTraits |= UIAccessibilityTraitButton;
        //---------
        _editMode = YES;
    }
    else {
        
        self.serverObject = [APDnsServerObject new];
        self.removeCell.hidden = YES;
        _editMode = NO;
        
        [self.nameTextField becomeFirstResponder];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


/////////////////////////////////////////////////////////////////////
#pragma mark Actions


- (IBAction)clickOnTableView:(id)sender {
    
    [self.view endEditing:YES];
}

- (IBAction)clickCancel:(id)sender {
    UIViewController *presenting = self.navigationController.presentingViewController;
    [presenting dismissViewControllerAnimated:YES completion:^{
        
    }];
}

- (IBAction)clickDone:(id)sender {
    
    APDnsServerObject *obj = self.serverObject;
    obj.serverDescription = self.descriptionTextField.text;
    
    UIViewController *presenting = self.navigationController.presentingViewController;

    APUIDnsServersController *delegate = self.delegate;
    
    if (_editMode) {
        [presenting dismissViewControllerAnimated:YES completion:^{
            [delegate modifyDnsServer:obj];
        }];
    }
    else {
        [presenting dismissViewControllerAnimated:YES completion:^{
            [delegate addDnsServer:obj];
        }];
    }
    
}

- (IBAction)clickRemove:(id)sender {
    
    APDnsServerObject *obj = self.serverObject;
    
    UIViewController *presenting = self.navigationController.presentingViewController;
    
    APUIDnsServersController *delegate = self.delegate;
    
    UIAlertController* sheet = [UIAlertController alertControllerWithTitle:nil
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    
    UIAlertAction * action = [UIAlertAction actionWithTitle:NSLocalizedString(@"Remove Server", @"(APUIAdguardDNSController) PRO version. Button text for deleting a custom DNS server.")
                                                          style:UIAlertActionStyleDestructive
                                                          handler:^(UIAlertAction * action) {
                                                              
                                                              [presenting dismissViewControllerAnimated:YES completion:^{
                                                                  [delegate removeDnsServer:obj];
                                                              }];
                                                          }];
    
    [sheet addAction:action];

    action = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"(APUIAdguardDNSController) PRO version. Text on the button that cancels the deleting of a custom DNS server.")
                                                      style:UIAlertActionStyleCancel
                                                    handler:nil];
    
    [sheet addAction:action];

    [self presentViewController:sheet animated:YES completion:nil];
}

- (IBAction)nameChanged:(id)sender {
    
    self.serverObject.serverName = self.nameTextField.text;
    
    [self resetStatusDoneButton];
}

- (IBAction)descriptionChanged:(id)sender {
    
    [self resetStatusDoneButton];
}

/////////////////////////////////////////////////////////////////////
#pragma mark Text View Delegate
- (void)textViewDidChange:(UITextView *)textView {
    
    [self.serverObject setIpAddressesFromString:textView.text];

    [self resetStatusDoneButton];
}

/////////////////////////////////////////////////////////////////////
#pragma mark Table Delegate

- (void)tableView:(UITableView *)tableView willDisplayFooterView:(nonnull UIView *)view forSection:(NSInteger)section {
    
    // tunning accessibility
    UITableViewHeaderFooterView *footer = (UITableViewHeaderFooterView *)view;
    
    footer.isAccessibilityElement = NO;
    footer.textLabel.isAccessibilityElement = NO;
    footer.detailTextLabel.isAccessibilityElement = NO;
    
    if (section == IP_ADDRESSES_SECTION_INDEX) {
        self.ipAddressesTextView.accessibilityHint = footer.textLabel.text;
    }
}

/////////////////////////////////////////////////////////////////////
#pragma mark Private Methods

- (void)resetStatusDoneButton {

    APDnsServerObject *obj = self.serverObject;
    self.doneButton.enabled = (obj.serverName.length && obj.ipAddressesAsString.length);
}

@end

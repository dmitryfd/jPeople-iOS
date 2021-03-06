//
//  DKFavoritesViewController.m
//  jPeople
//
//  Created by Dmitry on 5/6/13.
//  Copyright (c) 2013 Dmitrii Cucleschin. All rights reserved.
//

#import "DKFavoritesViewController.h"


@implementation DKFavoritesViewController

-(void) viewWillAppear:(BOOL)animated {
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    favorites = [prefs mutableArrayValueForKey:@"favorites"];
    
    [favoritesTable reloadData];
}

-(void) viewWillDisappear:(BOOL)animated {
    [ALAlertBanner forceHideAll];
    [super viewWillDisappear:animated];
}

- (void)viewDidLoad
{
    self.title = @"Favorites";
    [super viewDidLoad];
    
    background.image = [UIImage imageNamed:@"empty_favorites"];
    
    //Hack to remove header on iOS7
    CGRect frame = favoritesTable.tableHeaderView.frame;
    frame.size.height = 1;
    UIView *headerView = [[UIView alloc] initWithFrame:frame];
    [favoritesTable setTableHeaderView:headerView];
    
    /*//Swipe between tabs
    UISwipeGestureRecognizer *swipeLeft = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(tappedRightButton:)];
    [swipeLeft setDirection:UISwipeGestureRecognizerDirectionLeft];
    [self.view addGestureRecognizer:swipeLeft];
    
    UISwipeGestureRecognizer *swipeRight = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(tappedLeftButton:)];
    [swipeRight setDirection:UISwipeGestureRecognizerDirectionRight];
    [self.view addGestureRecognizer:swipeRight];*/
    
    // Left
    UIButton *a1 = [UIButton buttonWithType:UIButtonTypeCustom];
    [a1 setFrame:CGRectMake(0.0f, 0.0f, 32.0f, 32.0f)];
    [a1 addTarget:self action:@selector(openMenu) forControlEvents:UIControlEventTouchUpInside];
    [a1 setImage:[UIImage imageNamed:@"menu"] forState:UIControlStateNormal];
    
    UIBarButtonItem * barButton = [[UIBarButtonItem alloc] initWithCustomView:a1];
    self.navigationItem.leftBarButtonItem = barButton;
    
    self.navigationItem.hidesBackButton = YES;
    
    // Center    
    self.navigationItem.titleView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"favorites"]];
    
    // Right
    self.navigationItem.rightBarButtonItem = [self rightBarButton];
    
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    favorites = [prefs mutableArrayValueForKey:@"favorites"];
}

-(UIBarButtonItem*) rightBarButton {
    
    UIBarButtonItem * barButton;
    
    if (favoritesTable.isEditing) {
        UIButton *a1 = [UIButton buttonWithType:UIButtonTypeCustom];
        [a1 setFrame:CGRectMake(0.0f, 0.0f, 32.0f, 32.0f)];
        [a1 addTarget:self action:@selector(toggleEditing) forControlEvents:UIControlEventTouchUpInside];
        [a1 setImage:[UIImage imageNamed:@"done"] forState:UIControlStateNormal];
        
        barButton = [[UIBarButtonItem alloc] initWithCustomView:a1];
    }
    else {
        UIButton *a1 = [UIButton buttonWithType:UIButtonTypeCustom];
        [a1 setFrame:CGRectMake(0.0f, 0.0f, 32.0f, 32.0f)];
        [a1 addTarget:self action:@selector(toggleEditing) forControlEvents:UIControlEventTouchUpInside];
        [a1 setImage:[UIImage imageNamed:@"edit"] forState:UIControlStateNormal];
        
        barButton = [[UIBarButtonItem alloc] initWithCustomView:a1];
    }
    
    return barButton;
}

-(void) toggleEditing {
    [favoritesTable setEditing:!favoritesTable.editing];
    self.navigationItem.rightBarButtonItem = [self rightBarButton];
}

-(void) renewData {
    
    if (favorites.count == 0) return;
    
    NSUserDefaults* prefs = [NSUserDefaults standardUserDefaults];
    NSMutableArray *fUpdated = [NSMutableArray array];
    
    favoritesTable.allowsSelection = NO;
    favoritesTable.scrollEnabled = NO;

    NSString *query = @"http://jpeople.user.jacobs-university.de/ajax.php?action=fullAutoComplete&str=account:";
    
    for (int k = 0; k < [favorites count]; k++)
    {
        query = [query stringByAppendingString:[NSString stringWithFormat:@"%@,",[[favorites objectAtIndex:k]objectForKey:@"account"]]];
    }
    
    query = [query substringToIndex:[query length]-1]; // remove the last comma
    //NSLog(@"%@",query);
    
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:query]];
    
    [self.view makeToastActivity];
    [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *response, NSData* data, NSError* error) {
        
        if (error != nil)
        {
            ALAlertBanner *banner = [ALAlertBanner alertBannerForView:self.view style:ALAlertBannerStyleFailure position:ALAlertBannerPositionTop title:@"Ouch!" subtitle:@"Looks like you have a problem with Internet connection... Check it and try again later? :)"];
            [banner show];
            return;
        }

        NSDictionary *jsonRoot = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        
        for (NSDictionary *person in [jsonRoot objectForKey:@"records"])
        {
            [fUpdated addObject:person];
        }
        
        [prefs setObject:fUpdated forKey:@"favorites"];
        [prefs synchronize];
        
        [favorites removeAllObjects];
        [favorites addObjectsFromArray:fUpdated];
        
        favoritesTable.allowsSelection = YES;
        favoritesTable.scrollEnabled = YES;
        
        [self.view hideToastActivity];
        
        ALAlertBanner *banner = [ALAlertBanner alertBannerForView:self.view style:ALAlertBannerStyleSuccess position:ALAlertBannerPositionTop title:@"Success!" subtitle:nil];
        [banner show];
        
        [favoritesTable reloadData];

    }];
    
    
}

-(IBAction) openMenu {
    UIActionSheet *menu = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:@"Clear all" otherButtonTitles:@"E-mail all", @"Export to Contacts", @"Update data", nil];
    [menu showFromTabBar:self.tabBarController.tabBar];
}

-(void) checkContactsPermission {
    ABAddressBookRef addressBookRef = ABAddressBookCreateWithOptions(NULL, NULL);
    
    if (ABAddressBookGetAuthorizationStatus() == kABAuthorizationStatusNotDetermined) {
        ABAddressBookRequestAccessWithCompletion(addressBookRef, ^(bool granted, CFErrorRef error) {
            if (granted) {
                [self allToContacts:addressBookRef];
            }
            else {
                [self.view hideToastActivity];
                ALAlertBanner *banner = [ALAlertBanner alertBannerForView:self.view style:ALAlertBannerStyleFailure position:ALAlertBannerPositionTop title:@"Ouch!" subtitle:@"jPeople doesn't have permissions to modify the contacts :("];
                [banner show];
            }
        });
    }
    else if (ABAddressBookGetAuthorizationStatus() == kABAuthorizationStatusAuthorized) {
        [self allToContacts:addressBookRef];
    }
    else {
        ALAlertBanner *banner = [ALAlertBanner alertBannerForView:self.view style:ALAlertBannerStyleFailure position:ALAlertBannerPositionTop title:@"Ouch!" subtitle:@"jPeople doesn't have permissions to modify the contacts :("];
         [banner show];
        [self.view hideToastActivity];
    }
}

-(void) allToContacts:(ABAddressBookRef) addressBook {
    
    NSLog(@"Adding to contacts...");
    BOOL exists = FALSE;
    
    for (NSDictionary *dude in favorites) {
        [self.view makeToastActivity];
        
        if (![self contactExistsWithFirstname:[dude objectForKey:@"fname"] lastname:[dude objectForKey:@"lname"]]) {
            ABRecordRef person = ABPersonCreate(); // create a person
            
            if ([dude objectForKey:@"phone"] != nil && ![[dude objectForKey:@"phone"] isEqual:[NSNull null]]) {
                NSString *phone = [NSString stringWithFormat:@"+49421200%@",[dude objectForKey:@"phone"]];
                ABMutableMultiValueRef phoneNumberMultiValue =
                ABMultiValueCreateMutable(kABMultiStringPropertyType);
                ABMultiValueAddValueAndLabel(phoneNumberMultiValue ,(__bridge CFTypeRef)(phone),kABPersonPhoneMobileLabel, NULL);
                ABRecordSetValue(person, kABPersonPhoneProperty, phoneNumberMultiValue, nil); // set the phone number property
            }
            
            if ([dude objectForKey:@"room"] != nil && ![[dude objectForKey:@"room"] isEqual:[NSNull null]]) {
                ABMutableMultiValueRef address = ABMultiValueCreateMutable(kABMultiDictionaryPropertyType);
                NSMutableDictionary *addressDictionary = [[NSMutableDictionary alloc] init];
                [addressDictionary setObject:[NSString stringWithFormat:@"Room %@",[dude objectForKey:@"room"]] forKey:(NSString*)kABPersonAddressStreetKey];
                
                ABMultiValueAddValueAndLabel(address, (__bridge CFDictionaryRef)addressDictionary, kABHomeLabel, NULL);
                ABRecordSetValue(person, kABPersonAddressProperty, address, NULL);
            }
            
            ABRecordSetValue(person, kABPersonFirstNameProperty, (__bridge CFTypeRef)([dude objectForKey:@"fname"]) , nil);
            ABRecordSetValue(person, kABPersonLastNameProperty, (__bridge CFTypeRef)([dude objectForKey:@"lname"]), nil);
            
            ABMutableMultiValueRef multiEmail = ABMultiValueCreateMutable(kABMultiStringPropertyType);
            ABMultiValueAddValueAndLabel(multiEmail, (__bridge CFTypeRef)([dude objectForKey:@"email"]), kABHomeLabel, NULL);
            ABRecordSetValue(person, kABPersonEmailProperty, multiEmail, nil);
            
            ABAddressBookAddRecord(addressBook, person, nil); //add the new person to the record
        }
        else {
            exists = TRUE;
        }
    }
    
    ABAddressBookSave(addressBook, nil); //save the records
    
    
    [self.view hideToastActivity];
    if (!exists) {
        ALAlertBanner *banner = [ALAlertBanner alertBannerForView:self.view style:ALAlertBannerStyleSuccess position:ALAlertBannerPositionTop title:@"Success!" subtitle:nil];
        [banner show];
    }
    else {
        ALAlertBanner *banner = [ALAlertBanner alertBannerForView:self.view style:ALAlertBannerStyleSuccess position:ALAlertBannerPositionTop title:@"Success!" subtitle:@"Some people were already in the contact list and were not added."];
        [banner show];
    }
}

-(BOOL) contactExistsWithFirstname:(NSString *)first lastname:(NSString *)last {
    ABAddressBookRef addressbook = ABAddressBookCreate();
    NSArray *allPeople = (__bridge NSArray*)ABAddressBookCopyArrayOfAllPeople(addressbook);
    
    for (int i=0; i<[allPeople count]; i++)
    {
        ABRecordRef contact = (__bridge ABRecordRef)([allPeople objectAtIndex:i]);
        NSString *fContact = (__bridge NSString *)(ABRecordCopyValue(contact, kABPersonFirstNameProperty));
        NSString *lContact = (__bridge NSString *)(ABRecordCopyValue(contact, kABPersonLastNameProperty));
        
        if ([fContact isEqualToString:first] && [lContact isEqualToString:last])
            return TRUE;
    }
    
    return FALSE;
}


#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (favorites.count > 0)
        background.hidden = YES;
    else
        background.hidden = NO;
    
    return [favorites count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    
    NSDictionary *person = [favorites objectAtIndex:indexPath.row];
    
    UIView *college = [cell viewWithTag:11];
    
    if ([[person objectForKey:@"college"] isEqual:@"Krupp"]) {
        college.backgroundColor = RGB(217,41,41);
    }
    else if ([[person objectForKey:@"college"] isEqual:@"Nordmetall"]) {
        college.backgroundColor = RGB(227,211,34);
    }
    else if ([[person objectForKey:@"college"] isEqual:@"Mercator"]) {
        college.backgroundColor = RGB(34,137,227);
    }
    else if ([[person objectForKey:@"college"] isEqual:@"College-III"]) {
        college.backgroundColor = RGB(56,181,25);
    }
    
    UIImageView* country = (UIImageView*)[cell viewWithTag:12];
    country.image = [DKCountry iconForCountry:[person objectForKey:@"country"]];
    
    UILabel *name = (UILabel*)[cell viewWithTag:13];
    name.text = [NSString stringWithFormat:@"%@ %@",[person objectForKey:@"fname"],[person objectForKey:@"lname"]];
    
    return cell;
}


#pragma mark - Table view editing

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath
      toIndexPath:(NSIndexPath *)toIndexPath {
    
    
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    NSMutableArray *favs = favorites;
    
    NSDictionary *tempPerson = [NSDictionary dictionaryWithDictionary:[favs objectAtIndex:fromIndexPath.row]];
    
    [favs removeObject:[favs objectAtIndex:fromIndexPath.row]];
    [favs insertObject:tempPerson atIndex:toIndexPath.row];
    
    [prefs setObject:favs forKey:@"favorites"];
    [prefs synchronize];
    
}

- (void)tableView:(UITableView *)aTableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
forRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        
        NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
        NSMutableArray *favs = favorites;
        
        [favs removeObject:[favs objectAtIndex:indexPath.row]];
        
        [prefs setObject:favs forKey:@"favorites"];
        [prefs synchronize];
        
        [favoritesTable reloadData];
    }
}


#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    DKDetailViewController *detail = (DKDetailViewController*) [[UIStoryboard storyboardWithName:@"MainStoryboard" bundle:nil] instantiateViewControllerWithIdentifier:@"detailView"];
    detail.person = [[favorites objectAtIndex:indexPath.row] mutableCopy];
    
    [self.navigationController pushViewController:detail animated:YES];
}

#pragma mark UIActionSheet delegate

-(void) actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    
    if (buttonIndex == 4)
        return;
    
    if (buttonIndex == 0) //clear
    {
        NSMutableArray *empty = [NSMutableArray array];
        [prefs setObject:empty forKey:@"favorites"];
        [prefs synchronize];
        [favoritesTable reloadData];
        
        ALAlertBanner* banner = [ALAlertBanner alertBannerForView:self.view style:ALAlertBannerStyleSuccess position:ALAlertBannerPositionTop title:@"Success!" subtitle:nil];
        [banner show];
        
        return;
    }
    
    
    if ([favorites count] > 0)
    {
        if (buttonIndex == 1) //email all
        {
            NSMutableArray *sendTo = [NSMutableArray array];
            
            for (NSDictionary *person in favorites)
                [sendTo addObject:[person objectForKey:@"email"]];
            
            MFMailComposeViewController *mailer = [[MFMailComposeViewController alloc] init];
            
            mailer.mailComposeDelegate = self;
            [mailer setSubject:@""];
            
            [mailer setToRecipients:sendTo];
            
            NSString *emailBody = @"";
            [mailer setMessageBody:emailBody isHTML:NO];
            
            [self presentModalViewController:mailer animated:YES];
        }
        
        else if (buttonIndex == 2) //export to contacts
        {
            [favoritesTable scrollRectToVisible:CGRectMake(0, 0, 1, 1) animated:NO];
            [self performSelectorInBackground:@selector(checkContactsPermission) withObject:nil];
            [self.view makeToastActivity];
        }
        
        else if (buttonIndex == 3) //update data
        {
            [favoritesTable scrollRectToVisible:CGRectMake(0, 0, 1, 1) animated:NO];
            [self performSelectorInBackground:@selector(renewData) withObject:nil];
            [self.view makeToastActivity];
        }
        
    }
    
    else
    {
        ALAlertBanner *banner = [ALAlertBanner alertBannerForView:self.view style:ALAlertBannerStyleFailure position:ALAlertBannerPositionTop title:@"Ouch!" subtitle:@"The list is empty right now. Please, add someone before calling the group actions."];
        [banner show];
    }
    
}

#pragma mark - Mail controller delegate

- (void)mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error
{
    ALAlertBanner *banner;
    
    switch (result)
    {
        case MFMailComposeResultCancelled:
            NSLog(@"Mail cancelled: you cancelled the operation and no email message was queued.");
            break;
        case MFMailComposeResultSaved:
            NSLog(@"Mail saved: you saved the email message in the drafts folder.");
             banner = [ALAlertBanner alertBannerForView:self.view style:ALAlertBannerStyleSuccess position:ALAlertBannerPositionTop title:@"Saved in drafts.." subtitle:nil];
            [banner show];
            break;
        case MFMailComposeResultSent:
            NSLog(@"Mail send: the email message is queued in the outbox. It is ready to send.");
            banner = [ALAlertBanner alertBannerForView:self.view style:ALAlertBannerStyleSuccess position:ALAlertBannerPositionTop title:@"Message sent! ;)" subtitle:nil];
            [banner show];
            break;
        case MFMailComposeResultFailed:
            NSLog(@"Mail failed: the email message was not saved or queued, possibly due to an error.");
            banner = [ALAlertBanner alertBannerForView:self.view style:ALAlertBannerStyleFailure position:ALAlertBannerPositionTop title:@"Ouch!" subtitle:@"Sending failed! Maybe Internet problems? :("];
            [banner show];
            break;
        default:
            NSLog(@"Mail not sent.");
            break;
    }
    
    // Remove the mail view
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)tappedRightButton:(id)sender
{
    int selectedIndex = [self.tabBarController selectedIndex];
    
    if (selectedIndex + 1 >= [[self.tabBarController viewControllers] count]) {
        return;
    }
    
    /*
     UIView * fromView = self.view;
     UIView * toView = [[self.tabBarController.viewControllers objectAtIndex:selectedIndex+1] view];
    
    // Transition using a page curl.
    [UIView transitionFromView:fromView
                        toView:toView
                      duration:0.5
                       options:UIViewAnimationOptionTransitionFlipFromRight
                    completion:^(BOOL finished) {
                        if (finished) {
                            self.tabBarController.selectedIndex = selectedIndex+1;
                        }
                    }];
     */
    
    self.tabBarController.selectedIndex = selectedIndex+1;
}

- (IBAction)tappedLeftButton:(id)sender
{
    int selectedIndex = [self.tabBarController selectedIndex];
    
    if (selectedIndex - 1 < 0) {
        return;
    }
    
    /*
     UIView * fromView = self.view;
    UIView * toView = [[self.tabBarController.viewControllers objectAtIndex:selectedIndex-1] view];
    
    // Transition using a page curl.
    [UIView transitionFromView:fromView
                        toView:toView
                      duration:0.5
                       options:UIViewAnimationOptionTransitionFlipFromLeft
                    completion:^(BOOL finished) {
                        if (finished) {
                            self.tabBarController.selectedIndex = selectedIndex-1;
                        }
                    }];
     */

    self.tabBarController.selectedIndex = selectedIndex-1;
}


@end

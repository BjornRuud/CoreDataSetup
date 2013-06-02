//
//  BRViewController.h
//  CoreDataSetup
//
//  Created by Bjørn Olav Ruud on 02.06.13.
//
//

#import <UIKit/UIKit.h>

@interface BRViewController : UIViewController
<UITableViewDataSource, UITableViewDelegate>

@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;
@property (weak, nonatomic) IBOutlet UITableView *bookTableView;

- (void)coreDataInitialized;

@end

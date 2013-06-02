//
//  BRViewController.m
//  CoreDataSetup
//
//  Created by Bjørn Olav Ruud on 02.06.13.
//
//

#import <CoreData/CoreData.h>
#import "BRCoreDataManager.h"
#import "BRViewController.h"

@implementation BRViewController
{
    NSFetchedResultsController *_fetchController;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    [NSFetchedResultsController deleteCacheWithName:@"BookCache"];
}

#pragma mark - Methods

- (void)coreDataInitialized
{
    NSFetchRequest *fetch = [NSFetchRequest fetchRequestWithEntityName:@"Book"];
    NSSortDescriptor *alphaSort = [NSSortDescriptor sortDescriptorWithKey:@"title" ascending:YES];
    [fetch setSortDescriptors:@[alphaSort]];
    _fetchController = [[NSFetchedResultsController alloc]
                        initWithFetchRequest:fetch
                        managedObjectContext:[[BRCoreDataManager shared] mainContext]
                        sectionNameKeyPath:nil
                        cacheName:@"BookCache"];
    [self reloadData];
    [self.activityIndicator stopAnimating];
}

#pragma mark - Private methods

- (void)reloadData
{
    NSError *error = nil;
    ZAssert([_fetchController performFetch:&error], @"Fetch data failed: %@", [error localizedDescription]);
    [self.bookTableView reloadData];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [[_fetchController sections] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"BookCell" forIndexPath:indexPath];
    NSManagedObject *object = [_fetchController objectAtIndexPath:indexPath];
    cell.textLabel.text = [object valueForKey:@"title"];
    cell.detailTextLabel.text = [object valueForKey:@"author"];

    return cell;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    id <NSFetchedResultsSectionInfo> sectionInfo = [[_fetchController sections] objectAtIndex:section];
    return [sectionInfo numberOfObjects];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    id <NSFetchedResultsSectionInfo> sectionInfo = [[_fetchController sections] objectAtIndex:section];
    return [sectionInfo name];
}

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView
{
    return [_fetchController sectionIndexTitles];
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index
{
    return [_fetchController sectionForSectionIndexTitle:title atIndex:index];
}

@end

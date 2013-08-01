//
//  BRAppDelegate.m
//  CoreDataSetup
//
//  Created by Bjørn Olav Ruud on 02.06.13.
//
//

#import "BRAppDelegate.h"
#import "BRCoreDataManager.h"

@implementation BRAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"Library" withExtension:@"momd"];

    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *documentDirs = [fm URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask];
    NSURL *storeDirURL = [documentDirs lastObject];
    NSURL *storeURL = [storeDirURL URLByAppendingPathComponent:@"Library.sqlite"];
    //[fm removeItemAtURL:storeURL error:nil];

    BRCoreDataSetupType setupType = BRCoreDataSetupConcurrent;
    //BRCoreDataSetupType setupType = BRCoreDataSetupNested;

    BRCoreDataManager *manager = [BRCoreDataManager shared];
    [manager
     setupCoreDataWithModelURL:modelURL
     storeURL:storeURL
     setupType:setupType
     completion:^(NSError *error) {
         if (error) {
             UIAlertView *alert = [[UIAlertView alloc] initWithTitle:BRCoreDataManagerErrorDomain
                                                             message:[error localizedDescription]
                                                            delegate:nil
                                                   cancelButtonTitle:@"OK"
                                                   otherButtonTitles:nil];
             [alert show];
             return;
         }

         dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
             [self loadBooks];
             dispatch_async(dispatch_get_main_queue(), ^{
                 [self.window.rootViewController performSelector:@selector(coreDataInitialized)];
             });
         });
     }];

    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

- (void)loadBooks
{
    NSURL *jsonURL = [[NSBundle mainBundle] URLForResource:@"Books" withExtension:@"json"];
    NSError *error = nil;
    NSDictionary *result = [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfURL:jsonURL] options:0 error:&error];
    ZAssert(result, @"Failed to read %@: %@", [jsonURL absoluteString], [error localizedDescription]);

    NSManagedObjectContext *context = [[BRCoreDataManager shared] tempContext];
    NSFetchRequest *fetch = [NSFetchRequest fetchRequestWithEntityName:@"Book"];
    NSArray *books = [result objectForKey:@"Books"];
    for (NSDictionary *book in books) {
        error = nil;
        NSString *title = [book valueForKey:@"Title"];
        NSString *author = [book valueForKey:@"Author"];
        NSPredicate *titlePred = [NSPredicate predicateWithFormat:@"title LIKE %@", title];
        [fetch setPredicate:titlePred];
        NSArray *objects = [context executeFetchRequest:fetch error:&error];
        if (error) {
            ZAssert(error, @"Fetch book failed: %@", [error localizedDescription]);
            continue;
        }
        NSManagedObject *object = [objects lastObject];
        if (!object) {
            object = [NSEntityDescription insertNewObjectForEntityForName:@"Book" inManagedObjectContext:context];
        }
        [object setValue:title forKey:@"title"];
        [object setValue:author forKey:@"author"];
    }
    NSError *saveError = nil;
    ZAssert([context save:&saveError], @"Save books failed: %@", [saveError localizedDescription]);
}

@end

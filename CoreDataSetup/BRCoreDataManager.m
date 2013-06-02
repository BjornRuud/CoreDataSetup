//
//  BRCoreDataManager.m
//  CoreDataSetup
//
//  Created by Bjørn Olav Ruud on 02.06.13.
//
//

#import "BRCoreDataManager.h"

NSString * const BRCoreDataManagerErrorDomain = @"BRCoreDataManagerErrorDomain";

@implementation BRCoreDataManager
{
    NSManagedObjectContext *_storeContext;
    NSManagedObjectContext *_mainContext;
}

#pragma mark - Class methods

+ (BRCoreDataManager *)shared
{
    static BRCoreDataManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[BRCoreDataManager alloc] init];
    });

    return manager;
}

#pragma mark - Lifecycle

- (id)init
{
    self = [super init];
    if (self) {
        _isInitialized = NO;

        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc addObserver:self selector:@selector(processContextDidSaveNotification:) name:NSManagedObjectContextDidSaveNotification object:nil];
    }

    return self;
}

- (void)dealloc
{
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc removeObserver:self name:NSManagedObjectContextDidSaveNotification object:nil];
}

#pragma mark - Methods

- (NSManagedObjectContext *)mainContext
{
    return _mainContext;
}

- (NSManagedObjectContext *)tempContext
{
    NSManagedObjectContext *context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    if (_storeContext) {
        // Store context exists, we are using the nested context pattern
        [context setParentContext:_mainContext];
    } else {
        [context setPersistentStoreCoordinator:self.persistentStoreCoordinator];
    }

    return context;
}

#pragma mark - Helper methods

- (NSError *)errorWithMessage:(NSString *)message
{
    return [NSError errorWithDomain:BRCoreDataManagerErrorDomain
                               code:0
                           userInfo:@{NSLocalizedDescriptionKey: message}];
}

#pragma mark - Core Data setup

- (void)setupCoreDataWithModelURL:(NSURL *)modelURL
                         storeURL:(NSURL *)storeURL
                        setupType:(BRCoreDataSetupType)setupType
                       completion:(void (^)())completion
                          failure:(void (^)(NSError *error))failure
{
    if (_isInitialized) {
        NSString *message = @"Core Data already initialized";
        if (failure) failure([self errorWithMessage:message]);
        return;
    }

    DLog(@"Begin Core Data setup");

    NSManagedObjectModel *mom = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    if (!mom) {
        NSString *message = [NSString stringWithFormat:@"Failed to initialize managed object model %@", [modelURL absoluteString]];
        if (failure) failure([self errorWithMessage:message]);
        return;
    }
    DLog(@"Managed Object Model initialized");

    NSPersistentStoreCoordinator *psc = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:mom];
    if (!psc) {
        NSString *message = @"Failed to initialize persistent store coordinator";
        if (failure) failure([self errorWithMessage:message]);
        return;
    }
    DLog(@"Persistent Store Coordinator initialized");

    // Do the rest of the setup asynchronously since attaching a persistent store to a coordinator
    // might trigger migration, which can take some time depending on its complexity.
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(queue, ^{
        NSError *error = nil;
        NSPersistentStore *store = [psc addPersistentStoreWithType:NSSQLiteStoreType
                                                     configuration:nil
                                                               URL:storeURL
                                                           options:nil
                                                             error:&error];
        if (!store) {
            dispatch_sync(dispatch_get_main_queue(), ^{
                if (failure) failure(error);
            });
            return;
        }
        DLog(@"Persistent Store added to coordinator");

        // Setup contexts
        _persistentStoreCoordinator = psc;
        if (setupType == BRCoreDataSetupConcurrent) {
            // In the concurrent context pattern all contexts are associated with a store, and all changes in
            // contexts other than main are saved on a private queue and propagated to the main context.
            NSManagedObjectContext *mainContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
            [mainContext setPersistentStoreCoordinator:psc];
            _mainContext = mainContext;
        } else {
            // In the nested context pattern the context associated with a store saves on a private queue
            // to get async saving, and all other contexts are part of a context hierarchy with the store
            // context as root.
            NSManagedObjectContext *storeContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
            [storeContext setPersistentStoreCoordinator:psc];
            _storeContext = storeContext;

            NSManagedObjectContext *mainContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
            [mainContext setParentContext:storeContext];
            _mainContext = mainContext;
        }
        DLog(@"Contexts initialized");

        // Finalize on main thread
        dispatch_sync(dispatch_get_main_queue(), ^{
            _isInitialized = YES;
            DLog(@"End Core Data setup");
            if (completion) completion();
        });
    });
}

- (void)processContextDidSaveNotification:(NSNotification *)notification
{
    if (_storeContext) {
        [self processNestedContextDidSaveNotification:notification];
    } else {
        [self processConcurrentContextDidSaveNotification:notification];
    }
}

- (void)processConcurrentContextDidSaveNotification:(NSNotification *)notification
{
    NSManagedObjectContext *sender = (NSManagedObjectContext *)[notification object];
    // Only handle other contexts than main
    if (sender == _mainContext) return;
    // Only handle contexts that use the persistent store coordinator for this object
    if ([sender persistentStoreCoordinator] != self.persistentStoreCoordinator) return;

    [_mainContext mergeChangesFromContextDidSaveNotification:notification];
}

- (void)processNestedContextDidSaveNotification:(NSNotification *)notification
{
    NSManagedObjectContext *sender = (NSManagedObjectContext *)[notification object];
    // Ignore store context
    if (sender == _storeContext) return;
    // Main context save activates store save
    NSError *error = nil;
    if (sender == _mainContext) {
        ZAssert([_storeContext save:&error], @"Store context save failed: %@", [error localizedDescription]);
    }
    // Child context save activates main context save
    if ([sender parentContext] == _mainContext) {
        ZAssert([_mainContext save:&error], @"Main context save failed: %@", [error localizedDescription]);
    }
}

@end

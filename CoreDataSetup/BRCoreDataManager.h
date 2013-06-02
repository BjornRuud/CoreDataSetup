//
//  BRCoreDataManager.h
//  CoreDataSetup
//
//  Created by Bjørn Olav Ruud on 02.06.13.
//
//

#import <CoreData/CoreData.h>
#import <Foundation/Foundation.h>

FOUNDATION_EXPORT NSString * const BRCoreDataManagerErrorDomain;

typedef NS_ENUM(NSInteger, BRCoreDataSetupType) {
    BRCoreDataSetupConcurrent,
    BRCoreDataSetupNested
};

@interface BRCoreDataManager : NSObject

@property (nonatomic, readonly) BOOL isInitialized;
@property (nonatomic, readonly) NSPersistentStoreCoordinator *persistentStoreCoordinator;

+ (BRCoreDataManager *)shared;

- (void)setupCoreDataWithModelURL:(NSURL *)modelURL
                         storeURL:(NSURL *)storeURL
                        setupType:(BRCoreDataSetupType)setupType
                       completion:(void (^)())completion
                          failure:(void (^)(NSError *error))failure;

- (NSManagedObjectContext *)mainContext;
- (NSManagedObjectContext *)tempContext;

@end

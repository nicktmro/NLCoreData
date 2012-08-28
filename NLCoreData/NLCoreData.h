//  
//  NLCoreData.h
//  
//  Created by Jesper Skrufve <jesper@neolo.gy>
//  
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to
//  deal in the Software without restriction, including without limitation the
//  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
//  sell copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//  
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//  
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
//  IN THE SOFTWARE.
//  

/**
 If an error occurs during a core data operation and DEBUG is defined, an exception is usually raised.
 Make sure not to define DEBUG in production.
 */

#import <Foundation/Foundation.h>

#import "NSThread+NLCoreData.h"
#import "NSManagedObject+NLCoreData.h"
#import "NSManagedObjectContext+NLCoreData.h"
#import "NSFetchRequest+NLCoreData.h"
#import "NSFetchedResultsController+NLCoreData.h"

@class
NSManagedObjectModel,
NSPersistentStoreCoordinator,
NSManagedObjectContext;

extern const struct NLCoreDataExceptionsStruct
{
	__unsafe_unretained NSString* predicate;
	__unsafe_unretained NSString* count;
	__unsafe_unretained NSString* parameter;
	__unsafe_unretained NSString* merge;
} NLCoreDataExceptions;

#pragma mark -
@interface NLCoreData : NSObject

/**
 Whether or not the store exists. This is likely NO before it's used the first time only.
 Use it to check if the store needs to be seeded.
 */
@property (assign, nonatomic, readonly) BOOL storeExists;

/**
 Whether or not the store is encrypted.
 */
@property (assign, nonatomic, getter=isStoreEncrypted) BOOL storeEncrypted;

/**
 The persistent store coordinator.
 Set to automatic lightweight migration if needed.
 */
@property (strong, nonatomic) NSPersistentStoreCoordinator*	storeCoordinator;

/**
 The managed object model.
 */
@property (strong, nonatomic) NSManagedObjectModel* managedObjectModel;

/**
 @name Path
 Filesystem path to the store as NSString and NSURL.
 */
- (NSString *)storePath;
- (NSURL *)storeURL;

#pragma mark - Lifecycle

+ (void)initializeModels:(NSArray *)modelNames;
/**
 @name Lifecycle
 The shared instance. Use this, not alloc/init.
 */
+ (NLCoreData *)sharedForModel:(NSString *)modelName;
+ (NSString *)modelForEntityName:(NSString *)entityName;

/**
 @name Lifecycle
 Copies a preseeded database file to be used as your Core Data store.
 The filetype should be sqlite and it should conform to your model.
 @param filePath Path to the preseeded file.
 @warning This should be called before using Core Data on first run.
 */
- (void)usePreSeededFile:(NSString *)filePath;

/**
 @name Lifecycle
 Copies a preseeded database file to be used as your Core Data store.
 The filetype should be sqlite and it should conform to your model.
 Checks the main bundle for a sqlite file with the same name as your model.
 @warning This should be called before using Core Data on first run, but after setting the modelName.
 */
- (void)usePreSeededFileFromBundle;

@end

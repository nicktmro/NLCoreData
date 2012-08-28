//
//  NSManagedObjectContext+NLCoreData.m
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

#import "NSManagedObjectContext+NLCoreData.h"
#import "NSThread+NLCoreData.h"
#import "NSManagedObject+NLCoreData.h"

static NSString* NLCoreDataContextKey				= @"NLCoreDataContextKey";
static NSString* NLCoreDataNotificationBlockKey		= @"NLCoreDataNotificationBlockKey";
static NSString* NLCoreDataMergeTargetContextKey	= @"NLCoreDataMergeTargetContextKey";
static NSString* NLCoreDataMergeTargetThreadKey     = @"NLCoreDataMergeTargetThreadKey";

@implementation NSManagedObjectContext (NLCoreData)

@dynamic
undoEnabled;

#pragma mark - Lifecycle

- (BOOL)save
{
	if (![self hasChanges]) return YES;
	
	NSError* error = nil;
	
	if (![self save:&error]) {
#ifdef DEBUG
		NSLog(@"NSManagedObjectContext Error: %@", [error userInfo]);
		
		NSArray* details = [[error userInfo] objectForKey:@"NSDetailedErrors"];
		
		for (NSError* err in details)
			NSLog(@"Error %i: %@", [err code], [err userInfo]);
#endif
		return NO;
	}
	
	return YES;
}

+ (NSManagedObjectContext *)contextForThreadWithEntity:(Class)entity
{
	return [self contextForThread:[NSThread currentThread] withEntity:entity];
}

+ (NSManagedObjectContext *)contextForThread:(NSThread *)thread withEntity:(Class)entity
{
    
    NSString *modelName = [NLCoreData modelForEntityName:NSStringFromClass(entity)];
    
	NSMutableDictionary* dictionary = [thread threadDictionary];
	NSManagedObjectContext* context = [dictionary objectForKey:[NSString stringWithFormat:@"%@%@", NLCoreDataContextKey, modelName]];
	
	if (!context) {
		if (thread == [NSThread mainThread]) {
            context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
        }
        else {
            context = [[NSManagedObjectContext alloc] init];
        }        
        
        [context setPersistentStoreCoordinator:[[NLCoreData sharedForModel:modelName] storeCoordinator]];
		
		[dictionary setObject:context forKey:[NSString stringWithFormat:@"%@%@", NLCoreDataContextKey, modelName]];
	}
	
	return context;
}

#pragma mark - Notifications

- (void)mergeWithContext:(NSManagedObjectContext *)context onThread:(NSThread *)thread completion:(void (^)(NSNotification *))completion
{
#ifdef DEBUG
	if (self == context)
		[NSException raise:NLCoreDataExceptions.merge format:@"Can't merge a context with itself"];
#endif
	
	NSMutableDictionary* dictionary = [[NSThread currentThread] threadDictionary];
	
	if (completion)
		[dictionary setObject:[completion copy] forKey:NLCoreDataNotificationBlockKey];
	
	[dictionary setObject:thread forKey:NLCoreDataMergeTargetThreadKey];
    [dictionary setObject:context forKey:NLCoreDataMergeTargetContextKey];
	
	[[NSNotificationCenter defaultCenter]
	 addObserver:context
	 selector:@selector(managedObjectContextMerge:)
	 name:NSManagedObjectContextDidSaveNotification
	 object:self];
	
	[self save];
    
    [[NSNotificationCenter defaultCenter]
	 removeObserver:context name:NSManagedObjectContextDidSaveNotification object:self];
}

- (void)managedObjectContextMerge:(NSNotification *)note
{
	NSLog(@"managedObjectContextMerge: mainthr? %i", [NSThread mainThread] == [NSThread currentThread]);
	
	NSMutableDictionary* dictionary			= [[NSThread currentThread] threadDictionary];
	NSThread* thread						= [dictionary objectForKey:NLCoreDataMergeTargetThreadKey];
	NSManagedObjectContext* context			= [dictionary objectForKey:NLCoreDataMergeTargetContextKey];
	NLCoreDataNotificationBlock	completion	= [dictionary objectForKey:NLCoreDataNotificationBlockKey];
	
	[dictionary removeObjectForKey:NLCoreDataMergeTargetContextKey];
	[dictionary removeObjectForKey:NLCoreDataNotificationBlockKey];
	
	[thread performBlockOnThread:^{
        [context mergeChangesFromContextDidSaveNotification:note];
		
		if (completion)
			completion(note);
	}];
}

#pragma mark - Property Accessors

- (void)setUndoEnabled:(BOOL)undoEnabled
{
	if (undoEnabled && ![self isUndoEnabled])
		[self setUndoManager:[[NSUndoManager alloc] init]];
	else if (!undoEnabled)
		[self setUndoManager:nil];
}

- (BOOL)isUndoEnabled
{
	return !![self undoManager];
}

@end

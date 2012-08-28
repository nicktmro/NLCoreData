//
//  NSManagedObject+NLCoreData.m
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

#import "NSManagedObject+NLCoreData.h"
#import "NLCoreData.h"

#ifdef DEBUG
#define SET_PREDICATE_WITH_VARIADIC_ARGS \
	NSPredicate* predicate = nil; \
	if ([predicateOrString isKindOfClass:[NSString class]]) { \
		va_list args; \
		va_start(args, predicateOrString); \
		predicate = [NSPredicate predicateWithFormat:predicateOrString arguments:args]; \
		va_end(args); \
	} \
	else if ([predicateOrString isKindOfClass:[NSPredicate class]]) \
		predicate = predicateOrString; \
	else if (predicateOrString) \
		[NSException raise:NLCoreDataExceptions.predicate format:@"invalid predicate: %@", predicateOrString];
#else
#define SET_PREDICATE_WITH_VARIADIC_ARGS \
	NSPredicate* predicate = nil; \
	if ([predicateOrString isKindOfClass:[NSString class]]) { \
		va_list args; \
		va_start(args, predicateOrString); \
		predicate = [NSPredicate predicateWithFormat:predicateOrString arguments:args]; \
		va_end(args); \
	} \
	else if ([predicateOrString isKindOfClass:[NSPredicate class]]) \
		predicate = predicateOrString;
#endif

#pragma mark -
@implementation NSManagedObject (NLCoreData)

#pragma mark - Inserting

+ (id)insert
{
	return [self insertInContext:[NSManagedObjectContext contextForThreadWithEntity:[self class]]];
}

+ (id)insertInContext:(NSManagedObjectContext *)context
{
	return [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass([self class])
										 inManagedObjectContext:context];
}

#pragma mark - Deleting

- (void)delete
{
	[[self managedObjectContext] deleteObject:self];
}

+ (void)deleteWithRequest:(void (^)(NSFetchRequest* request))block
{
	[self deleteWithRequest:block context:[NSManagedObjectContext contextForThreadWithEntity:[self class]]];
}

+ (void)deleteWithRequest:(void (^)(NSFetchRequest* request))block context:(NSManagedObjectContext *)context
{
	NSArray* objects = [self fetchWithRequest:block context:context];
	
	for (NSManagedObject* object in objects)
		[context deleteObject:object];
}

+ (void)deleteWithPredicate:(id)predicateOrString, ...
{
	SET_PREDICATE_WITH_VARIADIC_ARGS
	[self deleteRange:NSMakeRange(0, 0) sortByKey:nil ascending:YES withPredicate:predicate];
}

+ (void)deleteRange:(NSRange)range withPredicate:(id)predicateOrString, ...
{
	SET_PREDICATE_WITH_VARIADIC_ARGS
	[self deleteRange:range sortByKey:nil ascending:YES withPredicate:predicate];
}

+ (void)deleteRange:(NSRange)range
		  sortByKey:(NSString *)keyPath
		  ascending:(BOOL)ascending
	  withPredicate:(id)predicateOrString, ...
{
	SET_PREDICATE_WITH_VARIADIC_ARGS
	[self deleteWithRequest:^(NSFetchRequest *request) {
		
		if (range.length > 0) {
			
			[request setFetchOffset:range.location];
			[request setFetchLimit:range.length];
		}
		
		if (keyPath)
			[request sortByKey:keyPath ascending:ascending];
		
		if (predicate)
			[request setPredicate:predicate];
		
	} context:[NSManagedObjectContext contextForThreadWithEntity:[self class]]];
}

#pragma mark - Counting

+ (NSUInteger)countWithPredicate:(id)predicateOrString, ...
{
	SET_PREDICATE_WITH_VARIADIC_ARGS
	return [self countWithRequest:^(NSFetchRequest *request) { [request setPredicate:predicate]; }
						  context:[NSManagedObjectContext contextForThreadWithEntity:[self class]]];
}

+ (NSUInteger)countWithRequest:(void (^)(NSFetchRequest* request))block
{
	return [self countWithRequest:block context:[NSManagedObjectContext contextForThreadWithEntity:[self class]]];
}

+ (NSUInteger)countWithRequest:(void (^)(NSFetchRequest* request))block context:(NSManagedObjectContext *)context
{
	NSFetchRequest* request = [NSFetchRequest fetchRequestWithEntity:[self class]];
	
	if (block)
		block(request);
	
	NSError* error;
	NSUInteger count = [context countForFetchRequest:request error:&error];
	
#ifdef DEBUG
	if (count == NSNotFound)
		[NSException raise:NLCoreDataExceptions.count format:@"%@", [error localizedDescription]];
#endif
	
	return count;
}

#pragma mark - Fetching

+ (id)fetchWithObjectID:(NSManagedObjectID *)objectID
{
	return [self fetchWithObjectID:objectID context:[NSManagedObjectContext contextForThreadWithEntity:[self class]]];
}

+ (id)fetchWithObjectID:(NSManagedObjectID *)objectID context:(NSManagedObjectContext *)context
{
	id object = [context objectRegisteredForID:objectID];
	
	if (object)
		return object;
	
	object = [context objectWithID:objectID];
	
	if (![object isFault])
		return object;
	
	NSError* error;
	object = [context existingObjectWithID:objectID error:&error];
	
	return object;
}

+ (NSArray *)fetchWithRequest:(void (^)(NSFetchRequest* request))block
{
	return [self fetchWithRequest:block context:[NSManagedObjectContext contextForThreadWithEntity:[self class]]];
}

+ (NSArray *)fetchWithRequest:(void (^)(NSFetchRequest* request))block context:(NSManagedObjectContext *)context
{
	NSFetchRequest* request = [NSFetchRequest fetchRequestWithEntity:[self class] context:context];
	
	if (block)
		block(request);
	
	NSError* error;
	NSArray* objects = [context executeFetchRequest:request error:&error];
	
	return objects;
}

+ (NSArray *)fetchWithPredicate:(id)predicateOrString, ...
{
	SET_PREDICATE_WITH_VARIADIC_ARGS
	return [self fetchRange:NSMakeRange(0, 0) sortByKey:nil ascending:YES withPredicate:predicate];
}

+ (NSArray *)fetchRange:(NSRange)range withPredicate:(id)predicateOrString, ...
{
	SET_PREDICATE_WITH_VARIADIC_ARGS
	return [self fetchRange:range sortByKey:nil ascending:YES withPredicate:predicate];
}

+ (NSArray *)fetchRange:(NSRange)range
			  sortByKey:(NSString *)keyPath
			  ascending:(BOOL)ascending
		  withPredicate:(id)predicateOrString, ...
{
	SET_PREDICATE_WITH_VARIADIC_ARGS
	return [self fetchWithRequest:^(NSFetchRequest *request) {
		
		if (range.length > 0) {
			
			[request setFetchOffset:range.location];
			[request setFetchLimit:range.length];
		}
		
		if (keyPath)
			[request sortByKey:keyPath ascending:ascending];
		
		if (predicate)
			[request setPredicate:predicate];
		
	} context:[NSManagedObjectContext contextForThreadWithEntity:[self class]]];
}

+ (NSArray *)fetchSingle:(NSUInteger)index withPredicate:(id)predicateOrString, ...
{
	SET_PREDICATE_WITH_VARIADIC_ARGS
	return [self fetchSingle:index sortByKey:nil ascending:YES withPredicate:predicate];
}

+ (NSArray *)fetchSingle:(NSUInteger)index
			   sortByKey:(NSString *)keyPath
			   ascending:(BOOL)ascending
		   withPredicate:(id)predicateOrString, ...
{
	SET_PREDICATE_WITH_VARIADIC_ARGS
	NSArray* objects = [self fetchRange:NSMakeRange(index, 1)
							  sortByKey:keyPath
							  ascending:ascending
						  withPredicate:predicate];
	
	return [objects count] ? [objects objectAtIndex:0] : nil;
}

+ (id)fetchOrInsertSingle:(NSUInteger)index withPredicate:(id)predicateOrString, ...
{
	SET_PREDICATE_WITH_VARIADIC_ARGS
	return [self fetchOrInsertSingle:index sortByKey:nil ascending:YES withPredicate:predicate];
}

+ (id)fetchOrInsertSingle:(NSUInteger)index
				sortByKey:(NSString *)keyPath
				ascending:(BOOL)ascending
			withPredicate:(id)predicateOrString, ...
{
	SET_PREDICATE_WITH_VARIADIC_ARGS
	id object = [self fetchSingle:index sortByKey:keyPath ascending:ascending withPredicate:predicate];
	
	if (object)
		return object;
	
	return [self insert];
}

+ (void)fetchAsynchronouslyWithRequest:(void (^)(NSFetchRequest* request))block
							completion:(void (^)(NSArray* objects))completion
{
#ifdef DEBUG
	if (!completion)
		[NSException raise:NLCoreDataExceptions.parameter format:@"completion block cannot be nil"];
#endif
	
	NSManagedObjectContext *child = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    [child setParentContext:[NSManagedObjectContext contextForThread:[NSThread mainThread] withEntity:[self class]]];
    
    [child performBlock:^{
        NSFetchRequest* idRequest = [NSFetchRequest fetchRequestWithEntity:[self class] context:child];
        
		if (block)
			block(idRequest);
        
		[idRequest setResultType:NSManagedObjectIDResultType];
		[idRequest setSortDescriptors:nil];
        
		NSError* idError;
		NSArray* objectIDs = [child executeFetchRequest:idRequest error:&idError];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF IN %@", objectIDs];
			NSFetchRequest *objRequest = [NSFetchRequest fetchRequestWithEntity:[self class]];
            
			if (block)
				block(objRequest);
            
			[objRequest setPredicate:predicate];
            
			NSError* objError;
			NSArray* objects = [[NSManagedObjectContext contextForThreadWithEntity:[self class]]
								executeFetchRequest:objRequest error:&objError];
            
            completion(objects);
        });
    }];
    
}

+ (void)fetchAsynchronouslyForBackgroundProcessingWithRequest:(void (^)(NSFetchRequest* request))block
                                                   completion:(void (^)(NSArray* objects))completion
{
#ifdef DEBUG
	if (!completion)
		[NSException raise:NLCoreDataExceptions.parameter format:@"completion block cannot be nil"];
#endif
	
	NSManagedObjectContext *child = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    [child setParentContext:[NSManagedObjectContext contextForThreadWithEntity:[self class]]];
    
    [child performBlock:^{
        NSFetchRequest* request = [NSFetchRequest fetchRequestWithEntity:[self class] context:child];
        
		if (block)
			block(request);
        
		NSError* objError;
        NSArray* objects = [[NSManagedObjectContext contextForThreadWithEntity:[self class]]
                            executeFetchRequest:request error:&objError];
        
        completion(objects);
    }];

}

@end

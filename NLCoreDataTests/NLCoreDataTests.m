//
//  NLCoreDataTests.m
//  NLCoreDataTests
//
//  Created by j on 27/9/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "NLCoreDataTests.h"
#import "NLCoreData.h"
#import "User.h"
#import "Group.h"

@interface NLCoreDataTests ()

- (void)seedUsers:(NSInteger)count;
- (void)deleteUsers;

@end

#pragma mark -
@implementation NLCoreDataTests

#pragma mark - Lifecycle

- (void)setUp
{
	[super setUp];
	[NLCoreData initializeModels:[NSArray arrayWithObject:@"CoreDataStore"]];
}

- (void)tearDown
{
	[User deleteWithPredicate:nil];
	[Group deleteWithPredicate:nil];
	
	[super tearDown];
}

#pragma mark - Logic tests

- (void)testContext
{
	NSManagedObjectContext* context = [NSManagedObjectContext contextForThreadWithEntity:[User class]];
	
	STAssertTrue(context && context == [NSManagedObjectContext contextForThread:[NSThread currentThread] withEntity:[User class]], @"");
}

- (void)testInsert
{
	[self seedUsers:1];
	STAssertNotNil([User fetchSingle:0 withPredicate:nil], @"");
	[self deleteUsers];
}

- (void)testFetch
{
	[self seedUsers:1];
	STAssertNotNil([User fetchSingle:0 withPredicate:nil], @"");
	STAssertTrue([[User fetchWithPredicate:nil] count] == 1, @"");
	[self deleteUsers];
}

- (void)testDelete
{
	[self seedUsers:1];
	[User deleteWithPredicate:nil];
	STAssertNil([User fetchSingle:0 withPredicate:nil], @"");
}

- (void)testCount
{
	[self seedUsers:1];
	STAssertTrue([User countWithPredicate:nil] == 1, @"");
}

- (void)testNotification
{
	[User deleteWithPredicate:nil];
	STAssertTrue([User countWithPredicate:nil] == 0, @"");
	
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		
		NSManagedObjectContext* context = [NSManagedObjectContext contextForThreadWithEntity:[User class]];
		[User deleteWithPredicate:nil];
		
		STAssertTrue([User countWithPredicate:nil] == 0, @"");
		[User insert];
		STAssertTrue([User countWithPredicate:nil] == 1, @"");
		
		[context mergeWithContext:[NSManagedObjectContext contextForThread:[NSThread mainThread] withEntity:[User class]] onThread:[NSThread mainThread] completion:^(NSNotification *note) {
			
			STAssertTrue([[NSThread currentThread] isMainThread], @"not on main thread");
			STAssertTrue([User countWithPredicate:nil] == 1, @"contexts not merged");
		}];
	});
}

- (void)testAsyncFetchWithBackgroundProcessing
{
    [self deleteUsers];
    [self seedUsers:1];
    [[NSManagedObjectContext contextForThreadWithEntity:[User class]] save];
    
    [User fetchAsynchronouslyForBackgroundProcessingWithRequest:^(NSFetchRequest *request) {

    } completion:^(NSArray *objects) {
        STAssertTrue(! [[NSThread currentThread] isMainThread], @"should not be on main thread");
        STAssertTrue([objects count] == 1, @"background fetch failed");
    }];
}

- (void)testAsyncFetching
{
    [self deleteUsers];
    [self seedUsers:1];
    [[NSManagedObjectContext contextForThreadWithEntity:[User class]] save];
    
    [User fetchAsynchronouslyWithRequest:^(NSFetchRequest *request) {
        
    } completion:^(NSArray *objects) {
        STAssertTrue([[NSThread currentThread] isMainThread], @"on main thread");
        STAssertTrue([objects count] == 1, @"background fetch failed");
    }];
}

#pragma mark - Helpers

- (void)seedUsers:(NSInteger)count
{
	for (int i = 0; i < count; i++) {
		
		User* user = [User insert];
		[user setUsername:@""];
	}
}

- (void)deleteUsers
{
	[User deleteWithPredicate:nil];
}

@end

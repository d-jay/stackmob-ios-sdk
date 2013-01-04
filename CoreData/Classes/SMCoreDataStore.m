/*
 * Copyright 2012 StackMob
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "SMCoreDataStore.h"
#import "SMIncrementalStore.h"
#import "SMError.h"

static NSString *const SM_ManagedObjectContextKey = @"SM_ManagedObjectContextKey";

@interface SMCoreDataStore ()

@property(nonatomic, readwrite, strong)NSManagedObjectModel *managedObjectModel;
@property (nonatomic, strong) NSManagedObjectContext *privateContext;

- (NSManagedObjectContext *)newPrivateQueueContextWithParent:(NSManagedObjectContext *)parent;

@end

@implementation SMCoreDataStore

@synthesize persistentStoreCoordinator = _persistentStoreCoordinator;
@synthesize managedObjectModel = _managedObjectModel;
@synthesize managedObjectContext = _managedObjectContext;
@synthesize mainThreadContext = _mainThreadContext;
@synthesize privateContext = _privateContext;

- (id)initWithAPIVersion:(NSString *)apiVersion session:(SMUserSession *)session managedObjectModel:(NSManagedObjectModel *)managedObjectModel
{
    self = [super initWithAPIVersion:apiVersion session:session];
    if (self) {
        _managedObjectModel = managedObjectModel;
    }
    
    return self;
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
    if (_persistentStoreCoordinator == nil) {
        [NSPersistentStoreCoordinator registerStoreClass:[SMIncrementalStore class] forStoreType:SMIncrementalStoreType];
        
        _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:self.managedObjectModel];
        
        NSError *error = nil;
        [_persistentStoreCoordinator addPersistentStoreWithType:SMIncrementalStoreType
                                                  configuration:nil 
                                                            URL:[NSURL URLWithString:SMIncrementalStoreType]
                                                        options:[NSDictionary dictionaryWithObject:self forKey:SM_DataStoreKey] 
                                                          error:&error];
        if (error != nil) {
            [NSException raise:SMExceptionAddPersistentStore format:@"Error creating incremental persistent store: %@", error];
        }
        
    }
    
    return _persistentStoreCoordinator;
    
}

- (NSManagedObjectContext *)privateContext
{
    if (_privateContext == nil) {
        _privateContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        [_privateContext setMergePolicy:NSMergeByPropertyObjectTrumpMergePolicy];
        [_privateContext setPersistentStoreCoordinator:self.persistentStoreCoordinator];
    }
    return _privateContext;
}

// TODO mark deprecated
- (NSManagedObjectContext *)managedObjectContext
{
    if (_managedObjectContext == nil) {
        _managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
        [_managedObjectContext setMergePolicy:NSMergeByPropertyObjectTrumpMergePolicy];
        [_managedObjectContext setParentContext:self.privateContext];
    }
    return _managedObjectContext;
}

- (NSManagedObjectContext *)mainThreadContext
{
    if (_mainThreadContext == nil) {
        _mainThreadContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
        [_mainThreadContext setMergePolicy:NSMergeByPropertyObjectTrumpMergePolicy];
        [_mainThreadContext setParentContext:self.privateContext];
    }
    return _mainThreadContext;
}

- (NSManagedObjectContext *)newPrivateQueueContextWithParent:(NSManagedObjectContext *)parent
{
    NSManagedObjectContext *context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    [context setMergePolicy:NSMergeByPropertyObjectTrumpMergePolicy];
    [context setParentContext:parent];
    
    return context;
}

- (NSManagedObjectContext *)contextForCurrentThread
{
    if ([NSThread isMainThread])
	{
		return self.mainThreadContext;
	}
	else
	{
		NSMutableDictionary *threadDict = [[NSThread currentThread] threadDictionary];
		NSManagedObjectContext *threadContext = [threadDict objectForKey:SM_ManagedObjectContextKey];
		if (threadContext == nil)
		{
			threadContext = [self newPrivateQueueContextWithParent:self.mainThreadContext];
			[threadDict setObject:threadContext forKey:SM_ManagedObjectContextKey];
		}
		return threadContext;
	}
}

@end


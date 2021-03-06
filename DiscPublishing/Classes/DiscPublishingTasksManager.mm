//
//  DiscPublishingTasksManager.m
//  DiscPublishing
//
//  Created by Alessandro Volz on 5/11/10.
//  Copyright 2010 OsiriX Team. All rights reserved.
//

#import "DiscPublishing.h"
#import "DiscPublishingTasksManager.h"
#import "DiscPublishingTool.h"
#import <OsiriXAPI/ThreadsManager.h>
#import <OsiriXAPI/NSThread+N2.h>

@interface ToolThread : NSThread

-(BOOL)isToolCancelled;
-(void)setIsToolCancelled:(BOOL)isToolCancelled;

@end


@implementation DiscPublishingTasksManager

+(DiscPublishingTasksManager*)defaultManager {
	static DiscPublishingTasksManager* defaultManager = NULL;
	if (!defaultManager)
		defaultManager = [[DiscPublishingTasksManager alloc] initWithThreadsManager:[ThreadsManager defaultManager]];
	return defaultManager;
}

-(id)initWithThreadsManager:(ThreadsManager*)threadsManager {
	self = [super init];
	
	_threadsManager = [threadsManager retain];
	
	for (NSString* threadId in [DiscPublishing.instance.tool listTasks]) {
		[[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(observeThreadInfoChange:) name:DPTThreadInfoChangeNotification object:threadId suspensionBehavior:NSNotificationSuspensionBehaviorDeliverImmediately];
		NSThread* thread = [[ToolThread alloc] init];
		thread.name = [NSString stringWithFormat:@"Disc Publishing Tool thread %@", threadId];
		thread.status = @"Recovering thread information...";
		thread.uniqueId = threadId;
		[_threadsManager addThreadAndStart: [thread autorelease]];
	}
	
	return self;
}

-(void)dealloc {
    [NSDistributedNotificationCenter.defaultCenter removeObserver:self];
	[super dealloc];
}

-(void)spawnDiscWrite:(NSString*)discRootDirPath info:(NSDictionary*)info {
    if ([DiscPublishing testing]) {
        NSString* name = [discRootDirPath lastPathComponent];
        NSString* fpath;
        NSInteger i = 0;
        do {
            NSString* fname = name;
            if (i++)
                fname = [NSString stringWithFormat:@"%@-%d", name, (int)i];
            fpath = [NSHomeDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"Desktop/%@", fname]];
        } while ([NSFileManager.defaultManager fileExistsAtPath:fpath]);
        
        [NSFileManager.defaultManager moveItemAtPath:discRootDirPath toPath:fpath error:NULL];
        
        NSLog(@"DP TEST MODE: moving files to Desktop: %@", [fpath lastPathComponent]);
        
        return;
    }
    
    [[DiscPublishing instance] updateBinSelection];
    
	NSString* threadId = [DiscPublishing.instance.tool publishDiscWithRoot:discRootDirPath info:info];
	[NSDistributedNotificationCenter.defaultCenter addObserver:self selector:@selector(observeThreadInfoChange:) name:DPTThreadInfoChangeNotification object:threadId suspensionBehavior:NSNotificationSuspensionBehaviorDeliverImmediately];
	
	// a dummy thread that displays info about the Tool thread that handles this burn
	NSThread* thread = [[ToolThread alloc] init];
	thread.name = [NSString stringWithFormat:@"Tool Thread %@", threadId];
	thread.uniqueId = threadId;
	[_threadsManager addThreadAndStart:thread];
}

-(ToolThread*)threadWithId:(NSString*)threadId {
	for (NSThread* thread in _threadsManager.threads)
		if ([thread.uniqueId isEqual:threadId])
			return (ToolThread*)thread;
	return NULL;
}

-(void)observeThreadInfoChange:(NSNotification*)notification {
	NSString* key = [notification.userInfo objectForKey:DPTThreadChangedInfoKey];

	ToolThread* thread = [self threadWithId:notification.object];
	if (!thread) {
		NSLog(@"thread info change for key %@ of unknown thread id %@", key, notification.object);
		return;
	}
	
	if ([key isEqual:NSThreadSupportsCancelKey])
		thread.supportsCancel = [[notification.userInfo objectForKey:key] boolValue];
	else
	if ([key isEqual:NSThreadIsCancelledKey])
		thread.isToolCancelled = [[notification.userInfo objectForKey:key] boolValue];
	else
	if ([key isEqual:NSThreadStatusKey])
		thread.status = [notification.userInfo objectForKey:key];
	else
	if ([key isEqual:NSThreadProgressKey])
		thread.progress = [[notification.userInfo objectForKey:key] floatValue];
	else
	if ([key isEqual:NSThreadWillExitNotification])
		thread.isToolCancelled = YES;
	
	else NSLog(@"unexpected thread info change with key %@", key);
}




@end

// Cancel in plugin interface
//   => AppleScript:CancelJob(id)
//   => Tool:Thread.isCancelled = YES
//   => DistributedNotification:NSThreadIsCancelledKey
//   => ToolThread(id).isToolCancelled = YES

@implementation ToolThread

NSString* const NSThreadIsToolCancelledKey = @"isToolCancelled";

-(BOOL)isToolCancelled {
	NSNumber* isToolCancelled = [self.threadDictionary objectForKey:NSThreadIsToolCancelledKey];
	return isToolCancelled? [isToolCancelled boolValue] : NO;
}

-(void)setIsToolCancelled:(BOOL)isToolCancelled {
	if (isToolCancelled == self.isToolCancelled) return;
	[self willChangeValueForKey:NSThreadIsToolCancelledKey];
	[self.threadDictionary setObject:[NSNumber numberWithBool:isToolCancelled] forKey:NSThreadIsToolCancelledKey];
	[self didChangeValueForKey:NSThreadIsToolCancelledKey];
}

-(NSDictionary*)info {
	return [DiscPublishing.instance.tool getTaskInfoForId:self.uniqueId];
}

-(void)main {
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    @try {
        // get tool thread properties: name, supportsCancel, isCancelled(isToolCancelled), status, progress, and transmit them to this thread
        NSDictionary* info = [self info];
        for (NSString* key in info)
        if ([key isEqual:@"name"])
            self.name = [info objectForKey:key];
        else
        if ([key isEqual:NSThreadSupportsCancelKey])
            self.supportsCancel = [[info objectForKey:key] boolValue];
        else
        if ([key isEqual:NSThreadIsCancelledKey])
            self.isCancelled = [[info objectForKey:key] boolValue];
        else
        if ([key isEqual:NSThreadStatusKey])
            self.status = [info objectForKey:key];
        else
        if ([key isEqual:NSThreadProgressKey])
            self.progress = [[info objectForKey:key] floatValue];
        
        // subsequent thread info is updated through NSDistributedNotificationCenter
        
        while (!self.isToolCancelled)
            [NSThread sleepForTimeInterval:0.1];
	} @catch (NSException* e) {
        NSLog(@"ToolThread exception: %@", e.reason);
    } @finally {
        [pool release];
    }
}

@end

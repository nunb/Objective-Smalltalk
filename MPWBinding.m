//
//  MPWBinding.m
//  MPWTalk
//
//  Created by Marcel Weiher on 11/22/04.
//  Copyright 2004 Marcel Weiher. All rights reserved.
//

#import "MPWBinding.h"


@implementation MPWBinding



-initWithValue:aValue
{
	self=[super init];
    if (aValue) {
        [self bindValue:aValue];
    }
	return self;
}

+bindingWithValue:aValue
{
	return [[[self alloc] initWithValue:aValue] autorelease];
}

idAccessor( _value, _setValue )
boolAccessor( isBound ,setIsBound )

-value
{
	if ( [self isBound] ) {
		return [self _value];
	} else {
		[NSException raise:@"unboundvariable" format:@"variable not bound to a value"];
		return nil;
	}
}

-fileSystemValue
{
    return [self value];
}

-valueForKeyPath:(NSString*)kvpath
{
	return [[self value] valueForKeyPath:kvpath];
}


-valueForPathComponent:(NSString*)kvpath
{
	return [[self value] valueForPathComponent:kvpath];
}

-(void)setValue:newValue forKey:(NSString*)kvpath
{
	[[self value] setValue:newValue forKey:kvpath];
}

-(void)bindValue:newValue
{
	[self _setValue:newValue];
	[self setIsBound:YES];
}

-(void)unbindValue
{
	[self setIsBound:NO];
	[self _setValue:nil];
}

-(BOOL)hasChildren
{
    return NO;
}



-(void)dealloc
{
	[_value release];
	[super dealloc];
}




@end

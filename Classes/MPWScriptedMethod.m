//
//  MPWScriptedMethod.m
//  MPWTalk
//
//  Created by Marcel Weiher on 12/09/2005.
//  Copyright 2005 Marcel Weiher. All rights reserved.
//

#import "MPWScriptedMethod.h"
#import "MPWEvaluator.h"
#import "MPWStCompiler.h"

@implementation MPWScriptedMethod


objectAccessor( MPWExpression, methodBody, setMethodBody )
objectAccessor( NSArray, localVars, setLocalVars )
idAccessor( script, _setScript )
//idAccessor( _contextClass, setContextClass )

-(void)setScript:newScript
{
	[self setMethodBody:nil];
//    NSLog(@"setScript: '%@'",newScript);
	[self _setScript:newScript];
}


-compiledScript
{
	if ( ![self methodBody] ) {
		if ( [self context] ) {
			[self setMethodBody:[[self script] compileIn:[self context]]];
		} else {
			[self setMethodBody:[self script]];
		}
	}
	return [self methodBody];
}

-contextClass
{
	id localContextClass=[[self context] class];
	if ( !localContextClass) {
		localContextClass=[MPWEvaluator class];
	}
	return localContextClass;
}


-freshExecutionContextForRealLocalVars
{
//	NSLog(@"creating new context from context: %@",[self context]);
	return [[[[self contextClass] alloc] initWithParent:[self context]] autorelease];
}

-compiledInExecutionContext
{
	return [self context];
}

-executionContext
{
	return [self freshExecutionContextForRealLocalVars];
}

-(NSException*)handleException:exception target:target
{
    NSException *newException;
    NSMutableDictionary *newUserInfo=[NSMutableDictionary dictionaryWithCapacity:2];
    [newUserInfo addEntriesFromDictionary:[exception userInfo]];
    newException=[NSException exceptionWithName:[exception name] reason:[exception reason] userInfo:newUserInfo];
    Class targetClass = [target class];
    int offset=[[[exception userInfo] objectForKey:@"offset"] intValue];
    NSString *frameDescription=[NSString stringWithFormat:@"%s[%@ %@] + %d",targetClass==target?"+":"-",targetClass,[self methodHeader],offset];
    [newException addScriptFrame: frameDescription];
    NSString *myselfInTrace=    @"-[MPWScriptedMethod evaluateOnObject:parameters:]";    
    
    [newException addCombinedFrame:frameDescription frameToReplace:myselfInTrace previousTrace:[exception callStackSymbols]];
//    NSLog(@"exception: %@/%@ in %@ with backtrace: %@",[exception name],[exception reason],frameDescription,[newException combinedStackTrace]);
    return newException;
}

-evaluateOnObject:target parameters:parameters
{
	id returnVal=nil;
	id executionContext = [self executionContext];
	id compiledMethod = [self compiledScript];
//	NSLog(@"will evaluate scripted method %x with context %x",self,executionContext);
    
    @try {
	returnVal = [executionContext evaluateScript:compiledMethod onObject:target formalParameters:[self formalParameters] parameters:parameters];
    } @catch (id exception) {
        id newException = [self handleException:exception target:target];
#if TARGET_OS_IPHONE
        NSLog(@"exception: %@ at %@",newException,[newException combinedStackTrace]);
        Class c=NSClassFromString(@"MethodServer");
        [c addException:newException];
        NSLog(@"added exception to %@",c);
#else
        @throw newException;
#endif
    }
//	NSLog(@"did evaluate scripted method %x with context %x",self,executionContext);
	return returnVal;
}

-(NSString *)stringValue
{
    return [NSString stringWithFormat:@"%@\n%@",
            [[self methodHeader] headerString],
            [[self script] stringValue]];
}

-(void)encodeWithCoder:aCoder
{
	id scriptData = [script dataUsingEncoding:NSUTF8StringEncoding];
	[super encodeWithCoder:aCoder];
	encodeVar( aCoder, scriptData );
}

-initWithCoder:aCoder
{
	id scriptData=nil;
	self = [super initWithCoder:aCoder];
	decodeVar( aCoder, scriptData );
	[self setScript:[scriptData stringValue]];
	[scriptData release];
	return self;
}

-(void)dealloc 
{
	[localVars release];
	[methodBody release];
	[script release];
	[super dealloc];
}

@end

@interface MPWScriptedMethod(fakeTestingInterfaces)

-xxxSimpleNilTestMethod;

@end


@implementation MPWScriptedMethod(testing)

+(void)testLookupOfNilVariableInMethodWorks
{
	MPWStCompiler* compiler = [MPWStCompiler compiler];
	id a=[[NSObject new] autorelease];
	id result;
	[compiler addScript:@"a:=nil. b:='2'. a isNil ifTrue:[ b:='335']. b." forClass:@"NSObject" methodHeaderString:@"xxxSimpleNilTestMethod"];
	result = [a xxxSimpleNilTestMethod];
	IDEXPECT( result, @"335", @"if nil is working");
}

+_objectWithNestedMethodsThatThrow
{
	MPWStCompiler* compiler = [MPWStCompiler compiler];
	id a=[[NSObject new] autorelease];
	[compiler addScript:@"self bozobozozo." forClass:@"NSObject" methodHeaderString:@"xxxSimpleMethodThatRaises"];
	[compiler addScript:@"self xxxSimpleMethodThatRaises." forClass:@"NSObject" methodHeaderString:@"xxxSimpleMethodThatCallsMethodThatRaises"];
    return a;
}


+(void)testSimpleBacktrace
{
    id a = [self _objectWithNestedMethodsThatThrow];
    @try {
        [a xxxSimpleMethodThatRaises];
    } @catch (id exception) {
        id trace=[exception scriptStackTrace];
        IDEXPECT([trace lastObject], @"-[NSObject xxxSimpleMethodThatRaises] + 15", @"stack trace");
        return ;
    }
    EXPECTTRUE(NO, @"should have raised");
    
}

+(void)testNestedBacktrace
{
    id a = [self _objectWithNestedMethodsThatThrow];
    @try {
        [a xxxSimpleMethodThatCallsMethodThatRaises];
    } @catch (id exception) {
        id trace=[exception scriptStackTrace];
        INTEXPECT([trace count], 2, @"shoud have 2 elements in script trace");
        IDEXPECT([trace lastObject], @"-[NSObject xxxSimpleMethodThatCallsMethodThatRaises] + 15", @"stack trace");
        IDEXPECT([trace objectAtIndex:0], @"-[NSObject xxxSimpleMethodThatRaises] + 15", @"stack trace");
        return ;
    }
    EXPECTTRUE(NO, @"should have raised");
    
}

+(void)testCombinedScriptedAndNativeBacktrace
{
    id a = [self _objectWithNestedMethodsThatThrow];
    @try {
        [a xxxSimpleMethodThatCallsMethodThatRaises];
    } @catch (id exception) {
        id trace=[exception combinedStackTrace];
        
        EXPECTTRUE([[trace objectAtIndex:4] rangeOfString:@"xxxSimpleMethodThatRaises"].length>0, @"method that raises present");
        EXPECTTRUE([[trace objectAtIndex:14] rangeOfString:@"xxxSimpleMethodThatCallsMethodThatRaises"].length>0,@"method that calls method that raises present");
        return ;
    }
    EXPECTTRUE(NO, @"should have raised");
}


+testSelectors
{
	return [NSArray arrayWithObjects:
            @"testLookupOfNilVariableInMethodWorks",
            @"testSimpleBacktrace",
            @"testNestedBacktrace",
//            @"testCombinedScriptedAndNativeBacktrace",
		nil];
}

@end


@implementation NSException(scriptStackTrace)

dictAccessor(NSMutableArray, scriptStackTrace, setScriptStackTrace, (NSMutableDictionary*)[self userInfo])

dictAccessor(NSMutableArray, combinedStackTrace, setCombinedStackTrace, (NSMutableDictionary*)[self userInfo])

-(void)cullTrace:(NSMutableArray*)trace replacingOriginal:original withFrame:frame
{
    for (int i=0;i<[trace count]-3;i++) {
        int numLeft=[trace count]-i;
        NSString *cur=[trace objectAtIndex:i];
        if ( [cur rangeOfString:original].length>0) {
            NSString *address=nil;
#if TARGET_OS_IPHONE
            address=@"0x00000000";
#else
            address=@"0x0000000000000000";
#endif
            
            NSString *formattedFrame=[NSString stringWithFormat:@"%-4dScript                              %@  %@",i,address,frame];
            
            [trace replaceObjectAtIndex:i withObject:formattedFrame];
            return ;
        }
        
    }
}


-(void)addCombinedFrame:(NSString*)frame frameToReplace:original previousTrace:previousTrace
{
    NSMutableArray *trace=[self combinedStackTrace];
    if (!trace) {
        trace=[[previousTrace mutableCopy] autorelease];
        [self setCombinedStackTrace:trace];
    }
    [self cullTrace:trace replacingOriginal:original withFrame:frame];
}

-(void)addScriptFrame:(NSString*)frame
{
    NSMutableArray *trace=[self scriptStackTrace];
    if (!trace) {
        trace=[NSMutableArray array];
        [self setScriptStackTrace:trace];
    }
    [trace addObject:frame];
}



@end


// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

// Simulator-only native-widget fixture. Not production code or a real endpoint.
#import <Foundation/Foundation.h>
#import <TargetConditionals.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <dispatch/dispatch.h>
#import <dlfcn.h>
#import <math.h>
#if !TARGET_OS_SIMULATOR
#error This private hook must only be built for Simulator.
#endif

static id Get(id o, NSString *s) { SEL k=NSSelectorFromString(s); return [o respondsToSelector:k]?((id(*)(id,SEL))objc_msgSend)(o,k):nil; }
static id IvarObject(id o,const char *n) { Ivar v=class_getInstanceVariable([o class],n); return v?object_getIvar(o,v):nil; }
static id Scalar(id o,NSString *s,char kind) {
    SEL k=NSSelectorFromString(s); NSMethodSignature *m=[o methodSignatureForSelector:k];
    if (!m || m.methodReturnType[0]!=kind) return nil;
    if(kind=='f') { float v=((float(*)(id,SEL))objc_msgSend)(o,k); return isfinite(v)?@(v):@"nonfinite"; }
    if(kind=='d') { double v=((double(*)(id,SEL))objc_msgSend)(o,k); return isfinite(v)?@(v):@"nonfinite"; }
    return nil;
}
@class TTNativeBaselineSource;
@interface TTNativeBaselineManager:NSObject
@property float volume;
@property BOOL available,feedback,muted;
@property unsigned int capabilities;
@property NSInteger revision;
@property(copy) NSString *label;
@property(strong) NSURL *directory;
@property(strong) NSMapTable *sources;
@property(strong) NSMutableArray *retainedSources;
@property(strong) dispatch_source_t timer;
@property(strong) NSDictionary *lastSnapshot;
- (void)tick;
@end
static TTNativeBaselineManager *Manager;
static void Record(NSString *event,NSDictionary *details) {
    if(!Manager) return;
    NSMutableDictionary *r=[@{@"event":event,@"timestamp":@([NSDate date].timeIntervalSince1970),@"uptime":@(NSProcessInfo.processInfo.systemUptime),@"fakeBackend":@YES,@"label":Manager.label?:@"initial",@"revision":@(Manager.revision),@"modelVolume":@(Manager.volume),@"available":@(Manager.available),@"feedback":@(Manager.feedback),@"capabilities":@(Manager.capabilities),@"mainThread":@(NSThread.isMainThread)} mutableCopy];
    [r addEntriesFromDictionary:details?:@{}];
    if(![NSJSONSerialization isValidJSONObject:r]) return;
    NSData *data=[NSJSONSerialization dataWithJSONObject:r options:NSJSONWritingSortedKeys error:NULL];
    NSMutableData *line=[data mutableCopy]; [line appendData:[@"\n" dataUsingEncoding:NSUTF8StringEncoding]];
    @synchronized(Manager) {
        NSURL *url=[Manager.directory URLByAppendingPathComponent:@"NativeBaselineJournal.jsonl"];
        if(![NSFileManager.defaultManager fileExistsAtPath:url.path]) [NSFileManager.defaultManager createFileAtPath:url.path contents:nil attributes:@{NSFilePosixPermissions:@0600}];
        NSFileHandle *f=[NSFileHandle fileHandleForWritingAtPath:url.path];
        @try { [f seekToEndOfFile]; [f writeData:line]; [f closeFile]; } @catch(NSException *e) { NSLog(@"NativeBaseline journal exception: %@",e.name); }
    }
}
static NSDictionary *Snapshot(id view) {
    id controls=Get(view,@"volumeControlsView"), controller=Get(view,@"volumeController");
    id sequencer=IvarObject(controls,"_crownInputSequencer");
    return @{@"view":view?[NSString stringWithFormat:@"%p",view]:@"none",@"controller":controller?[NSString stringWithFormat:@"%p",controller]:@"none",@"viewValue":Scalar(controls,@"value",'f')?:NSNull.null,@"nativeModel":Scalar(controller,@"volumeValue",'f')?:NSNull.null,@"sequencerOffset":Scalar(sequencer,@"offset",'d')?:NSNull.null};
}
@interface TTNativeBaselineSource:NSObject
@property(weak) id delegate;
@property(weak) id view;
@property(strong) id originalSource;
- (void)notify;
@end
@implementation TTNativeBaselineSource
- (float)volume { return Manager.volume; }
- (BOOL)isVolumeControlAvailable { return Manager.available; }
- (unsigned int)volumeControlCapabilities { return Manager.capabilities; }
- (BOOL)isMuted { return Manager.muted; }
- (BOOL)muted { return Manager.muted; }
- (NSString *)volumeAudioCategory { return @"Audio/Video"; }
- (NSString *)volumeControlLabel { return @"FAKE Simulator endpoint"; }
- (BOOL)applicationShouldOverrideHardwareVolumeBehavior { return NO; }
- (BOOL)volumeWarningEnabled { return NO; }
- (NSInteger)volumeWarningState { return 0; }
- (float)EUVolumeLimit { return 1; }
- (id)groupRoute { return nil; }
- (id)outputDeviceRoute { return nil; }
- (void)setVolume:(float)value {
    id scalar=isfinite(value)?@(value):@"nonfinite";
    NSMutableDictionary *fields=[Snapshot(self.view) mutableCopy]; fields[@"outgoing"]=scalar;
    fields[@"appliedToFakeBackend"]=@(Manager.feedback && isfinite(value));
    Record(@"native_outgoing_setVolume",fields);
    // Preserve the exact native scalar. No synthetic Crown delta or forced zero.
    if(Manager.feedback && isfinite(value)) { Manager.volume=value; [self notify]; }
}
- (void)setMuted:(BOOL)value { Manager.muted=value; [self notify]; }
- (void)reload { dispatch_async(dispatch_get_main_queue(),^{[self notify];}); }
- (void)initializeVolume { [self reload]; }
- (void)_initializeVolume { [self reload]; }
- (void)notify {
    id d=self.delegate; if(!d) return;
    SEL c=NSSelectorFromString(@"volumeControllerDataSource:didChangeVolumeCapabilities:");
    if([d respondsToSelector:c]) ((void(*)(id,SEL,id,unsigned int))objc_msgSend)(d,c,self,Manager.capabilities);
    c=NSSelectorFromString(@"volumeControllerDataSource:didChangeVolumeControlAvailability:");
    if([d respondsToSelector:c]) ((void(*)(id,SEL,id,BOOL))objc_msgSend)(d,c,self,Manager.available);
    c=NSSelectorFromString(@"volumeControllerDataSource:didChangeVolume:");
    if([d respondsToSelector:c]) ((void(*)(id,SEL,id,float))objc_msgSend)(d,c,self,Manager.volume);
    c=NSSelectorFromString(@"volumeControllerDataSource:didChangeMuted:");
    if([d respondsToSelector:c]) ((void(*)(id,SEL,id,BOOL))objc_msgSend)(d,c,self,Manager.muted);
    Record(@"fake_delegate_notification",Snapshot(self.view));
}
// Its block argument ABI was not established by the captured accessor dump.
// Never invoke an unverified completion. Direct getters/delegate callbacks remain usable.
- (void)getVolumeValueWithCompletion:(id)completion {
    (void)completion;
    Record(@"unsupported_completion",@{@"reason":@"unverified_completion_ABI_not_invoked"});
}

@end
static void Visit(id view,NSMutableArray *result) {
    Class c=NSClassFromString(@"SPInterfaceVolumeControlView");
    if(c && [view isKindOfClass:c]) [result addObject:view];
    for(id child in Get(view,@"subviews")) Visit(child,result);
}
static BOOL Validate(Class reference,Class fake) {
    for(NSString *name in @[@"volume",@"setVolume:",@"isVolumeControlAvailable",@"volumeControlCapabilities",@"isMuted",@"setDelegate:",@"volumeAudioCategory",@"volumeControlLabel"]) {
        SEL s=NSSelectorFromString(name); Method a=class_getInstanceMethod(reference,s),b=class_getInstanceMethod(fake,s);
        if(!a || !b || strcmp(method_getTypeEncoding(a),method_getTypeEncoding(b))) {
            Record(@"abi_validation_failed",@{@"selector":name,@"reference":a?@(method_getTypeEncoding(a)):@"missing",@"fake":b?@(method_getTypeEncoding(b)):@"missing"}); return NO;
        }
    }
    return YES;
}
@implementation TTNativeBaselineManager
- (void)tick {
    if(!self.capabilities) {
        typedef CFStringRef (*CopyDescription)(unsigned int);
        CopyDescription copy=(CopyDescription)dlsym(RTLD_DEFAULT,"MRMediaRemotePickedRouteVolumeControlCapabilitiesCopyDescription");
        if(!copy) return;
        NSMutableDictionary *candidates=[NSMutableDictionary dictionary];
        for(unsigned int n=1;n<=64;n<<=1) { NSString *description=CFBridgingRelease(copy(n)); candidates[@(n).stringValue]=description?:@"nil"; if([description isEqualToString:@"Absolute"]) self.capabilities=n; }
        Record(@"capability_discovery",@{@"candidates":candidates,@"selected":@(self.capabilities)});
        if(!self.capabilities) return;
    }
    NSURL *command=[self.directory URLByAppendingPathComponent:@"NativeBaselineCommand.json"];
    NSData *bytes=[NSData dataWithContentsOfURL:command];
    NSDictionary *json=bytes?[NSJSONSerialization JSONObjectWithData:bytes options:0 error:NULL]:nil;
    if([json isKindOfClass:NSDictionary.class] && [json[@"revision"] isKindOfClass:NSNumber.class] && [json[@"revision"] integerValue]>self.revision) {
        id number=json[@"volume"];
        if(number && (![number isKindOfClass:NSNumber.class] || !isfinite([number doubleValue]) || [number doubleValue]<0 || [number doubleValue]>1)) { Record(@"command_rejected",@{@"reason":@"volume_must_be_finite_0_to_1"}); return; }
        self.revision=[json[@"revision"] integerValue];
        if([json[@"label"] isKindOfClass:NSString.class]) self.label=json[@"label"];
        if(number) self.volume=[number floatValue];
        if(json[@"available"]) self.available=[json[@"available"] boolValue];
        if(json[@"feedback"]) self.feedback=[json[@"feedback"] boolValue];
        if(json[@"muted"]) self.muted=[json[@"muted"] boolValue];
        Record(@"command_applied",@{@"notify":json[@"notify"]?:@YES});
        if(!json[@"notify"] || [json[@"notify"] boolValue]) for(TTNativeBaselineSource *s in self.sources.objectEnumerator.allObjects) [s notify];
    }
    id appClass=NSClassFromString(@"UIApplication"); id app=Get(appClass,@"sharedApplication");
    NSMutableArray *views=[NSMutableArray array]; for(id window in Get(app,@"windows")) Visit(window,views);
    NSMutableArray *snapshots=[NSMutableArray array];
    for(id view in views) {
        id controller=Get(view,@"volumeController"); if(!controller) continue;
        TTNativeBaselineSource *fake=[self.sources objectForKey:controller];
        if(!fake) {
            NSMethodSignature *setter=[controller methodSignatureForSelector:NSSelectorFromString(@"setDataSource:")];
            if(!setter || setter.numberOfArguments!=3 || setter.methodReturnType[0]!='v' || [setter getArgumentTypeAtIndex:2][0]!='@') { Record(@"controller_setter_ABI_rejected",@{}); continue; }
            id old=Get(controller,@"dataSource");
            if(!Validate([old class],TTNativeBaselineSource.class)) continue;
            fake=[TTNativeBaselineSource new]; fake.view=view; fake.originalSource=old; [self.sources setObject:fake forKey:controller]; [self.retainedSources addObject:fake];
            NSMutableDictionary *provenance=[Snapshot(view) mutableCopy]; provenance[@"originalSourceClass"]=NSStringFromClass([old class]); provenance[@"originalSource"]=[NSString stringWithFormat:@"%p",old];
            Record(@"before_data_source_replacement",provenance);
            ((void(*)(id,SEL,id))objc_msgSend)(controller,NSSelectorFromString(@"setDataSource:"),fake);
            if(!fake.delegate) fake.delegate=controller;
            Record(@"fake_data_source_installed",Snapshot(view)); [fake notify];
        }
        [snapshots addObject:Snapshot(view)];
    }
    NSDictionary *snapshot=@{@"nativeViews":snapshots};
    if(![self.lastSnapshot isEqual:snapshot]) { self.lastSnapshot=snapshot; Record(@"native_state_changed",snapshot); }
}
@end
__attribute__((constructor)) static void StartNativeBaselineHook(void) {
    const char *flag=getenv("TT_NATIVE_BASELINE_HOOK"); if(!flag || strcmp(flag,"1")) return;
    dispatch_async(dispatch_get_main_queue(),^{
        if(![NSBundle.mainBundle.bundleIdentifier isEqualToString:@"net.qays.TeachingTimer.VolumeProbe"]) return;
        Manager=[TTNativeBaselineManager new]; Manager.volume=.625f; Manager.available=YES; Manager.feedback=YES; Manager.revision=-1; Manager.label=@"initial_known_fake_0.625";
        Manager.directory=[NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
        const char *raw=getenv("TT_NATIVE_BASELINE_CAPABILITIES");
        if(raw) { char *end=NULL; unsigned long mask=strtoul(raw,&end,0); if(end && *end=='\0' && mask>0 && mask<=UINT_MAX) Manager.capabilities=(unsigned int)mask; }
        Manager.sources=[NSMapTable weakToStrongObjectsMapTable]; Manager.retainedSources=[NSMutableArray array]; Record(@"hook_started",@{@"simulatorOnly":@YES,@"realEndpoint":@NO,@"rawCapabilityOverride":@(Manager.capabilities)});
        Manager.timer=dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER,0,0,dispatch_get_main_queue());
        dispatch_source_set_timer(Manager.timer,DISPATCH_TIME_NOW,NSEC_PER_SEC/10,NSEC_PER_MSEC*10);
        dispatch_source_set_event_handler(Manager.timer,^{@try{[Manager tick];}@catch(NSException *e){Record(@"hook_exception",@{@"name":e.name,@"reason":e.reason?:@"unknown"});}}); dispatch_resume(Manager.timer);
    });
}

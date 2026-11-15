// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

// Host-only Simulator experiment. Never include this in an app target.
// DTUHID protocol and connection adapted from Meta idb, MIT; see PINNED_UPSTREAM.md
// and LICENSE-idb.txt. This tool deliberately has no boot/install/launch path.
#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>
#import <xpc/xpc.h>
#import <dlfcn.h>
#import <mach/mach.h>
#import <stdatomic.h>
#import <math.h>
#import <errno.h>
#import <unistd.h>
#import <sys/stat.h>

// Minimal declarations for dynamic dispatch; no private framework link.
@interface NSObject (CoreSimulatorCrownExperiment)
+ (id)sharedServiceContextForDeveloperDir:(NSString *)developerDir error:(NSError **)error;
- (id)defaultDeviceSetWithError:(NSError **)error;
- (NSArray *)availableDevices;
- (NSUUID *)UDID;
- (unsigned long long)state;
- (NSString *)stateString;
- (NSString *)deviceTypeIdentifier;
- (id)deviceType;
- (int)productFamilyID;
- (mach_port_t)lookup:(NSString *)service error:(NSError **)error;
@end

static const char *Service = "com.apple.coredevice.feature.remote.hid.scroll";
static const double MaximumDelta = 100.0; // Smaller than upstream's 1800 bound.
static const double CrownDuration = 0.25;
static const useconds_t WarmTailUS = 200000;
static const useconds_t DrainUS = 1000000;
static const useconds_t BeginGapUS = 50000;
static BOOL ZeroBeganProfile = NO;

static NSString *profileName(void) {
    return ZeroBeganProfile ? @"zero-began" : @"upstream";
}

static void fail(NSString *message) {
    fprintf(stderr, "%s\n", message.UTF8String);
    exit(2);
}

static void emit(NSString *event, NSDictionary *details) {
    NSMutableDictionary *record = [details mutableCopy];
    record[@"event"] = event;
    record[@"hostUnixSeconds"] = @([[NSDate date] timeIntervalSince1970]);
    NSData *data = [NSJSONSerialization dataWithJSONObject:record options:NSJSONWritingSortedKeys error:NULL];
    if (data) {
        fwrite(data.bytes, 1, data.length, stdout);
        fputc('\n', stdout);
        fflush(stdout);
    }
    [record release];
}

static void requireSelector(id object, SEL selector) {
    if (![object respondsToSelector:selector]) {
        fail([NSString stringWithFormat:@"Required selector unavailable: %@", NSStringFromSelector(selector)]);
    }
}

static NSString *developerDirectory(void) {
    NSString *configured = NSProcessInfo.processInfo.environment[@"DEVELOPER_DIR"];
    if (configured.length) return configured.stringByStandardizingPath;
    NSTask *task = [[[NSTask alloc] init] autorelease];
    NSPipe *output = [NSPipe pipe];
    task.executableURL = [NSURL fileURLWithPath:@"/usr/bin/xcode-select"];
    task.arguments = @[@"-p"];
    task.standardOutput = output;
    task.standardError = [NSFileHandle fileHandleWithNullDevice];
    NSError *error = nil;
    if (![task launchAndReturnError:&error]) fail([NSString stringWithFormat:@"xcode-select failed: %@", error]);
    NSData *data = [output.fileHandleForReading readDataToEndOfFile];
    [task waitUntilExit];
    NSString *directory = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
    directory = [directory stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (task.terminationStatus != 0 || !directory.isAbsolutePath) fail(@"No selected developer directory");
    return directory;
}

static id bootedWatch(NSUUID *uuid, NSString *developerDir) {
    NSArray *paths = @[
        [developerDir stringByAppendingPathComponent:@"Library/PrivateFrameworks/CoreSimulator.framework/Versions/A/CoreSimulator"],
        @"/Library/Developer/PrivateFrameworks/CoreSimulator.framework/Versions/A/CoreSimulator"
    ];
    void *framework = NULL;
    for (NSString *path in paths) {
        if ([NSFileManager.defaultManager fileExistsAtPath:path]) {
            framework = dlopen(path.fileSystemRepresentation, RTLD_NOW | RTLD_LOCAL);
            if (framework) break;
        }
    }
    if (!framework) fail(@"Cannot load CoreSimulator from the selected Xcode or standard framework path");
    Class cls = NSClassFromString(@"SimServiceContext");
    requireSelector(cls, @selector(sharedServiceContextForDeveloperDir:error:));
    NSError *error = nil;
    id context = [cls sharedServiceContextForDeveloperDir:developerDir error:&error];
    if (!context) fail([NSString stringWithFormat:@"CoreSimulator context failed: %@", error]);
    requireSelector(context, @selector(defaultDeviceSetWithError:));
    id deviceSet = [context defaultDeviceSetWithError:&error];
    if (!deviceSet) fail([NSString stringWithFormat:@"Default simulator set failed: %@", error]);
    requireSelector(deviceSet, @selector(availableDevices));
    id selected = nil;
    for (id device in [deviceSet availableDevices]) {
        requireSelector(device, @selector(UDID));
        if ([[device UDID] isEqual:uuid]) {
            if (selected) fail(@"Ambiguous simulator UUID");
            selected = device;
        }
    }
    if (!selected) fail(@"Explicit UUID is not an available simulator in the default device set");
    requireSelector(selected, @selector(state));
    requireSelector(selected, @selector(stateString));
    requireSelector(selected, @selector(deviceTypeIdentifier));
    requireSelector(selected, @selector(deviceType));
    id type = [selected deviceType];
    requireSelector(type, @selector(productFamilyID));
    if ([selected state] != 3 || ![[selected stateString] isEqualToString:@"Booted"])
        fail(@"Selected simulator is not Booted; this tool never boots a device");
    if ([type productFamilyID] != 4 || ![[selected deviceTypeIdentifier] hasPrefix:@"com.apple.CoreSimulator.SimDeviceType.Apple-Watch"])
        fail(@"Selected simulator is not an Apple Watch");
    requireSelector(selected, @selector(lookup:error:));
    return selected;
}

static xpc_object_t envelope(const char *messageType, xpc_object_t payload, bool barrier) {
    xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_string(message, "messageType", messageType);
    xpc_dictionary_set_bool(message, "isBarrier", barrier);
    xpc_dictionary_set_string(message, "featureIdentifier", Service);
    xpc_dictionary_set_value(message, "payload", payload);
    return message;
}

static xpc_object_t scrollMessage(double delta, uint64_t phase) {
    xpc_object_t point = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_double(point, "x", 0);
    xpc_dictionary_set_double(point, "y", delta);
    xpc_dictionary_set_double(point, "z", 0);
    xpc_object_t payload = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_value(payload, "point", point);
    xpc_dictionary_set_uint64(payload, "phase", phase);
    xpc_dictionary_set_uint64(payload, "momentum", 0);
    xpc_dictionary_set_uint64(payload, "target", 0);
    xpc_object_t message = envelope("IndigoScrollEvent", payload, false);
    xpc_release(point);
    xpc_release(payload);
    return message;
}

static xpc_object_t barrierMessage(void) {
    xpc_object_t payload = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_uint64(payload, "usageCode", 0); // no event indicated
    xpc_dictionary_set_uint64(payload, "state", 2);     // HIDButtonState.up
    xpc_object_t message = envelope("IndigoKeyboardButtonEvent", payload, true);
    xpc_release(payload);
    return message;
}

static void selfTest(void) {
    for (uint64_t phase = 1; phase <= 2; phase++) {
      for (int sign = -1; sign <= 1; sign += 2) {
        xpc_object_t message = scrollMessage(sign * 5.0, phase);
        xpc_object_t payload = xpc_dictionary_get_value(message, "payload");
        xpc_object_t point = xpc_dictionary_get_value(payload, "point");
        if (strcmp(xpc_dictionary_get_string(message, "messageType"), "IndigoScrollEvent") ||
            xpc_get_type(xpc_dictionary_get_value(payload, "phase")) != XPC_TYPE_UINT64 ||
            xpc_get_type(xpc_dictionary_get_value(point, "y")) != XPC_TYPE_DOUBLE ||
            xpc_dictionary_get_double(point, "y") != sign * 5.0 ||
            xpc_dictionary_get_uint64(payload, "phase") != phase ||
            xpc_dictionary_get_uint64(payload, "target") != 0 ||
            xpc_dictionary_get_bool(message, "isBarrier")) fail(@"Self-test failed");
        xpc_release(message);
      }
    }
    const uint64_t zeroPhases[] = {1, 4};
    for (NSUInteger i = 0; i < sizeof(zeroPhases) / sizeof(zeroPhases[0]); i++) {
        xpc_object_t message = scrollMessage(0, zeroPhases[i]);
        xpc_object_t payload = xpc_dictionary_get_value(message, "payload");
        xpc_object_t point = xpc_dictionary_get_value(payload, "point");
        if (xpc_dictionary_get_uint64(payload, "phase") != zeroPhases[i] ||
            xpc_dictionary_get_double(point, "y") != 0 ||
            xpc_get_type(xpc_dictionary_get_value(payload, "phase")) != XPC_TYPE_UINT64 ||
            xpc_get_type(xpc_dictionary_get_value(point, "y")) != XPC_TYPE_DOUBLE)
            fail(@"Zero-boundary self-test failed");
        xpc_release(message);
    }
    xpc_object_t message = barrierMessage();
    xpc_object_t payload = xpc_dictionary_get_value(message, "payload");
    if (!xpc_dictionary_get_bool(message, "isBarrier") ||
        xpc_dictionary_get_uint64(payload, "usageCode") != 0 ||
        xpc_dictionary_get_uint64(payload, "state") != 2) fail(@"Barrier self-test failed");
    xpc_release(message);
    emit(@"self_test_passed", @{@"requestedProfile": profileName(), @"testedProfiles": @[@"upstream", @"zero-began"], @"CoreSimulatorLoaded": @NO, @"connections": @0, @"eventsSent": @0});
}

typedef xpc_object_t (*EndpointFromPort)(mach_port_t, uint64_t, uint64_t);
typedef xpc_connection_t (*ConnectionFromEndpoint)(xpc_object_t);
typedef void (*EnableSim2Host)(xpc_connection_t);
typedef struct { atomic_bool failed; atomic_bool replied; atomic_bool replyGood; } PeerState;

static void waitBarrier(xpc_connection_t connection, PeerState *peer) {
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    xpc_connection_send_barrier(connection, ^{ dispatch_semaphore_signal(done); });
    if (dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 4 * NSEC_PER_SEC)) != 0)
        fail(@"XPC send barrier timed out; delivery unverified");
    // A timeout exits the process, keeping the block's semaphore valid until exit.
    dispatch_release(done);
    if (atomic_load(&peer->failed)) fail(@"XPC connection failed; delivery may be partial");
}

static void sendRotation(id device, NSUUID *uuid, double delta) {
    EndpointFromPort endpointFromPort = (EndpointFromPort)dlsym(RTLD_DEFAULT, "xpc_endpoint_create_mach_port_4sim");
    ConnectionFromEndpoint fromEndpoint = (ConnectionFromEndpoint)dlsym(RTLD_DEFAULT, "xpc_connection_create_from_endpoint");
    EnableSim2Host enable = (EnableSim2Host)dlsym(RTLD_DEFAULT, "xpc_connection_enable_sim2host_4sim");
    if (!endpointFromPort || !fromEndpoint || !enable) fail(@"Required _4sim XPC symbols unavailable");
    // Recheck immediately before the sole HID lookup. No automatic device transition.
    if ([device state] != 3) fail(@"Simulator stopped being Booted before HID lookup");
    NSError *error = nil;
    mach_port_t port = [device lookup:[NSString stringWithUTF8String:Service] error:&error];
    if (port == MACH_PORT_NULL) fail([NSString stringWithFormat:@"Scroll service lookup failed: %@", error]);
    // Endpoint creation consumes lookup's send right, matching current idb.
    xpc_object_t endpoint = endpointFromPort(port, 0, 0);
    if (!endpoint) fail(@"Cannot make simulator XPC endpoint");
    xpc_connection_t connection = fromEndpoint(endpoint);
    xpc_release(endpoint);
    if (!connection) fail(@"Cannot make simulator XPC connection");
    enable(connection); // Without this the peer can connect but never receive payloads.
    dispatch_queue_t queue = dispatch_queue_create("net.qays.crown-hid-bridge.peer", DISPATCH_QUEUE_SERIAL);
    PeerState *peer = calloc(1, sizeof(PeerState));
    if (!peer) fail(@"Cannot allocate peer state");
    atomic_init(&peer->failed, false);
    atomic_init(&peer->replied, false);
    atomic_init(&peer->replyGood, false);
    xpc_connection_set_target_queue(connection, queue);
    xpc_connection_set_event_handler(connection, ^(xpc_object_t event) {
        if (xpc_get_type(event) == XPC_TYPE_ERROR) {
            atomic_store(&peer->failed, true);
            const char *description = xpc_dictionary_get_string(event, XPC_ERROR_KEY_DESCRIPTION);
            fprintf(stderr, "XPC peer error: %s\n", description ?: "unknown");
        }
    });
    xpc_connection_resume(connection);
    dispatch_semaphore_t reply = dispatch_semaphore_create(0);
    xpc_object_t barrier = barrierMessage();
    xpc_connection_send_message_with_reply(connection, barrier, queue, ^(xpc_object_t response) {
        atomic_store(&peer->replyGood, xpc_get_type(response) != XPC_TYPE_ERROR);
        atomic_store(&peer->replied, true);
        dispatch_semaphore_signal(reply);
    });
    xpc_release(barrier);
    if (dispatch_semaphore_wait(reply, dispatch_time(DISPATCH_TIME_NOW, 4 * NSEC_PER_SEC)) != 0 ||
        !atomic_load(&peer->replied) || !atomic_load(&peer->replyGood) || atomic_load(&peer->failed)) {
        xpc_connection_cancel(connection);
        fail(@"Scroll service did not answer a healthy liveness barrier; no Crown samples sent");
    }
    dispatch_release(reply);
    usleep(WarmTailUS);
    if (atomic_load(&peer->failed) || [device state] != 3) fail(@"Peer interrupted before Crown gesture; no samples sent");
    NSUInteger count = MAX(1, (NSUInteger)ceil(fabs(delta) / 5.0));
    double perStep = delta / (double)count;
    useconds_t stepDelay = (useconds_t)llround(CrownDuration * 1000000.0 / (double)(count + 1));
    emit(@"gesture_begin", @{@"profile": profileName(), @"simulatorUUID": uuid.UUIDString, @"signedDelta": @(delta), @"samples": @(count), @"sampleDelta": @(perStep)});
    if (ZeroBeganProfile) {
        xpc_object_t begin = scrollMessage(0, 1);
        xpc_connection_send_message(connection, begin);
        xpc_release(begin);
        waitBarrier(connection, peer);
        emit(@"began_sent", @{@"phase": @1, @"delta": @0, @"beginGapSeconds": @0.05});
        usleep(BeginGapUS);
    }
    for (NSUInteger i = 0; i < count; i++) {
        if (atomic_load(&peer->failed) || [device state] != 3) fail(@"Peer/device changed mid-gesture; delivery may be partial");
        uint64_t phase = ZeroBeganProfile || i > 0 ? 2 : 1;
        xpc_object_t sample = scrollMessage(perStep, phase);
        xpc_connection_send_message(connection, sample);
        xpc_release(sample);
        waitBarrier(connection, peer);
        emit(@"sample_sent", @{@"index": @(i), @"phase": @(phase), @"delta": @(perStep)});
        usleep(stepDelay);
    }
    xpc_object_t end = scrollMessage(0, 4);
    xpc_connection_send_message(connection, end);
    xpc_release(end);
    waitBarrier(connection, peer);
    emit(@"ended_sent", @{@"phase": @4, @"delta": @0, @"drainSeconds": @1});
    // Barrier proves host transmission, not guest consumption. Hold the connection
    // for a full second (upstream warm drain is 80ms); app logs confirm receipt.
    usleep(DrainUS);
    if (atomic_load(&peer->failed)) fail(@"Peer interrupted during drain; guest consumption unverified");
    xpc_connection_cancel(connection);
    emit(@"gesture_finished", @{@"simulatorUUID": uuid.UUIDString, @"signedDelta": @(delta), @"guestConsumption": @"verify app logs"});
    // The process owns this sole short-lived connection. Keep queue/state valid
    // through cancellation callbacks until process exit rather than racing teardown.
    xpc_release(connection);
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        umask(0077);
        if (argc > 1 && strcmp(argv[1], "--profile") == 0) {
            if (argc < 4 || (strcmp(argv[2], "upstream") != 0 && strcmp(argv[2], "zero-began") != 0))
                fail(@"--profile requires upstream or zero-began followed by an operation");
            ZeroBeganProfile = strcmp(argv[2], "zero-began") == 0;
            argc -= 2;
            argv += 2;
        }
        if (argc == 2 && strcmp(argv[1], "--self-test") == 0) { selfTest(); return 0; }
        if (argc != 4 || (strcmp(argv[1], "--dry-run") != 0 && strcmp(argv[1], "--send") != 0)) {
            fprintf(stderr, "Usage: CrownHIDBridge [--profile upstream|zero-began] --self-test\n       CrownHIDBridge [--profile upstream|zero-began] --dry-run|--send EXPLICIT-WATCH-UUID SIGNED-DELTA\nDefault profile: upstream. Delta must be finite, nonzero, and within +/-100 guest scroll units.\n");
            return 2;
        }
        NSString *uuidText = [NSString stringWithUTF8String:argv[2]];
        NSUUID *uuid = [[[NSUUID alloc] initWithUUIDString:uuidText] autorelease];
        if (!uuid || ![uuid.UUIDString isEqualToString:uuidText.uppercaseString]) fail(@"Expected a canonical explicit UUID; aliases such as booted are forbidden");
        char *tail = NULL;
        errno = 0;
        double delta = strtod(argv[3], &tail);
        if (errno || tail == argv[3] || *tail != '\0' || !isfinite(delta) || delta == 0 || fabs(delta) > MaximumDelta)
            fail(@"Delta must be a finite nonzero number within +/-100");
        NSString *developerDir = developerDirectory();
        id device = bootedWatch(uuid, developerDir);
        BOOL sending = strcmp(argv[1], "--send") == 0;
        emit(@"target_validated", @{@"simulatorUUID": uuid.UUIDString, @"deviceType": [device deviceTypeIdentifier], @"state": [device stateString], @"developerDirectory": developerDir, @"signedDelta": @(delta), @"sendRequested": @(sending)});
        if (!sending) {
            emit(@"dry_run_complete", @{@"HIDLookups": @0, @"connections": @0, @"eventsSent": @0});
            return 0;
        }
        sendRotation(device, uuid, delta);
    }
    return 0;
}

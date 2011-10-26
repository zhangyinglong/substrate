/* Cydia Substrate - Powerful Code Insertion Platform
 * Copyright (C) 2008-2011  Jay Freeman (saurik)
*/

/* GNU Lesser General Public License, Version 3 {{{ */
/*
 * Substrate is free software: you can redistribute it and/or modify it under
 * the terms of the GNU Lesser General Public License as published by the
 * Free Software Foundation, either version 3 of the License, or (at your
 * option) any later version.
 *
 * Substrate is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
 * License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with Substrate.  If not, see <http://www.gnu.org/licenses/>.
**/
/* }}} */

#include <CoreFoundation/CFPropertyList.h>
#import <Foundation/Foundation.h>
#include <string.h>
#include <stdint.h>

#include "Cydia.hpp"
#include "Environment.hpp"
#include "LaunchDaemons.hpp"

// XXX: NO means "failed", false means "unneeded"

static bool HookEnvironment(const char *name) {
    NSString *file([NSString stringWithFormat:@"%@/%s.plist", @ SubstrateLaunchDaemons_, name]);

    NSMutableDictionary *root([NSMutableDictionary dictionaryWithContentsOfFile:file]);
    if (root == nil)
        return NO;

    NSMutableDictionary *environment([root objectForKey:@"EnvironmentVariables"]);
    if (environment == nil) {
        environment = [NSMutableDictionary dictionaryWithCapacity:1];
        [root setObject:environment forKey:@"EnvironmentVariables"];
    }

    NSString *variable([environment objectForKey:@ SubstrateVariable_]);
    if (variable == nil || [variable length] == 0)
        [environment setObject:@ SubstrateLibrary_ forKey:@ SubstrateVariable_];
    else {
        NSArray *dylibs([variable componentsSeparatedByString:@":"]);

        NSUInteger index([dylibs indexOfObject:@ SubstrateLibrary_]);
        if (index != NSNotFound)
            return false;

        [environment setObject:[NSString stringWithFormat:@"%@:%@", variable, @ SubstrateLibrary_] forKey:@ SubstrateVariable_];
    }

    NSString *error;
    NSData *data([NSPropertyListSerialization dataFromPropertyList:root format:NSPropertyListBinaryFormat_v1_0 errorDescription:&error]);
    if (data == nil)
        return NO;

    if (![data writeToFile:file atomically:YES])
        return NO;

    return true;
}

static void InstallTether() {
    HookEnvironment("com.apple.mediaserverd");
    HookEnvironment("com.apple.itunesstored");
    HookEnvironment("com.apple.CommCenter");
    HookEnvironment("com.apple.AOSNotification");

    HookEnvironment("com.apple.BTServer");
    HookEnvironment("com.apple.iapd");

    HookEnvironment("com.apple.lsd");
    HookEnvironment("com.apple.imagent");

    HookEnvironment("com.apple.mobile.lockdown");
    HookEnvironment("com.apple.itdbprep.server");

    HookEnvironment("com.apple.locationd");

    HookEnvironment("com.apple.mediaremoted");
    HookEnvironment("com.apple.frontrow");

    HookEnvironment("com.apple.voiced");
    HookEnvironment("com.apple.MobileInternetSharing");

    HookEnvironment("com.apple.CommCenterClassic");
    HookEnvironment("com.apple.gamed");

    HookEnvironment("com.apple.mobile.softwareupdated");
    HookEnvironment("com.apple.softwareupdateservicesd");
    HookEnvironment("com.apple.twitterd");
    HookEnvironment("com.apple.mediaremoted");

    HookEnvironment("com.apple.assistivetouchd");
    HookEnvironment("com.apple.accountsd");

    HookEnvironment("com.apple.SpringBoard");

    FinishCydia("reboot");
}

static void InstallSemiTether() {
    MSClearLaunchDaemons();

    #define SubstrateLauncher_ "/Library/Frameworks/CydiaSubstrate.framework/Libraries/SubstrateLauncher.dylib"

    NSFileManager *manager([NSFileManager defaultManager]);
    NSError *error;

    NSString *temp([NSString stringWithFormat:@"/tmp/ms-%f.dylib", [[NSDate date] timeIntervalSinceReferenceDate]]);

    if (![manager copyItemAtPath:@ SubstrateLauncher_ toPath:temp error:&error]) {
        fprintf(stderr, "unable to copy: %s\n", [[error description] UTF8String]);
        temp = @ SubstrateLauncher_;
    }

    system([[@"/usr/bin/cynject 1 " stringByAppendingString:temp] UTF8String]);

    if (![manager removeItemAtPath:temp error:&error])
        if (unlink([temp UTF8String]) == -1)
            fprintf(stderr, "unable to remove: (%s):%d\n", [[error description] UTF8String], errno);

    FILE *file(fopen("/etc/launchd.conf", "w+"));
    fprintf(file, "bsexec .. /usr/bin/cynject 1 " SubstrateLauncher_ "\n");
    fclose(file);
}

int main(int argc, char *argv[]) {
    if (argc < 2 || (
        strcmp(argv[1], "install") != 0 &&
        strcmp(argv[1], "upgrade") != 0 &&
    true)) return 0;

    NSAutoreleasePool *pool([[NSAutoreleasePool alloc] init]);

    switch (DetectForkBug()) {
        case ForkBugUnknown:
            return 1;

        case ForkBugPresent:
            InstallTether();
            break;

        case ForkBugMissing:
            InstallSemiTether();
            break;
    }

    [pool release];
    return 0;
}

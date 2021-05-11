/*
===========================================================================

Doom 3 GPL Source Code
Copyright (C) 1999-2011 id Software LLC, a ZeniMax Media company.

This file is part of the Doom 3 GPL Source Code ("Doom 3 Source Code").

Doom 3 Source Code is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Doom 3 Source Code is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with Doom 3 Source Code.  If not, see <http://www.gnu.org/licenses/>.

In addition, the Doom 3 Source Code is also subject to certain additional terms. You should have received a copy of these additional terms immediately following the terms and conditions of the GNU General Public License which accompanied the Doom 3 Source Code.  If not, please request a copy in writing from id Software at the address below.

If you have questions concerning this license or the applicable additional terms, you may contact in writing id Software LLC, c/o ZeniMax Media Inc., Suite 120, Rockville, Maryland 20850 USA.

===========================================================================
*/

#include <sys/param.h>
#include <sys/ucontext.h>
#include <unistd.h>
#include <fenv.h>
#include <mach/thread_status.h>
#include <AppKit/AppKit.h>

#include <SDL_main.h>

#include "sys/platform.h"
#include "idlib/Str.h"
#include "framework/Common.h"

#include "sys/posix/posix_public.h"

bool Sys_GetPath(sysPath_t type, idStr &path) {
	char buf[MAXPATHLEN];
	char *snap;

	switch(type) {
	case PATH_BASE:
		strncpy(buf, [ [ [ NSBundle mainBundle ] bundlePath ] cString ], MAXPATHLEN );
		snap = strrchr(buf, '/');
		if (snap)
			*snap = '\0';

		path = buf;
		return true;

	case PATH_CONFIG:
	case PATH_SAVE:
		sprintf(buf, "%s/Library/Application Support/Steel Storm 2", [NSHomeDirectory() cString]);
		path = buf;
		return true;

	case PATH_EXE:
		strncpy(buf, [ [ [ NSBundle mainBundle ] bundlePath ] cString ], MAXPATHLEN);
		path = buf;
		return true;
	}

	return false;
}

/*
===============
Sys_Shutdown
===============
*/
void Sys_Shutdown( void ) {
	Posix_Shutdown();
}

/*
================
Sys_GetSystemRam
returns in megabytes
================
*/
int Sys_GetSystemRam( void ) {
	SInt32 ramSize;

	if ( Gestalt( gestaltPhysicalRAMSize, &ramSize ) == noErr ) {
		return ramSize / (1024*1024);
	}
	else
		return 1024;
}

bool OSX_GetCPUIdentification( int& cpuId, bool& oldArchitecture )
{
	SInt32 cpu;
	Gestalt(gestaltNativeCPUtype, &cpu);

	cpuId = cpu;
	oldArchitecture = cpuId < gestaltCPU970;
	return true;
}

void OSX_GetVideoCard( int& outVendorId, int& outDeviceId )
{
	kern_return_t err;
	mach_port_t masterPort;
	io_iterator_t itThis;
	io_service_t service;

	outVendorId = -1;
	outDeviceId = -1;

	// Get a mach port for us and check for errors
	err = IOMasterPort(MACH_PORT_NULL, &masterPort);
	if(err)
		return;
	// Grab all the PCI devices out of the registry
	err = IOServiceGetMatchingServices(masterPort, IOServiceMatching("IOPCIDevice"), &itThis);
	if(err)
		return;

	// Yank everything out of the iterator
	// We could walk through all devices and try to determine the best card. But for now,
	// we'll just look at the first card.
	while(1)
	{
		service = IOIteratorNext(itThis);
		io_name_t dName;

		// Make sure we have a valid service
		if(service)
		{
			// Get the classcode so we know what we're looking at
			CFDataRef classCode =  (CFDataRef)IORegistryEntryCreateCFProperty(service,CFSTR("class-code"),kCFAllocatorDefault,0);
			// Only accept devices that are
			// PCI Spec - 0x00030000 is a display device
			if((*(UInt32*)CFDataGetBytePtr(classCode) & 0x00ff0000) == 0x00030000)
			{
				// Get the name of the service (hw)
				IORegistryEntryGetName(service, dName);

			    CFDataRef vendorID, deviceID;

				// Get the information for the device we've selected from the list
			    vendorID = (CFDataRef)IORegistryEntryCreateCFProperty(service, CFSTR("vendor-id"),kCFAllocatorDefault,0);
			    deviceID = (CFDataRef)IORegistryEntryCreateCFProperty(service, CFSTR("device-id"),kCFAllocatorDefault,0);

			    outVendorId = *((long*)CFDataGetBytePtr(vendorID));
			    outDeviceId = *((long*)CFDataGetBytePtr(deviceID));

				CFRelease(vendorID);
				CFRelease(deviceID);
			}
			CFRelease(classCode);

			// Stop after finding the first device
			if (outVendorId != -1)
				break;
		}
		else
			break;
	}
}

/*
===============
main
===============
*/
int main( int argc, char *argv[] ) {
	NSAutoreleasePool *pool;

	pool = [[NSAutoreleasePool alloc] init];

	if (![[NSFileManager defaultManager] changeCurrentDirectoryPath:[[NSBundle mainBundle] resourcePath]])
		Sys_Error("Could not access application resources");

	if (argc > 1)
		common->Init(argc - 1, &argv[1]);
	else
		common->Init(0, NULL);

	[NSApp activateIgnoringOtherApps:YES];

	while (1) {
		common->Frame();

		// We should think about doing this less frequently than every frame
		[pool release];
		pool = [[NSAutoreleasePool alloc] init];
	}

	[pool release];
}

// TEMPORARY SPIKE CODE. Do not merge.

#ifndef STARBOARD_TVOS_SHARED_MEDIA_PIP_SPIKE_LOG_H_
#define STARBOARD_TVOS_SHARED_MEDIA_PIP_SPIKE_LOG_H_

#import <Foundation/Foundation.h>

#include <fcntl.h>
#include <unistd.h>

static inline void PipSpikeLog(NSString* text) {
  static int file = -1;
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    NSString* directory = NSSearchPathForDirectoriesInDomains(
                              NSCachesDirectory, NSUserDomainMask, YES)
                              .firstObject;
    NSString* path =
        [directory stringByAppendingPathComponent:@"pip_spike.log"];
    file = open(path.fileSystemRepresentation, O_WRONLY | O_APPEND | O_CREAT,
                0644);
  });
  NSDateFormatter* formatter = [[NSDateFormatter alloc] init];
  formatter.dateFormat = @"HH:mm:ss.SSS";
  NSString* line =
      [NSString stringWithFormat:@"%@ %@\n",
                                 [formatter stringFromDate:NSDate.date], text];
  NSData* data = [line dataUsingEncoding:NSUTF8StringEncoding];
  write(file, data.bytes, data.length);
}

#endif  // STARBOARD_TVOS_SHARED_MEDIA_PIP_SPIKE_LOG_H_

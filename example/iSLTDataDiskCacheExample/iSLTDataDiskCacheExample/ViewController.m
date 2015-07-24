#import "ViewController.h"

#import "SLTDataDiskCache.h"


@interface ViewController ()
@property (nonatomic, strong) SLTDataDiskCache *cache;
@end


@implementation ViewController

- (void)viewDidLoad
{
	[super viewDidLoad];

	NSString *cachePath = [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject] copy];
	cachePath = [cachePath stringByAppendingPathComponent:@"mycache"];

	self.cache = [[SLTDataDiskCache alloc] initWithPath:cachePath
										   maxSizeBytes:20L * 1024L * 1024L
								 maxSizeAfterCleanBytes:12L * 1024L * 1024L
										minBytesToClean:6L * 1024L * 1024L];

	NSData *data = [self.cache dataForKey:@"1"];
	if (data)
	{
		NSLog(@"data is got from cache");
	}
	else
	{
		NSLog(@"no data in cache");
		NSLog(@"put data to cache");
		NSString *s = @"123";
		[self.cache setData:[s dataUsingEncoding:NSUTF8StringEncoding] forKey:@"1"];
	}
}

@end

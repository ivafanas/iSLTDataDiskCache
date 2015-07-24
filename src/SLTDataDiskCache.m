#import "SLTDataDiskCache.h"


@interface SLTDataDiskCache()
@property (nonatomic, assign, readonly) unsigned long long maxSizeBytes;
@property (nonatomic, assign, readonly) unsigned long long maxSizeAfterCleanBytes;
@property (nonatomic, assign, readonly) unsigned long long minBytesToClean;
@property (nonatomic, assign) unsigned long long totalSizeBytes;
@property (nonatomic, copy, readonly) NSString *cachesPath;
@end

@implementation SLTDataDiskCache

- (instancetype)initWithPath:(NSString *)path
				maxSizeBytes:(unsigned long long)maxSizeBytes
{
	self = [self initWithPath:path
				 maxSizeBytes:maxSizeBytes
	   maxSizeAfterCleanBytes:maxSizeBytes * 3 / 5
			  minBytesToClean:maxSizeBytes * 2 / 5];
	return self;
}

- (instancetype)initWithPath:(NSString *)path
				maxSizeBytes:(unsigned long long)maxSizeBytes
	  maxSizeAfterCleanBytes:(unsigned long long)maxSizeAfterCleanBytes
			 minBytesToClean:(unsigned long long)minBytesToClean
{
	self = [super init];
	if (!self) return nil;

	maxSizeBytes = MAX(maxSizeBytes, 100);
	maxSizeAfterCleanBytes = MAX(maxSizeAfterCleanBytes, 1);
	maxSizeAfterCleanBytes = MIN(maxSizeAfterCleanBytes, maxSizeBytes);
	minBytesToClean = MAX(minBytesToClean, 10);
	minBytesToClean = MIN(minBytesToClean, maxSizeBytes);

	_maxSizeBytes = maxSizeBytes;
	_maxSizeAfterCleanBytes = maxSizeAfterCleanBytes;
	_minBytesToClean = minBytesToClean;

	if (path)
	{
		BOOL exists = [self ensureDirectoryExists:path];
		if (exists)
		{
			_cachesPath = [path copy];
			_totalSizeBytes = [self sizeOfDir:_cachesPath];
		}
		else
		{
			NSLog(@"SLTImagesDiskCacheError: can not create directory: %@", path);
		}
	}
	else
	{
		NSLog(@"SLTImagesDiskCacheError: path can not be nil");
	}

	return self;
}

- (NSData *)dataForKey:(NSString *)key
{
	if (!key.length)
		return nil;
	if (!self.cachesPath.length)
		return nil;

	@synchronized(self)
	{
		NSString *filename = [self filenameForKey:key];
		NSString *filepath = [self.cachesPath stringByAppendingPathComponent:filename];
		[self setFileRecentlyUsed:filepath];
		return [self contentOfFile:filepath];
	}
}

- (void)setData:(NSData *)data forKey:(NSString *)key
{
	if (!key.length)
		return;
	if (!self.cachesPath.length)
		return;

	@synchronized(self)
	{
		NSString *filename = [self filenameForKey:key];
		NSString *filepath = [self.cachesPath stringByAppendingPathComponent:filename];
		if (data)
		{
			[data writeToFile:filepath atomically:YES];
			self.totalSizeBytes += data.length;
			[self setFileRecentlyUsed:filepath];
			[self checkToCleanCache];
		}
		else
		{
			self.totalSizeBytes -= [self sizeOfFile:filepath];
			[[NSFileManager defaultManager] removeItemAtPath:filepath error:nil];
		}
	}
}

// MARK: Private

- (void)setFileRecentlyUsed:(NSString *)filepath
{
	NSDate *now = [NSDate date];
	[self setLastModificationData:now forFile:filepath];
}

- (void)checkToCleanCache
{
	if (self.totalSizeBytes > self.maxSizeBytes)
	{
		const unsigned long long overheadBytes = self.totalSizeBytes > self.maxSizeAfterCleanBytes ? self.totalSizeBytes - self.maxSizeAfterCleanBytes : 0;
		const unsigned long long bytesToClean = MAX(overheadBytes, self.minBytesToClean);

		NSFileManager *fileManager = [NSFileManager defaultManager];

		NSArray *filesSubpaths = [fileManager subpathsOfDirectoryAtPath:self.cachesPath error:nil];

		// form full paths
		NSMutableArray *filesPaths = [NSMutableArray arrayWithCapacity:filesSubpaths.count];
		for (NSString *fileSubpath in filesSubpaths)
		{
			[filesPaths addObject:[self.cachesPath stringByAppendingPathComponent:fileSubpath]];
		}

		// form modified dates
		NSMutableDictionary *pathToModifiedDate = [NSMutableDictionary dictionaryWithCapacity:filesSubpaths.count];
		for (NSString *filepath in filesPaths)
		{
			pathToModifiedDate[filepath] = [self lastModificationDateOfFile:filepath];
		}

		// sort by modification date
		[filesPaths sortUsingComparator:^NSComparisonResult(NSString *lpath, NSString *rpath) {
			NSDate *ldate = pathToModifiedDate[lpath];
			NSDate *rdate = pathToModifiedDate[rpath];
			return [ldate compare:rdate];
		}];

		unsigned long long bytesFreed = 0;

		for (NSString *filepath in filesPaths)
		{
			if (bytesFreed >= bytesToClean)
				break;

			const unsigned long long fileSize = [self sizeOfFile:filepath];

			BOOL removed = [fileManager removeItemAtPath:filepath error:nil];
			if (removed)
			{
				self.totalSizeBytes -= fileSize;
				bytesFreed += fileSize;
			}
		}
	}
}

- (unsigned long long)sizeOfFile:(NSString *)filepath
{
	return [[[NSFileManager defaultManager] attributesOfItemAtPath:filepath error:nil] fileSize];
}

- (NSDate *)lastModificationDateOfFile:(NSString *)filepath
{
	return [[[NSFileManager defaultManager] attributesOfItemAtPath:filepath error:nil] fileModificationDate] ?: [NSDate dateWithTimeIntervalSince1970:0];
}

- (void)setLastModificationData:(NSDate *)date forFile:(NSString *)filepath
{
	NSDictionary* attr =@{NSFileModificationDate: date};
	[[NSFileManager defaultManager] setAttributes:attr ofItemAtPath:filepath error:nil];
}

- (unsigned long long)sizeOfDir:(NSString *)path
{
	unsigned long long rv = 0;
	NSArray *subpathes = [[NSFileManager defaultManager] subpathsOfDirectoryAtPath:path error:nil];
	for (NSString *subpath in subpathes)
	{
		NSString *filepath = [path stringByAppendingPathComponent:subpath];
		rv += [self sizeOfFile:filepath];
	}
	return rv;
}

- (NSData *)contentOfFile:(NSString *)filepath
{
	if ([[NSFileManager defaultManager] fileExistsAtPath:filepath])
	{
		return [NSData dataWithContentsOfFile:filepath];
	}
	return nil;
}

- (BOOL)ensureDirectoryExists:(NSString *)path
{
	NSFileManager *fileManager = [NSFileManager defaultManager];
	BOOL isDir = NO;
	BOOL exists = [fileManager fileExistsAtPath:path isDirectory:&isDir];
	if (!exists)
	{
		return [fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:0];
	}
	else
	{
		return isDir;
	}
}

- (NSString *)filenameForKey:(NSString *)key
{
	// Ok, it is not super fast.
	// If you has this code as hotspot and want to speedup, just make pull-request
	NSMutableString *rv = [NSMutableString stringWithString:key];
	[rv replaceOccurrencesOfString:@"[" withString:@"_" options:0 range:NSMakeRange(0, rv.length)];
	[rv replaceOccurrencesOfString:@"]" withString:@"_" options:0 range:NSMakeRange(0, rv.length)];
	[rv replaceOccurrencesOfString:@"/" withString:@"_" options:0 range:NSMakeRange(0, rv.length)];
	[rv replaceOccurrencesOfString:@":" withString:@"_" options:0 range:NSMakeRange(0, rv.length)];
	[rv replaceOccurrencesOfString:@" " withString:@"_" options:0 range:NSMakeRange(0, rv.length)];
	[rv replaceOccurrencesOfString:@"%" withString:@"_" options:0 range:NSMakeRange(0, rv.length)];
	[rv replaceOccurrencesOfString:@"," withString:@"_" options:0 range:NSMakeRange(0, rv.length)];
	[rv replaceOccurrencesOfString:@"." withString:@"_" options:0 range:NSMakeRange(0, rv.length)];
	[rv replaceOccurrencesOfString:@"?" withString:@"_" options:0 range:NSMakeRange(0, rv.length)];
	[rv replaceOccurrencesOfString:@"!" withString:@"_" options:0 range:NSMakeRange(0, rv.length)];
	[rv replaceOccurrencesOfString:@"@" withString:@"_" options:0 range:NSMakeRange(0, rv.length)];
	[rv replaceOccurrencesOfString:@"$" withString:@"_" options:0 range:NSMakeRange(0, rv.length)];
	[rv replaceOccurrencesOfString:@"^" withString:@"_" options:0 range:NSMakeRange(0, rv.length)];
	[rv replaceOccurrencesOfString:@"&" withString:@"_" options:0 range:NSMakeRange(0, rv.length)];
	[rv replaceOccurrencesOfString:@"(" withString:@"_" options:0 range:NSMakeRange(0, rv.length)];
	[rv replaceOccurrencesOfString:@")" withString:@"_" options:0 range:NSMakeRange(0, rv.length)];
	return [rv copy];
}

@end

#import <Foundation/Foundation.h>


@interface SLTDataDiskCache : NSObject

/*!
 * DI
 * @param path path to directory to store cached objects. Content of this directory is managed by SLTImagesDiskCache.
 * @param maxSizeBytes maximum cache size in bytes
 * @param maxSizeAfterCleanBytes maximum cache size after clean operation
 * @param minBytesToClean minimum number of bytes to clean
 */
- (instancetype)initWithPath:(NSString *)path
				maxSizeBytes:(unsigned long long)maxSizeBytes
	  maxSizeAfterCleanBytes:(unsigned long long)maxSizeAfterCleanBytes
			 minBytesToClean:(unsigned long long)minBytesToClean NS_DESIGNATED_INITIALIZER;

/*!
 * DI
 * @param path path to directory to store cached objects. Content of this directory is managed by SLTImagesDiskCache.
 * @param maxSizeBytes maximum cache size in bytes
 */
- (instancetype)initWithPath:(NSString *)path
				maxSizeBytes:(unsigned long long)maxSizeBytes;

/*!
 * Read data for key
 *
 * Thread safe
 *
 * @return cached data or nil (if no cached data)
 */
- (NSData *)dataForKey:(NSString *)key;

/*!
 * Setup data for key
 *
 * Thread safe
 *
 * Pass nil data to remove item from cache
 */
- (void)setData:(NSData *)data forKey:(NSString *)key;

@end

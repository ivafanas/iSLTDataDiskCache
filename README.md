# iSLTDataDiskCache
LRU disk cache to store NSData objects

## Features
- customize cache directory
- supports directories which cleaning is managed by OS like NSTemproraryDirectory() and NSCachesDirectory
- customize maximum cache size (in bytes)
- customize maximum cache size after clean
- customize minimum size per clean
- thread safe

## Requirements
- cache keys should not contain symbols: '[]/: %,.?!@$^&()'
- tested on iOS 7.1 and higher

## License
MIT License


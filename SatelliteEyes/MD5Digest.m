#include <CommonCrypto/CommonDigest.h>
#include "MD5Digest.h"

static NSString* md5Digest(const void *data, CC_LONG length)
{
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    unsigned char* d = CC_MD5(data, length, digest);
    
    return [NSString stringWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
            d[0], d[1], d[2], d[3], d[4], d[5], d[6], d[7], d[8], d[9], d[10], d[11], d[12], d[13], d[14], d[15],
            nil];
}

@implementation NSString (MD5Digest)

- (NSString*) md5Digest
{
    return md5Digest([self UTF8String], (CC_LONG)[self lengthOfBytesUsingEncoding:NSUTF8StringEncoding]);
}

@end

@implementation NSData (MD5Digest)

- (NSString*) md5Digest
{
    return md5Digest([self bytes], (CC_LONG)[self length]);
}

@end
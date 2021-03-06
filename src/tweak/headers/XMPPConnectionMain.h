#import "WAJID.h"

@interface XMPPConnectionMain : NSObject
    // Check if should send readReceipts and then sends.
    -(void)sendReadReceiptsForMessagesIfNeeded:(id)arg1;
    // Returns if given jid is online.
    -(_Bool)isOnline:(WAJID *)jid;
    // Set to receive presence updates.
    - (void)presenceSubscribeToJIDIfNecessary:(id)arg1;
@end

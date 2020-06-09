#import <AVFoundation/AVFoundation.h>
#import "CMBCustomListController.h"

@interface CMBRootListController : CMBCustomListController
@property (nonatomic,retain,readonly) AVAudioPlayer *audioPlayer;
@property (nonatomic,retain,readonly) NSURL *rubYouDownURL;
@end

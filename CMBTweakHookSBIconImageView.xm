//#import <Foundation/Foundation.h>
#import "SpringBoard.h"
#import "CMBManager.h"
#import "CMBPreferences.h"

%hook SBIconView

@interface SBIconView : UIView
@property (nonatomic,retain) SBIcon *icon;
@end

-(void)iconImageDidUpdate:(id)arg1 {
	%orig;
	
	if (![[CMBPreferences sharedInstance] tweakEnabled]) return;
	
	CMBIconInfo* iconInfo = [[CMBIconInfo sharedInstance] getIconInfo:[self icon]];
	
	if (iconInfo.isApplication) {
		[[CMBManager sharedInstance] refreshBadges:iconInfo.nodeIdentifier];
	}
}
%end

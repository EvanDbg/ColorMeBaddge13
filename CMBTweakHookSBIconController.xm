#import "SpringBoard.h"
#import "CMBPreferences.h"

%hook SBIconController
-(BOOL)iconManager:(id)arg1 allowsBadgingForIcon:(id)arg2 {
	if(![[CMBPreferences sharedInstance] tweakEnabled]) return %orig();

	BOOL original = %orig();

	if([[CMBPreferences sharedInstance] showAllBadges]) return YES;

	return original;
}

-(BOOL)allowsBadgingForIcon:(id)arg1 {
	if(![[CMBPreferences sharedInstance] tweakEnabled]) return %orig();

	BOOL original = %orig();

	if([[CMBPreferences sharedInstance] showAllBadges]) return YES;

	return original;
}
%end

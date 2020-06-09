#import "SpringBoard.h"
#import "CMBManager.h"
#import "CMBPreferences.h"

%hook SBDownloadingIcon

- (id)appPlaceholder
{
	if (![[CMBPreferences sharedInstance] tweakEnabled])
	{
		return %orig();
	}

	id retval = %orig();

	[[CMBManager sharedInstance] refreshBadges:[retval applicationBundleID]];

	return retval;
}

- (void)setApplicationPlaceholder:(id)arg1
{
	if (![[CMBPreferences sharedInstance] tweakEnabled])
	{
		%orig();
		return;
	}

	%orig();

	[[CMBManager sharedInstance] refreshBadges:[arg1 applicationBundleID]];
}

%end

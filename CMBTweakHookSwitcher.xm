#import "SpringBoard.h"
#import "CMBIconInfo.h"
#import "CMBManager.h"
#import "CMBPreferences.h"

%hook SBFluidSwitcherIconImageContainerView

- (void)setImage:(UIImage*)arg1
{
	UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"" message:[NSString stringWithFormat:@"%@", @"Setting image"] preferredStyle:UIAlertControllerStyleAlert];
	UIAlertAction* dismissAction = [UIAlertAction actionWithTitle:@"Dismiss" style:UIAlertActionStyleCancel handler:^(UIAlertAction * action) {}];
	[alert addAction:dismissAction];
	[[[UIApplication sharedApplication] keyWindow].rootViewController presentViewController:alert animated:YES completion:nil];
	
	// clear any existing badge -- do this now, so they are cleared even if tweak is disabled
	for (UIView *subview in [self.imageView subviews])
		[subview removeFromSuperview];

	if (![[CMBPreferences sharedInstance] tweakEnabled])
	{
		%orig;
		return;
	}

	if (![[CMBPreferences sharedInstance] switcherBadgesEnabled])
	{
		%orig;
		return;
	}

	%orig;

	[self createSwitcherIconBadge];
}

%new
- (void)createSwitcherIconBadge
{
	if (![[self icon] nodeIdentifier])
		return;

	if (![[objc_getClass("SBIconController") sharedInstance] allowsBadgingForIcon:[self icon]])
		return;

	CMBIconInfo *iconInfo = [[CMBIconInfo sharedInstance] getIconInfo:[self icon]];

	id badgeNumberOrString = [iconInfo fakeBadgeNumberOrString];

	NSInteger badgeType = [[CMBManager sharedInstance] getBadgeValueType:badgeNumberOrString];

	// default for numeric/special... override under numeric check below
	NSString *badgeString = (NSString *)badgeNumberOrString;

	if (kEmptyBadge == badgeType)
		return;

	if (kNumericBadge == badgeType)
	{
		// just recreate badge value from scratch

		if ([badgeNumberOrString isKindOfClass:[NSNumber class]])
			badgeString = [badgeNumberOrString stringValue];

		NSString *groupingSeparator = [[NSLocale currentLocale] objectForKey:NSLocaleGroupingSeparator];
		NSString *delocalizedBadgeString = [badgeString stringByReplacingOccurrencesOfString:groupingSeparator withString:@""];

		// no separator, because a) we could use the space, and b) binary badges get formatted when they shouldn't be
/*
		NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
		[numberFormatter setNumberStyle:NSNumberFormatterDecimalStyle];
		[numberFormatter setGroupingSeparator:groupingSeparator];

		NSNumber *badgeValue = [numberFormatter numberFromString:delocalizedBadgeString];
		badgeString = [numberFormatter stringFromNumber:badgeValue];
*/
		badgeString = delocalizedBadgeString;
	}

	CMBColorInfo *badgeColors = [[CMBManager sharedInstance] getBadgeColorsForIcon:[self icon]];

	// original image size
	CGFloat iconWidth = [self imageView].image.size.width;
	CGFloat iconHeight = [self imageView].image.size.height;
	CGFloat iconMaxDimension = fmaxf(iconWidth, iconHeight);

	// calculated values from original image size based on home screen icons:
	// icon: 60 px
	// badge: 24 px
	// badge offset x: 46 px
	// badge offset y: -10 px

	// labelFontSize: 17
	// buttonFontSize: 18
	// smallSystemFontSize: 12
	// systemFontSize: 14

//	CGFloat badgeSize = 15.0;
//	CGFloat badgeGrowThreshold = 7.5;

	CGFloat badgeScale = iconMaxDimension / 60.0;
//	CGFloat badgeSizeScale = 1.15; // => badgeSize = 14
//	CGFloat badgeSizeScale = 1.2;  // => badgeSize = 14
//	CGFloat badgeSizeScale = 1.25; // => badgeSize = 15
//	CGFloat badgeSizeScale = 1.3;  // => badgeSize = 16
	CGFloat badgeSizeScale = (iconMaxDimension + 5.0) / iconMaxDimension;  // iconMaxDimension = 29 => badgeSize = 14 ; iconMaxDimension = 40 => badgeSize = 18
	CGFloat badgeSize = ceil(badgeScale * badgeSizeScale * 24.0);
	CGFloat badgeShift = (((badgeSizeScale - 1.0) * badgeSize) / 2.0);
	CGFloat badgeFontSize = ceil(badgeScale * badgeSizeScale * [UIFont labelFontSize]);
	CGFloat badgeOffsetX = floor(badgeScale * 46.0 - badgeShift);
	CGFloat badgeOffsetY = floor(badgeScale * -10.0 - badgeShift);
	CGFloat badgeGrowThreshold = badgeSize / 2.0;

	// create and build label
	UILabel *badge = [[UILabel alloc] initWithFrame:CGRectZero];
	badge.font = [UIFont systemFontOfSize:badgeFontSize];
	badge.text = badgeString;
	badge.textAlignment = NSTextAlignmentCenter;
	badge.backgroundColor = badgeColors.backgroundColor;
	badge.textColor = badgeColors.foregroundColor;

	[badge sizeToFit];

	// adjusted values for our badge
	CGFloat x = badgeOffsetX;
	CGFloat y = badgeOffsetY;
	CGFloat w = badgeSize;
	CGFloat h = badgeSize;

	CGFloat grow = fmaxf(ceil(CGRectGetWidth(badge.frame)-badgeGrowThreshold), 0.0);

	x -= grow;
	w += grow;

	badge.frame = CGRectMake(x, y, w, h);

	CGFloat fullCornerRadius = (fminf(CGRectGetWidth(badge.frame), CGRectGetHeight(badge.frame)) - 1.0) / 2.0;
	CGFloat cornerRadius = [[CMBManager sharedInstance] getScaledCornerRadius:fullCornerRadius];

	badge.layer.cornerRadius = cornerRadius;
	badge.layer.masksToBounds = YES;

	if ([[CMBPreferences sharedInstance] badgeBordersEnabled])
	{
		badge.layer.borderWidth = 1.0;
		badge.layer.borderColor = badgeColors.borderColor.CGColor;
	}

	[[self imageView] addSubview:badge];
}

%end /* hook */

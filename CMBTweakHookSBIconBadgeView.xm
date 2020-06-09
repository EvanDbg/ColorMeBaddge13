#import "SpringBoard.h"
#import "CMBManager.h"
#import "CMBPreferences.h"
#import "CMBSexerUpper.h"
#import "NSString+CMBEmoji.h"
#import "external/Chameleon/UIColor+ChameleonPrivate.h"

// keep track of per-view text colors when crossfading
static NSMutableDictionary *crossfadeColors = nil;

// stock iOS badge color, determined at runtime
static UIColor *stockBadgeColor = nil;

static BOOL tweakIsOrWasPreviouslyEnabled()
{
	// sticky enable flag (disable tweak and respring to clear)
	static BOOL enabledFlag = NO;

	if (enabledFlag)
	{
		return YES;
	}

	if ([[CMBPreferences sharedInstance] tweakEnabled])
	{
		enabledFlag = YES;
		return YES;
	}
	return NO;
}

static void setCrossfadeColor(UIColor *crossfadeColor, NSString *key)
{
	@synchronized(crossfadeColors)
	{
		[crossfadeColors setObject:crossfadeColor forKey:key];
	}
}

static UIColor *getCrossfadeColor(NSString *key)
{
	UIColor *crossfadeColor = [UIColor whiteColor];

	@synchronized(crossfadeColors)
	{
		crossfadeColor = [crossfadeColors objectForKey:key];

		if (crossfadeColor)
		{
			[crossfadeColors removeObjectForKey:key];
		}
	}

	return crossfadeColor;
}

static UIImage *colorizeImage(UIImage *image, UIColor *color)
{
	UIImage *colorizedImage;

	UIGraphicsBeginImageContextWithOptions(image.size, NO, image.scale);
	CGContextRef context = UIGraphicsGetCurrentContext();
	[color setFill];
	CGContextTranslateCTM(context, 0, image.size.height);
	CGContextScaleCTM(context, 1.0, -1.0);
	CGContextClipToMask(context, CGRectMake(0, 0, image.size.width, image.size.height), [image CGImage]);
	CGContextFillRect(context, CGRectMake(0, 0, image.size.width, image.size.height));
	colorizedImage = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();

	return colorizedImage;
}

static UIColor *colorOfMiddlePixel(UIImage *image)
{
	int w = CGImageGetWidth(image.CGImage);
	int h = CGImageGetHeight(image.CGImage);
	int x = w / 2;
	int y = h / 2;

	UIColor *pixelColor = [UIColor colorFromImage:image atPoint:CGPointMake(x, y)];

	CGFloat r, g, b, a;

	[pixelColor getRed:&r green:&g blue:&b alpha:&a];

	pixelColor = [UIColor colorWithRed:r green:g blue:b alpha:1.0];

	return pixelColor;
}

%hook SBIconBadgeView
- (void)configureForIcon:(id)arg1 infoProvider:(id)arg2 {
	if (!tweakIsOrWasPreviouslyEnabled()) {
		%orig();
		return;
	}

	CMBColorInfo *badgeColors = [self getBadgeColorsForIcon:arg1 prepareForCrossfade:NO];

	%orig();

	[self setBadgeColors:badgeColors];
}

- (void)configureAnimatedForIcon:(id)arg1 infoProvider:(id)arg2 animator:(id)arg3 {
	if (!tweakIsOrWasPreviouslyEnabled()) {
		%orig();
		return;
	}

	CMBColorInfo *badgeColors = [self getBadgeColorsForIcon:arg1 prepareForCrossfade:YES];

	%orig();

	[self setBadgeColors:badgeColors];
}

- (void)_crossfadeToTextImage:(id)arg1 animator:(id)arg2 {
	if (!tweakIsOrWasPreviouslyEnabled()) {
		%orig();
		return;
	}

	UIColor *crossfadeColor = getCrossfadeColor([self getCrossfadeColorKey]);

	if (arg1) arg1 = colorizeImage(arg1, crossfadeColor);

	%orig();
}

%new
- (CMBColorInfo *)getBadgeColorsForIcon:(id)icon prepareForCrossfade:(BOOL)prepareForCrossfade
{
	CMBColorInfo *badgeColors = nil;

	CMBIconInfo *iconInfo = [[CMBIconInfo sharedInstance] getIconInfo:icon];

	if (iconInfo.isApplication == NO)
	{
		NSInteger folderBadgeBackgroundType = [[CMBPreferences sharedInstance] folderBadgeBackgroundType];

		if (folderBadgeBackgroundType == kFBB_RandomBadge)
		{
			UIView *rootView;

			for (rootView = self; [rootView superview]; rootView = [rootView superview]);

			if (![rootView isKindOfClass:NSClassFromString(@"SBHomeScreenWindow")])
			{
				badgeColors = [[CMBManager sharedInstance] getBadgeColorsForFolderUsingColorsFromRandomBadge:iconInfo preferCachedColors:YES];
			}
		} else if (folderBadgeBackgroundType == kFBB_FolderMinigrid)
		{
			UIView* view = nil;
			for(UIView* v in self.superview.subviews){
				if([v isKindOfClass:%c(SBFolderIconImageView)]){
					view = v;
					break;
				}
			}
		}
	}

	if (badgeColors == nil) badgeColors = [[CMBManager sharedInstance] getBadgeColorsForIcon:icon];

	if (prepareForCrossfade) setCrossfadeColor(badgeColors.foregroundColor, [self getCrossfadeColorKey]);
	
	return badgeColors;
}

%new
- (void)setBadgeBackgroundColor:(CMBColorInfo *)badgeColors
{
	SBDarkeningImageView *backgroundView;
	SBIconAccessoryImage *backgroundImage;
	UIImage *colorizedImage;
	
	//backgroundImage = MSHookIvar<SBIconAccessoryImage*>(self, "_backgroundImage");
	backgroundImage = [self _checkoutBackgroundImage];
	
	if (!backgroundImage)
		return;
	
	backgroundView = MSHookIvar<SBDarkeningImageView*>(self, "_backgroundView");

	if (!backgroundView)
		return;
	
	@synchronized(stockBadgeColor)
	{
		if (!stockBadgeColor)
		{
			stockBadgeColor = colorOfMiddlePixel(backgroundImage);
			[CMBColorInfo sharedInstance].stockBackgroundColor = stockBadgeColor;
			[CMBColorInfo sharedInstance].stockForegroundColor = REAL_WHITE_COLOR;
		}
	}
	
	CGFloat paddingPoints = 1.0;
	
	paddingPoints -= [[CMBPreferences sharedInstance] badgeSizeAdjustment];
	
	CGSize badgeSize = backgroundImage.size;

	CGRect fullRect = CGRectMake(0.0, 0.0, badgeSize.width, badgeSize.height);
	CGRect badgeRect = CGRectMake(paddingPoints, paddingPoints, badgeSize.width - 2.0 * paddingPoints, badgeSize.height - 2.0 * paddingPoints);

	CGFloat fullCornerRadius = ((fminf(badgeSize.width, badgeSize.height) - 2.0 * paddingPoints) - 1.0) / 2.0;
	CGFloat cornerRadius = [[CMBManager sharedInstance] getScaledCornerRadius:fullCornerRadius];

	UIView *badgeView = [[UIView alloc] initWithFrame:badgeRect];
	badgeView.layer.cornerRadius = cornerRadius;
	badgeView.backgroundColor = badgeColors.backgroundColor;

	if ([[CMBPreferences sharedInstance] badgeBordersEnabled])
	{
		badgeView.layer.borderWidth = [[CMBPreferences sharedInstance] badgeBorderWidth];
		badgeView.layer.borderColor = badgeColors.borderColor.CGColor;
	}

	UIGraphicsBeginImageContextWithOptions(badgeView.frame.size, NO, 0.0);
	[badgeView.layer renderInContext:UIGraphicsGetCurrentContext()];
	colorizedImage = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	
	UIGraphicsBeginImageContextWithOptions(fullRect.size, NO, 0.0);
	[[UIColor clearColor] setFill];
	
	[colorizedImage drawAtPoint:CGPointMake(paddingPoints, paddingPoints)];
	colorizedImage = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();

	if (!colorizedImage)
		return;

	double verticalInset = colorizedImage.size.height / 2.0;
	double horizontalInset = colorizedImage.size.width / 2.0;

	UIEdgeInsets insets = UIEdgeInsetsMake(verticalInset, horizontalInset, verticalInset, horizontalInset);

	colorizedImage = [colorizedImage resizableImageWithCapInsets:insets];

	if (!colorizedImage)
		return;
	
	[backgroundView setCustomImage:colorizedImage];
	backgroundView.image = colorizedImage;
}

%new
- (void)setBadgeForegroundColor:(CMBColorInfo *)badgeColors
{
	SBDarkeningImageView *textView;
	SBIconAccessoryImage *textImage;

	textImage = MSHookIvar<SBIconAccessoryImage*>(self, "_textImage");

	if (!textImage)
		return;

	textView = MSHookIvar<SBDarkeningImageView*>(self, "_textView");

	if (!textView)
		return;
	
	if (![[CMBPreferences sharedInstance] colorizeEmojis])
	{
		NSString *text;

		text = MSHookIvar<NSString *>(self, "_text");

		if (text) {
			if ([text containsEmoji]) {
				[textView setImage:textImage];
				return;
			}
		}
	}

	UIImage *colorizedImage;

	colorizedImage = colorizeImage(textImage, badgeColors.foregroundColor);

	if (!colorizedImage)
		return;

	[textView setImage:colorizedImage];
}

%new
- (void)setBadgeColors:(CMBColorInfo *)badgeColors
{
	[self setBadgeBackgroundColor:badgeColors];
	[self setBadgeForegroundColor:badgeColors];
}

%new
- (NSString *)getCrossfadeColorKey
{
	NSString *key = [NSString stringWithFormat:@"%p", self];

	return key;
}
%end /* Hook */

%ctor {
	%init;

	crossfadeColors = [[NSMutableDictionary alloc] init];
}

%hook SBDarkeningImageView
BOOL custom;

%new
-(void) setCustomImage: (UIImage*) image{
	if(![[CMBPreferences sharedInstance] tweakEnabled]) return;
	
	custom = true;
	[self setImage: image];
	custom = false;
}

-(void) setImage: (UIImage*) image{
	if(custom || ![[CMBPreferences sharedInstance] tweakEnabled]){
		%orig;
	}
}
%end

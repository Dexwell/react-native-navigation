#import "RNNTopBarButtonPresenter.h"
#import "RNNUIBarButtonItem.h"
#import <React/RCTConvert.h>
#import "RCTHelpers.h"
#import "UIImage+tint.h"
#import "RNNComponentViewController.h"
#import "UIImage+insets.h"
#import "UIViewController+LayoutProtocol.h"

@interface RNNTopBarButtonPresenter()

@property (weak, nonatomic) UIViewController<RNNLayoutProtocol>* viewController;
@property (strong, nonatomic) RNNReactComponentRegistry* componentRegistry;
@end

@implementation RNNTopBarButtonPresenter

-(instancetype)initWithViewController:(UIViewController<RNNLayoutProtocol>*)viewController componentRegistry:(id)componentRegistry {
	self = [super init];
	self.viewController = viewController;
	self.componentRegistry = componentRegistry;
	return self;
}

- (void)applyLeftButtons:(NSArray *)buttons defaultLeftButtonStyle:(RNNButtonOptions *)defaultButtonStyle {
	NSArray * result = [self getButtons:buttons defaultStyle:defaultButtonStyle insets:[self leftButtonInsets:defaultButtonStyle.iconInsets]];
	[self.viewController.navigationItem setLeftBarButtonItems:result animated:NO];
}

- (void)applyRightButtons:(NSArray *)buttons defaultRightButtonStyle:(RNNButtonOptions *)defaultButtonStyle {
	NSArray *result = [self getButtons:buttons defaultStyle:defaultButtonStyle insets:[self rightButtonInsets:defaultButtonStyle.iconInsets]];
	[self.viewController.navigationItem setRightBarButtonItems:result animated:NO];
}

-(NSArray *)getButtons:(NSArray*)buttons defaultStyle:(RNNButtonOptions *)defaultStyle insets:(UIEdgeInsets)insets {
	NSMutableArray *barButtonItems = [NSMutableArray new];
	for (NSDictionary *button in [self resolveButtons:buttons]) {
        [barButtonItems addObject:[self buildButton:button defaultStyle:defaultStyle insets:insets]];
		UIColor* color = [self color:[RCTConvert UIColor:button[@"color"]] defaultColor:[defaultStyle.color getWithDefaultValue:nil]];
		if (color) {
			self.viewController.navigationController.navigationBar.tintColor = color;
		}
	}
	return barButtonItems;
}

- (NSArray *)resolveButtons:(id)buttons {
	if ([buttons isKindOfClass:[NSArray class]]) {
		return buttons;
	} else {
		return @[buttons];
	}
}

-(RNNUIBarButtonItem*)buildButton: (NSDictionary*)dictionary defaultStyle:(RNNButtonOptions *)defaultStyle insets:(UIEdgeInsets)insets {
	NSString* buttonId = dictionary[@"id"];
	NSString* title = [self getValue:dictionary[@"text"] withDefault:[defaultStyle.text getWithDefaultValue:nil]];
	NSDictionary* component = dictionary[@"component"];
	NSString* systemItemName = dictionary[@"systemItem"];
	
	UIColor* color = [self color:[RCTConvert UIColor:dictionary[@"color"]] defaultColor:[defaultStyle.color getWithDefaultValue:nil]];
	UIColor* disabledColor = [self color:[RCTConvert UIColor:dictionary[@"disabledColor"]] defaultColor:[defaultStyle.disabledColor getWithDefaultValue:nil]];
	
	if (!buttonId) {
		@throw [NSException exceptionWithName:@"NSInvalidArgumentException" reason:[@"button id is not specified " stringByAppendingString:title] userInfo:nil];
	}
	
	UIImage* defaultIcon = [defaultStyle.icon getWithDefaultValue:nil];
	UIImage* iconImage = [self getValue:dictionary[@"icon"] withDefault:defaultIcon];
	if (![iconImage isKindOfClass:[UIImage class]]) {
		iconImage = [RCTConvert UIImage:iconImage];
	}
	
	if (iconImage) {
		iconImage = [iconImage imageWithInsets:insets];
		if (color) {
			iconImage = [iconImage withTintColor:color];
		}
	}
	
	RNNUIBarButtonItem *barButtonItem;
	if (component) {
		RNNComponentOptions* componentOptions = [RNNComponentOptions new];
		componentOptions.componentId = [[Text alloc] initWithValue:component[@"componentId"]];
		componentOptions.name = [[Text alloc] initWithValue:component[@"name"]];
		
		RNNReactView *view = [_componentRegistry createComponentIfNotExists:componentOptions parentComponentId:self.viewController.layoutInfo.componentId reactViewReadyBlock:nil];
		[view removeFromSuperview];
		[NSLayoutConstraint deactivateConstraints:view.constraints];
        [view invalidateIntrinsicContentSize];

        barButtonItem = [[RNNUIBarButtonItem alloc] init:buttonId withCustomView:view componentRegistry:_componentRegistry];
	} else if (iconImage) {
		barButtonItem = [[RNNUIBarButtonItem alloc] init:buttonId withIcon:iconImage];
	} else if (title) {
		barButtonItem = [[RNNUIBarButtonItem alloc] init:buttonId withTitle:title];
		
		NSMutableDictionary *buttonTextAttributes = [RCTHelpers textAttributesFromDictionary:dictionary withPrefix:@"button"];
		if (buttonTextAttributes.allKeys.count > 0) {
			[barButtonItem setTitleTextAttributes:buttonTextAttributes forState:UIControlStateNormal];
		}
	} else if (systemItemName) {
		barButtonItem = [[RNNUIBarButtonItem alloc] init:buttonId withSystemItem:systemItemName];
	} else {
		return nil;
	}
	
	barButtonItem.target = self.viewController;
	barButtonItem.action = @selector(onButtonPress:);
	
	NSNumber *enabled = [self getValue:dictionary[@"enabled"] withDefault:defaultStyle.enabled.getValue];
	BOOL enabledBool = enabled ? [enabled boolValue] : YES;
	[barButtonItem setEnabled:enabledBool];
	
	NSMutableDictionary* textAttributes = [[NSMutableDictionary alloc] init];
	NSMutableDictionary* disabledTextAttributes = [[NSMutableDictionary alloc] init];
	
	if (!enabledBool && disabledColor) {
		color = disabledColor;
		disabledTextAttributes[NSForegroundColorAttributeName] = disabledColor;
	}
	
	if (color) {
		textAttributes[NSForegroundColorAttributeName] = color;
		[barButtonItem setImage:[[iconImage withTintColor:color] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal]];
		barButtonItem.tintColor = color;
	}
	
	NSNumber* fontSize = [self fontSize:dictionary[@"fontSize"] defaultFontSize:[defaultStyle.fontSize getWithDefaultValue:nil]];
	NSString* fontFamily = [self fontFamily:dictionary[@"fontFamily"] defaultFontFamily:[defaultStyle.fontFamily getWithDefaultValue:nil]];
	UIFont *font = nil;
	if (fontFamily) {
		font = [UIFont fontWithName:fontFamily size:[fontSize floatValue]];
	} else {
		font = [UIFont systemFontOfSize:[fontSize floatValue]];
	}
	textAttributes[NSFontAttributeName] = font;
	disabledTextAttributes[NSFontAttributeName] = font;
	
	[barButtonItem setTitleTextAttributes:textAttributes forState:UIControlStateNormal];
	[barButtonItem setTitleTextAttributes:textAttributes forState:UIControlStateHighlighted];
	[barButtonItem setTitleTextAttributes:disabledTextAttributes forState:UIControlStateDisabled];
	
	NSString *testID = dictionary[@"testID"];
	if (testID) {
		barButtonItem.accessibilityIdentifier = testID;
	}
	
	return barButtonItem;
}

- (UIColor *)color:(UIColor *)color defaultColor:(UIColor *)defaultColor {
	if (color) {
		return color;
	} else if (defaultColor) {
		return defaultColor;
	}
	
	return nil;
}

- (NSNumber *)fontSize:(NSNumber *)fontSize defaultFontSize:(NSNumber *)defaultFontSize {
	if (fontSize) {
		return fontSize;
	} else if (defaultFontSize) {
		return defaultFontSize;
	}
	
	return @(17);
}

- (NSString *)fontFamily:(NSString *)fontFamily defaultFontFamily:(NSString *)defaultFontFamily {
	if (fontFamily) {
		return fontFamily;
	} else {
		return defaultFontFamily;
	}
}

- (id)getValue:(id)value withDefault:(id)defaultValue {
	return value ? value : defaultValue;
}

- (UIEdgeInsets)leftButtonInsets:(RNNInsetsOptions *)defaultInsets {
	return UIEdgeInsetsMake([defaultInsets.top getWithDefaultValue:0],
					 [defaultInsets.left getWithDefaultValue:0],
					 [defaultInsets.bottom getWithDefaultValue:0],
					 [defaultInsets.right getWithDefaultValue:15]);
}

- (UIEdgeInsets)rightButtonInsets:(RNNInsetsOptions *)defaultInsets {
	return UIEdgeInsetsMake([defaultInsets.top getWithDefaultValue:0],
					 [defaultInsets.left getWithDefaultValue:15],
					 [defaultInsets.bottom getWithDefaultValue:0],
					 [defaultInsets.right getWithDefaultValue:0]);
}

@end

//
//  TTAboutViewController.m
//  SatelliteEyes
//
//  Created by Tom Taylor on 28/07/2013.
//
//

#import "TTAboutViewController.h"

@implementation TTAboutViewController

@synthesize aboutTextView, versionTextField;

- (void)awakeFromNib {
    NSString *path = [[NSBundle mainBundle] pathForResource:@"Credits" ofType:@"rtf"];
    NSAttributedString *attributedString = [[NSAttributedString alloc] initWithPath:path documentAttributes:nil];
    [aboutTextView.textStorage setAttributedString:attributedString];
    [aboutTextView setEditable:NO];
    [aboutTextView setBackgroundColor:[NSColor clearColor]];
    
    // Set the height of the credits view to maximum size that will contain it all,
    // so there's no trailing space at the end
    NSLayoutManager *layoutManager = aboutTextView.layoutManager;
    NSTextContainer *textContainer = (layoutManager.textContainers)[0];
    [layoutManager glyphRangeForTextContainer:textContainer]; // forces layout
    NSRect rect = [layoutManager usedRectForTextContainer:textContainer];
    [aboutTextView setFrameSize:rect.size];
    
    NSString *version = [[NSBundle mainBundle] infoDictionary][@"CFBundleVersion"];
    NSString *gitRevision = [[NSBundle mainBundle] infoDictionary][@"GitRevision"];
    NSString *longVersion = [NSString stringWithFormat:@"Version %@\nBuild %@", version, gitRevision];
    
    [versionTextField setStringValue:longVersion];
}

- (IBAction)clickVisitHomepage:(id)sender {
    NSURL *url = [NSURL URLWithString:@"http://satelliteeyes.tomtaylor.co.uk/"];
    [[NSWorkspace sharedWorkspace] openURL:url];
}

@end

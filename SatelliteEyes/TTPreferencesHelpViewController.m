//
//  TTPreferencesHelpViewController.m
//  Satellite Eyes
//
//  Created by Paul Schuberth on 07.10.23.
//

#import "TTPreferencesHelpViewController.h"

@implementation TTPreferencesHelpViewController

@synthesize helpTextView;

- (void)awakeFromNib {
    [super viewDidLoad];
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"PreferencesHelp" withExtension:@"rtf"];
    NSAttributedString *attributedString = [[NSAttributedString alloc]
                                            initWithURL:url options:@{NSDefaultAttributesDocumentOption: @YES}
                                            documentAttributes:nil
                                            error:nil];

    [helpTextView.textStorage setAttributedString:attributedString];
    [helpTextView setEditable:NO];
    helpTextView.backgroundColor = [NSColor clearColor];
}

@end

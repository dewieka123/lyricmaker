#import <Cocoa/Cocoa.h>
#import <AVFoundation/AVFoundation.h>

@interface AppDelegate : NSObject <NSApplicationDelegate, NSWindowDelegate>

@property (strong) NSWindow *window;
@property (strong) AVAudioPlayer *player;
@property (strong) NSData *audioData;
@property (strong) NSMutableArray *lyricData;
@property (strong) NSTimer *playbackTimer;

// UI Elements
@property (strong) NSTextField *currentLyricDisplay;
@property (strong) NSTextField *timeLabel;
@property (strong) NSSlider *progressSlider;
@property (strong) NSButton *playPauseButton;
@property (strong) NSTextField *lyricInputField;
@property (strong) NSTextView *lyricLogView;

@end

@implementation AppDelegate

- (void)applicationWillFinishLaunching:(NSNotification *)notification {
    [self buildMenu];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    self.lyricData = [[NSMutableArray alloc] init];
    
    // 1. Setup Native Window
    NSRect frame = NSMakeRect(0, 0, 700, 500);
    NSWindowStyleMask style = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable;
    self.window = [[NSWindow alloc] initWithContentRect:frame styleMask:style backing:NSBackingStoreBuffered defer:NO];
    [self.window setTitle:@"LyricMaker"];
    [self.window setMinSize:NSMakeSize(500, 400)];
    [self.window center];
    self.window.delegate = self;
    
    // 2. Adaptive Background (Supports Light/Dark Mode)
    NSVisualEffectView *vibrancy = [[NSVisualEffectView alloc] initWithFrame:frame];
    vibrancy.material = NSVisualEffectMaterialWindowBackground;
    vibrancy.blendingMode = NSVisualEffectBlendingModeBehindWindow;
    vibrancy.state = NSVisualEffectStateActive;
    self.window.contentView = vibrancy;
    
    // 3. Main Stack View
    NSStackView *mainStack = [[NSStackView alloc] initWithFrame:NSMakeRect(20, 20, 660, 460)];
    mainStack.orientation = NSUserInterfaceLayoutOrientationVertical;
    mainStack.spacing = 20;
    mainStack.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [vibrancy addSubview:mainStack];
    
    // 4. Current Lyric Display (Huge Text)
    self.currentLyricDisplay = [NSTextField labelWithString:@"Load an MP3 or .lya file to begin."];
    self.currentLyricDisplay.font = [NSFont systemFontOfSize:32 weight:NSFontWeightBold];
    self.currentLyricDisplay.textColor = [NSColor labelColor]; // Adapts to theme
    self.currentLyricDisplay.alignment = NSTextAlignmentCenter;
    self.currentLyricDisplay.lineBreakMode = NSLineBreakByWordWrapping;
    [mainStack addArrangedSubview:self.currentLyricDisplay];
    
    // 5. Audio Controls Stack
    NSStackView *controlStack = [[NSStackView alloc] init];
    controlStack.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    controlStack.spacing = 15;
    
    self.playPauseButton = [NSButton buttonWithTitle:@"Play" target:self action:@selector(togglePlayback)];
    self.timeLabel = [NSTextField labelWithString:@"00:00.0 / 00:00.0"];
    self.timeLabel.font = [NSFont monospacedDigitSystemFontOfSize:14 weight:NSFontWeightRegular];
    
    self.progressSlider = [NSSlider sliderWithTarget:self action:@selector(sliderScrubbed:)];
    self.progressSlider.minValue = 0;
    self.progressSlider.maxValue = 100;
    
    [controlStack addArrangedSubview:self.playPauseButton];
    [controlStack addArrangedSubview:self.timeLabel];
    [controlStack addArrangedSubview:self.progressSlider];
    [controlStack setContentHuggingPriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
    [mainStack addArrangedSubview:controlStack];
    
    // 6. Lyric Input Stack
    NSStackView *inputStack = [[NSStackView alloc] init];
    inputStack.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    inputStack.spacing = 10;
    
    self.lyricInputField = [[NSTextField alloc] init];
    self.lyricInputField.placeholderString = @"Type lyric here...";
    [[self.lyricInputField cell] setLineBreakMode:NSLineBreakByTruncatingTail];
    
    NSButton *addLyricBtn = [NSButton buttonWithTitle:@"Set at Current Time" target:self action:@selector(addLyricAtCurrentTime)];
    
    [inputStack addArrangedSubview:self.lyricInputField];
    [inputStack addArrangedSubview:addLyricBtn];
    [mainStack addArrangedSubview:inputStack];
    
    // 7. Log View for Synced Lyrics
    NSScrollView *scrollView = [[NSScrollView alloc] init];
    scrollView.hasVerticalScroller = YES;
    scrollView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    
    self.lyricLogView = [[NSTextView alloc] initWithFrame:scrollView.bounds];
    self.lyricLogView.editable = NO;
    self.lyricLogView.backgroundColor = [NSColor textBackgroundColor];
    self.lyricLogView.textColor = [NSColor textColor];
    self.lyricLogView.font = [NSFont systemFontOfSize:14];
    scrollView.documentView = self.lyricLogView;
    
    [mainStack addArrangedSubview:scrollView];
    
    [self.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
    
    // 8. Start Timer
    self.playbackTimer = [NSTimer scheduledTimerWithTimeInterval:0.05 target:self selector:@selector(updateUI) userInfo:nil repeats:YES];
}

// --- MENU CONSTRUCTION ---
- (void)buildMenu {
    NSMenu *mainMenu = [[NSMenu alloc] init];
    
    // App Menu
    NSMenuItem *appItem = [[NSMenuItem alloc] init];
    NSMenu *appMenu = [[NSMenu alloc] initWithTitle:@"LyricMaker"];
    [appMenu addItemWithTitle:@"Quit LyricMaker" action:@selector(terminate:) keyEquivalent:@"q"];
    [appItem setSubmenu:appMenu];
    [mainMenu addItem:appItem];
    
    // File Menu
    NSMenuItem *fileItem = [[NSMenuItem alloc] init];
    NSMenu *fileMenu = [[NSMenu alloc] initWithTitle:@"File"];
    [fileMenu addItemWithTitle:@"Open MP3..." action:@selector(openMP3) keyEquivalent:@"o"];
    [fileMenu addItemWithTitle:@"Open .lya File..." action:@selector(openLYA) keyEquivalent:@"O"]; // Shift+Cmd+O
    [fileMenu addItem:[NSMenuItem separatorItem]];
    [fileMenu addItemWithTitle:@"Save as .lya..." action:@selector(saveLYA) keyEquivalent:@"s"];
    [fileItem setSubmenu:fileMenu];
    [mainMenu addItem:fileItem];
    
    // Edit Menu (Required for Copy/Paste in TextFields)
    NSMenuItem *editItem = [[NSMenuItem alloc] init];
    NSMenu *editMenu = [[NSMenu alloc] initWithTitle:@"Edit"];
    [editMenu addItemWithTitle:@"Undo" action:@selector(undo:) keyEquivalent:@"z"];
    [editMenu addItemWithTitle:@"Redo" action:@selector(redo:) keyEquivalent:@"Z"];
    [editMenu addItem:[NSMenuItem separatorItem]];
    [editMenu addItemWithTitle:@"Cut" action:@selector(cut:) keyEquivalent:@"x"];
    [editMenu addItemWithTitle:@"Copy" action:@selector(copy:) keyEquivalent:@"c"];
    [editMenu addItemWithTitle:@"Paste" action:@selector(paste:) keyEquivalent:@"v"];
    [editMenu addItemWithTitle:@"Select All" action:@selector(selectAll:) keyEquivalent:@"a"];
    [editItem setSubmenu:editMenu];
    [mainMenu addItem:editItem];
    
    // View Menu
    NSMenuItem *viewItem = [[NSMenuItem alloc] init];
    NSMenu *viewMenu = [[NSMenu alloc] initWithTitle:@"View"];
    NSMenuItem *fsItem = [[NSMenuItem alloc] initWithTitle:@"Toggle Full Screen" action:@selector(toggleFullScreen:) keyEquivalent:@"f"];
    [fsItem setKeyEquivalentModifierMask:NSEventModifierFlagControl | NSEventModifierFlagCommand];
    [viewMenu addItem:fsItem];
    [viewItem setSubmenu:viewMenu];
    [mainMenu addItem:viewItem];
    
    // Lyrics Menu
    NSMenuItem *lyricsItem = [[NSMenuItem alloc] init];
    NSMenu *lyricsMenu = [[NSMenu alloc] initWithTitle:@"Lyrics"];
    [lyricsMenu addItemWithTitle:@"Clear All Lyrics" action:@selector(clearLyrics) keyEquivalent:@"K"];
    [lyricsItem setSubmenu:lyricsMenu];
    [mainMenu addItem:lyricsItem];
    
    [NSApp setMainMenu:mainMenu];
}

// --- FILE OPERATIONS ---
- (void)openMP3 {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    [panel setAllowedFileTypes:@[@"mp3"]];
    if ([panel runModal] == NSModalResponseOK) {
        self.audioData = [NSData dataWithContentsOfURL:panel.URL];
        [self loadAudioFromData];
        [self clearLyrics];
    }
}

- (void)openLYA {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    [panel setAllowedFileTypes:@[@"lya"]];
    if ([panel runModal] == NSModalResponseOK) {
        NSData *fileData = [NSData dataWithContentsOfURL:panel.URL];
        NSError *error;
        NSDictionary *unarchived = [NSPropertyListSerialization propertyListWithData:fileData options:NSPropertyListImmutable format:nil error:&error];
        
        if (unarchived && unarchived[@"audio"] && unarchived[@"lyrics"]) {
            self.audioData = unarchived[@"audio"];
            self.lyricData = [unarchived[@"lyrics"] mutableCopy];
            [self loadAudioFromData];
            [self refreshLyricLog];
        } else {
            NSAlert *alert = [[NSAlert alloc] init];
            alert.messageText = @"Invalid .lya File";
            [alert runModal];
        }
    }
}

- (void)saveLYA {
    if (!self.audioData) return;
    
    NSSavePanel *panel = [NSSavePanel savePanel];
    [panel setAllowedFileTypes:@[@"lya"]];
    [panel setNameFieldStringValue:@"MySong.lya"];
    
    if ([panel runModal] == NSModalResponseOK) {
        NSDictionary *package = @{
            @"audio": self.audioData,
            @"lyrics": self.lyricData
        };
        
        NSError *error;
        NSData *plistData = [NSPropertyListSerialization dataWithPropertyList:package format:NSPropertyListBinaryFormat_v1_0 options:0 error:&error];
        
        if (plistData) {
            [plistData writeToURL:panel.URL atomically:YES];
        }
    }
}

// --- AUDIO LOGIC ---
- (void)loadAudioFromData {
    NSError *error;
    self.player = [[AVAudioPlayer alloc] initWithData:self.audioData error:&error];
    if (self.player) {
        [self.player prepareToPlay];
        self.progressSlider.maxValue = self.player.duration;
        self.progressSlider.doubleValue = 0;
        self.playPauseButton.title = @"Play";
        self.currentLyricDisplay.stringValue = @"Audio loaded. Ready to sync.";
    }
}

- (void)togglePlayback {
    if (!self.player) return;
    if (self.player.isPlaying) {
        [self.player pause];
        self.playPauseButton.title = @"Play";
    } else {
        [self.player play];
        self.playPauseButton.title = @"Pause";
    }
}

- (void)sliderScrubbed:(NSSlider *)sender {
    if (self.player) {
        self.player.currentTime = sender.doubleValue;
    }
}

// --- LYRIC SYNCING LOGIC ---
- (void)addLyricAtCurrentTime {
    if (!self.player) return;
    
    NSString *text = self.lyricInputField.stringValue;
    if (text.length == 0) return;
    
    double currentTime = self.player.currentTime;
    
    NSDictionary *newLyric = @{
        @"time": @(currentTime),
        @"text": text
    };
    
    [self.lyricData addObject:newLyric];
    
    // Sort array so times are always chronological
    [self.lyricData sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        return [obj1[@"time"] compare:obj2[@"time"]];
    }];
    
    self.lyricInputField.stringValue = @"";
    [self refreshLyricLog];
}

- (void)clearLyrics {
    [self.lyricData removeAllObjects];
    [self refreshLyricLog];
    self.currentLyricDisplay.stringValue = @"";
}

- (void)refreshLyricLog {
    NSMutableString *log = [NSMutableString string];
    for (NSDictionary *dict in self.lyricData) {
        double time = [dict[@"time"] doubleValue];
        NSString *text = dict[@"text"];
        [log appendFormat:@"[%02d:%04.1f] %@\n", (int)(time / 60), fmod(time, 60.0), text];
    }
    self.lyricLogView.string = log;
}

// --- UPDATE UI TIMER ---
- (void)updateUI {
    if (!self.player) return;
    
    double current = self.player.currentTime;
    double total = self.player.duration;
    
    // Prevent slider jumping if user is dragging it
    if (self.player.isPlaying) {
        self.progressSlider.doubleValue = current;
    }
    
    self.timeLabel.stringValue = [NSString stringWithFormat:@"%02d:%04.1f / %02d:%04.1f",
                                  (int)(current / 60), fmod(current, 60.0),
                                  (int)(total / 60), fmod(total, 60.0)];
                                  
    // Find current lyric
    NSString *displayText = @"";
    for (NSDictionary *dict in self.lyricData) {
        double lyricTime = [dict[@"time"] doubleValue];
        if (current >= lyricTime) {
            displayText = dict[@"text"];
        } else {
            break; // Stop searching once we pass current time
        }
    }
    
    if (displayText.length > 0) {
        self.currentLyricDisplay.stringValue = displayText;
    }
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        AppDelegate *delegate = [[AppDelegate alloc] init];
        app.delegate = delegate;
        [app run];
    }
    return 0;
}
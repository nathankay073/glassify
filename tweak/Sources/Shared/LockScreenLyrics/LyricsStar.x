// The lock screen player's star flips the full-screen artwork between the lyrics (LyricsArtwork.x) and
// whatever it showed before: iOS 26 draws an app's like command as a star in the widget's left slot, so the
// mod takes that command over while the switch is on. The star is filled while the lyrics show.
//
// Spotify enables, disables and adds targets to the like command itself (its like/dislike flag), so while
// the switch is on its calls on that one command are let through only when they agree with the mod's.
// Read at launch, like every switch.
#import <MediaPlayer/MediaPlayer.h>
#import "Core/SGCore.h"
#import "LockScreenLyrics.h"
#import "Shared/AnimatedArtwork/AnimatedArtwork.h"

static BOOL sg_on;
static BOOL sg_ours;   // the mod's own calls on the command, past the hooks below

static MPFeedbackCommand *likeCommand(void) {
    return MPRemoteCommandCenter.sharedCommandCenter.likeCommand;
}

// What the star goes back to from the lyrics: the last other pick, Moving artwork if there never was one.
static SGLockArtwork otherArtwork(void) {
    SGLockArtwork other = (SGLockArtwork)SGInt(SGKeyLockScreenStarOther, SGLockArtworkMotion);
    return other == SGLockArtworkLyrics ? SGLockArtworkMotion : other;
}

// Main thread.
static void refresh(void) {
    MPFeedbackCommand *command = likeCommand();
    BOOL lyrics = SGLockScreenArtwork() == SGLockArtworkLyrics;
    sg_ours = YES;
    command.enabled = YES;
    command.localizedTitle = lyrics ? @"Show artwork" : @"Show lyrics";
    command.localizedShortTitle = @"Lyrics";
    command.active = lyrics;
    sg_ours = NO;
}

static MPRemoteCommandHandlerStatus toggle(void) {
    SGLockArtwork now = SGLockScreenArtwork();
    if (now == SGLockArtworkLyrics) {
        SGSetInt(SGKeyLockScreenArtwork, otherArtwork());
    } else {
        SGSetInt(SGKeyLockScreenStarOther, now);
        SGSetInt(SGKeyLockScreenArtwork, SGLockArtworkLyrics);
    }
    SGLog(@"lyrics star: %@", now == SGLockArtworkLyrics ? @"back to the artwork" : @"lyrics");
    // LyricsArtwork.x and LockScreenMotion.x hear the change through NSUserDefaults and swap the artwork.
    refresh();
    return MPRemoteCommandHandlerStatusSuccess;
}

%hook MPRemoteCommand
- (void)setEnabled:(BOOL)enabled {
    if (sg_on && !sg_ours && self == likeCommand()) return;
    %orig;
}

- (id)addTargetWithHandler:(MPRemoteCommandHandlerStatus (^)(MPRemoteCommandEvent *))handler {
    if (sg_on && !sg_ours && self == likeCommand()) return nil;
    return %orig;
}

- (void)addTarget:(id)target action:(SEL)action {
    if (sg_on && !sg_ours && self == likeCommand()) return;
    %orig;
}
%end

%hook MPFeedbackCommand
- (void)setActive:(BOOL)active {
    if (sg_on && !sg_ours && self == likeCommand()) return;
    %orig;
}

- (void)setLocalizedTitle:(NSString *)title {
    if (sg_on && !sg_ours && self == likeCommand()) return;
    %orig;
}

- (void)setLocalizedShortTitle:(NSString *)title {
    if (sg_on && !sg_ours && self == likeCommand()) return;
    %orig;
}
%end

%ctor {
    if (@available(iOS 26.0, *)) {
        if (!SGFlag(SGKeyLockScreenStar, NO)) return;
        sg_on = YES;
        %init;
        dispatch_async(dispatch_get_main_queue(), ^{
            MPFeedbackCommand *command = likeCommand();
            sg_ours = YES;
            [command removeTarget:nil];
            [command addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent *event) {
                if (NSThread.isMainThread) return toggle();
                dispatch_async(dispatch_get_main_queue(), ^{ toggle(); });
                return MPRemoteCommandHandlerStatusSuccess;
            }];
            sg_ours = NO;
            refresh();
            SGLog(@"lyrics star: on, the lock screen shows %@", SGLockScreenArtwork() == SGLockArtworkLyrics ? @"lyrics" : @"the artwork");
        });
        // A pick on the Lock screen page fills or empties the star too. Heard on the writing thread and
        // handed to main without waiting (AGENTS.md).
        [NSNotificationCenter.defaultCenter addObserverForName:NSUserDefaultsDidChangeNotification object:nil queue:nil
                                                    usingBlock:^(NSNotification *note) {
            dispatch_async(dispatch_get_main_queue(), ^{
                BOOL lyrics = SGLockScreenArtwork() == SGLockArtworkLyrics;
                if (likeCommand().active != lyrics) refresh();
            });
        }];
    }
}

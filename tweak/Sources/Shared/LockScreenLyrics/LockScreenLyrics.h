// The line being sung in place of the artist in the system's now playing: lock screen, Dynamic Island,
// Control Center, CarPlay. There is a Live Activity for it too (Shared/LiveActivity). The
// lines and the clock come from Karaoke.
#import <Foundation/Foundation.h>

#define SGKeyLockScreenLyrics @"spotifyglass.lockScreenLyrics"

// Off until switched on: the lock screen player's star flips the full-screen artwork between the lyrics and
// the last other pick, kept under the second key (LyricsStar.x). iOS 26 and up.
#define SGKeyLockScreenStar @"spotifyglass.lockscreen.lyricsStar"
#define SGKeyLockScreenStarOther @"spotifyglass.lockscreen.lyricsStarOther"

#include "keys.h"

uint8_t getModifier(rfbKeySym key) {
  switch (key) {
  case 0xFFE3u: return 1 << 0; // left ctrl
  case 0xFFE1u: return 1 << 1; // left shift
  case 0xFFE9u: return 1 << 2; // left alt
  case 0xFFE7u: return 1 << 3; // left gui
  case 0xFFE4u: return 1 << 4; // right ctrl
  case 0xFFE2u: return 1 << 5; // right shift;
  case 0xFFEAu: return 1 << 6; // right alt
  case 0xFFE8u: return 1 << 7; // right gui
  case 0x21: // Keyboard 1 and !
  case 0x40: // Keyboard 2 and @
  case 0x23: // Keyboard 3 and #
  case 0x24: // Keyboard 4 and $
  case 0x25: // Keyboard 5 and %
  case 0x5E: // Keyboard 6 and ^
  case 0x26: // Keyboard 7 and &
  case 0x2A: // Keyboard 8 and *
  case 0x28: // Keyboard 9 and (
  case 0x29: // Keyboard 0 and )
  case 0x5F: // Keyboard - and (underscore)
  case 0x2B: // Keyboard = and +
  case 0x7B: // Keyboard [ and {
  case 0x7D: // Keyboard ] and }
  case 0x7C: // Keyboard \ and |
  // case unknown: // Keyboard Non-US # and ~
  case 0x3A: // Keyboard ; and :
  case 0x22: // Keyboard ' and "
  case 0x7E: // Keyboard Grave Accent and Tilde
  case 0x3C: // Keyboard, and <
  case 0x3E: // Keyboard . and >
  case 0x3F: // Keyboard / and ?
    return 1 << 1; // left shift
  default: 
    if (key != tolower(key))
      return 1 << 1; // left shift
  }
  return 0;
}

uint8_t mapKey(rfbKeySym key) {
  if (key >= 0x41 && key <= 0x5A) // Map capital letters to lowercase
    key |= 0x20;
  
  switch (key) {
  case 0x61: return 0x4; // Keyboard a and A
  case 0x62: return 0x5; // Keyboard b and B
  case 0x63: return 0x6; // Keyboard c and C
  case 0x64: return 0x7; // Keyboard d and D
  case 0x65: return 0x8; // Keyboard e and E
  case 0x66: return 0x9; // Keyboard f and F
  case 0x67: return 0xA; // Keyboard g and G
  case 0x68: return 0xB; // Keyboard h and H
  case 0x69: return 0xC; // Keyboard i and I
  case 0x6A: return 0xD; // Keyboard j and J
  case 0x6B: return 0xE; // Keyboard k and K
  case 0x6C: return 0xF; // Keyboard l and L
  case 0x6D: return 0x10; // Keyboard m and M
  case 0x6E: return 0x11; // Keyboard n and N
  case 0x6F: return 0x12; // Keyboard o and O
  case 0x70: return 0x13; // Keyboard p and P
  case 0x71: return 0x14; // Keyboard q and Q
  case 0x72: return 0x15; // Keyboard r and R
  case 0x73: return 0x16; // Keyboard s and S
  case 0x74: return 0x17; // Keyboard t and T
  case 0x75: return 0x18; // Keyboard u and U
  case 0x76: return 0x19; // Keyboard v and V
  case 0x77: return 0x1A; // Keyboard w and W
  case 0x78: return 0x1B; // Keyboard x and X
  case 0x79: return 0x1C; // Keyboard y and Y
  case 0x7A: return 0x1D; // Keyboard z and Z
  case 0x31: case 0x21: return 0x1E; // Keyboard 1 and !
  case 0x32: case 0x40: return 0x1F; // Keyboard 2 and @
  case 0x33: case 0x23: return 0x20; // Keyboard 3 and #
  case 0x34: case 0x24: return 0x21; // Keyboard 4 and $
  case 0x35: case 0x25: return 0x22; // Keyboard 5 and %
  case 0x36: case 0x5E: return 0x23; // Keyboard 6 and ^
  case 0x37: case 0x26: return 0x24; // Keyboard 7 and &
  case 0x38: case 0x2A: return 0x25; // Keyboard 8 and *
  case 0x39: case 0x28: return 0x26; // Keyboard 9 and (
  case 0x30: case 0x29: return 0x27; // Keyboard 0 and )
  case 0xFF0Du: return 0x28; // Keyboard Return (ENTER)
  case 0xFF1Bu: return 0x29; // Keyboard ESCAPE
  case 0xFF08u: return 0x2A; // Keyboard DELETE (Backspace)
  case 0xFF09u: return 0x2B; // Keyboard Tab
  case 0x20: return 0x2C; // Keyboard Spacebar
  case 0x2D: case 0x5F: return 0x2D; // Keyboard - and (underscore)
  case 0x3D: case 0x2B: return 0x2E; // Keyboard = and +
  case 0x5B: case 0x7B: return 0x2F; // Keyboard [ and {
  case 0x5D: case 0x7D: return 0x30; // Keyboard ] and }
  case 0x5C: case 0x7C: return 0x31; // Keyboard \ and |
  // case unknown: return 0x32; // Keyboard Non-US # and ~
  case 0x3B: case 0x3A: return 0x33; // Keyboard ; and :
  case 0x27: case 0x22: return 0x34; // Keyboard ' and "
  case 0x60: case 0x7E: return 0x35; // Keyboard Grave Accent and Tilde
  case 0x2C: case 0x3C: return 0x36; // Keyboard, and <
  case 0x2E: case 0x3E: return 0x37; // Keyboard . and >
  case 0x2F: case 0x3F: return 0x38; // Keyboard / and ?
  // case unknown: return 0x39; // Keyboard Caps Lock
  case 0xFFBEu: return 0x3A; // Keyboard F1
  case 0xFFBFu: return 0x3B; // Keyboard F2
  case 0xFFC0u: return 0x3C; // Keyboard F3
  case 0xFFC1u: return 0x3D; // Keyboard F4
  case 0xFFC2u: return 0x3E; // Keyboard F5
  case 0xFFC3u: return 0x3F; // Keyboard F6
  case 0xFFC4u: return 0x40; // Keyboard F7
  case 0xFFC5u: return 0x41; // Keyboard F8
  case 0xFFC6u: return 0x42; // Keyboard F9
  case 0xFFC7u: return 0x43; // Keyboard F10
  case 0xFFC8u: return 0x44; // Keyboard F11
  case 0xFFC9u: return 0x45; // Keyboard F12
  case 0xFFCAu: return 0x46; // Keyboard PrintScreen
  // case unknown: return 0x47; // Keyboard Scroll Lock
  case 0xFF02u: return 0x48; // Keyboard Pause
  case 0xFF6Au: return 0x49; // Keyboard Insert
  case 0xFF50u: return 0x4A; // Keyboard Home
  case 0xFF55u: return 0x4B; // Keyboard PageUp
  case 0xFFFFu: return 0x4C; // Keyboard Delete Forward
  case 0xFF57u: return 0x4D; // Keyboard End
  case 0xFF56u: return 0x4E; // Keyboard PageDown
  case 0xFF53u: return 0x4F; // Keyboard RightArrow
  case 0xFF51u: return 0x50; // Keyboard LeftArrow
  case 0xFF54u: return 0x51; // Keyboard DownArrow
  case 0xFF52u: return 0x52; // Keyboard UpArrow
  // case unknown: return 0x53; // Keypad Num Lock and Clear
  case 0xFFAFu: return 0x54; // Keypad /
  case 0xFFAAu: return 0x55; // Keypad *
  case 0xFFADu: return 0x56; // Keypad -
  case 0xFFABu: return 0x57; // Keypad +
  case 0xFF8Du: return 0x58; // Keypad ENTER
  case 0xFFB1u: return 0x59; // Keypad 1 and End
  case 0xFFB2u: return 0x5A; // Keypad 2 and Down Arrow
  case 0xFFB3u: return 0x5B; // Keypad 3 and PageDn
  case 0xFFB4u: return 0x5C; // Keypad 4 and Left Arrow
  case 0xFFB5u: return 0x5D; // Keypad 5
  case 0xFFB6u: return 0x5E; // Keypad 6 and Right Arrow
  case 0xFFB7u: return 0x5F; // Keypad 7 and Home
  case 0xFFB8u: return 0x60; // Keypad 8 and Up Arrow
  case 0xFFB9u: return 0x61; // Keypad 9 and PageUp
  case 0xFFB0u: return 0x62; // Keypad 0 and Insert
  case 0xFFAEu: return 0x63; // Keypad . and Delete
  // case unknown: return 0x64; // Keyboard Non-US \ and |
  // case unknown: return 0x65; // Keyboard Application
  // case unknown: return 0x66; // Keyboard Power
  // case unknown: return 0x67; // Keypad =
  // case unknown: return 0x68; // Keyboard F13
  // case unknown: return 0x69; // Keyboard F14
  // case unknown: return 0x6A; // Keyboard F15
  // case unknown: return 0x6B; // Keyboard F16
  // case unknown: return 0x6C; // Keyboard F17
  // case unknown: return 0x6D; // Keyboard F18
  // case unknown: return 0x6E; // Keyboard F19
  // case unknown: return 0x6F; // Keyboard F20
  // case unknown: return 0x70; // Keyboard F21
  // case unknown: return 0x71; // Keyboard F22
  // case unknown: return 0x72; // Keyboard F23
  // case unknown: return 0x73; // Keyboard F24
  // case unknown: return 0x74; // Keyboard Execute
  // case unknown: return 0x75; // Keyboard Help
  // case unknown: return 0x76; // Keyboard Menu
  // case unknown: return 0x77; // Keyboard Select
  // case unknown: return 0x78; // Keyboard Stop
  // case unknown: return 0x79; // Keyboard Again
  // case unknown: return 0x7A; // Keyboard Undo
  // case unknown: return 0x7B; // Keyboard Cut
  // case unknown: return 0x7C; // Keyboard Copy
  // case unknown: return 0x7D; // Keyboard Paste
  // case unknown: return 0x7E; // Keyboard Find
  // case unknown: return 0x7F; // Keyboard Mute
  // case unknown: return 0x80; // Keyboard Volume Up
  // case unknown: return 0x81; // Keyboard Volume Down
  // case unknown: return 0x82; // Keyboard Locking Caps Lock
  // case unknown: return 0x83; // Keyboard Locking Num Lock
  // case unknown: return 0x84; // Keyboard Locking Scroll Lock
  // case unknown: return 0x85; // Keypad Comma
  // case unknown: return 0x86; // Keypad Equal Sign
  // case unknown: return 0x87; // Keyboard International1
  // case unknown: return 0x88; // Keyboard International2
  // case unknown: return 0x89; // Keyboard International3
  // case unknown: return 0x8A; // Keyboard International4
  // case unknown: return 0x8B; // Keyboard International5
  // case unknown: return 0x8C; // Keyboard International6
  // case unknown: return 0x8D; // Keyboard International7
  // case unknown: return 0x8E; // Keyboard International8
  // case unknown: return 0x8F; // Keyboard International9
  // case unknown: return 0x90; // Keyboard LANG1
  // case unknown: return 0x91; // Keyboard LANG2
  // case unknown: return 0x92; // Keyboard LANG3
  // case unknown: return 0x93; // Keyboard LANG4
  // case unknown: return 0x94; // Keyboard LANG5
  // case unknown: return 0x95; // Keyboard LANG6
  // case unknown: return 0x96; // Keyboard LANG7
  // case unknown: return 0x97; // Keyboard LANG8
  // case unknown: return 0x98; // Keyboard LANG9
  // case unknown: return 0x99; // Keyboard Alternate Erase
  // case unknown: return 0x9A; // Keyboard SysReq/Attention
  // case unknown: return 0x9B; // Keyboard Cancel
  // case unknown: return 0x9C; // Keyboard Clear
  // case unknown: return 0x9D; // Keyboard Prior
  // case unknown: return 0x9E; // Keyboard Return
  // case unknown: return 0x9F; // Keyboard Separator
  // case unknown: return 0xA0; // Keyboard Out
  // case unknown: return 0xA1; // Keyboard Oper
  // case unknown: return 0xA2; // Keyboard Clear/Again
  // case unknown: return 0xA3; // Keyboard CrSel/Props
  // case unknown: return 0xA4; // Keyboard ExSel
  // case 0xFFE3u: return 0xE0; // Keyboard LeftControl
  // case 0xFFE1u: return 0xE1; // Keyboard LeftShift
  // case 0xFE03u: return 0xE2; // Keyboard LeftAlt
  // case 0xFFE9u: return 0xE3; // Keyboard Left GUI
  // case 0xFFE4u: return 0xE4; // Keyboard RightControl
  // case 0xFFE2u: return 0xE5; // Keyboard RightShift
  // case 0xFF7Eu: return 0xE6; // Keyboard RightAlt
  // case 0xFFEBu: return 0xE7; // Keyboard Right GUI default:
  default: return 0;
  }
}


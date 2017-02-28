#ifndef _KEYS_H_
#define _KEYS_H_

#include <rfb/rfbproto.h>

uint8_t getModifier(rfbKeySym key);
uint8_t mapKey(rfbKeySym key);

#endif

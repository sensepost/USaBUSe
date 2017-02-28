#include <rfb/rfb.h>
#include <stdbool.h>
#include <sys/stat.h> 
#include <fcntl.h>
#include <ctype.h>
#include "keys.h"

static int fd = -1;

rfbBool openHidDevice(const char *path) {
  if (fd != -1)
    close(fd);
  fd = open(path, O_RDWR);
  return fd != -1;
}

void closeHidDevice(void) {
  if (fd != -1)
    close(fd);
  fd = -1;
}

rfbBool emitKeyEvent(rfbBool pressed, rfbKeySym key) {
  static uint8_t keys[9];
  uint8_t newKeys[9];
  int i;

  memcpy(newKeys, keys, sizeof(keys));
  newKeys[0] = 2; // report ID for the keyboard

  uint8_t modifier = getModifier(key);
  // printf("KM: %02X %04X\n", modifier, key);
  if (modifier != 0) {
    if (pressed) {
      newKeys[1] |= modifier;
      if ((newKeys[1] & (1<<1 | 1<<5)) == (1<<1 | 1<<5)) // left-shift && right-shift
      // reset key state
        memset(&newKeys[1], 0, sizeof(newKeys)-1);
    } else
      newKeys[1] &= ~modifier;
  }

  uint8_t mapkey = mapKey(key);
  // printf("KE: m: 0x%X, 0x%X => 0x%X, %s\n", modifier, key, mapkey, pressed ? "down" : "up");
  if (pressed) {
    bool found = false;
    for (i = 3; i < 9; i++)
      if (newKeys[i] == mapkey)
        found = true;
    if (! found) {
      for (i = 3; i < 9; i++)
        if (newKeys[i] == 0) {
          newKeys[i] = mapkey;
          break;
        }
    }
  } else {
    for (i = 3; i < 9; i++)
      if (newKeys[i] == mapkey)
        newKeys[i] = 0;
  }

  if (memcmp(keys, newKeys, sizeof(keys)) != 0) {
    // printf("KE: %02X %02X %02X %02X %02X %02X %02X %02X %02X\n", newKeys[0], newKeys[1], newKeys[2], newKeys[3], newKeys[4], newKeys[5], newKeys[6], newKeys[7], newKeys[8]);
    if (write(fd, newKeys, sizeof(newKeys)) != sizeof(newKeys))
      return false;
    memcpy(keys, newKeys, sizeof(keys));
  }
  return true;
}

static int8_t pointer_event[] = {1, 0, -1, -1, 0};

rfbBool emitPointerEvent(int mask, int x, int y, int z) {
  static int old_x = -1, old_y = -1;
  
  if (old_x != -1) {
    
    pointer_event[0] = 1; // report id for the mouse
    pointer_event[1] = mask;
    pointer_event[2] = x - old_x;
    pointer_event[3] = y - old_y;
    pointer_event[4] = z;
    if (write(fd, pointer_event, sizeof(pointer_event)) != sizeof(pointer_event))
      return false;
  }
  old_x = x;
  old_y = y;
  return true;
}

static void doptr(int buttonMask,int x,int y,rfbClientPtr cl)
{
  emitPointerEvent(buttonMask, x, y, 0); 
}

static void dokey(rfbBool down,rfbKeySym key,rfbClientPtr cl)
{
  emitKeyEvent(down, key);
}

void dopaste(char* str,int len,rfbClientPtr cl) {
  int i;
  for (i=0; i<len; i++) {
    rfbKeySym key = str[i];
    switch(key) {
    case 0x0A: key = 0xFF0Du; break; // Keyboard Return (ENTER)
    case 0x09: key = 0xFF09u; break; // Keyboard Tab
    }
    dokey(true, key, cl);
    dokey(false, key, cl);
  }
}

int main(int argc,char** argv)
{                                                                
  if (!openHidDevice("/dev/hidg0")) {
    perror("Could not open the hid device");
    exit(1);
  }
  rfbScreenInfoPtr server=rfbGetScreen(&argc,argv,1024,768,1,1,1);
  if(!server)
    return 0;
  server->frameBuffer=(char*)malloc(1024*768);
  server->ptrAddEvent = doptr;
  server->kbdAddEvent = dokey;
  server->setXCutText = dopaste;
  rfbInitServer(server);           
  rfbRunEventLoop(server,-1,FALSE);
  closeHidDevice();
  return(0);
}

#include "../../hal/sound_hal.h"
#include <stdio.h>

void sound_hal_init(void) {}
void sound_hal_tick(void) {}
void sound_hal_play(Sound s) { printf("[sim] chime! (%s)\n", s == SOUND_DONE ? "done" : s == SOUND_ASK ? "ask" : "session reset"); }

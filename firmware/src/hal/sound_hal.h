#pragma once

// Optional audio output (a passive piezo buzzer driven by LEDC PWM). Chimes
// when the Claude session limit resets, a task finishes, or Claude Code asks. Boards without a buzzer — the
// AMOLED-1.8 and the C6, whose stock hardware has no speaker output — no-op on
// init/tick and ignore play requests.
//
// Playback is non-blocking: sound_hal_play() only *queues* the chime and
// returns immediately; sound_hal_tick() (called every loop) advances the notes
// so the LVGL render loop never stalls.

void sound_hal_init(void);
void sound_hal_tick(void);
enum Sound { SOUND_RESET, SOUND_ASK };

void sound_hal_play(Sound s);

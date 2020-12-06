#if !defined(OSX_MAIN_H)

#import <AudioToolbox/AudioToolbox.h>
#include "handmade.h"

const uint16 UpArrowKeyCode = 0x7E;
const uint16 DownArrowKeyCode = 0x7D;
const uint16 LeftArrowKeyCode = 0x7B;
const uint16 RightArrowKeyCode = 0x7C;
const uint16 AKeyCode = 0x00;
const uint16 SKeyCode = 0x01;
const uint16 DKeyCode = 0x02;
const uint16 FKeyCode = 0x03;
const uint16 WKeyCode = 0x0D;
const uint16 EKeyCode = 0x0E;

struct osx_game_controller
{
  uint32 Button1UsageId;
  uint32 Button2UsageId;
  uint32 Button3UsageId;
  uint32 Button4UsageId;
  uint32 Button5UsageId;
  uint32 Button6UsageId;

  bool32 Button1State;
  bool32 Button2State;
  bool32 Button3State;
  bool32 Button4State;
  bool32 Button5State;
  bool32 Button6State;
  int32 DPadX;
  int32 DPadY;
};

struct osx_sound_output
{
  uint32 SamplesPerSecond;
  uint32 BytesPerSample;
  uint32 BufferSize;
  uint32 WriteCursor;
  // NOTE: This isn't the real sound card play cursor.
  // it is just the last time CoreAudio called us.
  uint32 PlayCursor;
  void *Data;
  AudioComponentInstance *AudioUnit;
};

struct osx_game_code
{
  void *GameCodeDLL;
  game_update_and_render *UpdateAndRender;
  game_get_sound_samples *GetSoundSamples;
  bool32 IsValid;
};

#define OSX_MAIN_H
#endif

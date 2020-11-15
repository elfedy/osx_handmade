#include <stdio.h>
#include <AppKit/AppKit.h>
#import <IOKit/hid/IOHIDLib.h>
#import <AudioToolbox/AudioToolbox.h>
#include "osx_main.h"
#include <math.h>
#include <mach/mach_init.h>
#include <mach/mach_time.h>
#include "../cpp/code/handmade.cpp"


global_variable bool GlobalRunning = true;

internal void osxRefreshBuffer(game_offscreen_buffer *bitmap, NSWindow *window)
{
    if(bitmap->Memory) {
      free(bitmap->Memory);
    }
    bitmap->Width = window.contentView.bounds.size.width;
    bitmap->Height =  window.contentView.bounds.size.height;
    bitmap->BytesPerPixel = 4;
    bitmap->Pitch = bitmap->Width * bitmap->BytesPerPixel;
    int bufferSize = bitmap->Pitch * bitmap->Height;
    bitmap->Memory = (uint8_t *)malloc(bufferSize);
}

internal void osxRedrawBuffer(game_offscreen_buffer *bitmap, NSWindow *window)
{
    uint8_t *planes[1] = {bitmap->Memory};
    @autoreleasepool {
        NSBitmapImageRep *imageRep = [[[NSBitmapImageRep alloc]
                                 initWithBitmapDataPlanes: planes
                                 pixelsWide: bitmap->Width
                                 pixelsHigh: bitmap->Height
                                 bitsPerSample: 8
                                 samplesPerPixel: bitmap->BytesPerPixel
                                 hasAlpha: true
                                 isPlanar: false
                                 colorSpaceName: NSDeviceRGBColorSpace
                                 bytesPerRow: bitmap->Pitch
                                 bitsPerPixel: 8 * bitmap->BytesPerPixel] autorelease];
        NSSize imageSize = NSMakeSize(bitmap->Width, bitmap->Height);
        NSImage *image = [[[NSImage alloc] initWithSize: imageSize] autorelease];
        [image addRepresentation: imageRep];
        window.contentView.layer.contents = image;
    }
}

// Define a class that inherits from NSObject and implements the NSWindowDelegate interface
// the methods defined here are called when window events happen (closing window, window resize, etc)
@interface HandmadeWindowDelegate: NSObject<NSWindowDelegate>;
@end

@implementation HandmadeWindowDelegate

-(void)windowWillClose:(NSNotification *)notification {
    GlobalRunning = false;
}

@end

@interface KeyIgnoringWindow: NSWindow
@end

@implementation KeyIgnoringWindow
-(void)keyDown:(NSEvent *)theEvent{ }
@end


// Callback to be run when device input that was asked for in ControllerConnected
// happens
internal void ControllerInput(void *context, IOReturn result, void *sender, IOHIDValueRef value)
{
  if(result != kIOReturnSuccess) {
      return;
  }

  osx_game_controller *osxGameController = (osx_game_controller *)context;

  IOHIDElementRef Element = IOHIDValueGetElement(value);
  uint32 UsagePage = IOHIDElementGetUsagePage(Element);
  uint32 Usage = IOHIDElementGetUsage(Element);

  // Buttons
  if(UsagePage == kHIDPage_Button) 
  {
      int buttonState = IOHIDValueGetIntegerValue(value); 

      if(Usage == osxGameController->Button1UsageId)
      {
        osxGameController->Button1State = buttonState;
      }
      else if(Usage == osxGameController->Button2UsageId)
      {
        osxGameController->Button2State = buttonState;
      }
      else if(Usage == osxGameController->Button3UsageId)
      {
        osxGameController->Button3State = buttonState;
      }
      else if(Usage == osxGameController->Button4UsageId)
      {
        osxGameController->Button4State = buttonState;
      }
      else if(Usage == osxGameController->Button5UsageId)
      {
        osxGameController->Button5State = buttonState;
      }
      else if(Usage == osxGameController->Button6UsageId)
      {
        osxGameController->Button6State = buttonState;
      }
  }
  else if(UsagePage == kHIDPage_GenericDesktop)
  {
    int elementValue = IOHIDValueGetIntegerValue(value);
    float normalizedValue = 0.0;
    long min = IOHIDElementGetLogicalMin(Element);
    long max = IOHIDElementGetLogicalMax(Element);

    if(min != max)
    {
      normalizedValue = (float)(elementValue - min) / (float)(max - min);
    }

    float scaledMin = -25.0;
    float scaledMax = 25.0;

    int scaledValue = scaledMin + normalizedValue * (scaledMax - scaledMin);
    
    if(Usage == kHIDUsage_GD_Y)
    {
      osxGameController->DPadY = scaledValue;
    }
    if(Usage == kHIDUsage_GD_X)
    {
      osxGameController->DPadX = scaledValue;
    }
  }
}

// Callback that runs when the OS detects a device matching the criteria we specified 
// in osxSetupGameController 
internal void ControllerConnected(void *context, IOReturn result, void *sender, IOHIDDeviceRef device)
{
    if(result != kIOReturnSuccess) {
        printf("Error during Controller Connected callback\n");
        return;
    }

    NSUInteger vendorID = [(__bridge NSNumber *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDVendorIDKey)) unsignedIntegerValue];
    NSUInteger productID = [(__bridge NSNumber *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductIDKey)) unsignedIntegerValue];


    osx_game_controller *osxGameController = (osx_game_controller *)context;

    //NOTE(Fede): This is hardcoded to the actual controller I have but should be controller independent code somehow
    osxGameController->Button1UsageId = 0x01;
    osxGameController->Button2UsageId = 0x02;
    osxGameController->Button3UsageId = 0x03;
    osxGameController->Button4UsageId = 0x04;
    osxGameController->Button5UsageId = 0x05;
    osxGameController->Button6UsageId = 0x06;

    // Set a callback to run when input from the device that matches the criteria is detected
    IOHIDDeviceRegisterInputValueCallback(device, ControllerInput, (void *)osxGameController);

    // Set matching criteria for device input so that a callback is run any time this type of input happens
    IOHIDDeviceSetInputValueMatchingMultiple(device, (__bridge CFArrayRef)@[
      @{@(kIOHIDElementUsagePageKey): @(kHIDPage_GenericDesktop)},
      @{@(kIOHIDElementUsagePageKey): @(kHIDPage_Button)},
    ]);

}

internal void osxSetupGameController(osx_game_controller *osxGameController)
{
    // Object the app uses to manage IOHID
    IOHIDManagerRef HIDManager = IOHIDManagerCreate(kCFAllocatorDefault, 0);
    if(IOHIDManagerOpen(HIDManager, kIOHIDOptionsTypeNone) != kIOReturnSuccess)
    {
        printf("Error initializing OSX Handmade Controllers\n");
        return;
    }

    // Set criteria to get devices that our app will use
		IOHIDManagerSetDeviceMatchingMultiple(HIDManager, (__bridge CFArrayRef)@[ @{ [NSString stringWithUTF8String:kIOHIDDeviceUsagePageKey]:
											[NSNumber numberWithInt:kHIDPage_GenericDesktop],
										[NSString stringWithUTF8String:kIOHIDDeviceUsageKey]:
											[NSNumber numberWithInt:kHIDUsage_GD_Joystick]
										},
									@{ (NSString*)CFSTR(kIOHIDDeviceUsagePageKey):
											[NSNumber numberWithInt:kHIDPage_GenericDesktop],
										(NSString*)CFSTR(kIOHIDDeviceUsageKey):
											[NSNumber numberWithInt:kHIDUsage_GD_GamePad]
										},
									@{ (NSString*)CFSTR(kIOHIDDeviceUsagePageKey):
											[NSNumber numberWithInt:kHIDPage_GenericDesktop],
										(NSString*)CFSTR(kIOHIDDeviceUsageKey):
											[NSNumber numberWithInt:kHIDUsage_GD_MultiAxisController]
										 }]);

    // Register a callback that our app will use when the Manager detects a device matching our criteria
    IOHIDManagerRegisterDeviceMatchingCallback(HIDManager, ControllerConnected, (void *)osxGameController);

    // We need to add the Manager to the main run loop in order for it to do its work
    IOHIDManagerScheduleWithRunLoop(HIDManager, CFRunLoopGetMain(), kCFRunLoopDefaultMode);

}

// NOTE(Fede): This is what CoreAudio calls to play sound. We pass it the sound output
// And we copy the contents of the circular buffer into the AudioBufferList first
// buffer.
internal OSStatus
OsxCoreAudioRenderCallback(
  void *inRefCon,
  AudioUnitRenderActionFlags *ioActionFlags,
  const AudioTimeStamp *inTimeStamp,
  uint32 inBusNumber,
  uint32 inNumberFrames,
  AudioBufferList *ioData
)
{
  osx_sound_output *SoundOutput = (osx_sound_output *)inRefCon;

  uint32 BytesToOutput = inNumberFrames * SoundOutput->BytesPerSample;

  // Region 1 is the number of bytes up to the end of the sound buffer.
  // If the frames to be rendered causes us to wrap, the remainder goes into Region 2
  uint32 Region1Size = BytesToOutput;
  uint32 Region2Size = 0;

  // case where we wrap
  if(SoundOutput->PlayCursor + BytesToOutput > SoundOutput->BufferSize)
  {
    // Region 1 is the distance from the PlayCursor to the end of the
    // sound buffer, a.k.a. BufferSize
    Region1Size = SoundOutput->BufferSize - SoundOutput->PlayCursor;

    Region2Size = BytesToOutput - Region1Size;
  }

  uint8 *Channel = (uint8 *)ioData->mBuffers[0].mData;

  memcpy(Channel, (uint8 *)SoundOutput->Data + SoundOutput->PlayCursor, Region1Size);
  memcpy(&Channel[Region1Size], SoundOutput->Data, Region2Size);

  // Finally move the play cursor
  SoundOutput->PlayCursor = (SoundOutput->PlayCursor + BytesToOutput) % SoundOutput->BufferSize;
  return noErr;
}

// Fill in the SoundOutput struct that we are going to use
// to interact with Core Audio and set up the callback that gets called whenever
// Core Audio's buffers need to be filled with new data to play.
internal void OsxSetupAudio(osx_sound_output *SoundOutput)
{
  // 48 kHz sound
  SoundOutput->SamplesPerSecond = 48000;
  // two 2 byte channels (stereo)
  int32 AudioFrameSize = sizeof(int16) * 2;
  int32 NumberOfSeconds = 2;
  SoundOutput->BytesPerSample = AudioFrameSize;

  //Allocate a two second sound buffer
  SoundOutput->BufferSize = SoundOutput->SamplesPerSecond * AudioFrameSize * NumberOfSeconds;
  SoundOutput->Data = malloc(SoundOutput->BufferSize);
  SoundOutput->PlayCursor = 0;


  AudioComponentInstance AudioUnit;
  SoundOutput->AudioUnit = &AudioUnit;
  // Add information for the audio component
  AudioComponentDescription Acd;
  Acd.componentType = kAudioUnitType_Output; 
  Acd.componentSubType = kAudioUnitSubType_DefaultOutput;
  Acd.componentManufacturer = kAudioUnitManufacturer_Apple;
  Acd.componentFlags = 0;
  Acd.componentFlagsMask = 0;

  // Ask OSX to get an Audio Component that matches our component description
  AudioComponent OutputComponent = AudioComponentFindNext(NULL, &Acd);
  OSStatus status = AudioComponentInstanceNew(OutputComponent, SoundOutput->AudioUnit);

  if(status != noErr) {
    printf("There was an error setting up sound.\n");
    return;
  }

  // Describe the format of our audio
  AudioStreamBasicDescription AudioDescriptor;
  AudioDescriptor.mSampleRate = SoundOutput->SamplesPerSecond;
  AudioDescriptor.mFormatID = kAudioFormatLinearPCM;
  AudioDescriptor.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
  int framesPerPacket = 1;
  int bytesPerFrame = sizeof(int16) * 2;
  AudioDescriptor.mFramesPerPacket = 1;
  AudioDescriptor.mChannelsPerFrame = 2; // Stereo sound
  AudioDescriptor.mBitsPerChannel = sizeof(int16) * 8;
  AudioDescriptor.mBytesPerFrame = SoundOutput->BytesPerSample;
  AudioDescriptor.mBytesPerPacket = SoundOutput->BytesPerSample;

  // Set the format to  our audio unit
  status = AudioUnitSetProperty(
    *SoundOutput->AudioUnit, 
    kAudioUnitProperty_StreamFormat,
    kAudioUnitScope_Input,
    0,
    &AudioDescriptor,
    sizeof(AudioDescriptor)
  );

  if(status != noErr) {
    printf("There was an error setting up sound.\n");
    return;
  }

  // Set the callback that gets called when the OS needs more data to be processed
  AURenderCallbackStruct RenderCallback;
  RenderCallback.inputProcRefCon = (void *)SoundOutput;
  RenderCallback.inputProc = OsxCoreAudioRenderCallback;

  status = AudioUnitSetProperty(
    *SoundOutput->AudioUnit, 
    kAudioUnitProperty_SetRenderCallback,
    kAudioUnitScope_Global,
    0,
    &RenderCallback,
    sizeof(RenderCallback)
  );

  if(status != noErr) {
    printf("There was an error setting up sound.\n");
    return;
  }

  AudioUnitInitialize(*SoundOutput->AudioUnit);
  AudioOutputUnitStart(*SoundOutput->AudioUnit);
}

internal void OsxProcessGameControllerButton(game_button_state *OldState,
  game_button_state *NewState,
  bool32 IsDown)
{
  NewState->EndedDown = IsDown;
  NewState->HalfTransitionCount += ((NewState->EndedDown == OldState->EndedDown) ? 0 : 1);
}

int main(int argc, const char *argv[])
{
    double RenderWidth = 1024;
    double RenderHeight = 768;

    NSRect screenRect = [[NSScreen mainScreen] frame];
    NSRect initialFrame = NSMakeRect(
                                    (screenRect.size.width - RenderWidth) * 0.5,
                                    (screenRect.size.height - RenderHeight) * 0.5,
                                    RenderWidth,
                                    RenderHeight);
    NSWindow *window = [[KeyIgnoringWindow alloc] initWithContentRect: initialFrame
                                                    styleMask: NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable
                                                    backing: NSBackingStoreBuffered
                                                       defer: NO];
    
    game_offscreen_buffer bitmap = {};

    [window setBackgroundColor: NSColor.blackColor];
    [window setTitle: @"Handmade Hero"];
    [window makeKeyAndOrderFront: nil];
    
    HandmadeWindowDelegate *windowDelegate = [[HandmadeWindowDelegate alloc] init];
    [window setDelegate: windowDelegate];
    window.contentView.wantsLayer = true;

    osxRefreshBuffer(&bitmap, window);
    
    uint8_t red = 255;
    uint8_t blue = 0;
    uint8_t green = 0;
    uint8_t alpha = 255;

    uint8 offsetX = 0;
    uint8 offsetY = 0;

    osx_game_controller osxGameController = {};
    osxSetupGameController(&osxGameController);

    osx_game_controller osxKeyboardController = {};

    osx_game_controller *OsxControllers[2] = { &osxKeyboardController, &osxGameController };
    game_input Input[2] = {};
    game_input *NewInput = &Input[0];
    game_input *OldInput = &Input[1];

    osx_sound_output SoundOutput = {};
    OsxSetupAudio(&SoundOutput);

    game_sound_output_buffer SoundBuffer = {};
    int16 *Samples = (int16 *)calloc(
        SoundOutput.SamplesPerSecond,
        SoundOutput.BytesPerSample
      );
    SoundBuffer.SamplesPerSecond = SoundOutput.SamplesPerSecond;

    // Let's be a 15th of a second ahead of the play cursor
    int32 LatencySampleCount = SoundOutput.SamplesPerSecond / 15;
    int32 TargetQueueBytes = LatencySampleCount * SoundOutput.BytesPerSample;
    
    local_persist uint32 RunningSampleIndex = 0;

    mach_timebase_info_data_t TimeBase;
    mach_timebase_info(&TimeBase);

    uint64 LastCounter = mach_absolute_time();
    while(GlobalRunning)
    {
        // Process app incoming events
        NSEvent* Event;

        do {
            Event = [NSApp nextEventMatchingMask: NSEventMaskAny
                                    untilDate: nil
                                    inMode: NSDefaultRunLoopMode
                                    dequeue: YES];
            switch ([Event type]) {
                case NSEventTypeKeyDown:
                    if(Event.keyCode == UpArrowKeyCode) {
                      osxKeyboardController.DPadY = -25;
                    }
                    if(Event.keyCode == DownArrowKeyCode) {
                      osxKeyboardController.DPadY = 25;
                    }
                    if(Event.keyCode == RightArrowKeyCode) {
                      osxKeyboardController.DPadX = 25;
                    }
                    if(Event.keyCode == LeftArrowKeyCode) {
                      osxKeyboardController.DPadX = -25;
                    }
                    if(Event.keyCode == AKeyCode) {
                      osxKeyboardController.Button1State = true;
                    }
                    if(Event.keyCode == SKeyCode) {
                      osxKeyboardController.Button2State = true;
                    }
                    if(Event.keyCode == DKeyCode) {
                      osxKeyboardController.Button3State = true;
                    }
                    if(Event.keyCode == FKeyCode) {
                      osxKeyboardController.Button4State = true;
                    }
                    if(Event.keyCode == WKeyCode) {
                      osxKeyboardController.Button5State = true;
                    }
                    if(Event.keyCode == EKeyCode) {
                      osxKeyboardController.Button6State = true;
                    }
                    break;
                case NSEventTypeKeyUp:
                    if(Event.keyCode == UpArrowKeyCode) {
                      if(osxKeyboardController.DPadY == -25) {
                        osxKeyboardController.DPadY = 0;
                      }
                    }
                    if(Event.keyCode == DownArrowKeyCode) {
                      if(osxKeyboardController.DPadY == 25) {
                        osxKeyboardController.DPadY = 0;
                      }
                    }
                    if(Event.keyCode == RightArrowKeyCode) {
                      if(osxKeyboardController.DPadX == 25) {
                        osxKeyboardController.DPadX = 0;
                      }
                    }
                    if(Event.keyCode == LeftArrowKeyCode) {
                      if(osxKeyboardController.DPadX == -25) {
                        osxKeyboardController.DPadX = 0;
                      }
                    }
                    if(Event.keyCode == AKeyCode) {
                      osxKeyboardController.Button1State = false;
                    }
                    if(Event.keyCode == SKeyCode) {
                      osxKeyboardController.Button2State = false;
                    }
                    if(Event.keyCode == DKeyCode) {
                      osxKeyboardController.Button3State = false;
                    }
                    if(Event.keyCode == FKeyCode) {
                      osxKeyboardController.Button4State = false;
                    }
                    if(Event.keyCode == WKeyCode) {
                      osxKeyboardController.Button5State = false;
                    }
                    if(Event.keyCode == EKeyCode) {
                      osxKeyboardController.Button6State = false;
                    }
                    break;
                default:
                    break;
            }
            [NSApp sendEvent: Event];
        } while(Event != nil);

        game_input *Temp = NewInput;
        NewInput = OldInput;
        OldInput = Temp;

        for (int osxControllerIndex = 0; osxControllerIndex < 2; osxControllerIndex++)
        {
          osx_game_controller *OsxController = OsxControllers[osxControllerIndex];

          game_controller_input *OldController = &OldInput->Controllers[osxControllerIndex];
          game_controller_input *NewController = &NewInput->Controllers[osxControllerIndex];

          OsxProcessGameControllerButton(
            &(OldController->ActionLeft),
            &(NewController->ActionLeft),
            OsxController->Button1State
          );
          OsxProcessGameControllerButton(
            &(OldController->ActionUp),
            &(NewController->ActionUp),
            OsxController->Button2State
          );
          OsxProcessGameControllerButton(
            &(OldController->ActionRight),
            &(NewController->ActionRight),
            OsxController->Button3State
          );
          OsxProcessGameControllerButton(
            &(OldController->ActionDown),
            &(NewController->ActionDown),
            OsxController->Button4State
          );
          OsxProcessGameControllerButton(
            &(OldController->LeftShoulder),
            &(NewController->LeftShoulder),
            OsxController->Button5State
          );
          OsxProcessGameControllerButton(
            &(OldController->RightShoulder),
            &(NewController->RightShoulder),
            OsxController->Button6State
          );

          bool32 Right = OsxController->DPadX > 0;
          bool32 Left = OsxController->DPadX < 0;
          bool32 Down = OsxController->DPadY > 0;
          bool32 Up = OsxController->DPadY < 0;

          OsxProcessGameControllerButton(
            &(OldController->MoveRight),
            &(NewController->MoveRight),
            Right
          );
          OsxProcessGameControllerButton(
            &(OldController->MoveLeft),
            &(NewController->MoveLeft),
            Left
          );
          OsxProcessGameControllerButton(
            &(OldController->MoveUp),
            &(NewController->MoveUp),
            Up
          );
          OsxProcessGameControllerButton(
            &(OldController->MoveDown),
            &(NewController->MoveDown),
            Down
          );
        }

        
        uint32 TargetCursor = ((SoundOutput.PlayCursor + TargetQueueBytes) % SoundOutput.BufferSize);

        int32 ByteToLock = (RunningSampleIndex * SoundOutput.BytesPerSample) % SoundOutput.BufferSize;
        int32 BytesToWrite;

        if(ByteToLock > TargetCursor) {
          // Play cursor wrapped

          // Bytes to the end of the circular buffer.
          BytesToWrite = (SoundOutput.BufferSize - ByteToLock);

          // Bytes up to the target cursor.
          BytesToWrite += TargetCursor;
        } else {
          BytesToWrite = TargetCursor - ByteToLock;
        }

        SoundBuffer.Samples = Samples;
        SoundBuffer.SampleCount = (BytesToWrite/SoundOutput.BytesPerSample);
        GameUpdateAndRender(NewInput, &bitmap, &SoundBuffer);
        osxRedrawBuffer(&bitmap, window);

        void *Region1 = (uint8 *)SoundOutput.Data + ByteToLock;
        uint32 Region1Size = BytesToWrite;

        if(Region1Size + ByteToLock > SoundOutput.BufferSize) {
          Region1Size = SoundOutput.BufferSize - ByteToLock;
        }

        void *Region2 = (uint8 *)SoundOutput.Data;
        uint32 Region2Size = BytesToWrite - Region1Size;

        uint32 Region1SampleCount = Region1Size / SoundOutput.BytesPerSample;
        int16 *SampleOut = (int16*)Region1;

        real32 ToneVolume = 5000;

        for(int SampleIndex = 0; SampleIndex < Region1SampleCount; ++SampleIndex)
        {
          *SampleOut++ = *SoundBuffer.Samples++;
          *SampleOut++ = *SoundBuffer.Samples++;
          RunningSampleIndex++;
        }

        uint32 Region2SampleCount = Region2Size / SoundOutput.BytesPerSample;
        SampleOut = (int16*)Region2;

        for(int SampleIndex = 0; SampleIndex < Region2SampleCount; ++SampleIndex)
        {
          *SampleOut++ = *SoundBuffer.Samples++;
          *SampleOut++ = *SoundBuffer.Samples++;
          RunningSampleIndex++;
        }
      
        // End of Frame
        uint64 EndOfFrameTime = mach_absolute_time();
        uint64 TimeUnitsPerFrame = EndOfFrameTime - LastCounter;

        uint64 NanosecondsPerFrame = TimeUnitsPerFrame * (TimeBase.numer / TimeBase.denom);
        real32 SecondsPerFrame = (real32)NanosecondsPerFrame * 1.0E-9;
        real32 FramesPerSecond = 1 / SecondsPerFrame;

        printf("Frames per second: %f\n", FramesPerSecond);

        LastCounter = mach_absolute_time();
    }

    printf("Handmade finished running\n");
}

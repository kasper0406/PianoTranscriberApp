#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

typedef struct MidiEvent {
  uint64_t attack_time;
  uint8_t note;
  uint64_t duration;
  uint8_t velocity;
} MidiEvent;

typedef struct MidiEventList {
  struct MidiEvent *ptr;
  uintptr_t length;
  uintptr_t _capacity;
} MidiEventList;

typedef struct MLMultiArrayWrapper_3 {
  uint64_t strides[3];
  uint64_t dims[3];
  const uint8_t *data;
} MLMultiArrayWrapper_3;

typedef struct MLMultiArrayWrapper_3 MLMultiArrayWrapper3;

struct MidiEventList *extract_midi_events(MLMultiArrayWrapper3 data,
                                          double overlap,
                                          double duration_per_frame);

void free_midi_events(struct MidiEventList *ptr);

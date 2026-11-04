/* Solar Tracker MANUAL V7 — Nano ATmega328P, 16 MHz.
   Barcha motor buyruqlari TrackerControl.h orqali o'tadi. AUTO yo'q. */
#include <Arduino.h>
#include <OneButton.h>
#include <avr/pgmspace.h>
#include <stdio.h>
#include <string.h>
#include "TrackerControl.h"
#include "TrackerDisplay.h"

using namespace tracker;
enum KeyIndex : uint8_t { K_L, K_R, K_U, K_D, K_M };
const uint8_t KEY_PINS[5] = {6, 5, 7, 8, 4};
const uint8_t RELAY_PINS[4] = {12, 11, 10, 9};
const uint8_t LIMIT_L_PIN = 3, LIMIT_R_PIN = 2;
OneButton buttons[5];
AxisController axes[2]; // H: NEG=L, POS=R; V: NEG=DN, POS=UP.
AnalogLimit topLimit, downLimit;
uint8_t doubleEvents = 0, singleEvents = 0, midEvents = 0;
bool globalReleaseGate = true;
bool allUpTiming = false;
uint32_t allUpAt = 0;
bool relayOn[4] = {false, false, false, false};

// Callbacklar faqat hodisa qayd etadi.
void clickL() { singleEvents |= 1U << K_L; }
void clickR() { singleEvents |= 1U << K_R; }
void clickU() { singleEvents |= 1U << K_U; }
void clickD() { singleEvents |= 1U << K_D; }
void doubleL() { doubleEvents |= 1U << K_L; }
void doubleR() { doubleEvents |= 1U << K_R; }
void doubleU() { doubleEvents |= 1U << K_U; }
void doubleD() { doubleEvents |= 1U << K_D; }
void midClick() { midEvents |= 1; }
void midDouble() { midEvents |= 2; }
void midLong() { midEvents |= 4; }

// Rele GPIO yozuvlarining yagona egasi; avval OFF, keyin ON.
void applyRelayOutputs(bool initialize = false) {
  bool wanted[4] = {
    axes[0].activeDir == NEG, axes[0].activeDir == POS,
    axes[1].activeDir == POS, axes[1].activeDir == NEG
  };
  for (uint8_t i = 0; i < 4; ++i) {
    if (initialize || (relayOn[i] && !wanted[i])) {
      digitalWrite(RELAY_PINS[i], HIGH);
      relayOn[i] = false;
    }
  }
  if (initialize) {
    for (uint8_t i = 0; i < 4; ++i) pinMode(RELAY_PINS[i], OUTPUT);
    return;
  }
  for (uint8_t i = 0; i < 4; ++i) {
    if (wanted[i] && !relayOn[i]) {
      digitalWrite(RELAY_PINS[i], LOW);
      relayOn[i] = true;
    }
  }
}

void requestGlobalStop() {
  globalReleaseGate = true;
  allUpTiming = false;
}

void serviceSafety() {
  for (uint8_t k = 0; k < 5; ++k) buttons[k].tick();
  bool down[5];
  bool rawAllUp = true;
  bool debouncedAllUp = true;
  for (uint8_t k = 0; k < 5; ++k) {
    down[k] = buttons[k].debouncedValue() != 0; // OneButton 2.6.2: true=bosilgan.
    if (down[k]) debouncedAllUp = false;
    if (digitalRead(KEY_PINS[k]) == LOW) rawAllUp = false;
  }
  topLimit.sample(analogRead(A6));
  downLimit.sample(analogRead(A7));
  bool leftLimit = digitalRead(LIMIT_L_PIN) == LOW;
  bool rightLimit = digitalRead(LIMIT_R_PIN) == LOW;
  uint32_t now = millis();
  if (midEvents & 4) requestGlobalStop();
  if (globalReleaseGate) {
    if (!rawAllUp) allUpTiming = false;
    else if (!allUpTiming) { allUpTiming = true; allUpAt = now; }
    else if (debouncedAllUp && elapsed(now, allUpAt, DEBOUNCE_MS)) {
      globalReleaseGate = false;
      allUpTiming = false;
      for (uint8_t k = 0; k < 5; ++k) buttons[k].reset();
    }
  } else {
    if (midEvents & 1) tracker_display::nextSlide(now);
    if (midEvents & 2) tracker_display::lockSlide(now);
  }
  midEvents = 0;
  axes[0].update(now, down[K_L], down[K_R], doubleEvents & 3, singleEvents & 3,
                 leftLimit, rightLimit, false, globalReleaseGate);
  uint8_t vDouble = ((doubleEvents >> K_D) & 1) | (((doubleEvents >> K_U) & 1) << 1);
  uint8_t vSingle = ((singleEvents >> K_D) & 1) | (((singleEvents >> K_U) & 1) << 1);
  axes[1].update(now, down[K_D], down[K_U], vDouble, vSingle,
                 downLimit.pressed, topLimit.pressed,
                 downLimit.uncertain || topLimit.uncertain, globalReleaseGate);
  doubleEvents = singleEvents = 0;
  applyRelayOutputs();
  if (axes[0].takeReset(0)) buttons[K_L].reset();
  if (axes[0].takeReset(1)) buttons[K_R].reset();
  if (axes[1].takeReset(0)) buttons[K_D].reset();
  if (axes[1].takeReset(1)) buttons[K_U].reset();
}

// ON ko'rsatkichi GPIO buyrug'idan olinadi; kontakt feedback mavjud emas.
void motorStatus(char (&text)[17]) {
  strcpy_P(text, PSTR("MAN "));
  uint8_t n = 4;
  if (relayOn[K_L]) text[n++] = 'L';
  else if (relayOn[K_R]) text[n++] = 'R';
  if (relayOn[K_U] || relayOn[K_D]) {
    if (n > 4) text[n++] = '+';
    text[n++] = relayOn[K_U] ? 'U' : 'D';
    text[n++] = relayOn[K_U] ? 'P' : 'N';
  }
  text[n] = 0;
  bool moving = n > 4;
  bool fault = axes[0].state == FAULT || axes[1].state == FAULT;
  bool timeout = axes[0].state == TIMEOUT || axes[1].state == TIMEOUT;
  bool limited = axes[0].state == LIMIT_BLOCKED || axes[1].state == LIMIT_BLOCKED;
  bool waiting = axes[0].pendingDir != STOP || axes[1].pendingDir != STOP;
  if (moving) {
    if (fault) strcat_P(text, PSTR(" F!"));
    else if (timeout) strcat_P(text, PSTR(" T!"));
    else if (limited) strcat_P(text, PSTR(" LIM"));
    else if (waiting) strcat_P(text, PSTR(" WAIT"));
  } else if (fault) strcpy_P(text, PSTR("MAN FAULT"));
  else if (timeout) strcpy_P(text, PSTR("MAN TIMEOUT"));
  else if (limited) {
    char direction = axes[0].state == LIMIT_BLOCKED ?
      (axes[0].blockedDir == NEG ? 'L' : 'R') :
      (axes[1].blockedDir == NEG ? 'D' : 'U');
    snprintf_P(text, sizeof(text), PSTR("MAN LIMIT-%c"), direction);
  } else if (waiting) strcpy_P(text, PSTR("MAN WAIT"));
  else strcpy_P(text, PSTR("MAN STOP"));
}

void setup() {
  applyRelayOutputs(true);
  pinMode(LIMIT_L_PIN, INPUT_PULLUP);
  pinMode(LIMIT_R_PIN, INPUT_PULLUP);
  // A6/A7 analog-only: tashqi 20 kOhm pull-up, pinMode chaqirilmaydi.
  for (uint8_t k = 0; k < 5; ++k) {
    buttons[k].setup(KEY_PINS[k], INPUT_PULLUP, true);
    buttons[k].setDebounceMs(DEBOUNCE_MS);
    buttons[k].setClickMs(CLICK_WINDOW_MS);
    buttons[k].setPressMs(MID_LONG_MS);
  }
  buttons[K_L].attachClick(clickL); buttons[K_L].attachDoubleClick(doubleL);
  buttons[K_R].attachClick(clickR); buttons[K_R].attachDoubleClick(doubleR);
  buttons[K_U].attachClick(clickU); buttons[K_U].attachDoubleClick(doubleU);
  buttons[K_D].attachClick(clickD); buttons[K_D].attachDoubleClick(doubleD);
  buttons[K_M].attachClick(midClick);
  buttons[K_M].attachDoubleClick(midDouble);
  buttons[K_M].attachLongPressStart(midLong);
  tracker_display::begin();
  if (tracker_display::takeBusFault()) requestGlobalStop();
  serviceSafety();
}

void loop() {
  serviceSafety();
  char bottom[17];
  motorStatus(bottom);
  tracker_display::service(millis(), bottom);
  if (tracker_display::takeBusFault()) requestGlobalStop();
  serviceSafety(); // Bitta cheklangan I2C bo'lagidan keyin qayta tekshiruv.
}

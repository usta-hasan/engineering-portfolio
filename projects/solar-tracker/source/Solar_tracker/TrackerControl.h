#ifndef TRACKER_CONTROL_H
#define TRACKER_CONTROL_H

#include <stdint.h>

namespace tracker {
const uint16_t DEBOUNCE_MS = 80;
const uint16_t CLICK_WINDOW_MS = 650;
const uint16_t MID_LONG_MS = 3000;
const uint16_t REVERSE_DEADTIME_MS = 700;
const uint16_t RESTART_DEADTIME_MS = 120;
const uint32_t MAX_CONTINUOUS_MS = 60000UL;
const uint16_t PRESS_ADC = 200;
const uint16_t RELEASE_ADC = 800;
enum Direction : int8_t { NEG = -1, STOP = 0, POS = 1 };
enum AxisMode : uint8_t {
  STOPPED, WAITING_RESTART, WAITING_REVERSE, MOVING_NEG, MOVING_POS,
  LIMIT_BLOCKED, TIMEOUT, FAULT
};
inline bool elapsed(uint32_t now, uint32_t then, uint32_t interval) {
  return (uint32_t)(now - then) >= interval;
}

struct AnalogLimit {
  bool pressed = true;
  bool uncertain = true;
  void sample(uint16_t adc) {
    uncertain = adc > PRESS_ADC && adc < RELEASE_ADC;
    if (adc <= PRESS_ADC) pressed = true;
    else if (adc >= RELEASE_ADC) pressed = false;
    // Oraliqda oldingi limit holati saqlanadi, butun o'q bloklanadi.
  }
};

struct KeyCommand {
  bool down = false;
  bool holdOK = false;
  bool ignoreUntilUp = false;
  bool doubleOK = false;
  bool resetPending = false;
  uint32_t generation = 0;
};

class AxisController {
 public:
  Direction activeDir = STOP;
  Direction requestedDir = STOP;
  Direction latchedDir = STOP;
  Direction pendingDir = STOP;
  Direction lastDir = STOP;
  Direction ownerDir = STOP;
  Direction blockedDir = STOP;
  AxisMode state = STOPPED;
  uint32_t commandGeneration = 0;
  uint32_t stoppedAt = 0;
  uint32_t startedAt = 0;
  bool releaseGate = false;
  KeyCommand keys[2]; // 0=NEG, 1=POS

  // Callback motorni yoqmaydi; barcha hodisalar bitta siklda baholanadi.
  void update(uint32_t now, bool negDown, bool posDown,
              uint8_t doubleMask, uint8_t singleMask,
              bool negLimit, bool posLimit, bool sensorFault,
              bool globalStop) {
    bool down[2] = {negDown, posDown};
    bool press[2];
    bool limit[2] = {negLimit, posLimit};
    for (uint8_t k = 0; k < 2; ++k) {
      press[k] = down[k] && !keys[k].down;
      Direction dir = k == 0 ? NEG : POS;
      if (!down[k] && keys[k].down && state == WAITING_REVERSE &&
          pendingDir == dir) {
        // Revers tugamasdan release: shu gesture kechikib latch bo'lmasin.
        cancelKey(k);
      }
      if (!down[k]) {
        keys[k].holdOK = false;
        if (keys[k].ignoreUntilUp) {
          keys[k].ignoreUntilUp = false;
          keys[k].resetPending = true;
        }
      }
      keys[k].down = down[k];
    }

    bool fault = sensorFault || (negLimit && posLimit);
    bool collision = negDown && posDown;
    if (globalStop || fault || collision) {
      cancelAll();
      releaseGate = true;
      stop(now);
      state = (fault || collision) ? FAULT : STOPPED;
      return;
    }
    if (activeDir != STOP && elapsed(now, startedAt, MAX_CONTINUOUS_MS)) {
      cancelAll();
      releaseGate = true;
      stop(now);
      state = TIMEOUT;
      return;
    }
    if (releaseGate) {
      cancelAll();
      stop(now);
      if (!negDown && !posDown) releaseGate = false;
      return; // Faqat keyingi yangi press ruxsatli.
    }

    for (uint8_t k = 0; k < 2; ++k) {
      Direction dir = k == 0 ? NEG : POS;
      if (limit[k]) {
        bool relevant = keys[k].down || latchedDir == dir ||
                        activeDir == dir || pendingDir == dir;
        cancelKey(k);
        if (latchedDir == dir) latchedDir = STOP;
        if (relevant) { state = LIMIT_BLOCKED; blockedDir = dir; }
      }
    }

    for (uint8_t k = 0; k < 2; ++k) {
      if (!press[k]) continue;
      KeyCommand &key = keys[k];
      Direction dir = k == 0 ? NEG : POS;
      if (limit[k] || key.ignoreUntilUp) { cancelKey(k); continue; }
      if (latchedDir == dir) {
        cancelAll();
        state = STOPPED;
        break; // Shu press/release faqat STOP uchun sarflanadi.
      }
      if (ownerDir != dir) {
        ++commandGeneration;
        cancelKey(1 - k);
        latchedDir = STOP;
        pendingDir = STOP;
        ownerDir = dir;
      }
      key.holdOK = true;
      // Faol bosishni reset qilmaymiz; bekor qilingan tarix latch bermaydi.
      key.doubleOK = !key.resetPending;
      key.generation = commandGeneration;
      state = STOPPED;
      blockedDir = STOP;
    }

    for (uint8_t k = 0; k < 2; ++k) {
      KeyCommand &key = keys[k];
      if ((doubleMask & (1U << k)) && key.doubleOK &&
          key.generation == commandGeneration && !key.down &&
          !key.ignoreUntilUp && !key.resetPending && !keys[1-k].down &&
          !limit[k]) {
        latchedDir = k == 0 ? NEG : POS;
        key.doubleOK = false;
        state = STOPPED;
        blockedDir = STOP;
      }
      if (singleMask & (1U << k)) key.doubleOK = false;
    }

    requestedDir = keys[0].holdOK && keys[0].down ? NEG :
                   keys[1].holdOK && keys[1].down ? POS : latchedDir;
    if (activeDir != STOP && activeDir != requestedDir) stop(now);
    pendingDir = STOP;
    if (requestedDir == STOP) {
      if (state == MOVING_NEG || state == MOVING_POS ||
          state == WAITING_RESTART || state == WAITING_REVERSE) state = STOPPED;
      return;
    }
    if (activeDir == requestedDir) {
      state = activeDir == NEG ? MOVING_NEG : MOVING_POS;
      return;
    }
    bool reversing = lastDir != STOP && lastDir != requestedDir;
    uint16_t wait = reversing ? REVERSE_DEADTIME_MS : RESTART_DEADTIME_MS;
    if (lastDir != STOP && !elapsed(now, stoppedAt, wait)) {
      pendingDir = requestedDir;
      state = reversing ? WAITING_REVERSE : WAITING_RESTART;
      return;
    }
    activeDir = requestedDir;
    startedAt = now;
    state = activeDir == NEG ? MOVING_NEG : MOVING_POS;
  }

  bool takeReset(uint8_t k) {
    if (!keys[k].down && keys[k].resetPending) {
      keys[k].resetPending = false;
      return true;
    }
    return false;
  }

 private:
  void stop(uint32_t now) {
    if (activeDir != STOP) {
      lastDir = activeDir;
      activeDir = STOP;
      stoppedAt = now;
    }
  }
  void cancelKey(uint8_t k) {
    keys[k].holdOK = false;
    keys[k].doubleOK = false;
    keys[k].resetPending = true;
    if (keys[k].down) keys[k].ignoreUntilUp = true;
  }
  void cancelAll() {
    ++commandGeneration;
    cancelKey(0);
    cancelKey(1);
    latchedDir = requestedDir = pendingDir = ownerDir = STOP;
  }
};
} // namespace tracker
#endif

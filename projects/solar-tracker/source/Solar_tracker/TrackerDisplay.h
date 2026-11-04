#ifndef SOLAR_TRACKER_DISPLAY_H
#define SOLAR_TRACKER_DISPLAY_H

#include <Arduino.h>
#include <Wire.h>
#include <LiquidCrystal_I2C.h>
#include <myDC3231.h>
#include <avr/pgmspace.h>
#include <math.h>
#include <stdio.h>
#include <string.h>

namespace tracker_display {

const uint8_t LCD_ADDRESS = 0x27;
const uint8_t RTC_ADDRESS = 0x68;
const uint32_t I2C_CLOCK_HZ = 100000UL;
const uint32_t I2C_TIMEOUT_US = 3000UL;
const uint32_t BUS_BACKOFF_MS = 1000UL;
const uint32_t RTC_POLL_MS = 1000UL;
const uint16_t LCD_REFRESH_MS = 250;
const uint32_t SLIDE_INTERVAL_MS = 3000UL;
const uint32_t SLIDE_LOCK_MS = 300000UL;
const float SITE_LATITUDE_DEG = 39.775f;
const float SITE_LONGITUDE_DEG = 64.429f;
const int8_t SITE_TIMEZONE_HOURS = 5;

static LiquidCrystal_I2C lcd(LCD_ADDRESS, 16, 2);
static myDC3231 rtc;
static TDT rtcTime = {};
static bool clockValid = false;
static bool daylight = false;
static uint8_t dayPercent = 0;
static bool lcdOnline = false;
static bool busFault = false;
static bool busBackoff = false;
static uint32_t faultAt = 0;
static uint32_t rtcAt = 0;
static uint32_t topAt = 0;
static uint32_t slideAt = 0;
static uint32_t lockAt = 0;
static uint8_t slide = 0;
static bool slideLocked = false;
static bool topDirty = true;
static char desired[2][17] = {};
static char shown[2][17] = {};
static uint8_t cursorIndex = 255;

struct DayWindow {
  bool valid;
  uint32_t sunriseSec;
  uint32_t sunsetSec;
};
static DayWindow sun = {false, 0, 0};
static uint16_t sunDate = 0;

static bool elapsed(uint32_t now, uint32_t then, uint32_t interval) {
  return (uint32_t)(now - then) >= interval;
}

static bool leapYear(uint16_t year) {
  return year % 4 == 0 && (year % 100 != 0 || year % 400 == 0);
}

static uint8_t daysInMonth(uint16_t year, uint8_t month) {
  if (month == 2) return leapYear(year) ? 29 : 28;
  return (month == 4 || month == 6 || month == 9 || month == 11) ? 30 : 31;
}

static bool validDate(uint16_t year, uint8_t month, uint8_t day) {
  return year >= 2000 && year <= 2099 && month >= 1 && month <= 12 &&
         day >= 1 && day <= daysInMonth(year, month);
}

static uint16_t dayOfYear(uint16_t year, uint8_t month, uint8_t day) {
  uint16_t result = day;
  for (uint8_t m = 1; m < month; ++m) result += daysInMonth(year, m);
  return result;
}

static bool bcdValue(uint8_t raw, uint8_t maximum, uint8_t &value) {
  if ((raw & 15) > 9 || (raw >> 4) > 9) return false;
  value = (raw >> 4) * 10 + (raw & 15);
  return value <= maximum;
}

// Mavjud kutubxonaning TDT formati saqlanadi; tekshirilmagan now() ishlatilmaydi.
static bool decodeRtc(const uint8_t *raw, TDT &result) {
  if ((raw[15] & 0x80) || (raw[0] & 0x80) || (raw[1] & 0x80) ||
      (raw[2] & 0x80) || (raw[3] & 0xF8) || (raw[4] & 0xC0) ||
      (raw[5] & 0xE0)) return false;
  TDT next = {};
  if (!bcdValue(raw[0], 59, next.sekund) ||
      !bcdValue(raw[1], 59, next.minut)) return false;
  if (raw[2] & 0x40) {
    uint8_t hour;
    if (!bcdValue(raw[2] & 0x1F, 12, hour) || hour == 0) return false;
    next.soat = (hour % 12) + ((raw[2] & 0x20) ? 12 : 0);
  } else if (!bcdValue(raw[2], 23, next.soat)) return false;
  next.hafta = raw[3];
  if (next.hafta < 1 || next.hafta > 7 ||
      !bcdValue(raw[4], 31, next.kun) ||
      !bcdValue(raw[5], 12, next.oy) ||
      !bcdValue(raw[6], 99, next.yil) ||
      !validDate(2000U + next.yil, next.oy, next.kun)) return false;
  result = next;
  return true;
}

static void markBusFault(uint32_t now) {
  busFault = true;
  busBackoff = true;
  faultAt = now;
  clockValid = false;
  topDirty = true;
  // Yarim yozilgan LCD nibble holatini yurish vaqtida qayta boshlamaymiz.
  lcdOnline = false;
  cursorIndex = 255;
}

static bool checkTimeout(uint32_t now) {
  if (!Wire.getWireTimeoutFlag()) return false;
  Wire.clearWireTimeoutFlag();
  markBusFault(now);
  return true;
}

static bool transactionOK(uint8_t error, uint32_t now) {
  if (checkTimeout(now)) return false;
  if (error >= 4) markBusFault(now);
  return error == 0;
}

static bool probe(uint8_t address, uint32_t now) {
  Wire.beginTransmission(address);
  return transactionOK(Wire.endTransmission(), now);
}

static bool readRtc(TDT &result, uint32_t now) {
  uint8_t raw[16];
  Wire.beginTransmission(RTC_ADDRESS);
  Wire.write((uint8_t)0);
  if (!transactionOK(Wire.endTransmission(), now)) return false;
  const uint8_t count = Wire.requestFrom(RTC_ADDRESS, (uint8_t)sizeof(raw));
  if (checkTimeout(now)) return false;
  if (count != sizeof(raw) || Wire.available() != (int)sizeof(raw)) {
    while (Wire.available()) Wire.read();
    return false;
  }
  for (uint8_t i = 0; i < sizeof(raw); ++i) raw[i] = Wire.read();
  return decodeRtc(raw, result);
}

static DayWindow calculateDay(uint16_t year, uint8_t month, uint8_t day) {
  DayWindow result = {false, 0, 0};
  if (!validDate(year, month, day)) return result;
  const float rad = 0.0174532925199433f;
  const float lat = SITE_LATITUDE_DEG * rad;
  // NOAA yaqinlashuvi: shu sananing mahalliy soat 12:00 dagi qiymati.
  const float gamma = 6.28318530717959f /
      (leapYear(year) ? 366.0f : 365.0f) * (dayOfYear(year, month, day) - 1);
  const float c1 = cosf(gamma), s1 = sinf(gamma);
  const float c2 = cosf(2.0f * gamma), s2 = sinf(2.0f * gamma);
  const float eq = 229.18f * (0.000075f + 0.001868f * c1 - 0.032077f * s1
      - 0.014615f * c2 - 0.040849f * s2);
  const float decl = 0.006918f - 0.399912f * c1 + 0.070257f * s1
      - 0.006758f * c2 + 0.000907f * s2
      - 0.002697f * cosf(3.0f * gamma) + 0.001480f * sinf(3.0f * gamma);
  const float cosH = (cosf(90.833f * rad) - sinf(lat) * sinf(decl)) /
      (cosf(lat) * cosf(decl));
  if (!isfinite(cosH) || cosH < -1.0f || cosH > 1.0f) return result;
  const float halfDayMin = 4.0f * acosf(cosH) / rad;
  const float noonMin = 720.0f - 4.0f * SITE_LONGITUDE_DEG - eq
      + 60.0f * SITE_TIMEZONE_HOURS;
  const float sunrise = (noonMin - halfDayMin) * 60.0f;
  const float sunset = (noonMin + halfDayMin) * 60.0f;
  if (!isfinite(sunrise) || !isfinite(sunset) || sunrise < 0.0f ||
      sunset >= 86400.0f || sunset <= sunrise) return result;
  result.sunriseSec = (uint32_t)(sunrise + 0.5f);
  result.sunsetSec = (uint32_t)(sunset + 0.5f);
  result.valid = result.sunsetSec > result.sunriseSec;
  return result;
}

static void updateDay() {
  daylight = false;
  dayPercent = 0;
  if (!clockValid) return;
  const uint16_t date = (uint16_t)rtcTime.yil * 512U +
      (uint16_t)rtcTime.oy * 32U + rtcTime.kun;
  if (date != sunDate) {
    sun = calculateDay(2000U + rtcTime.yil, rtcTime.oy, rtcTime.kun);
    sunDate = date;
  }
  if (!sun.valid) return;
  const uint32_t seconds = (uint32_t)rtcTime.soat * 3600UL +
      (uint32_t)rtcTime.minut * 60UL + rtcTime.sekund;
  daylight = seconds >= sun.sunriseSec && seconds < sun.sunsetSec;
  if (!daylight) return;
  const uint32_t duration = sun.sunsetSec - sun.sunriseSec;
  dayPercent = (uint8_t)(((seconds - sun.sunriseSec) * 100UL + duration / 2) /
      duration);
}

static void copyLine(char *dest, const char *src) {
  uint8_t i = 0;
  while (i < 16 && src[i]) { dest[i] = src[i]; ++i; }
  while (i < 16) dest[i++] = ' ';
  dest[16] = 0;
}

static void renderTop() {
  char top[17];
  if (slide == 0) {
    if (clockValid) snprintf_P(top, sizeof(top), PSTR("%02u.%02u %02u:%02u:%02u"),
        (unsigned)rtcTime.kun, (unsigned)rtcTime.oy, (unsigned)rtcTime.soat,
        (unsigned)rtcTime.minut, (unsigned)rtcTime.sekund);
    else strcpy_P(top, PSTR("RTC XATO"));
  } else if (slide == 1) {
    if (!clockValid) strcpy_P(top, PSTR("RTC XATO"));
    else if (!sun.valid) strcpy_P(top, PSTR("KUN HISOB XATO"));
    else if (!daylight) strcpy_P(top, PSTR("TUNGI REJIM"));
    else {
      snprintf_P(top, sizeof(top), PSTR("KUN %3u%% [-----]"), (unsigned)dayPercent);
      const uint8_t bars = (dayPercent * 5U + 50U) / 100U;
      for (uint8_t i = 0; i < bars; ++i) top[10 + i] = '#';
    }
  } else strcpy_P(top, PSTR("H:---.- V:---.-"));
  copyLine(desired[0], top);
  if (slideLocked) desired[0][desired[0][15] == ' ' ? 15 : 3] = '*';
  topDirty = false;
}

void nextSlide(uint32_t now) {
  slide = (slide + 1) % 3;
  slideLocked = false;
  slideAt = now;
  topDirty = true;
}

void lockSlide(uint32_t now) {
  slideLocked = true;
  lockAt = now;
  topDirty = true;
}

bool takeBusFault() {
  const bool result = busFault;
  busFault = false;
  return result;
}

void begin() {
  // Chaqiruvchi bundan OLDIN barcha rele latchlarini HIGH/OUTPUT qiladi.
  clockValid = false;
  daylight = false;
  dayPercent = 0;
  busFault = false;
  busBackoff = false;
  slide = 0;
  slideLocked = false;
  cursorIndex = 255;
  sun.valid = false;
  sunDate = 0;
  rtc.Wirebegin(RTC_ADDRESS);
  Wire.setClock(I2C_CLOCK_HZ);
  Wire.setWireTimeout(I2C_TIMEOUT_US, true);
  Wire.clearWireTimeoutFlag();
  const uint32_t started = millis();
  lcdOnline = probe(LCD_ADDRESS, started);
  if (lcdOnline) {
    // Kutubxonaning ichki ~1.06 s kutishi faqat xavfsiz setup da.
    lcd.begin();
    if (!checkTimeout(millis())) {
      lcd.backlight();
      checkTimeout(millis());
    }
    Wire.setClock(I2C_CLOCK_HZ);
    Wire.setWireTimeout(I2C_TIMEOUT_US, true);
  }
  memset(shown, 0, sizeof(shown));
  memset(desired, ' ', sizeof(desired));
  desired[0][16] = desired[1][16] = 0;
  memcpy_P(desired[1], PSTR("MAN STOP"), 8);
  const uint32_t now = millis();
  slideAt = now;
  topAt = now;
  rtcAt = now - RTC_POLL_MS;
  renderTop();
}

static void writeOneLcdChunk(uint32_t now) {
  if (!lcdOnline) return;
  // Haqiqiy motor qatori barcha yuqori slayd belgilaridan ustuvor.
  for (int8_t row = 1; row >= 0; --row) {
    for (uint8_t col = 0; col < 16; ++col) {
      if (desired[row][col] == shown[row][col]) continue;
      if (!probe(LCD_ADDRESS, now)) { lcdOnline = false; return; }
      const uint8_t index = row * 16 + col;
      if (cursorIndex != index) {
        lcd.setCursor(col, row);
        if (!checkTimeout(millis())) cursorIndex = index;
      } else {
        lcd.write((uint8_t)desired[row][col]);
        if (!checkTimeout(millis())) {
          shown[row][col] = desired[row][col];
          cursorIndex = col < 15 ? index + 1 : 255;
        }
      }
      return;
    }
  }
}

void service(uint32_t now, const char *actualMotorStatus) {
  copyLine(desired[1], actualMotorStatus);
  if (slideLocked && elapsed(now, lockAt, SLIDE_LOCK_MS)) {
    slideLocked = false;
    slideAt = now;
    topDirty = true;
  }
  if (!slideLocked && elapsed(now, slideAt, SLIDE_INTERVAL_MS)) nextSlide(now);
  if (topDirty || elapsed(now, topAt, LCD_REFRESH_MS)) {
    renderTop();
    topAt = now;
  }
  if (busBackoff) {
    if (!elapsed(now, faultAt, BUS_BACKOFF_MS)) return;
    busBackoff = false;
  }
  if (elapsed(now, rtcAt, RTC_POLL_MS)) {
    rtcAt = now;
    clockValid = readRtc(rtcTime, now);
    updateDay();
    topDirty = true;
    return;
  }
  // Bir servisda RTC o'qish YOKI bitta LCD buyruq/belgi bajariladi.
  writeOneLcdChunk(now);
}

}  // tracker_display

#endif

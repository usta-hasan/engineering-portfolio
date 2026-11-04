#include <Arduino.h>
#include <string.h>

const uint8_t lowPins[4] = {4, 8, 7, 10};
const uint8_t pwmPins[4] = {5, 9, 6, 11};
char rxBuffer[100];
uint8_t rxIndex = 0;
bool bufferOverflow = false;
bool invalidByte = false;
uint32_t lastByteAt = 0;
const uint16_t frameTimeoutMs = 500;
int motors[4] = {0, 0, 0, 0};

int percentToPWM(int p) {
  return (p * 255 + 50) / 100;
}

void setMotors() {
  for (uint8_t i = 0; i < 4; ++i) {
    digitalWrite(lowPins[i], LOW);
    analogWrite(pwmPins[i], percentToPWM(motors[i]));
  }
}

void sendError(const __FlashStringHelper *error) {
  Serial.print(F("{\"ok\":0,\"error\":\""));
  Serial.print(error);
  Serial.println(F("\"}"));
}

bool consume(const char *&p, const char *token) {
  const size_t n = strlen(token);
  if (strncmp(p, token, n) != 0) return false;
  p += n;
  return true;
}

// Saturating parse avoids AVR 16-bit integer overflow.
bool readPercent(const char *&p, int &value, bool &invalidValue) {
  bool negative = false;
  if (*p == '-') { negative = true; ++p; }
  if (*p < '0' || *p > '9') return false;
  if (*p == '0' && p[1] >= '0' && p[1] <= '9') return false;
  unsigned int n = 0;
  while (*p >= '0' && *p <= '9') {
    if (n <= 100) n = n * 10 + (*p - '0');
    ++p;
  }
  if (n > 100 || (negative && n != 0)) invalidValue = true;
  value = negative ? -int(n) : int(n);
  return true;
}

void processJSON() {
  const char *p = rxBuffer;
  int next[4];
  bool invalidValue = false;
  bool valid = consume(p, "{\"cmd\":\"set\",\"m1\":") &&
    readPercent(p, next[0], invalidValue) && consume(p, ",\"m2\":") &&
    readPercent(p, next[1], invalidValue) && consume(p, ",\"m3\":") &&
    readPercent(p, next[2], invalidValue) && consume(p, ",\"m4\":") &&
    readPercent(p, next[3], invalidValue) && consume(p, "}") && *p == '\0';
  if (!valid || invalidByte) {
    sendError(F("INVALID_JSON"));
    return;
  }
  if (invalidValue) {
    sendError(F("INVALID_VALUE"));
    return;
  }
  for (uint8_t i = 0; i < 4; ++i) motors[i] = next[i];
  setMotors();
  Serial.print(F("{\"ok\":1,\"m1\":"));
  Serial.print(motors[0]);
  Serial.print(F(",\"m2\":")); Serial.print(motors[1]);
  Serial.print(F(",\"m3\":")); Serial.print(motors[2]);
  Serial.print(F(",\"m4\":")); Serial.print(motors[3]);
  Serial.println(F("}"));
}

void setup() {
  for (uint8_t i = 0; i < 4; ++i) {
    pinMode(lowPins[i], OUTPUT);
    pinMode(pwmPins[i], OUTPUT);
  }
  setMotors();
  Serial.begin(9600);
}

void loop() {
  // Discard a torn frame before a later connection can append to it.
  if ((rxIndex != 0 || bufferOverflow) &&
      uint32_t(millis() - lastByteAt) >= frameTimeoutMs) {
    if (bufferOverflow) sendError(F("BUFFER_OVERFLOW"));
    else sendError(F("INVALID_JSON"));
    rxIndex = 0;
    bufferOverflow = false;
    invalidByte = false;
  }
  while (Serial.available() > 0) {
    const char c = char(Serial.read());
    lastByteAt = millis();
    if (c == '\r') continue;
    if (c == '\n') {
      rxBuffer[rxIndex] = '\0';
      if (bufferOverflow) sendError(F("BUFFER_OVERFLOW"));
      else processJSON();
      rxIndex = 0;
      bufferOverflow = false;
      invalidByte = false;
    } else if (!bufferOverflow) {
      if (c == '\0') invalidByte = true;
      if (rxIndex < sizeof(rxBuffer) - 1) rxBuffer[rxIndex++] = c;
      else bufferOverflow = true;
    }
  }
}


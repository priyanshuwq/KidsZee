/*
 * ============================================================
 *  5-DOF Robotic Arm — Adapted for FABRI Creator App
 * ============================================================
 *
 *  THIS IS THE SKETCH CURRENTLY FLASHED ON THE ARDUINO.
 *  The KidsZee Flutter app speaks this exact protocol — do NOT
 *  change the protocol here without updating CommandService.
 *
 * ── App Slider → BT Command → Servo ───────────────────────
 *
 *   FABRI cmd   KidsZee joint     Pin  Servo
 *   ─────────────────────────────────────────
 *   s1<angle>   Base / Waist      D5   MG995
 *   s2<angle>   Shoulder          D6   MG995
 *   s4<angle>   Elbow             D7   MG995
 *   s5<angle>   Wrist Rotation    D8   SG90
 *   s6<angle>   Wrist Pitch       D9   SG90
 *   s7<angle>   Gripper           D10  SG90
 *   ss<value>   Playback speed     —    —
 *
 * ── Buttons (onboard recording) ───────────────────────────
 *   SAVE  → store current position as a step
 *   RUN   → play recorded sequence  (PAUSE toggles)
 *   RESET → clear sequence
 *
 * ── Notes ─────────────────────────────────────────────────
 *   • Commands have NO newline. End-of-command = 10 ms silence.
 *   • HC-05: TX→D3 (SoftwareSerial RX), RX←D4 (via divider).
 *   • MG995 servos: external 5–6 V (≥3 A) supply, shared GND.
 * ============================================================
 */

#include <Servo.h>
#include <SoftwareSerial.h>

SoftwareSerial BT(3, 4); // RX = D3, TX = D4

/* Index: 0=Base(D5) 1=Shoulder(D6) 2=Elbow(D7) 3=WristRot(D8) 4=Wrist(D9)
 * 5=Gripper(D10) */
Servo srv[6];
const byte PIN[6] = {5, 6, 7, 8, 9, 10};

byte pos[6] = {90, 90, 90,
               90, 90, 90}; // power-on positions (KidsZee home matches this)

const byte MAX_STEPS = 25;
byte rec[MAX_STEPS][6];
byte stepCount = 0;

byte playSpeed = 25; // ms per degree, lower = faster

const byte BUF_SZ = 16;
char buf[BUF_SZ];

byte cmdToIdx(char c) {
  switch (c) {
  case '1':
    return 0; // Base
  case '2':
    return 1; // Shoulder
  case '4':
    return 2; // Elbow
  case '5':
    return 3; // Wrist Rotation
  case '6':
    return 4; // Wrist Pitch
  case '7':
    return 5; // Gripper
  default:
    return 255;
  }
}

bool readCmd() {
  if (!BT.available())
    return false;
  byte len = 0;
  unsigned long lastByte = millis();
  while (millis() - lastByte < 10) {
    if (BT.available()) {
      char c = (char)BT.read();
      if (len < BUF_SZ - 1)
        buf[len++] = c;
      lastByte = millis();
    }
  }
  buf[len] = '\0';
  return (len > 0);
}

void smoothMoveTo(const byte tgt[]) {
  bool moving = true;
  while (moving) {
    moving = false;
    for (byte i = 0; i < 6; i++) {
      if (pos[i] < tgt[i]) {
        pos[i]++;
        moving = true;
      } else if (pos[i] > tgt[i]) {
        pos[i]--;
        moving = true;
      }
      srv[i].write(pos[i]);
    }
    delay(playSpeed);
  }
}

void saveStep() {
  if (stepCount >= MAX_STEPS)
    return;
  for (byte i = 0; i < 6; i++)
    rec[stepCount][i] = pos[i];
  stepCount++;
  Serial.print(F("Saved: "));
  Serial.println(stepCount);
}

void playSequence() {
  if (stepCount < 2)
    return;
  Serial.println(F("Playing"));
  bool running = true;
  while (running) {
    for (byte i = 0; i < stepCount && running; i++) {
      if (readCmd()) {
        if (strncmp(buf, "PAUSE", 5) == 0) {
          Serial.println(F("Paused"));
          while (true) {
            if (readCmd()) {
              if (strncmp(buf, "RUN", 3) == 0) {
                Serial.println(F("Resumed"));
                break;
              }
              if (strncmp(buf, "RESET", 5) == 0) {
                running = false;
                break;
              }
            }
          }
          if (!running)
            break;
        } else if (strncmp(buf, "RESET", 5) == 0) {
          running = false;
          break;
        } else if (buf[0] == 's' && buf[1] == 's') {
          playSpeed = constrain(atoi(&buf[2]), 1, 50);
        }
      }
      smoothMoveTo(rec[i]);
    }
  }
  stepCount = 0;
  Serial.println(F("Stopped"));
}

void processCmd() {
  if (buf[0] == 's' && buf[1] == 's') {
    playSpeed = constrain(atoi(&buf[2]), 1, 50);
    Serial.print(F("Speed: "));
    Serial.println(playSpeed);
    return;
  }
  if (buf[0] == 's') {
    byte idx = cmdToIdx(buf[1]);
    if (idx < 6) {
      byte angle = (byte)constrain(atoi(&buf[2]), 0, 180);
      pos[idx] = angle;
      srv[idx].write(angle);
    }
    return;
  }
  if (strncmp(buf, "SAVE", 4) == 0) {
    saveStep();
    return;
  }
  if (strncmp(buf, "RUN", 3) == 0) {
    playSequence();
    return;
  }
  if (strncmp(buf, "RESET", 5) == 0) {
    stepCount = 0;
    Serial.println(F("Reset"));
    return;
  }
}

void setup() {
  Serial.begin(9600);
  BT.begin(9600);
  for (byte i = 0; i < 6; i++) {
    srv[i].attach(PIN[i]);
    srv[i].write(pos[i]);
    delay(20);
  }
  delay(500);
  Serial.println(F("Ready - FABRI App Mode"));
}

void loop() {
  if (readCmd())
    processCmd();
}

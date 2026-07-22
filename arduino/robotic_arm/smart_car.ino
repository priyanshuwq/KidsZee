#include <IRremote.hpp>
#include <SoftwareSerial.h>

SoftwareSerial BT(2, 3);

#define IR_RECEIVE_PIN 4

#define LEFT_IR A0
#define CENTER_IR A1
#define RIGHT_IR A2

#define IN1 8
#define IN2 9
#define IN3 10
#define IN4 11

#define BTN_1 0xBA45FF00
#define BTN_2 0xB946FF00
#define BTN_3 0xB847FF00

#define IR_FORWARD 0xE718FF00
#define IR_BACKWARD 0xAD52FF00
#define IR_LEFT 0xF708FF00
#define IR_RIGHT 0xA55AFF00
#define IR_STOP 0xE31CFF00

int mode = 1;
// 1 = Bluetooth
// 2 = IR Remote
// 3 = Line Following

unsigned long lastIRTime = 0;
const unsigned long IR_TIMEOUT = 220;

void setup() {
  Serial.begin(9600);
  BT.begin(9600);

  IrReceiver.begin(IR_RECEIVE_PIN, ENABLE_LED_FEEDBACK);

  pinMode(LEFT_IR, INPUT);
  pinMode(CENTER_IR, INPUT);
  pinMode(RIGHT_IR, INPUT);

  pinMode(IN1, OUTPUT);
  pinMode(IN2, OUTPUT);
  pinMode(IN3, OUTPUT);
  pinMode(IN4, OUTPUT);

  stopCar();

  Serial.println("Car Ready");
  Serial.println("1 = Bluetooth Mode");
  Serial.println("2 = IR Remote Mode");
  Serial.println("3 = Light Following Mode");
}

void loop() {
  checkIRRemote();

  if (mode == 1) {
    bluetoothMode();
  }

  else if (mode == 2) {
    if (millis() - lastIRTime > IR_TIMEOUT) {
      stopCar();
    }
  }

  else if (mode == 3) {
    lineFollowingMode();
  }
}

void checkIRRemote() {
  if (IrReceiver.decode()) {
    unsigned long value = IrReceiver.decodedIRData.decodedRawData;

    Serial.print("IR: ");
    Serial.println(value, HEX);

    if (value == BTN_1) {
      mode = 1;
      stopCar();
      Serial.println("Bluetooth Mode Selected");
    }

    else if (value == BTN_2) {
      mode = 2;
      stopCar();
      Serial.println("IR Remote Mode Selected");
    }

    else if (value == BTN_3) {
      mode = 3;
      stopCar();
      Serial.println("Line Following Mode Selected");
    }

    else if (mode == 2) {
      lastIRTime = millis();

      if (value == IR_FORWARD)
        leftTurn();
      else if (value == IR_BACKWARD)
        rightTurn();
      else if (value == IR_LEFT)
        forward();
      else if (value == IR_RIGHT)
        backward();
      else if (value == IR_STOP)
        stopCar();
    }

    IrReceiver.resume();
  }
}

void bluetoothMode() {
  if (BT.available()) {
    char c = BT.read();

    if (c == 'U')
      leftTurn();
    else if (c == 'D')
      rightTurn();
    else if (c == 'L')
      forward();
    else if (c == 'R')
      backward();
    else if (c == 'S')
      stopCar();
  }
}

void lineFollowingMode() {
  int L = digitalRead(LEFT_IR);
  int C = digitalRead(CENTER_IR);
  int R = digitalRead(RIGHT_IR);

  // BLACK = 1, WHITE = 0

  if (L == 0 && C == 1 && R == 0) {
    forward();
  } else if (L == 1 && C == 0 && R == 0) {
    leftTurn();
  } else if (L == 0 && C == 0 && R == 1) {
    rightTurn();
  } else if (L == 1 && C == 1 && R == 0) {
    leftTurn();
  } else if (L == 0 && C == 1 && R == 1) {
    rightTurn();
  } else if (L == 1 && C == 1 && R == 1) {
    forward();
  } else if (L == 0 && C == 0 && R == 0) {
    stopCar();
  } else {
    stopCar();
  }

  delay(60);
}

void forward() {
  digitalWrite(IN1, HIGH);
  digitalWrite(IN2, LOW);
  digitalWrite(IN3, HIGH);
  digitalWrite(IN4, LOW);
}

void backward() {
  digitalWrite(IN1, LOW);
  digitalWrite(IN2, HIGH);
  digitalWrite(IN3, LOW);
  digitalWrite(IN4, HIGH);
}

void leftTurn() {
  digitalWrite(IN1, LOW);
  digitalWrite(IN2, HIGH);
  digitalWrite(IN3, HIGH);
  digitalWrite(IN4, LOW);
}

void rightTurn() {
  digitalWrite(IN1, HIGH);
  digitalWrite(IN2, LOW);
  digitalWrite(IN3, LOW);
  digitalWrite(IN4, HIGH);
}

void stopCar() {
  digitalWrite(IN1, LOW);
  digitalWrite(IN2, LOW);
  digitalWrite(IN3, LOW);
  digitalWrite(IN4, LOW);
}
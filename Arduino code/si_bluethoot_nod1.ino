#include <SoftwareSerial.h>
#include <ArduinoJson.h>
 
const int rxPin = 2;
const int txPin = 3;
 
const int buzzerPin = 8; 
const int mq135Pin = A0;
const int ldrPin = A1;   
 
SoftwareSerial myBluetooth(rxPin, txPin);
 
void setup() {
  Serial.begin(9600);
 
  pinMode(buzzerPin, OUTPUT);
 
  tone(buzzerPin, 1000, 2000);

  myBluetooth.begin(9600);
  Serial.println("Bluetooth este pregătit pentru comunicare");
}
 
void loop() {
  int mq135Value = analogRead(mq135Pin);
  int ldrValue = analogRead(ldrPin);
 
  if (myBluetooth.available()) {
    char received = myBluetooth.read();
    Serial.print("Recepționat: ");
    Serial.println(received);
  }
 
  if (mq135Value > 500) {
    tone(buzzerPin, 1000);
  }
  else {
    noTone(buzzerPin);
  }
 
  static unsigned long lastSendTime = 0;
  if (millis() - lastSendTime > 2000) {
 
    StaticJsonDocument<200> jsonDoc;
    jsonDoc["MQ135"] = mq135Value;
    jsonDoc["LDR"] = ldrValue;
 
    String jsonString;
    serializeJson(jsonDoc, jsonString);
 
    myBluetooth.println(jsonString);
 
    Serial.print("Trimis JSON: ");
    Serial.println(jsonString);
 
    lastSendTime = millis();
  }
}
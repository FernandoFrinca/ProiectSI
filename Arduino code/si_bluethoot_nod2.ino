#include <SoftwareSerial.h>
#include <ArduinoJson.h>
#include <dht.h>
 
dht DHT;
 
#define DHT11_PIN 10
 
int lowerThreshold = 600;
int upperThreshold = 620;
 
const int rxPin = 2;
const int txPin = 3;
 
const int waterLevelPin = A0;   
 
int val = 0;
 
int redLED = 8;
int yellowLED = 6;
int greenLED = 9;
 
SoftwareSerial myBluetooth(rxPin, txPin);
 
void setup() {

  Serial.begin(9600);
 
  myBluetooth.begin(9600);
  Serial.println("Bluetooth este pregătit pentru comunicare");
 
	pinMode(redLED, OUTPUT);
	pinMode(yellowLED, OUTPUT);
	pinMode(greenLED, OUTPUT);
 
	digitalWrite(redLED, LOW);
	digitalWrite(yellowLED, LOW);
	digitalWrite(greenLED, LOW);
}
 
void loop() {

  int waterLevelValue = analogRead(waterLevelPin);
  // Serial.println(waterLevelValue);
 
  if (waterLevelValue == 0) {
		digitalWrite(redLED, LOW);
		digitalWrite(yellowLED, LOW);
		digitalWrite(greenLED, HIGH);
	}
	else if (waterLevelValue > 0 && waterLevelValue <= lowerThreshold) {
		digitalWrite(redLED, LOW);
		digitalWrite(yellowLED, LOW);
		digitalWrite(greenLED, HIGH);
	}
	else if (waterLevelValue > lowerThreshold && waterLevelValue <= upperThreshold) {
		digitalWrite(redLED, LOW);
		digitalWrite(yellowLED, HIGH);
		digitalWrite(greenLED, LOW);
	}
	else if (waterLevelValue > upperThreshold) {
		digitalWrite(redLED, HIGH);
		digitalWrite(yellowLED, LOW);
		digitalWrite(greenLED, LOW);
	}
 
  int chk = DHT.read11(DHT11_PIN);
  float humidity = DHT.humidity;
  float temperature = DHT.temperature;
 
  if (chk == DHTLIB_OK) {
    Serial.print("Umiditate: ");
    Serial.print(humidity);
    Serial.print(" %, Temperatură: ");
    Serial.print(temperature);
    Serial.println(" *C");
  }
 
  if (myBluetooth.available()) {
    char received = myBluetooth.read();
    Serial.print("Recepționat: ");
    Serial.println(received);
  }
 
  static unsigned long lastSendTime = 0;
  if (millis() - lastSendTime > 2000) {

    StaticJsonDocument<200> jsonDoc;
    if (chk == DHTLIB_OK) {
      jsonDoc["Humidity"] = humidity;
      jsonDoc["Temperature"] = temperature;
    } else {
      jsonDoc["Humidity"] = "Error";
      jsonDoc["Temperature"] = "Error";
    }
    jsonDoc["Wlvl"] = waterLevelValue;
 
    String jsonString;
    serializeJson(jsonDoc, jsonString);
 
    myBluetooth.println(jsonString);
 
    Serial.print("Trimis JSON: ");
    Serial.println(jsonString);
 
    lastSendTime = millis();
  }
}
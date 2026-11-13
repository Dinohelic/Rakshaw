#include <Arduino.h>
#include <SPI.h>
#include <MFRC522.h>
#include <TinyGPSPlus.h>
#include <Adafruit_GFX.h>
#include <Adafruit_ILI9341.h>

// =====================================================
// RAKSHA KWACCH - SCREENING DEMO v6 INSTANT TAP + BACKGROUND SYNC
//
// ESP32-S3
// + RC522 RFID
// + NEO-M8N GPS
// + A7672S 4Gr
// + Supabase
// + ILI9341 TFT
// + Buzzer
// + Mode Button
// =====================================================


// =====================================================
// RFID
// =====================================================

#define RFID_SS    8
#define RFID_RST   16
#define RFID_SCK   6
#define RFID_MOSI  15
#define RFID_MISO  7

MFRC522 rfid(RFID_SS, RFID_RST);


// =====================================================
// GPS
// =====================================================

#define GPS_RX     4
#define GPS_TX     5
#define GPS_BAUD   9600

HardwareSerial GPS(2);

TinyGPSPlus gps;


// =====================================================
// A7672S MODEM
// =====================================================

#define MODEM_RX   17
#define MODEM_TX   18
#define MODEM_BAUD 115200

HardwareSerial Modem(1);


// =====================================================
// BUZZER + BUTTON
// =====================================================

#define BUZZER_PIN 35
#define BUTTON_PIN 36

bool lastButtonState = HIGH;

unsigned long lastDebounceTime = 0;

const unsigned long DEBOUNCE_DELAY = 50;


// =====================================================
// TFT DISPLAY
// =====================================================

#define TFT_CS    37
#define TFT_RST   38
#define TFT_DC    39

#define TFT_MOSI  40
#define TFT_SCLK  41
#define TFT_MISO  42

SPIClass tftSPI(FSPI);

Adafruit_ILI9341 tft(
  &tftSPI,
  TFT_DC,
  TFT_CS,
  TFT_RST
);


// =====================================================
// SUPABASE
// =====================================================

const char* FUNCTION_URL =
  "https://uijvhpfycmhnedccytiq.supabase.co/functions/v1/raksha-attendance";

// Device identity used in the attendance payload.
// Device-key authentication is intentionally disabled for this prototype.
const char* DEVICE_ID =
  "raksha-esp32s3-01";

// Replace with the parent/test phone number including country code.
const char* PARENT_PHONE =
  "+917217857586";

// Session-level duplicate protection.
// Once a UID + event_type is successfully recorded, the same combination
// is blocked until the ESP32 restarts. Different event types remain allowed.
const int MAX_SESSION_EVENTS = 200;

struct ProcessedEvent
{
  char uid[24];
  char eventType[24];
};

ProcessedEvent processedEvents[MAX_SESSION_EVENTS];
int processedEventCount = 0;

// =====================================================
// SCREENING / NETWORK RUNTIME STATE
// =====================================================

bool httpClientReady = false;
bool modemOnline = false;

String lastServerResponse = "";
String lastStudentName = "";
String lastVerificationStatus = "";
double lastPhoneDistanceM = -1.0;
long lastPhoneLocationAgeSeconds = -1;
double lastPhoneAccuracyM = -1.0;

// =====================================================
// INSTANT TAP / BACKGROUND SYNC RUNTIME
// =====================================================

struct AttendanceJob
{
  char uid[24];
  char eventType[24];
  char modeName[28];
  double latitude;
  double longitude;
};

struct AttendanceResult
{
  int statusCode;
  char uid[24];
  char eventType[24];
  char modeName[28];
  char studentName[64];
  char verificationStatus[40];
  double phoneDistanceM;
  long phoneLocationAgeSeconds;
  double phoneAccuracyM;
  bool smsAttempted;
  bool smsSuccess;
  bool isCardBlocked;
};

QueueHandle_t attendanceQueue = nullptr;
QueueHandle_t resultQueue = nullptr;
TaskHandle_t gpsTaskHandle = nullptr;
TaskHandle_t networkTaskHandle = nullptr;

volatile bool networkBusy = false;

portMUX_TYPE gpsMux = portMUX_INITIALIZER_UNLOCKED;
volatile bool gpsSnapshotValid = false;
volatile double gpsSnapshotLat = 0.0;
volatile double gpsSnapshotLon = 0.0;
volatile unsigned long gpsSnapshotMillis = 0;

unsigned long lastReadyRefresh = 0;
unsigned long uiReturnAt = 0;
bool uiIsIdle = false;

// Cache the small status fields shown on the idle screen.
// This prevents clearing/redrawing the entire TFT every 700 ms.
bool lastDisplayedGpsReady = false;
bool lastDisplayedModemOnline = false;
bool readyStatusCacheValid = false;

// Forward declarations used by the UI.
bool getGPSCoordinates(double &latitude, double &longitude);
bool isGPSReady();


// =====================================================
// GPS SETTINGS
// =====================================================

const unsigned long GPS_MAX_AGE = 15000;


// =====================================================
// DEVICE MODES
// =====================================================

enum DeviceMode
{
  MORNING_BOARDING,
  EVENING_BOARDING,
  DEBOARDING
};

DeviceMode currentMode = MORNING_BOARDING;


// =====================================================
// MODE NAME
// =====================================================

String getModeName()
{
  switch (currentMode)
  {
    case MORNING_BOARDING:
      return "MORNING BOARDING";

    case EVENING_BOARDING:
      return "EVENING BOARDING";

    case DEBOARDING:
      return "DEBOARDING";
  }

  return "UNKNOWN";
}


String getEventType()
{
  switch (currentMode)
  {
    case MORNING_BOARDING:
      return "morning_boarding";

    case EVENING_BOARDING:
      return "evening_boarding";

    case DEBOARDING:
      return "deboarding";
  }

  return "unknown";
}


// =====================================================
// BUZZER
// =====================================================

void beep(unsigned int duration)
{
  digitalWrite(BUZZER_PIN, HIGH);

  delay(duration);

  digitalWrite(BUZZER_PIN, LOW);
}


void successBeep()
{
  beep(120);

  delay(100);

  beep(120);
}


void errorBeep()
{
  beep(700);
}


void modeBeep()
{
  if (currentMode == MORNING_BOARDING)
  {
    beep(150);
  }

  else if (currentMode == EVENING_BOARDING)
  {
    beep(120);

    delay(100);

    beep(120);
  }

  else
  {
    beep(100);

    delay(80);

    beep(100);

    delay(80);

    beep(100);
  }
}


// =====================================================
// TFT UI - SCREENING BUILD
// =====================================================

void drawHeader()
{
  tft.fillScreen(ILI9341_BLACK);
  tft.fillRect(0, 0, 320, 38, ILI9341_BLUE);
  tft.setTextColor(ILI9341_WHITE);
  tft.setTextSize(2);
  tft.setCursor(65, 10);
  tft.print("RAKSHA KWACCH");
}

String shortModeName()
{
  switch (currentMode)
  {
    case MORNING_BOARDING: return "MORNING BOARDING";
    case EVENING_BOARDING: return "EVENING BOARDING";
    case DEBOARDING: return "DEBOARDING";
  }
  return "UNKNOWN";
}

void updateReadyStatusFields(bool force = false)
{
  if (!uiIsIdle && !force) return;

  bool gpsReady = isGPSReady();

  if (force || !readyStatusCacheValid || modemOnline != lastDisplayedModemOnline)
  {
    // Clear only the 4G status field, never the whole display.
    tft.fillRect(45, 134, 125, 18, ILI9341_BLACK);
    tft.setTextSize(1);
    tft.setCursor(50, 140);
    tft.setTextColor(modemOnline ? ILI9341_GREEN : ILI9341_YELLOW);
    tft.print(modemOnline ? "4G: CONNECTED" : "4G: STARTING");
    lastDisplayedModemOnline = modemOnline;
  }

  if (force || !readyStatusCacheValid || gpsReady != lastDisplayedGpsReady)
  {
    // Clear only the GPS status field. This removes the visible full-screen flicker.
    tft.fillRect(175, 134, 140, 18, ILI9341_BLACK);
    tft.setTextSize(1);
    tft.setCursor(180, 140);
    tft.setTextColor(gpsReady ? ILI9341_GREEN : ILI9341_YELLOW);
    tft.print(gpsReady ? "GPS: READY" : "GPS: ACQUIRING");
    lastDisplayedGpsReady = gpsReady;
  }

  readyStatusCacheValid = true;
}

void showReadyScreen()
{
  // Full redraw is used only when actually entering the ready screen.
  drawHeader();
  tft.setTextColor(ILI9341_CYAN);
  tft.setTextSize(2);
  tft.setCursor(18, 55);
  tft.print(shortModeName());
  tft.drawFastHLine(10, 88, 300, ILI9341_WHITE);
  tft.setTextColor(ILI9341_GREEN);
  tft.setTextSize(2);
  tft.setCursor(65, 105);
  tft.print("SYSTEM ONLINE");

  tft.setTextColor(ILI9341_WHITE);
  tft.setTextSize(2);
  tft.setCursor(50, 178);
  tft.print("TAP RFID CARD");
  tft.setTextSize(1);
  tft.setTextColor(ILI9341_WHITE);
  tft.setCursor(48, 214);
  tft.print("Attendance + safety verification");

  readyStatusCacheValid = false;
  updateReadyStatusFields(true);
}

void showCardDetected(String uid)
{
  drawHeader();
  tft.setTextColor(ILI9341_CYAN);
  tft.setTextSize(2);
  tft.setCursor(55, 62);
  tft.print("CARD DETECTED");
  tft.setTextColor(ILI9341_WHITE);
  tft.setTextSize(1);
  tft.setCursor(90, 95);
  tft.print("RFID: ");
  tft.print(uid);
  tft.setTextSize(2);
  tft.setTextColor(ILI9341_YELLOW);
  tft.setCursor(45, 135);
  tft.print("IDENTIFYING STUDENT");
  tft.setTextSize(1);
  tft.setTextColor(ILI9341_WHITE);
  tft.setCursor(70, 180);
  tft.print("Checking GPS and verification...");
}

void showTapCapturedScreen(String uid)
{
  drawHeader();
  tft.setTextColor(ILI9341_GREEN);
  tft.setTextSize(2);
  tft.setCursor(57, 62);
  tft.print("TAP CAPTURED");

  tft.setTextColor(ILI9341_WHITE);
  tft.setTextSize(1);
  tft.setCursor(92, 94);
  tft.print("RFID: ");
  tft.print(uid);

  tft.setTextColor(ILI9341_CYAN);
  tft.setTextSize(2);
  tft.setCursor(33, 126);
  tft.print("ATTENDANCE QUEUED");

  tft.setTextColor(ILI9341_WHITE);
  tft.setTextSize(1);
  tft.setCursor(55, 164);
  tft.print("Secure verification continues");
  tft.setCursor(76, 184);
  tft.print("in the background.");

  tft.setTextColor(ILI9341_GREEN);
  tft.setTextSize(1);
  tft.setCursor(70, 218);
  tft.print("NEXT STUDENT MAY TAP");
}

void showQueueFullScreen()
{
  drawHeader();
  tft.setTextColor(ILI9341_YELLOW);
  tft.setTextSize(2);
  tft.setCursor(63, 72);
  tft.print("SYSTEM BUSY");
  tft.setTextColor(ILI9341_WHITE);
  tft.setTextSize(1);
  tft.setCursor(50, 125);
  tft.print("Attendance queue is temporarily full.");
  tft.setCursor(75, 150);
  tft.print("Please tap the card again.");
}

void showGPSError()
{
  drawHeader();
  tft.setTextColor(ILI9341_YELLOW);
  tft.setTextSize(2);
  tft.setCursor(72, 70);
  tft.print("GPS ACQUIRING");
  tft.setTextColor(ILI9341_WHITE);
  tft.setTextSize(2);
  tft.setCursor(38, 120);
  tft.print("PLEASE WAIT A MOMENT");
  tft.setTextSize(1);
  tft.setCursor(55, 170);
  tft.print("Location lock is required for safety");
  tft.setCursor(92, 190);
  tft.print("verification.");
}

void showSendingScreen()
{
  drawHeader();
  tft.setTextColor(ILI9341_GREEN);
  tft.setTextSize(2);
  tft.setCursor(85, 65);
  tft.print("GPS LOCKED");
  tft.setTextColor(ILI9341_CYAN);
  tft.setCursor(44, 112);
  tft.print("VERIFYING STUDENT");
  tft.setTextSize(1);
  tft.setTextColor(ILI9341_WHITE);
  tft.setCursor(61, 155);
  tft.print("Secure attendance request in progress");
}

String verificationDisplayName(String status)
{
  if (status == "phone_present") return "PHONE VERIFIED";
  if (status == "phone_not_nearby") return "PHONE NOT NEARBY";
  if (status == "location_unavailable") return "PHONE LOCATION UNAVAILABLE";
  if (status == "verification_uncertain") return "PHONE LOCATION UNCERTAIN";
  return "VERIFICATION RECORDED";
}

uint16_t verificationColor(String status)
{
  if (status == "phone_present") return ILI9341_GREEN;
  if (status == "phone_not_nearby") return ILI9341_RED;
  return ILI9341_YELLOW;
}

void showAttendanceResultScreen(
  bool smsComplete,
  bool smsSuccess,
  const char *studentName = nullptr,
  const char *verificationStatus = nullptr,
  double phoneDistanceM = -1.0,
  long phoneLocationAgeSeconds = -1
)
{
  drawHeader();
  String name;
  if (studentName && studentName[0])
  {
    name = String(studentName);
  }
  else if (lastStudentName.length())
  {
    name = lastStudentName;
  }
  else
  {
    name = "REGISTERED STUDENT";
  }
  if (name.length() > 24) name = name.substring(0, 24);
  tft.setTextColor(ILI9341_WHITE);
  tft.setTextSize(2);
  tft.setCursor(18, 48);
  tft.print(name);
  tft.setTextColor(ILI9341_CYAN);
  tft.setTextSize(1);
  tft.setCursor(18, 76);
  tft.print(shortModeName());
  tft.setTextColor(ILI9341_GREEN);
  tft.setTextSize(2);
  tft.setCursor(34, 98);
  tft.print("ATTENDANCE RECORDED");
  tft.drawFastHLine(12, 126, 296, ILI9341_WHITE);
  String vStatus = (verificationStatus && verificationStatus[0]) ? String(verificationStatus) : lastVerificationStatus;
  String verification = verificationDisplayName(vStatus);
  tft.setTextColor(verificationColor(vStatus));
  if (verification.length() <= 20)
  {
    tft.setTextSize(2);
    tft.setCursor(28, 140);
    tft.print(verification);
  }
  else
  {
    tft.setTextSize(1);
    tft.setCursor(64, 143);
    tft.print(verification);
  }

  if (phoneDistanceM >= 0.0 &&
      (vStatus == "phone_present" || vStatus == "phone_not_nearby"))
  {
    tft.setTextSize(1);
    tft.setTextColor(ILI9341_WHITE);
    tft.setCursor(92, 169);
    tft.print("Phone distance: ");
    if (phoneDistanceM < 1000.0)
    {
      tft.print(phoneDistanceM, 1);
      tft.print(" m");
    }
    else
    {
      tft.print(phoneDistanceM / 1000.0, 2);
      tft.print(" km");
    }
  }
  else if (phoneLocationAgeSeconds >= 0)
  {
    tft.setTextSize(1);
    tft.setTextColor(ILI9341_WHITE);
    tft.setCursor(92, 169);
    tft.print("Phone data age: ");
    tft.print(phoneLocationAgeSeconds);
    tft.print(" s");
  }
  tft.fillRect(0, 195, 320, 45, ILI9341_BLACK);
  tft.setTextSize(1);
  if (!smsComplete)
  {
    tft.setCursor(88, 205);
    tft.setTextColor(ILI9341_CYAN);
    tft.print("Parent alert: sending...");
  }
  else if (smsSuccess)
  {
    tft.setCursor(100, 205);
    tft.setTextColor(ILI9341_GREEN);
    tft.print("Parent alert: SENT");
  }
  else
  {
    tft.setCursor(65, 205);
    tft.setTextColor(ILI9341_YELLOW);
    tft.print("Attendance saved - alert pending");
  }
}

void showAlreadyRecordedScreen()
{
  drawHeader();
  tft.setTextColor(ILI9341_YELLOW);
  tft.setTextSize(2);
  tft.setCursor(32, 72);
  tft.print("ATTENDANCE ALREADY");
  tft.setCursor(92, 100);
  tft.print("RECORDED");
  tft.setTextColor(ILI9341_WHITE);
  tft.setTextSize(1);
  tft.setCursor(58, 150);
  tft.print("No duplicate entry was created.");
  tft.setCursor(71, 178);
  tft.print("Student may continue safely.");
}

void showStudentNotRegisteredScreen()
{
  drawHeader();
  tft.setTextColor(ILI9341_RED);
  tft.setTextSize(2);
  tft.setCursor(48, 72);
  tft.print("CARD NOT REGISTERED");
  tft.setTextColor(ILI9341_WHITE);
  tft.setTextSize(1);
  tft.setCursor(69, 128);
  tft.print("No attendance was recorded.");
  tft.setCursor(76, 153);
  tft.print("Please contact the admin.");
}

void showCardBlockedScreen()
{
  drawHeader();
  tft.setTextColor(ILI9341_RED);
  tft.setTextSize(2);
  tft.setCursor(88, 60);
  tft.print("CARD BLOCKED");
  tft.setCursor(82, 88);
  tft.print("ACCESS DENIED");
  tft.drawFastHLine(20, 116, 280, ILI9341_RED);
  tft.setTextColor(ILI9341_WHITE);
  tft.setTextSize(1);
  tft.setCursor(76, 134);
  tft.print("Attendance was not recorded.");
  tft.setTextColor(ILI9341_YELLOW);
  tft.setTextSize(1);
  tft.setCursor(61, 158);
  tft.print(">> VISIT TRANSPORT DEPARTMENT <<");
  tft.setTextColor(ILI9341_WHITE);
  tft.setTextSize(1);
  tft.setCursor(70, 184);
  tft.print("Contact Transport Admin Office");
}

void showServiceUnavailableScreen()
{
  drawHeader();
  tft.setTextColor(ILI9341_YELLOW);
  tft.setTextSize(2);
  tft.setCursor(42, 72);
  tft.print("SERVICE TEMPORARILY");
  tft.setCursor(88, 100);
  tft.print("UNAVAILABLE");
  tft.setTextColor(ILI9341_WHITE);
  tft.setTextSize(1);
  tft.setCursor(62, 150);
  tft.print("Attendance was not recorded.");
  tft.setCursor(70, 175);
  tft.print("Please scan the card again.");
}

// =====================================================
// CHANGE DEVICE MODE
// =====================================================

void changeMode()
{
  if (currentMode == MORNING_BOARDING)
  {
    currentMode =
      EVENING_BOARDING;
  }

  else if (
    currentMode ==
    EVENING_BOARDING
  )
  {
    currentMode =
      DEBOARDING;
  }

  else
  {
    currentMode =
      MORNING_BOARDING;
  }


  Serial.println();

  Serial.print("DEVICE MODE CHANGED: ");

  Serial.println(
    getModeName()
  );


  modeBeep();

  showReadyScreen();
}


// =====================================================
// BUTTON HANDLER
// =====================================================

void handleButton()
{
  bool currentButtonState =
    digitalRead(BUTTON_PIN);


  if (
    lastButtonState == HIGH &&
    currentButtonState == LOW
  )
  {
    if (
      millis() -
      lastDebounceTime >
      DEBOUNCE_DELAY
    )
    {
      lastDebounceTime =
        millis();

      changeMode();
    }
  }


  lastButtonState =
    currentButtonState;
}


// =====================================================
// FAST MODEM COMMAND RESPONSE
// =====================================================

String readModem(unsigned long timeout = 3000)
{
  String response = "";
  unsigned long start = millis();
  unsigned long lastData = millis();
  bool receivedAny = false;
  while (millis() - start < timeout)
  {
    while (Modem.available())
    {
      response += (char)Modem.read();
      lastData = millis();
      receivedAny = true;
    }
    if (receivedAny &&
        (response.indexOf("\r\nOK\r\n") >= 0 || response.indexOf("\nOK\r\n") >= 0 || response.indexOf("ERROR") >= 0) &&
        millis() - lastData > 20)
      break;
    delay(2);
  }
  return response;
}

String sendAT(String command, unsigned long timeout = 2000)
{
  Serial.print("\n>> ");
  Serial.println(command);
  while (Modem.available()) Modem.read();
  Modem.println(command);
  String response = readModem(timeout);
  Serial.println(response);
  return response;
}

bool setupHttpClient()
{
  Serial.println("\nConfiguring secure attendance link...");
  sendAT("AT+HTTPTERM", 800);
  String r = sendAT("AT+HTTPINIT", 1500);
  if (r.indexOf("OK") < 0) return false;
  r = sendAT("AT+CSSLCFG=\"sslversion\",0,4", 1200);
  if (r.indexOf("OK") < 0) return false;
  r = sendAT("AT+CSSLCFG=\"enableSNI\",0,1", 1200);
  if (r.indexOf("OK") < 0) return false;
  r = sendAT("AT+HTTPPARA=\"SSLCFG\",0", 1200);
  if (r.indexOf("OK") < 0) return false;
  String urlCommand = String("AT+HTTPPARA=\"URL\",\"") + FUNCTION_URL + "\"";
  r = sendAT(urlCommand, 1500);
  if (r.indexOf("OK") < 0) return false;
  r = sendAT("AT+HTTPPARA=\"CONTENT\",\"application/json\"", 1200);
  if (r.indexOf("OK") < 0) return false;
  httpClientReady = true;
  Serial.println("Secure attendance link ready.");
  return true;
}

String readHttpResponse(unsigned long timeout = 5000)
{
  String response = "";
  unsigned long start = millis();
  unsigned long lastData = millis();
  bool receivedAny = false;
  int announcedLen = -1;
  int payloadStart = -1;
  bool payloadComplete = false;

  while (millis() - start < timeout)
  {
    while (Modem.available())
    {
      response += (char)Modem.read();
      lastData = millis();
      receivedAny = true;
    }

    // Determine the announced payload length from +HTTPREAD: header
    if (announcedLen < 0)
    {
      int tagIndex = response.indexOf("+HTTPREAD: ");
      if (tagIndex >= 0)
      {
        int nl = response.indexOf('\n', tagIndex);
        if (nl > tagIndex)
        {
          String headerLine = response.substring(tagIndex + 11, nl);
          headerLine.trim();
          int comma = headerLine.indexOf(',');
          announcedLen = (comma >= 0) ? headerLine.substring(comma + 1).toInt() : headerLine.toInt();
          payloadStart = nl + 1;
        }
      }
    }

    // If announced length is known, verify whether all payload bytes have arrived
    if (announcedLen >= 0 && payloadStart >= 0)
    {
      int payloadReceived = (int)response.length() - payloadStart;
      if (payloadReceived >= announcedLen)
      {
        payloadComplete = true;
        // Payload is completely read; check for final modem status terminator or trailing silence
        int afterPayload = payloadStart + announcedLen;
        if (response.indexOf("+HTTPREAD: 0", afterPayload) >= 0 ||
            response.indexOf("\nOK", afterPayload) >= 0 ||
            millis() - lastData > 80)
        {
          break;
        }
      }
      // If announced length was identified but payload is incomplete, never exit on 800ms silence.
      // Wait for complete data until the hard timeout expires.
    }
    else if (response.indexOf("+HTTPREAD: 0") >= 0 && (response.indexOf("\nOK") >= 0 || millis() - lastData > 100))
    {
      payloadComplete = true;
      break;
    }
    else if (receivedAny && millis() - lastData > 800)
    {
      // Only stop on idle silence if no +HTTPREAD payload length was identified
      break;
    }

    delay(2);
  }

  // If a valid payload length was identified but the payload remains incomplete at timeout,
  // return an explicit failure indication ("") so the caller rejects the response.
  if (announcedLen > 0 && !payloadComplete)
  {
    Serial.print("ERROR: Incomplete HTTP response payload. Expected ");
    Serial.print(announcedLen);
    Serial.print(" bytes, received ");
    Serial.println(payloadStart >= 0 ? (int)response.length() - payloadStart : 0);
    return "";
  }

  return response;
}

String extractJsonString(const String &json, const String &key)
{
  String marker = "\"" + key + "\":\"";
  int start = json.indexOf(marker);
  if (start < 0) return "";
  start += marker.length();
  int end = json.indexOf('"', start);
  if (end < 0) return "";
  return json.substring(start, end);
}

double extractJsonNumber(const String &json, const String &key, double fallback = -1.0)
{
  String marker = "\"" + key + "\":";
  int start = json.indexOf(marker);
  if (start < 0) return fallback;
  start += marker.length();
  while (start < json.length() && json[start] == ' ') start++;
  if (json.substring(start, start + 4) == "null") return fallback;
  int end = start;
  while (end < json.length())
  {
    char c = json[end];
    if (!(isDigit(c) || c == '-' || c == '+' || c == '.' || c == 'e' || c == 'E')) break;
    end++;
  }
  if (end == start) return fallback;
  return json.substring(start, end).toDouble();
}

// =====================================================
// WAIT FOR DOWNLOAD
// =====================================================

bool waitForDownload(
  unsigned long timeout = 10000
)
{
  unsigned long start =
    millis();

  String response = "";


  while (
    millis() - start <
    timeout
  )
  {
    while (
      Modem.available()
    )
    {
      response +=
        (char)Modem.read();
    }


    if (
      response.indexOf(
        "DOWNLOAD"
      ) >= 0
    )
    {
      Serial.println(
        "Modem ready for POST data."
      );

      return true;
    }


    if (
      response.indexOf(
        "ERROR"
      ) >= 0
    )
    {
      Serial.println(response);

      return false;
    }


    delay(5);
  }


  Serial.println(
    "DOWNLOAD timeout."
  );

  Serial.println(response);


  return false;
}


// =====================================================
// WAIT FOR BODY ACCEPTANCE
// =====================================================

bool waitForBodyAccepted(
  unsigned long timeout = 10000
)
{
  unsigned long start =
    millis();

  String response = "";


  while (
    millis() - start <
    timeout
  )
  {
    while (
      Modem.available()
    )
    {
      response +=
        (char)Modem.read();
    }


    if (
      response.indexOf(
        "ERROR"
      ) >= 0
    )
    {
      Serial.println(response);

      return false;
    }


    if (
      response.indexOf(
        "OK"
      ) >= 0
    )
    {
      Serial.println(response);

      return true;
    }


    delay(5);
  }


  Serial.println(
    "POST body acceptance timeout."
  );

  Serial.println(response);


  return false;
}


// =====================================================
// WAIT FOR HTTP ACTION
// =====================================================

int waitForHttpAction(
  unsigned long timeout = 60000
)
{
  unsigned long start =
    millis();

  String response = "";


  while (
    millis() - start <
    timeout
  )
  {
    while (
      Modem.available()
    )
    {
      response +=
        (char)Modem.read();
    }


    int pos =
      response.indexOf(
        "+HTTPACTION:"
      );


    if (pos >= 0)
    {
      Serial.println(
        "\nHTTP ACTION RESULT:"
      );

      Serial.println(response);


      int firstComma =
        response.indexOf(
          ',',
          pos
        );


      int secondComma =
        response.indexOf(
          ',',
          firstComma + 1
        );


      if (
        firstComma >= 0 &&
        secondComma >= 0
      )
      {
        return response.substring(
          firstComma + 1,
          secondComma
        ).toInt();
      }
    }


    delay(5);
  }


  Serial.println(
    "HTTPACTION timeout."
  );

  Serial.println(response);


  return -1;
}


// =====================================================
// DUPLICATE PROTECTION
// =====================================================

bool isDuplicateScan(String uid, String eventType)
{
  for (int i = 0; i < processedEventCount; i++)
  {
    if (uid.equals(processedEvents[i].uid) &&
        eventType.equals(processedEvents[i].eventType))
    {
      return true;
    }
  }

  return false;
}


void rememberSuccessfulScan(String uid, String eventType)
{
  // Do not add the same event twice.
  if (isDuplicateScan(uid, eventType))
  {
    return;
  }

  if (processedEventCount >= MAX_SESSION_EVENTS)
  {
    Serial.println("WARNING: Session duplicate cache is full.");
    return;
  }

  uid.toCharArray(
    processedEvents[processedEventCount].uid,
    sizeof(processedEvents[processedEventCount].uid)
  );

  eventType.toCharArray(
    processedEvents[processedEventCount].eventType,
    sizeof(processedEvents[processedEventCount].eventType)
  );

  processedEventCount++;

  Serial.print("Session event remembered. Total successful events: ");
  Serial.println(processedEventCount);
}

void forgetProcessedScan(String uid, String eventType)
{
  for (int i = 0; i < processedEventCount; i++)
  {
    if (uid.equals(processedEvents[i].uid) &&
        eventType.equals(processedEvents[i].eventType))
    {
      for (int j = i; j < processedEventCount - 1; j++)
      {
        processedEvents[j] = processedEvents[j + 1];
      }
      processedEventCount--;
      return;
    }
  }
}


// =====================================================
// SMS - FAST SCREENING PATH
// =====================================================

bool sendSMS(String message)
{
  Serial.println("\nSending parent alert...");

  // Re-assert SMS text mode immediately before every send. HTTP activity can
  // leave the modem in a different command context on some A7672S firmware.
  String smsMode = sendAT("AT+CMGF=1", 2000);
  if (smsMode.indexOf("OK") < 0)
  {
    Serial.println("SMS ERROR: Could not enter text mode.");
    return false;
  }

  String charset = sendAT("AT+CSCS=\"GSM\"", 2000);
  if (charset.indexOf("OK") < 0)
  {
    Serial.println("SMS WARNING: Could not confirm GSM character set.");
  }

  while (Modem.available()) Modem.read();

  Modem.print("AT+CMGS=\"");
  Modem.print(PARENT_PHONE);
  Modem.println("\"");

  unsigned long start = millis();
  String prompt = "";

  while (millis() - start < 8000)
  {
    while (Modem.available())
    {
      prompt += (char)Modem.read();
    }

    if (prompt.indexOf(">") >= 0) break;
    if (prompt.indexOf("ERROR") >= 0 || prompt.indexOf("+CMS ERROR:") >= 0) break;
    delay(2);
  }

  Serial.println("SMS CMGS PROMPT RESPONSE:");
  Serial.println(prompt);

  if (prompt.indexOf(">") < 0)
  {
    Serial.println("SMS ERROR: Modem did not provide the > prompt.");
    return false;
  }

  Modem.print(message);
  Modem.write(26); // Ctrl+Z submits the SMS

  // Cellular SMS submission can legitimately take well over 12 seconds.
  start = millis();
  String result = "";

  while (millis() - start < 45000)
  {
    while (Modem.available())
    {
      result += (char)Modem.read();
    }

    if (result.indexOf("+CMGS:") >= 0 && result.indexOf("OK") >= 0)
    {
      Serial.println("SMS MODEM RESPONSE:");
      Serial.println(result);
      Serial.println("PARENT ALERT SENT");
      return true;
    }

    if (result.indexOf("+CMS ERROR:") >= 0 || result.indexOf("\r\nERROR\r\n") >= 0)
    {
      Serial.println("SMS MODEM RESPONSE:");
      Serial.println(result);
      Serial.println("SMS ERROR: Modem/network rejected the message.");
      return false;
    }

    delay(5);
  }

  Serial.println("SMS MODEM RESPONSE (TIMEOUT):");
  Serial.println(result);
  Serial.println("Parent alert pending; attendance remains saved.");
  return false;
}

// =====================================================
// GPS - CONTINUOUS BACKGROUND PARSER
// =====================================================

void gpsWorkerTask(void *parameter)
{
  for (;;)
  {
    while (GPS.available())
    {
      gps.encode(GPS.read());

      if (gps.location.isUpdated() && gps.location.isValid())
      {
        portENTER_CRITICAL(&gpsMux);
        gpsSnapshotLat = gps.location.lat();
        gpsSnapshotLon = gps.location.lng();
        gpsSnapshotMillis = millis();
        gpsSnapshotValid = true;
        portEXIT_CRITICAL(&gpsMux);
      }
    }

    vTaskDelay(pdMS_TO_TICKS(5));
  }
}

bool getGPSCoordinates(double &latitude, double &longitude)
{
  bool valid;
  double lat;
  double lon;
  unsigned long stamp;

  portENTER_CRITICAL(&gpsMux);
  valid = gpsSnapshotValid;
  lat = gpsSnapshotLat;
  lon = gpsSnapshotLon;
  stamp = gpsSnapshotMillis;
  portEXIT_CRITICAL(&gpsMux);

  if (!valid) return false;
  if (millis() - stamp > GPS_MAX_AGE) return false;

  latitude = lat;
  longitude = lon;
  return true;
}

bool isGPSReady()
{
  double lat = 0.0;
  double lon = 0.0;
  return getGPSCoordinates(lat, lon);
}


// =====================================================
// RFID UID
// =====================================================

String getRFIDUID()
{
  String uid = "";


  for (
    byte i = 0;
    i < rfid.uid.size;
    i++
  )
  {
    if (
      rfid.uid.uidByte[i] <
      0x10
    )
    {
      uid += "0";
    }


    uid += String(
      rfid.uid.uidByte[i],
      HEX
    );
  }


  uid.toUpperCase();


  return uid;
}


// =====================================================
// SEND ATTENDANCE - REUSES THE HTTP SESSION FOR SPEED
// =====================================================

int sendAttendance(String rfidUID, double latitude, double longitude, String eventType)
{
  Serial.println("\n================================");
  Serial.println("SECURE ATTENDANCE REQUEST");
  Serial.println("================================");
  lastServerResponse = "";
  lastStudentName = "";
  lastVerificationStatus = "";
  lastPhoneDistanceM = -1.0;
  lastPhoneLocationAgeSeconds = -1;
  lastPhoneAccuracyM = -1.0;

  if (!httpClientReady && !setupHttpClient())
  {
    Serial.println("Attendance service connection failed.");
    return -1;
  }

  String json = String("{") +
    "\"rfid_uid\":\"" + rfidUID + "\"," +
    "\"latitude\":" + String(latitude, 6) + "," +
    "\"longitude\":" + String(longitude, 6) + "," +
    "\"device_id\":\"" + DEVICE_ID + "\"," +
    "\"event_type\":\"" + eventType + "\"" + "}";

  Serial.println("POST JSON:");
  Serial.println(json);
  while (Modem.available()) Modem.read();
  String dataCommand = String("AT+HTTPDATA=") + String(json.length()) + ",5000";
  Modem.println(dataCommand);
  if (!waitForDownload(5000))
  {
    httpClientReady = false;
    return -1;
  }
  Modem.print(json);
  if (!waitForBodyAccepted(5000))
  {
    httpClientReady = false;
    return -1;
  }
  while (Modem.available()) Modem.read();
  Modem.println("AT+HTTPACTION=1");
  int statusCode = waitForHttpAction(15000);
  if (statusCode < 0)
  {
    httpClientReady = false;
    return -1;
  }

  Serial.println("\nServer response:");
  delay(50);
  while (Modem.available()) Modem.read();
  Modem.println("AT+HTTPREAD=0,512");
  lastServerResponse = readHttpResponse(5000);
  Serial.println(lastServerResponse);

  if (lastServerResponse.length() == 0)
  {
    Serial.println("ERROR: Incomplete or empty HTTP response from modem.");
    httpClientReady = false;
    return -1;
  }

  lastStudentName = extractJsonString(lastServerResponse, "student_name");
  lastVerificationStatus = extractJsonString(lastServerResponse, "verification_status");
  lastPhoneDistanceM = extractJsonNumber(lastServerResponse, "phone_distance_m", -1.0);
  lastPhoneLocationAgeSeconds = (long)extractJsonNumber(lastServerResponse, "phone_location_age_seconds", -1.0);
  lastPhoneAccuracyM = extractJsonNumber(lastServerResponse, "phone_accuracy_m", -1.0);

  Serial.print("HTTP STATUS: ");
  Serial.println(statusCode);
  return statusCode;
}

// =====================================================
// BACKGROUND NETWORK WORKER
// =====================================================

void networkWorkerTask(void *parameter)
{
  AttendanceJob job;

  for (;;)
  {
    if (xQueueReceive(attendanceQueue, &job, portMAX_DELAY) == pdTRUE)
    {
      networkBusy = true;

      int statusCode = sendAttendance(
        String(job.uid),
        job.latitude,
        job.longitude,
        String(job.eventType)
      );

      AttendanceResult result = {};
      result.statusCode = statusCode;
      strncpy(result.uid, job.uid, sizeof(result.uid) - 1);
      strncpy(result.eventType, job.eventType, sizeof(result.eventType) - 1);
      strncpy(result.modeName, job.modeName, sizeof(result.modeName) - 1);
      lastStudentName.toCharArray(result.studentName, sizeof(result.studentName));
      lastVerificationStatus.toCharArray(result.verificationStatus, sizeof(result.verificationStatus));
      result.phoneDistanceM = lastPhoneDistanceM;
      result.phoneLocationAgeSeconds = lastPhoneLocationAgeSeconds;
      result.phoneAccuracyM = lastPhoneAccuracyM;
      result.smsAttempted = false;
      result.smsSuccess = false;
      result.isCardBlocked = (statusCode == 403 &&
        (lastServerResponse.indexOf("CARD_BLOCKED") >= 0 ||
         extractJsonString(lastServerResponse, "error_code") == "CARD_BLOCKED"));

      if (statusCode == 200)
      {
        // Parent alert with a directly tappable Google Maps location URL.
        // Kept concise so the normal screening message remains SMS-friendly.
        String smsMessage = "RAKSHA KWACCH: ";
        smsMessage += lastStudentName.length() ? lastStudentName : "Student";
        smsMessage += " attendance recorded. ";
        smsMessage += verificationDisplayName(lastVerificationStatus);
        smsMessage += ". Map: https://maps.google.com/?q=";
        smsMessage += String(job.latitude, 6);
        smsMessage += ",";
        smsMessage += String(job.longitude, 6);

        result.smsAttempted = true;
        result.smsSuccess = sendSMS(smsMessage);
      }

      xQueueSend(resultQueue, &result, portMAX_DELAY);
      networkBusy = false;
    }
  }
}


// =====================================================
// SETUP
// =====================================================

void setup()
{
  Serial.begin(115200);

  delay(400);


  Serial.println();

  Serial.println(
    "================================"
  );

  Serial.println(
    "RAKSHA KWACCH SYSTEM STARTING"
  );

  Serial.println(
    "================================"
  );


  // -----------------------------------------
  // BUZZER
  // -----------------------------------------

  pinMode(
    BUZZER_PIN,
    OUTPUT
  );

  digitalWrite(
    BUZZER_PIN,
    LOW
  );


  // -----------------------------------------
  // BUTTON
  // -----------------------------------------

  pinMode(
    BUTTON_PIN,
    INPUT_PULLUP
  );


  // -----------------------------------------
  // TFT SPI
  // -----------------------------------------

  tftSPI.begin(
    TFT_SCLK,
    TFT_MISO,
    TFT_MOSI,
    TFT_CS
  );


  tft.begin();

  tft.setRotation(1);

  drawHeader();


  tft.setTextColor(
    ILI9341_YELLOW
  );

  tft.setTextSize(2);

  tft.setCursor(
    55,
    100
  );

  tft.print(
    "INITIALIZING..."
  );


  Serial.println(
    "TFT initialized."
  );


  // -----------------------------------------
  // GPS
  // -----------------------------------------

  GPS.begin(
    GPS_BAUD,
    SERIAL_8N1,
    GPS_RX,
    GPS_TX
  );


  Serial.println(
    "GPS UART started."
  );

  // Parse GPS continuously even while modem/network code is busy.
  xTaskCreatePinnedToCore(
    gpsWorkerTask,
    "RakshaGPS",
    4096,
    nullptr,
    2,
    &gpsTaskHandle,
    0
  );


  // -----------------------------------------
  // RFID SPI
  // -----------------------------------------

  SPI.begin(
    RFID_SCK,
    RFID_MISO,
    RFID_MOSI,
    RFID_SS
  );


  rfid.PCD_Init();


  Serial.println(
    "RFID reader initialized."
  );


  // -----------------------------------------
  // MODEM
  // -----------------------------------------

  Modem.begin(
    MODEM_BAUD,
    SERIAL_8N1,
    MODEM_RX,
    MODEM_TX
  );


  delay(500);


  Serial.println(
    "Checking modem..."
  );


  String modemResponse =
    sendAT("AT");


  if (
    modemResponse.indexOf(
      "OK"
    ) >= 0
  )
  {
    Serial.println(
      "4G modem ready."
    );
  }

  else
  {
    Serial.println(
      "WARNING: Modem did not respond."
    );
  }


  // -----------------------------------------
  // PRE-WARM NETWORK SERVICES
  // -----------------------------------------

  modemOnline = modemResponse.indexOf("OK") >= 0;

  if (modemOnline)
  {
    sendAT("AT+CMGF=1", 1200);
    if (!setupHttpClient())
      Serial.println("Attendance link will retry on first scan.");
  }

  // -----------------------------------------
  // BACKGROUND ATTENDANCE PIPELINE
  // -----------------------------------------

  attendanceQueue = xQueueCreate(12, sizeof(AttendanceJob));
  resultQueue = xQueueCreate(12, sizeof(AttendanceResult));

  if (attendanceQueue && resultQueue)
  {
    xTaskCreatePinnedToCore(
      networkWorkerTask,
      "RakshaNetwork",
      12288,
      nullptr,
      1,
      &networkTaskHandle,
      0
    );
  }
  else
  {
    Serial.println("WARNING: Attendance background queue could not start.");
  }

  // -----------------------------------------
  // READY
  // -----------------------------------------

  Serial.println();

  Serial.println(
    "================================"
  );

  Serial.println(
    "RAKSHA KWACCH READY"
  );

  Serial.print(
    "MODE: "
  );

  Serial.println(
    getModeName()
  );

  Serial.println(
    "PLEASE SCAN STUDENT RFID CARD"
  );

  Serial.println(
    "================================"
  );


  showReadyScreen();
  uiIsIdle = true;
  lastReadyRefresh = millis();

  // Startup confirmation
  beep(100);

  delay(80);

  beep(100);
}


// =====================================================
// MAIN LOOP - RFID NEVER WAITS FOR 4G / SUPABASE / SMS
// =====================================================

void loop()
{
  // ---------------------------------------------------
  // DISPLAY COMPLETED BACKGROUND RESULTS
  // ---------------------------------------------------

  AttendanceResult result;

  if (resultQueue && xQueueReceive(resultQueue, &result, 0) == pdTRUE)
  {
    lastStudentName = String(result.studentName);
    lastVerificationStatus = String(result.verificationStatus);
    lastPhoneDistanceM = result.phoneDistanceM;
    lastPhoneLocationAgeSeconds = result.phoneLocationAgeSeconds;
    lastPhoneAccuracyM = result.phoneAccuracyM;

    String resultUid = String(result.uid);
    String resultEventType = String(result.eventType);

    if (result.statusCode == 200)
    {
      Serial.println("\n================================");
      Serial.println("ATTENDANCE SYNCED");
      Serial.println("================================");
      Serial.print("Student: ");
      Serial.println(result.studentName[0] ? result.studentName : (lastStudentName.length() ? lastStudentName.c_str() : "REGISTERED STUDENT"));
      Serial.print("Verification: ");
      Serial.println(result.verificationStatus[0] ? result.verificationStatus : (lastVerificationStatus.length() ? lastVerificationStatus.c_str() : "verified"));

      showAttendanceResultScreen(
        result.smsAttempted,
        result.smsSuccess,
        result.studentName,
        result.verificationStatus,
        result.phoneDistanceM,
        result.phoneLocationAgeSeconds
      );
      successBeep();
      uiIsIdle = false;
      uiReturnAt = millis() + 1800;
    }
    else if (result.statusCode == 403 && result.isCardBlocked)
    {
      // Card blocked by Three-Strike Disciplinary Policy.
      // Must forget processed scan so once unblocked by admin, the card works without rebooting device.
      forgetProcessedScan(resultUid, resultEventType);
      Serial.println("\n================================");
      Serial.println("TRANSPORT CARD BLOCKED");
      Serial.println("================================");
      Serial.println("Error: CARD_BLOCKED (Three-Strike Disciplinary Policy)");
      Serial.println("Access Denied - Visit Transport Department");

      showCardBlockedScreen();
      errorBeep();
      uiIsIdle = false;
      uiReturnAt = millis() + 2500;
    }
    else if (result.statusCode == 409)
    {
      Serial.println("\nATTENDANCE ALREADY RECORDED ON SERVER");
      showAlreadyRecordedScreen();
      beep(80);
      uiIsIdle = false;
      uiReturnAt = millis() + 1400;
    }
    else if (result.statusCode == 404)
    {
      // A locally captured tap was not a registered student. Allow retry.
      forgetProcessedScan(resultUid, resultEventType);
      Serial.println("\nCARD NOT REGISTERED");
      showStudentNotRegisteredScreen();
      errorBeep();
      uiIsIdle = false;
      uiReturnAt = millis() + 1800;
    }
    else
    {
      // Network/server problem: allow the card to be tapped again.
      forgetProcessedScan(resultUid, resultEventType);
      Serial.println("\nATTENDANCE SYNC FAILED - RETRY ALLOWED");
      showServiceUnavailableScreen();
      errorBeep();
      uiIsIdle = false;
      uiReturnAt = millis() + 1800;
    }
  }

  // ---------------------------------------------------
  // RETURN TO READY + REFRESH GPS STATUS AUTOMATICALLY
  // ---------------------------------------------------

  if (!uiIsIdle && uiReturnAt != 0 && (long)(millis() - uiReturnAt) >= 0)
  {
    showReadyScreen();
    uiIsIdle = true;
    uiReturnAt = 0;
    lastReadyRefresh = millis();
  }

  if (uiIsIdle && millis() - lastReadyRefresh >= 700)
  {
    // Poll GPS/4G status, but repaint only a status field if its value changed.
    // Do NOT clear/redraw the whole TFT while idle.
    updateReadyStatusFields();
    lastReadyRefresh = millis();
  }

  // ---------------------------------------------------
  // MODE BUTTON
  // ---------------------------------------------------

  handleButton();

  // ---------------------------------------------------
  // RFID - THIS PATH STAYS FAST
  // ---------------------------------------------------

  if (!rfid.PICC_IsNewCardPresent())
  {
    delay(5);
    return;
  }

  if (!rfid.PICC_ReadCardSerial())
  {
    delay(5);
    return;
  }

  String uid = getRFIDUID();
  String eventType = getEventType();
  String modeName = getModeName();

  rfid.PICC_HaltA();
  rfid.PCD_StopCrypto1();

  Serial.println("\n================================");
  Serial.println("RFID TAP CAPTURED");
  Serial.println("================================");
  Serial.print("RFID UID: ");
  Serial.println(uid);
  Serial.print("MODE: ");
  Serial.println(modeName);

  if (isDuplicateScan(uid, eventType))
  {
    Serial.println("LOCAL DUPLICATE BLOCKED INSTANTLY.");
    showAlreadyRecordedScreen();
    beep(80);
    uiIsIdle = false;
    uiReturnAt = millis() + 1000;
    return;
  }

  double latitude = 0.0;
  double longitude = 0.0;

  if (!getGPSCoordinates(latitude, longitude))
  {
    Serial.println("GPS FIX NOT READY - TAP NOT QUEUED.");
    showGPSError();
    errorBeep();
    uiIsIdle = false;
    uiReturnAt = millis() + 1200;
    return;
  }

  // Prevent rapid double taps immediately, before network sync finishes.
  rememberSuccessfulScan(uid, eventType);

  AttendanceJob job = {};
  uid.toCharArray(job.uid, sizeof(job.uid));
  eventType.toCharArray(job.eventType, sizeof(job.eventType));
  modeName.toCharArray(job.modeName, sizeof(job.modeName));
  job.latitude = latitude;
  job.longitude = longitude;

  if (!attendanceQueue || xQueueSend(attendanceQueue, &job, 0) != pdTRUE)
  {
    forgetProcessedScan(uid, eventType);
    Serial.println("ATTENDANCE QUEUE FULL - RETRY REQUIRED.");
    showQueueFullScreen();
    errorBeep();
    uiIsIdle = false;
    uiReturnAt = millis() + 1200;
    return;
  }

  // The door-side interaction ends here: ~instant acknowledgement.
  beep(70);
  showTapCapturedScreen(uid);
  uiIsIdle = false;
  uiReturnAt = millis() + 700;

  Serial.print("GPS SNAPSHOT: ");
  Serial.print(latitude, 6);
  Serial.print(", ");
  Serial.println(longitude, 6);
  Serial.println("ATTENDANCE EVENT QUEUED - NEXT STUDENT MAY TAP.");
}

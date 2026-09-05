/*
 * BirdPi — XIAO ESP32-S3 Sense PDM capture → WebSocket stream
 *
 * Hardware: Seeed XIAO ESP32-S3 Sense (built-in PDM mic on the expansion board)
 * Capture : 16 kHz, 16-bit mono PDM via I2S-PDM peripheral
 * Stream  : binary WebSocket frames to a LAN receiver (iOS app in ../ios/)
 * Power   : modem-sleep duty cycle by default; optional true deep sleep
 *
 * UNTESTED ON HARDWARE — written to spec from the ESP32 Arduino core APIs
 * (core 3.x). Expect minor fixes on first bring-up.
 *
 * Libraries (Arduino Library Manager):
 *   - WebSockets by Markus Sattler (links2004)
 *   - ArduinoJson (v7)
 */

#include <WiFi.h>
#include <WiFiClient.h>
#include <WebSocketsClient.h>
#include <ArduinoJson.h>
#include <PDM.h>   // ESP32 Arduino core built-in PDM (I2S-PDM) driver

// ---------------- User config ----------------
static const char* WIFI_SSID = "YOUR_SSID";
static const char* WIFI_PASS = "YOUR_PASS";

// Receiver (iPhone app) address. Use the IP shown in the app's Settings tab.
static const char* WS_HOST = "192.168.1.42";
static const uint16_t WS_PORT = 8765;

// Duty cycle
static const uint32_t LISTEN_MS   = 30ul * 1000;  // capture + stream
static const uint32_t SLEEP_MS    = 90ul * 1000;  // modem off, socket kept
// Set to 1 for true deep sleep between cycles (max battery, ~4 s reconnect)
#ifndef BIRDPI_AGGRESSIVE_SLEEP
#define BIRDPI_AGGRESSIVE_SLEEP 0
#endif

// ---------------- Audio config ----------------
static const uint32_t SAMPLE_RATE = 16000;
static const size_t   CHUNK_BYTES = 1024;  // per WS binary frame (512 x int16)

// ---------------- State ----------------
static WebSocketsClient ws;
static int16_t pcmBuf[CHUNK_BYTES / sizeof(int16_t)];
static volatile size_t pcmFilled = 0;
static uint32_t cycleStart = 0;
static bool listening = false;
static uint32_t framesSent = 0;

// ---- PDM callback: moves samples from driver buffer to our PCM buffer ----
void onPDMdata() {
  int bytes = PDM.available();
  if (bytes <= 0) return;
  // Read directly into staging; PDM.read() copies up to requested size.
  static int16_t tmp[512];
  int n = bytes / sizeof(int16_t);
  if (n > (int)(sizeof(tmp)/sizeof(tmp[0]))) n = sizeof(tmp)/sizeof(tmp[0]);
  PDM.read(tmp, n);
  for (int i = 0; i < n; i++) {
    pcmBuf[pcmFilled++] = tmp[i];
    if (pcmFilled >= sizeof(pcmBuf)/sizeof(pcmBuf[0])) {
      pcmFilled = 0;
      if (ws.isConnected()) {
        ws.sendBIN((uint8_t*)pcmBuf, CHUNK_BYTES);
        framesSent++;
      }
    }
  }
}

void connectWiFi() {
  WiFi.mode(WIFI_STA);
  WiFi.setSleep(false);              // low latency while streaming
  WiFi.begin(WIFI_SSID, WIFI_PASS);
  uint32_t t0 = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - t0 < 15000) {
    delay(200);
  }
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("[BIRDPI] WiFi failed, rebooting");
    ESP.restart();
  }
  Serial.printf("[BIRDPI] WiFi connected, IP %s\n", WiFi.localIP().toString().c_str());
}

void setup() {
  Serial.begin(115200);
  delay(300);

  connectWiFi();

  ws.begin(WS_HOST, WS_PORT, "/");
  ws.setReconnectInterval(2000);

  // PDM mic: 16 kHz, 16-bit mono. On the XIAO ESP32-S3 Sense the mic is wired
  // internally on the expansion board; default PDM pins from the core work.
  PDM.onReceive(onPDMdata);
  PDM.setBufferSize(1024);
  if (!PDM.begin(1, SAMPLE_RATE)) {
    Serial.println("[BIRDPI] PDM init failed!");
  }
  Serial.printf("[BIRDPI] PDM configured: %lu Hz, 16-bit mono\n",
                (unsigned long)SAMPLE_RATE);

  cycleStart = millis();
  listening = true;
}

void startListening() {
  WiFi.setSleep(false);
  WiFi.resume();           // back from modem sleep
  ws.begin(WS_HOST, WS_PORT, "/");
  PDM.begin(1, SAMPLE_RATE);
  framesSent = 0;
  cycleStart = millis();
  listening = true;
  Serial.println("[BIRDPI] listen window start");
}

void stopListening() {
  PDM.end();
  listening = false;
  Serial.printf("[BIRDPI] listen window end, %lu frames sent\n",
                (unsigned long)framesSent);
}

#if BIRDPI_AGGRESSIVE_SLEEP
static void deepSleepCycle() {
  esp_sleep_enable_timer_wakeup((uint64_t)(LISTEN_MS + SLEEP_MS) * 1000ULL);
  Serial.println("[BIRDPI] deep sleep");
  Serial.flush();
  esp_deep_sleep_start();
  // never returns; setup() runs again on wake
}
#endif

void loop() {
  ws.loop();

  uint32_t elapsed = millis() - cycleStart;

  if (listening) {
#if !BIRDPI_AGGRESSIVE_SLEEP
    if (elapsed >= LISTEN_MS) {
      stopListening();
      // Modem off (light sleep, TCP preserved in the stack's modem-sleep mode
      // with keepalive). Simplest robust approach: WiFi.setSleep(true) +
      // stop WS pings. Reconnect on wake.
      WiFi.setSleep(true);
    }
#endif
  } else {
#if BIRDPI_AGGRESSIVE_SLEEP
    deepSleepCycle();
#else
    if (elapsed >= LISTEN_MS + SLEEP_MS) {
      startListening();
    }
#endif
  }

  // Send a status ping every ~100 frames so the receiver shows liveness.
  if (listening && framesSent > 0 && (framesSent % 100) == 0) {
    StaticJsonDocument<192> doc;
    doc["t"] = "status";
    doc["frames"] = (uint32_t)framesSent;
    doc["rssi"] = WiFi.RSSI();
    doc["vbat_mv"] = analogReadMilliVolts(A0);  // XIAO BAT pad divider on A0
    char buf[192];
    size_t len = serializeJson(doc, buf, sizeof(buf));
    ws.sendTXT(buf, len);
  }

  delay(2);  // yield
}

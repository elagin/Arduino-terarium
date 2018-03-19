#include <LiquidCrystal_I2C.h>
#include <OneWire.h>
#include <DallasTemperature.h>
/*
  #if defined(ARDUINO) && ARDUINO > 18
  #include <SPI.h>
  #endif
  #include <Ethernet.h>
  #include <EthernetDHCP.h>
*/
// Data wire is plugged into port 2 on the Arduino
#define ONE_WIRE_BUS 2
#define TEMPERATURE_PRECISION 9

// initialize the library with the numbers of the interface pins
LiquidCrystal_I2C lcd(0x27, 20, 4);   // Задаем адрес и размерность дисплея.
#define MAX_DS1820_SENSORS 5

char displayBuf[200];

signed int TempPrev[MAX_DS1820_SENSORS];
char deltaT[MAX_DS1820_SENSORS]; // positive delta t 0 = warm, 1 cold

long scanTempInterval = 1000 * 5;        // Интервал замера температуры при больше 25 - не опрашиваются датчики во второй раз
long printInterval = 1000 * 5;           // Интервал обновления экрана при больше 25 - не опрашиваются датчики во второй раз

long previousScanTempMillis = 0;     // Предидущее время замера температуры
long previousPrintMillis = 0;        // Предидущее время обновления экрана

unsigned char sensorCount = 0;
char buf[40];
char bufSerial[20];
char bufFloat[40];

unsigned char screenSizeX = 20;
unsigned char screenSizeY = 4;

char ledScanTime = 13;
char ledAlarm    = 40;

bool isRestart = true;
bool isRepaint = false;
/*
  // Just a utility function to nicely format an IP address.
  const char* ip_to_str(const uint8_t* ipAddr)
  {
  static char buf[16];
  sprintf(buf, "%d.%d.%d.%d\0", ipAddr[0], ipAddr[1], ipAddr[2], ipAddr[3]);
  return buf;
  }
*/
struct sensorData
{
  DeviceAddress addr;     // Адрес датчика
  char name[20];          // Имя для отображения
  bool        trackMin;   // Отслеживать мин. температуру
  bool        trackMax;   // Отслеживать макс. температуру
  signed char minLimit;   // Минимальный лимит температуры
  signed char maxLimit;   // Максимальный лимит
  signed char minTemp;    // Минимальное значение температуры
  signed char maxTemp;    // Максимальное значение температуры
  signed char temp;       // Текущее значение температуры
};

//byte mac[] = {  0xDE, 0xAD, 0xBE, 0xEF, 0xdE, 0xED };
//byte server[] = { 192, 168, 0, 103 }; // ya.ru
//byte ip[] = { 192, 168, 0, 100 };
//byte server[] = { 77,88,21,3 }; // ya.ru

const int printRoundSize = 5;
int printRound[printRoundSize] = {0, 3, 4};

OneWire oneWire(ONE_WIRE_BUS);  // Setup a oneWire instance to communicate with any OneWire devices (not just Maxim/Dallas temperature ICs)
DallasTemperature sensors(&oneWire);    // Pass our oneWire reference to Dallas Temperature.
DeviceAddress insideThermometer, outsideThermometer;    // arrays to hold device addresses
sensorData sensorsParams[MAX_DS1820_SENSORS] = {
  0x28, 0x1A, 0xAE, 0xC7, 0x02, 0x0, 0x0, 0xEB, "Out", false, false, 0, 0, 0, 0, 0, //remote
  0x28, 0x93, 0xBB, 0xC7, 0x02, 0x00, 0x00, 0x39, "rename", false, true, 0, 30, 0, 0, 0
};

void roundRotate()
{
  int mem = printRound[0];
  for (int i = 0; i < printRoundSize - 1; i++)
  {
    printRound[i] = printRound[i + 1];
  }
  printRound[printRoundSize - 1] = mem;
}

void setup()
{
  pinMode(10, OUTPUT);
  pinMode(4, OUTPUT);
  digitalWrite(10, HIGH);
  digitalWrite(4, HIGH);

  delay(200);
  Serial.begin(9600);
  Serial1.begin(9600); // BT 18 - 19 Pins

  //  sprintf(displayBuf, "Attempting to obtain a DHCP lease...");
  //  Serial.println(displayBuf);
  /*
    EthernetDHCP.begin(mac);
    //    Ethernet.begin(mac, ip);
    const byte* ipAddr = EthernetDHCP.ipAddress();

    sprintf(displayBuf, "A DHCP lease has been obtained.");
    Serial.println(displayBuf);
    //    lcd.print(displayBuf);

    sprintf(displayBuf, "My IP address is  %s", ip_to_str(ipAddr));
    Serial.println(displayBuf);
  */
  lcd.init();                            // Инициализация lcd
  lcd.backlight();                       // Включаем подсветку
  lcd.clear();
  sensors.begin();
  oneWire.reset_search();
  for (int i = 0; i < MAX_DS1820_SENSORS; i++)
  {
    if (oneWire.search(sensorsParams[i].addr))
    {
      sensors.setResolution(sensorsParams[i].addr, TEMPERATURE_PRECISION);
      sensorCount++;
    }
    else
    {
      break;
    }
  }

  pinMode(ledScanTime, OUTPUT);
  pinMode(ledAlarm, OUTPUT);
  lcd.begin(screenSizeX, screenSizeY);
  lcd.setCursor(0, 0);
  sprintf(buf, "Found %d sensors", sensorCount);
  Serial.println(buf);
  lcd.print(buf);
  delay(500);
  lcd.clear();
  if (sensorCount == 0)
  {
    return;
  }

  digitalWrite(4, HIGH);
}

// function to print a device address
void printAddress(DeviceAddress deviceAddress)
{
  for (uint8_t i = 0; i < 8; i++)
  {
    // zero pad the address if necessary
    if (deviceAddress[i] < 16) Serial.print("0");
    Serial.print(deviceAddress[i], HEX);
  }
}

void getSensorData()
{
  byte present = 0;
  digitalWrite(ledScanTime, HIGH);
  sensors.requestTemperatures();
  bool isAlarm = false;
  for (int i = 0; i < sensorCount; i++)
  {
    int sensor = printRound[i];
    sensorsParams[sensor].temp = sensors.getTempC(sensorsParams[sensor].addr);

    if (TempPrev[sensor] > sensorsParams[sensor].temp)
    {
      deltaT[sensor] = 1;
    }
    else if (TempPrev[sensor] < sensorsParams[sensor].temp)
    {
      deltaT[sensor] = 0;
    }
    else
    {
      deltaT[sensor] = 2;
    }
    if (sensorsParams[sensor].temp < sensorsParams[sensor].minTemp || isRestart)
    {
      sensorsParams[sensor].minTemp = sensorsParams[sensor].temp;
      sprintf(buf, "New min temp %s - %d", sensorsParams[sensor].name, sensorsParams[sensor].minTemp);
      Serial.println(buf);
    }
    else if (sensorsParams[sensor].temp > sensorsParams[sensor].maxTemp || isRestart)
    {
      sensorsParams[sensor].maxTemp = sensorsParams[sensor].temp;
      sprintf(buf, "New max temp %s - %d", sensorsParams[sensor].name, sensorsParams[sensor].maxTemp);
      Serial.println(buf);
    }
    if (sensorsParams[sensor].trackMin && (sensorsParams[sensor].minLimit > sensorsParams[sensor].temp))
    {
      isAlarm = true;
    }

    if (sensorsParams[sensor].trackMax && (sensorsParams[sensor].maxLimit < sensorsParams[sensor].temp))
    {
      isAlarm = true;
    }

    TempPrev[sensor] = sensorsParams[sensor].temp;
  }

  if (isAlarm)
  {
    digitalWrite(ledAlarm, HIGH);
  }
  else
  {
    digitalWrite(ledAlarm, LOW);
  }

  digitalWrite(ledScanTime, LOW);
  isRepaint = true;
}

char* getName(DeviceAddress deviceAddress)
{
  bool isFound = false;
  uint8_t foundId = 0;

  for (uint8_t i = 0; i < sizeof(sensorsParams); i++)
  {
    if (compareAddres(sensorsParams[i].addr, deviceAddress))
    {
      isFound = true;
      foundId = i;
    }
  }
  if (isFound)
  {
    return (sensorsParams[foundId].name);
  }
  else
  {
    return "Unknow sensor";
  }
}

bool compareAddres(DeviceAddress deviceAddress, DeviceAddress deviceAddress2)
{
  int count = 0;
  for (uint8_t i = 0; i < 8; i++)
  {
    // zero pad the address if necessary
    if (deviceAddress[i] == deviceAddress2[i])
      count ++;
  }
  return count == 8;
}

/*
  void sendTemp()
  {
  char url[50] = "/test.php\0";
  char params[50] = "?sensor_id=2&temperatura=23\0";
  sendToServer(url, params);
  }
*/

void printTemp()
{
  int startSensor = 0;
  int sensorPrintCount = min(sensorCount, screenSizeY - 1);
  const int n = 0;
  for (int lineNum = startSensor; lineNum < sensorPrintCount; lineNum++)
    //    for(int lineNum=startSensor; lineNum < sensorPrintCount; lineNum++)
  {

    int sensor = printRound[lineNum];

    //char url[50] = "/test.php\0";
    //        char params[50] = "?sensor_id=2&temperatura=23\0";

    dtostrf(sensorsParams[sensor].temp, 2, n, bufFloat);

    sprintf(displayBuf, "?sensor_id=%i&temperatura=%i\0", sensor, sensorsParams[sensor].temp);

    Serial.println(getName(sensorsParams[sensor].addr));

    Serial.println(displayBuf);
    //sendToServer(url, displayBuf);
    //        int sensor = lineNum;
    lcd.setCursor(0, lineNum);
    if (sensorsParams[sensor].trackMin && (sensorsParams[sensor].minLimit > sensorsParams[sensor].temp))
    {
      lcd.print("!Min");
    }
    if (sensorsParams[sensor].trackMax && (sensorsParams[sensor].maxLimit < sensorsParams[sensor].temp))
    {
      lcd.print("!Max");
    }
    lcd.print(getName(sensorsParams[sensor].addr));

    lcd.setCursor(8, lineNum);
    lcd.print(sensorsParams[sensor].minTemp);
    lcd.print("/");
    lcd.print(sensorsParams[sensor].maxTemp);

    dtostrf(sensorsParams[sensor].temp, 2, n, bufFloat);
    lcd.setCursor(screenSizeX - strlen(bufFloat) - 1, lineNum);

    if (deltaT[sensor] == 0)
    {
      //lcd.print(217, BYTE); // up
      //lcd.print("\0xD9");
      lcd.print("A");
    }
    else if (deltaT[sensor] == 1)
    {
      //lcd.print(218, BYTE); // down
      //lcd.print("\0xDA");
      lcd.print("V");
    }
    else
    {
      //lcd.print(239, BYTE); //round
      //lcd.print("\0xEF");
      lcd.print("=");
    }

    lcd.print(bufFloat);
    //        sprintf(buf, "%d:%d Min:%d Max:%d", sensor+1, sensorsParams[sensor].temp, sensorsParams[sensor].minTemp, sensorsParams[sensor].maxTemp);

  }

  Serial1.write( Serial.read() );

  isRepaint = false;
  roundRotate();
}

void printTime()
{
  unsigned long Seconds = millis() / 1000;
  const unsigned long  SecondsInDay = 60 * 60 * 24;
  int day = Seconds / SecondsInDay;
  // Отбрасываем дни
  Seconds %= SecondsInDay;
  int hours = Seconds / 3600;
  // Отбрасываем часы
  Seconds %= 3600;
  // Вычисляем и выводим количество минут
  int mins = Seconds / 60;
  // Вычисляем и выводим количество секунд
  Seconds = Seconds % 60;
  lcd.setCursor(0, screenSizeY - 1);
  sprintf(buf, "%02d %02d:%02d:%02d", day, hours, mins, Seconds);
  lcd.print(buf);
}

void loop(void)
{
  unsigned long currentMillis = millis();
  if (isRestart)
  {
    getSensorData();
    if (isRepaint)
    {
      printTemp();
    }
    isRestart = false;
  }
  if (currentMillis - previousScanTempMillis > scanTempInterval)
  {
    previousScanTempMillis = currentMillis;
    getSensorData();
  }
  if (currentMillis - previousPrintMillis > printInterval /*|| isRepaint*/)
  {
    lcd.clear();
    previousPrintMillis = currentMillis;
    printTemp();
    printTime();
  }
  char c;
  if (Serial1.available())
  {
    c = Serial1.read();
    if (c == 't')
      postBTData();
  }
  if (Serial.available())
  {
    c = Serial.read();
    if (c == 't')
      postBTData();
  }
}

void postBTData()
{
  Serial1.print("postBTData");

  int startSensor = 0;
  int sensorPrintCount = min(sensorCount, screenSizeY - 1);
  const int n = 0;
  for (int lineNum = startSensor; lineNum < sensorPrintCount; lineNum++)
  {
    int sensor = printRound[lineNum];
    dtostrf(sensorsParams[sensor].temp, 2, n, bufFloat);
    //sprintf(displayBuf, "?sensor_id=%i&temperatura=%i\0", sensor, sensorsParams[sensor].temp);
    Serial1.print(getName(sensorsParams[sensor].addr));
    Serial1.print(";");
    Serial1.print(sensorsParams[sensor].minTemp);
    Serial1.print(";");
    Serial1.print(sensorsParams[sensor].maxTemp);
    Serial1.print(";");
    dtostrf(sensorsParams[sensor].temp, 2, n, bufFloat);
    /*
        lcd.setCursor(screenSizeX - strlen(bufFloat) - 1, lineNum);
        if (deltaT[sensor] == 0)
        {
          //lcd.print(217, BYTE); // up
          //lcd.print("\0xD9");
          lcd.print("A");
        }
        else if (deltaT[sensor] == 1)
        {
          //lcd.print(218, BYTE); // down
          //lcd.print("\0xDA");
          lcd.print("V");
        }
        else
        {
          //lcd.print(239, BYTE); //round
          //lcd.print("\0xEF");
          lcd.print("=");
        }
    */
    Serial1.println(bufFloat);
    //        sprintf(buf, "%d:%d Min:%d Max:%d", sensor+1, sensorsParams[sensor].temp, sensorsParams[sensor].minTemp, sensorsParams[sensor].maxTemp);

  }
}

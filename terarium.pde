// include the library code:
#include <LiquidCrystal.h>
#include <OneWire.h>
#include <DallasTemperature.h>

// Data wire is plugged into port 2 on the Arduino
#define ONE_WIRE_BUS 10
#define TEMPERATURE_PRECISION 9

// initialize the library with the numbers of the interface pins
LiquidCrystal lcd(12, 11, 5, 4, 3, 2);
#define MAX_DS1820_SENSORS 6

signed int TempPrev[MAX_DS1820_SENSORS];
char deltaT[MAX_DS1820_SENSORS]; // positive delta t 0 = warm, 1 cold

long scanTempInterval = 1000 * 25;        // Интервал замера температуры при больше 25 - не опрашиваются датчики во второй раз
long printInterval = 1000 * 5;           // Интервал обновления экрана при больше 25 - не опрашиваются датчики во второй раз

long previousScanTempMillis = 0;     // Предидущее время замера температуры
long previousPrintMillis = 0;        // Предидущее время обновления экрана

unsigned char sensorCount = 0;
char buf[40];
char bufSerial[20];
char bufFloat[40];

unsigned char screenSizeX=20;
unsigned char screenSizeY=4;

bool isRestart = true;
bool isRepaint = false;

struct sensorData
{
    DeviceAddress addr;     // Адрес датчика
    char name[20];          // Имя для отображения
    signed char minLimit;   // Минимальный лимит температуры
    signed char maxLimit;   // Максимальный лимит
    signed char minTemp;    // Минимальное значение температуры
    signed char maxTemp;    // Максимальное значение температуры
    signed char temp;       // Текущее значение температуры
};

const int printRoundSize = 4;
int printRound[printRoundSize] = {0,4,2,3};

OneWire oneWire(ONE_WIRE_BUS);  // Setup a oneWire instance to communicate with any OneWire devices (not just Maxim/Dallas temperature ICs)
DallasTemperature sensors(&oneWire);    // Pass our oneWire reference to Dallas Temperature.
DeviceAddress insideThermometer, outsideThermometer;    // arrays to hold device addresses
sensorData sensorsParams[MAX_DS1820_SENSORS] = {0x28, 0x45, 0xAF, 0xC7, 0x02, 0x0, 0x0, 0x2C,"Out", -3, 28, 0, 0, 0,//remote
                                                0x28, 0x93, 0xBB, 0xC7, 0x02, 0x00, 0x00, 0x39, "rename me", 0, 0, 0, 0, 0,
                                                0x28, 0xB0, 0xDB, 0xC7, 0x02, 0x00, 0x00, 0xC7, "Test", 18, 30, 0, 0, 0,//out
                                                0x28, 0x9B, 0xC5, 0xC7, 0x02, 0x00, 0x00, 0x57, "Ter cold", 22, 35, 0, 0, 0,
                                                0x28, 0xFA, 0xDF, 0xC7, 0x02, 0x00, 0x00, 0x62, "Stepan", 22, 39, 0, 0, 0};
void roundRotate()
{
    int mem = printRound[0];
    for(int i=0; i < printRoundSize-1; i++)
    {
        printRound[i]=printRound[i+1];
    }
    printRound[printRoundSize-1] = mem;
}


void setup()
{
    lcd.clear();
    sensors.begin();
    oneWire.reset_search();
    for(int i=0; i < MAX_DS1820_SENSORS; i++)
    {
        if(oneWire.search(sensorsParams[i].addr))
        {
            sensors.setResolution(sensorsParams[i].addr, TEMPERATURE_PRECISION);
            sensorCount++;
        }
        else
        {
            break;
        }
    }
    
    pinMode(13, OUTPUT);
    lcd.begin(screenSizeX, screenSizeY);
    lcd.setCursor(0,0);
    sprintf(buf, "Found %d sensors", sensorCount);
    lcd.print(buf);
    delay(500);
    lcd.clear();
    if(sensorCount==0)
    {
        return;
    }
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
    digitalWrite(13, HIGH);
    sensors.requestTemperatures();
    
    for(int i=0; i<sensorCount; i++)
    {
      int sensor = printRound[i];
        sensorsParams[sensor].temp = sensors.getTempC(sensorsParams[sensor].addr);
        
        if(TempPrev[sensor] > sensorsParams[sensor].temp)
        {
            deltaT[sensor] = 1;
        }
        else if(TempPrev[sensor] < sensorsParams[sensor].temp)
        {
            deltaT[sensor] = 0;
        }
        else
        {
            deltaT[sensor] = 2;
        }
        if(sensorsParams[sensor].temp < sensorsParams[sensor].minTemp || isRestart)
        {
            sensorsParams[sensor].minTemp = sensorsParams[sensor].temp;
        }
        else if(sensorsParams[sensor].temp > sensorsParams[sensor].maxTemp || isRestart)
        {
            sensorsParams[sensor].maxTemp = sensorsParams[sensor].temp;
        }
        TempPrev[sensor] = sensorsParams[sensor].temp;
    }
    
    digitalWrite(13, LOW);
    isRepaint = true;
}

char* getName(DeviceAddress deviceAddress)
{
    bool isFound = false;
    uint8_t foundId = 0;
    
    for(uint8_t i = 0; i < sizeof(sensorsParams); i++)
    {
        if(compareAddres(sensorsParams[i].addr, deviceAddress))
        {
            isFound = true;
            foundId = i;
        }
    }
    if(isFound)
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
    return count==8;
}


void printTemp()
{
    int startSensor = 0;
    int sensorPrintCount = min(sensorCount, screenSizeY - 1);
    const int n = 0;
    for(int lineNum=startSensor; lineNum < sensorPrintCount; lineNum++)
//    for(int lineNum=startSensor; lineNum < sensorPrintCount; lineNum++)
    {
        int sensor = printRound[lineNum];
//        int sensor = lineNum;
        lcd.setCursor(0,lineNum);
        if(sensorsParams[sensor].minLimit > sensorsParams[sensor].temp)
        {
            lcd.print("!");
        }
        
        lcd.print(getName(sensorsParams[sensor].addr));
        
        lcd.setCursor(10, lineNum);
        lcd.print(sensorsParams[sensor].minTemp);
        lcd.print("/");
        lcd.print(sensorsParams[sensor].maxTemp);
        
        dtostrf(sensorsParams[sensor].temp, 2, n, bufFloat);
        lcd.setCursor(screenSizeX - strlen(bufFloat)-1, lineNum);
        
        if(deltaT[sensor] == 0)
        {
            lcd.print(217, BYTE); // up
        }
        else if(deltaT[sensor] == 1)
        {
            lcd.print(218, BYTE); // down
        }
        else
        {
            lcd.print(239, BYTE); //round
        }
        lcd.print(bufFloat);
        //        sprintf(buf, "%d:%d Min:%d Max:%d", sensor+1, sensorsParams[sensor].temp, sensorsParams[sensor].minTemp, sensorsParams[sensor].maxTemp);
        
    }
    
    isRepaint = false;
    roundRotate();
}

void printTime()
{
    unsigned long Seconds = millis()/1000;
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
    if(isRestart)
    {
        getSensorData();
        if(isRepaint)
        {
            printTemp();
        }
        isRestart = false;
    }
    if(currentMillis - previousScanTempMillis > scanTempInterval)
    {
        previousScanTempMillis = currentMillis;
        getSensorData();
    }
    if(currentMillis - previousPrintMillis > printInterval || isRepaint)
    {
        lcd.clear();
        previousPrintMillis = currentMillis;
        printTemp();
        printTime();
    }
}


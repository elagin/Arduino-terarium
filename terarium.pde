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

signed int Temp[MAX_DS1820_SENSORS];
signed int TempMax[MAX_DS1820_SENSORS];
signed int TempMin[MAX_DS1820_SENSORS];
signed int TempPrev[MAX_DS1820_SENSORS];
char deltaT[MAX_DS1820_SENSORS]; // positive delta t 0 = warm, 1 cold

long interval = 1000 * 20;           // interval at which to blink (milliseconds)
long previousMillis = 0;        // will store last time LED was updated
unsigned char sensorCount = 0;
char buf[40];
char bufSerial[20];
char bufFloat[40];

unsigned char screenSizeX=20;
unsigned char screenSizeY=4;

bool isRestart = true;

struct sensorData
{
    DeviceAddress addr;
    char name[20];
    signed char minLimit;
    signed char maxLimit;
};

OneWire oneWire(ONE_WIRE_BUS);  // Setup a oneWire instance to communicate with any OneWire devices (not just Maxim/Dallas temperature ICs)
DallasTemperature sensors(&oneWire);    // Pass our oneWire reference to Dallas Temperature.
DeviceAddress insideThermometer, outsideThermometer;    // arrays to hold device addresses
sensorData sensorsParams[MAX_DS1820_SENSORS] = {0x28, 0x45, 0xAF, 0xC7, 0x02, 0x0, 0x0, 0x2C,"Out", -10, 28, //remote
                             0x28, 0x93, 0xBB, 0xC7, 0x02, 0x00, 0x00, 0x39, "Test", 0, 0,
                             0x28, 0xB0, 0xDB, 0xC7, 0x02, 0x00, 0x00, 0xC7, "Testreal", 18, 30,//out
                             0x28, 0x9B, 0xC5, 0xC7, 0x02, 0x00, 0x00, 0x57, "Ter cold", 22, 35,
                             0x28, 0xFA, 0xDF, 0xC7, 0x02, 0x00, 0x00, 0x62, "Stepan", 22, 39};
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
        //    ds.reset_search();
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

    for(int sensor=0; sensor<sensorCount; sensor++)
    {
        Temp[sensor] = sensors.getTempC(sensorsParams[sensor].addr);

        if(TempPrev[sensor] > Temp[sensor])
        {
            deltaT[sensor] = 1;
        }
        else if(TempPrev[sensor] < Temp[sensor])
        {
            deltaT[sensor] = 0;
        }
        else
        {
            deltaT[sensor] = 2;
        }

        if(Temp[sensor] < TempMin[sensor] || isRestart)
        {
            TempMin[sensor] = Temp[sensor];
        }
        else if(Temp[sensor] > TempMax[sensor] || isRestart)
        {
            TempMax[sensor] = Temp[sensor];
        }
        TempPrev[sensor] = Temp[sensor];
    }

    digitalWrite(13, LOW);
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
    for(int sensor=0; sensor<sensorCount; sensor++)
    {
        lcd.setCursor(0,sensor);
        lcd.print(getName(sensorsParams[sensor].addr));

        lcd.setCursor(8, sensor);
        lcd.print(TempMin[sensor]);
        lcd.print("/");
        lcd.print(TempMax[sensor]);

//        lcd.print(Temp[sensor]/10);

        if(sensorsParams[sensor].minLimit > Temp[sensor])
        {
            lcd.print("!");
        }

        dtostrf(Temp[sensor], 2, 2, bufFloat);
        lcd.setCursor(screenSizeX - strlen(bufFloat)-1, sensor);

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
//        sprintf(buf, "%d:%d Min:%d Max:%d", sensor+1, Temp[sensor], TempMin[sensor], TempMax[sensor]);
    }
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

    sprintf(buf, "%02d %02d:%02d:%02d", day, hours, mins, Seconds);
    lcd.print(buf);
}

void loop(void)
{
    unsigned long currentMillis = millis();
    if(isRestart)
    {
        getSensorData();
        printTemp();
        isRestart = false;
    }
    if(currentMillis - previousMillis > interval)
    {
        previousMillis = currentMillis;
        getSensorData();
        printTemp();
    }
}


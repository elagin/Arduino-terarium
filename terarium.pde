// include the library code:
#include <LiquidCrystal.h>
#include <OneWire.h>
#include <DallasTemperature.h>

// Data wire is plugged into port 2 on the Arduino
#define ONE_WIRE_BUS 10
#define TEMPERATURE_PRECISION 9

// initialize the library with the numbers of the interface pins
LiquidCrystal lcd(12, 11, 5, 4, 3, 2);
#define MAX_DS1820_SENSORS 4

DeviceAddress sensorAddr[MAX_DS1820_SENSORS];
float Temp[MAX_DS1820_SENSORS];
float TempMax[MAX_DS1820_SENSORS];
float TempMin[MAX_DS1820_SENSORS];
int deltaT[MAX_DS1820_SENSORS]; // positive delta t 0 = warm, 1 cold

long interval = 1000 * 5;           // interval at which to blink (milliseconds)
long previousMillis = 0;        // will store last time LED was updated
int sensorCount = 0;
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
};

OneWire oneWire(ONE_WIRE_BUS);  // Setup a oneWire instance to communicate with any OneWire devices (not just Maxim/Dallas temperature ICs)
DallasTemperature sensors(&oneWire);    // Pass our oneWire reference to Dallas Temperature.
DeviceAddress insideThermometer, outsideThermometer;    // arrays to hold device addresses
sensorData sensorsName[2] = {0x28, 0x45, 0xAF, 0xC7, 0x02, 0x0, 0x0, 0x2C,"test",
                             0x28, 0x93, 0xBB, 0xC7, 0x02, 0x00, 0x00, 0x39, "hot"};
void setup()
{
    lcd.clear();
    sensors.begin();
    oneWire.reset_search();
    for(int i=0; i < MAX_DS1820_SENSORS; i++)
    {
        if (!oneWire.search(sensorAddr[i]))
        {
            sensors.setResolution(sensorAddr[i], TEMPERATURE_PRECISION);
            sensorCount++;
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
    for( int sensor=0; sensor<sensorCount; sensor++)
    {
        Temp[sensor] = sensors.getTempCByIndex(sensor);
        int prevTemp = Temp[sensor];
        //    Temp[sensor]=(data[1]<<8)+data[0];//take the two bytes from the response relating to temperature
        //    Temp[sensor]=Temp[sensor]/16; //divide by 16 to get pure celcius readout
        if(prevTemp > Temp[sensor])
        {
            deltaT[sensor] = 1;
        }
        else if(prevTemp < Temp[sensor])
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
    }
    digitalWrite(13, LOW);
}

char* getName(DeviceAddress deviceAddress)
{
    bool isFound = false;
    uint8_t foundId = 0;
    
    for(uint8_t i = 0; i < sizeof(sensorsName); i++)
    {
        if(compareAddres(sensorsName[i].addr, deviceAddress))
        {
            isFound = true;
            foundId = i;
        }
    }
    if(isFound)
    {
        return (sensorsName[foundId].name);
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
    for( int sensor=0; sensor<sensorCount; sensor++)
    {
        lcd.setCursor(0,sensor);
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
        //    sprintf(buf, "%d:%3.2f Min:%3.2f Max:%3.2f", sensor+1, Temp[sensor], TempMin[sensor], TempMax[sensor]);
        
        dtostrf(Temp[sensor], 2, 2, bufFloat);
        sprintf(buf, "%s:%s", getName(sensorAddr[sensor]), bufFloat);
        lcd.print(buf);
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


// include the library code:
#include <LiquidCrystal.h>
#include <DallasTemperature.h>

//DallasTemperature tempSensor;
OneWire ds(10);  // on pin 10

// initialize the library with the numbers of the interface pins
LiquidCrystal lcd(12, 11, 5, 4, 3, 2);
#define MAX_DS1820_SENSORS 4
byte addr[MAX_DS1820_SENSORS][8];
int Temp[MAX_DS1820_SENSORS];
int TempMax[MAX_DS1820_SENSORS];
int TempMin[MAX_DS1820_SENSORS];
int deltaT[MAX_DS1820_SENSORS]; // positive delta t 0 = warm, 1 cold
char buf[40];
char bufSerial[20];
int sensorCount = 0;
long interval = 1000 * 60;           // interval at which to blink (milliseconds)
long previousMillis = 0;        // will store last time LED was updated

bool isRestart = true;

void setup()
{
  pinMode(13, OUTPUT);
  // set up the LCD's number of columns and rows:
  lcd.begin(20, 4);
  lcd.setCursor(0,0);

  // Print a message to the LCD.
  lcd.print("DS1820 scan sensors...");
  for(int i=0; i < MAX_DS1820_SENSORS; i++)
  {
    if(ds.search(addr[i]))
    {
      sensorCount++;
    }
  }
  lcd.clear();
  sprintf(buf, "Found %d sensors", sensorCount);
  lcd.print(buf);
  delay(500);

  if(sensorCount==0)
  {
    ds.reset_search();
    return;
  }

}

void getSensorData()
{
  byte i;
  byte data[12];
  byte present = 0;
  digitalWrite(13, HIGH);
  for( int sensor=0; sensor<sensorCount; sensor++)
  {
    if( OneWire::crc8( addr[sensor], 7) != addr[sensor][7])
    {
      lcd.setCursor(0,0);
      lcd.print("CRC is not valid");
      return;
    }

    if ( addr[sensor][0] != 0x28)
    {
      lcd.setCursor(0,0);
      lcd.print("Device is not a DS18S20 family device.");
      return;
    }
    ds.reset();
    ds.select(addr[sensor]);
    ds.write(0x44,1);	   // start conversion, with parasite power on at the end
  }
  delay(1000);     // maybe 750ms is enough, maybe not
  // we might do a ds.depower() here, but the reset will take care of it.
  for( int sensor=0; sensor<sensorCount; sensor++)
  {
    present = ds.reset();
    ds.select(addr[sensor]);
    ds.write(0xBE);	   // Read Scratchpad

    for ( i = 0; i < 9; i++) // we need 9 bytes
    {
      data[i] = ds.read();
    }
    int prevTemp = Temp[sensor];
    Temp[sensor]=(data[1]<<8)+data[0];//take the two bytes from the response relating to temperature
    Temp[sensor]=Temp[sensor]/16; //divide by 16 to get pure celcius readout
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

void printTemp()
{

  //  }
  //   lcd.print(239, BYTE); round
  //   lcd.print(217, BYTE); // up
  //      lcd.print(218, BYTE); // down
  //    lcd.clear();
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
    sprintf(buf, "%d:%d Min:%d Max:%d", sensor+1, Temp[sensor], TempMin[sensor], TempMax[sensor]);
    lcd.print(buf);
  }
}

void printTime()
{
  lcd.setCursor(0,3);
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

void blink()
{
     digitalWrite(13, HIGH);   // set the LED on
     delay(100);              // wait for a second
     digitalWrite(13, LOW);    // set the LED off
     delay(100);              // wait for a second
}

void loop()
{
  if(sensorCount==0)
  {
    delay(1000);
    return;
  }

  lcd.setCursor(0, 0);
  //  display(analogRead(0)/4/17.517006803);

  if(isRestart)
  {
    getSensorData();
    printTemp();
    isRestart = false;
  }

  unsigned long currentMillis = millis();
  if(currentMillis - previousMillis > interval)
  {
    previousMillis = currentMillis;
    getSensorData();
    printTemp();
  }
  printTime();
  delay(300);
}


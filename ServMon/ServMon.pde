#include <math.h>

#define ADC_VCC 4840
float thermister(int RawADC) { // for [SAMKYUNG]NTC-502F397
  long x = map(RawADC,0,1023,0,ADC_VCC);
  float th = (((float)(ADC_VCC-x)*10.0)/(float)x)*1000.0;
  float ce = ((log(4.0*th-3000.0)/(-0.024119329)+473)-32.0)/1.8;
  return ce;
}

#include <LiquidCrystal.h>
// RS, EN D4, D5, D6, D6
LiquidCrystal lcd(3, 2, 4, 5, 6, 7);

#define PIN_LED 13
#define PIN_LED_WARN (14+4)
#define PIN_LED_GUAGE (14+3)

#define PIN_CALIBRATION 8
#define PIN_MODE_SWITCH 12

#define PIN_FAN 9
#define PIN_BACKLIGHT 10 // guage
#define PIN_GUAGE 11 // backlight

#define PIN_TEMP0 0 // cpu
#define PIN_TEMP1 1 // dc2dc
#define PIN_TEMP2 2 // case

#define PIN_RESET_TRIGGER (14+5)

void init_gpio(void)
{
  pinMode(PIN_LED, OUTPUT);
  pinMode(PIN_LED_WARN, OUTPUT);
  pinMode(PIN_LED_GUAGE, OUTPUT);

  pinMode(PIN_CALIBRATION, INPUT);
  digitalWrite(PIN_CALIBRATION, HIGH); // pull-up
  pinMode(PIN_MODE_SWITCH, INPUT);
  digitalWrite(PIN_MODE_SWITCH, HIGH); // pull-up

  pinMode(PIN_FAN, OUTPUT);
  pinMode(PIN_BACKLIGHT, OUTPUT);
  pinMode(PIN_GUAGE, OUTPUT);

  pinMode(PIN_RESET_TRIGGER, OUTPUT);
  digitalWrite(PIN_RESET_TRIGGER, LOW);

}

void setup()
{
  init_gpio();
  lcd.begin(16, 2); // 16 column, 2 row
  lcd.setCursor(0, 0);
  Serial.begin(9600);

  // Noti. for start
  digitalWrite(PIN_LED, HIGH);
  digitalWrite(PIN_LED_WARN, HIGH);
  delay(1000);
  digitalWrite(PIN_LED, LOW);
  digitalWrite(PIN_LED_WARN, LOW);
}

enum DISP_MODE {
  DISP_MODE_TEMP = 0,
  DISP_MODE_MESSAGE,
  DISP_MODE_MAX,
};
int disp_mode = 0;

unsigned int backlight = 0;
unsigned char guage_to = 0;
unsigned char guage_curr = 0;

#define BACKLIGHT(x) analogWrite(PIN_BACKLIGHT, (x)&0xff);
#define GUAGE(x) guage_to = x
#define FAN(x) analogWrite(PIN_FAN, (x)&0xff)

void update_guages()
{
  if (guage_to > guage_curr) guage_curr+=1;
  else if (guage_to < guage_curr) guage_curr-=1;

  analogWrite(PIN_GUAGE, guage_curr);
}

unsigned char auto_fan(int temp)
{
  //find highist temp
  unsigned char fan_speed;

  // no speed when under 35 degree,
  // full speen when over 90 degree
  fan_speed = map(temp, 35, 90, 0, 0xff);
  FAN(fan_speed);

  return fan_speed;
}

void loop()
{
  if (digitalRead(PIN_CALIBRATION) == LOW) {
    BACKLIGHT(255);
    GUAGE(255);
    FAN(255);
  } else if (digitalRead(PIN_MODE_SWITCH) == LOW) {
#if 0
    disp_mode += 1;
    if (disp_mode >= DISP_MODE_MAX)
      disp_mode = 0;
#else
    backlight += 25;
    if (backlight > 255) backlight = 0;
    BACKLIGHT(backlight);
    digitalWrite(PIN_LED_GUAGE, backlight?HIGH:LOW);
    delay(500);
#endif
  } else {
    if (Serial.available() >= 3) {
      if(Serial.read() == '#') {
        char mode; //'A','B','D','R'; //guageA, guageB, display
        mode = Serial.read();
#if 0
        if (mode == 'B')
          BACKLIGHT(int(Serial.read()));
#endif
        if (mode == 'G')
          GUAGE(int(Serial.read()));
        else if (mode == 'F')
          FAN(int(Serial.read()));
        else if (mode == 'M') {
          char msg[16+1];
          int i;
          int len = int(Serial.read());
          if (len > 16) len = 16;
          while(Serial.available() < len) {
            //TODO: add timeout
            delay(1);
            digitalWrite(PIN_LED, HIGH);
          }
          digitalWrite(PIN_LED, LOW);
          for(i=0; i<len; i++) msg[i] = Serial.read();
          for(; i<16; i++) msg[i] = ' ';
          msg[16] = 0;           
          lcd.setCursor(0,0);
          lcd.print(msg);
        }
        else if (mode == 'R') {
          digitalWrite(PIN_RESET_TRIGGER, HIGH);
          delay(100);
          digitalWrite(PIN_RESET_TRIGGER, LOW);
        }
      }
    } else {
      int t0, t1, t2, fan;
      t0 = int(thermister(analogRead(PIN_TEMP0))); // CPU
      t1 = int(thermister(analogRead(PIN_TEMP1))); // DC2DC
      t2 = int(thermister(analogRead(PIN_TEMP2))); // CASE

      int t_max;
      t_max = (t0 > t1)?t0:t1;
      t_max = (t_max > t2)?t_max:t2;
      fan = auto_fan(t_max);

      // update status
      lcd.setCursor(0, 1);
      lcd.print("T:");
      lcd.print(t_max);
      lcd.print("\xDF F:");
      lcd.print(fan);
      lcd.print("/255  ");
    }
    update_guages();
    delay(5);
  }
}

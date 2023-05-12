/* 陈昕枫，2020-12
 * 注意：D0, D1, D12, D13 为保留端口。
 * 0. 烧录代码，打开串口，设置： "波特率 19200 baud", 
 * 1. 测试，在串口中输入：
 *       <-h>                               | reply： [Arduino daq for Matlab]。表示程序正常
 * 2. 配置通道，在串口中输入：
 *       <-p^>                              | reply: [Parameters: Adding Channel Begin]。开始配置参数,并覆盖之前的配置
 *       addCO(2, 10, 0.02, 0.5)            | reply: [addCO(2,10,0.02000,0.5)]。TTL脉冲， D2通道, 10Hz, 延迟0.02秒，占空比50%
 *       addCO(3, 1, 0.0, 0.4)              | reply: [addCO(3,1,0,0.4)]。 TTL脉冲，D3通道, 1Hz, 延迟0秒，占空比40%。不同通道之间独立，互不干扰。
 *       addAI(0)
 *       <-pv>                              | reply: [Parameters: Adding Channel End]
 * 3. 开始运行
 *       <-b>                               | reply: total channel3
 * 4. 结束运行并重启
 *       重新插拔串口
 */
 
#include "LinkedList.h"
#include "daqParser.h"
#define PIN_IN_6_1 PINC

class Channel;
LinkedList<Channel *> *myLinkedList;

class Channel
{
public:
  int channelID_;
  float Frequency_;
  float InitialDelay_;
  float DutyCycle_;
  boolean CurrentValue;
  float PeriodYushu;
  float CumPeriodYushu;
  unsigned int Periodlen;
  unsigned int Periodonlen;
  unsigned long nextUpTime;
  unsigned long nextDownTime;
  static unsigned long StartTime_;
  
  Channel(int channelID, float Frequency, float InitialDelay, float DutyCycle)
  {
    this->channelID_    = channelID;
    this->Frequency_    = Frequency;
    this->InitialDelay_ = InitialDelay;
    this->DutyCycle_    = DutyCycle;
    double period  = (double)1000.0 / Frequency;
    Periodlen = floor(period);
    Periodonlen = floor(period * DutyCycle);
    PeriodYushu = period - Periodlen;
    CumPeriodYushu = 0;
    pinMode(channelID_, OUTPUT);
  }
  
  static void beginTimer()
  {
    Channel::StartTime_ = millis();
  }
  
  void beginTimerSub()
  {
    unsigned long firstOn = Channel::StartTime_ + 1000 * InitialDelay_;
    nextUpTime = firstOn;
    nextDownTime = firstOn + Periodonlen;
    this->CurrentValue  = 0;
    digitalWrite(channelID_, this->CurrentValue);
  }
  
  void stopTimerSub()
  {
    this->CurrentValue  = 0;
    digitalWrite(channelID_, this->CurrentValue);
  }
  
  boolean checkAndUpdate(unsigned long CurrentTime)
  {
    if(this->CurrentValue == 0 && CurrentTime > this->nextUpTime ){
      this->CurrentValue = 1;
      if(this->PeriodYushu != 0){
        this->CumPeriodYushu += this->PeriodYushu;
        if(this->CumPeriodYushu >= 1){
          this->nextUpTime +=1;  //add 1 ms to next period
          this->CumPeriodYushu -= 1;
        }
      }
      this->nextUpTime += Periodlen;
      digitalWrite(channelID_, this->CurrentValue);
    }
    else if(this->CurrentValue == 1 && CurrentTime > this->nextDownTime){
      this->CurrentValue = 0;
      this->nextDownTime = this->nextUpTime + Periodonlen;
      digitalWrite(channelID_, this->CurrentValue);
    }
    else{
      //nothing
    }
  }
};
unsigned long Channel::StartTime_ = 0;

bool AIpin[6]={false,false,false,false,false,false};
void addAnalogInputChannel(double a){
  if(a>=0 && a<=5){
    AIpin[int(a)] = true;
  }
}

void addCounterOutputChannel(int channelID, float Frequency, float InitialDelay, float DutyCycle)
{
// Frequency, Hz
// InitialDelay, second
// DutyCycle, range [0.0 - 1.0]
  // check if already in existed channel lists
  removeChannel(channelID);
  Channel * sub = new Channel(channelID, Frequency, InitialDelay, DutyCycle);
  myLinkedList->add(sub);
}

void removeAllChannels()
{
  for(int i=0; i<myLinkedList->size(); ++i){
    Channel * myObject = myLinkedList->get(i);
    if(myObject->channelID_ != 12){
      myLinkedList->remove(i);
      delete myObject;
    }
  }
}

void removeChannel(int channelID)
{
  for(int i=0; i<myLinkedList->size(); ++i){
    Channel * myObject = myLinkedList->get(i);
    if(myObject->channelID_ == channelID){
      myLinkedList->remove(i);
      delete myObject;
      return;
    }
  }
}

unsigned long tpre;
unsigned long tbegined;
void setup()
{
  myLinkedList = new LinkedList<Channel *>();
  Serial.begin(19200);
  pinMode(13, OUTPUT);
  digitalWrite(13, HIGH);
  addCounterOutputChannel(12, 1, 0, 0.4);
//  addCounterOutputChannel(2, 5, 0, 0.25);  //405channel
//  addCounterOutputChannel(3, 5, 0.066, 0.25);  //470channel
//  addCounterOutputChannel(4, 5, 0.133, 0.25);   //565channel
//  addCounterOutputChannel(5, 15, 0.009, 0.1);   //cammer channel
  waittingPannel_root();

  Channel::beginTimer();
  Channel * mychannel;
  Serial.print("total channel" ); Serial.println(myLinkedList->size());
  for(int i=0; i<myLinkedList->size(); ++i){
    mychannel = myLinkedList->get(i);
    mychannel->beginTimerSub();
  }
  tpre =  millis();
  tbegined = tpre;
}

long n=0;
void loop()
{
  unsigned long tnow = millis();
  Channel * mychannel;
  for(int i=0; i<myLinkedList->size(); ++i){
    mychannel = myLinkedList->get(i);
    mychannel->checkAndUpdate(tnow);  }
  if(tnow-tpre>10000){
    tpre = tnow;
    n=0;
  }
  n++;
  pinScanning();
}

// pinscan
void pinScanning()
{
    static boolean doinit = 1;
    static unsigned long t_raise[6];
    static byte pre_status = 0; //[NULL NULL A5<-A0]
    static byte AI_enable = 0; //[NULL NULL A5<-A0]
    char prefix[] = "IN";
    if(doinit) {                       // do init, the first time
        doinit = 0;
        unsigned long AppBeginTime = tbegined;
        for(int i = 0; i < 6; ++i) {
            t_raise[i] = AppBeginTime;   //when pin start with HIGH
        }
        for(int i = 0; i < 6; ++i) {
            bitWrite(AI_enable, i, AIpin[i]);
        }
    }
    byte now_status = PIN_IN_6_1,changed_status;
    changed_status = (pre_status ^ now_status) & AI_enable;
    if(changed_status !=  0) {   //reduce time consume
        unsigned long now_time = millis();
        for(int i = 0; i < 6; ++i) {
            if(bitRead(changed_status, i)) {
                if(bitRead(now_status, i)) { //up slope
                    t_raise[i] = now_time;
                }
                else {              //down slope
                    sendmsg(prefix, i + 1, t_raise[i], now_time);
                }
            }
        }
        pre_status = now_status;
    }
}
// Serial.print for 'pinScanning()', 'pinWriting()'
// "OUT3:100 300": D3, turn on at 100ms, off at 300ms, duration as 200ms
// "IN3:100 300" : AI3, turn on at 100ms, off at 300ms, duration as 200ms
void sendmsg(char prefix[], int pin, unsigned long t_raise, unsigned long t_decline)
{
    char buf[40], temp[11];  //long is 10 char + '\0';
    unsigned long AppBeginTime = tbegined;
    buf[0] = '\0';
    strcat(buf, prefix);
    strcat(buf,itoa(pin, temp,10));
    strcat(buf, ":");
    strcat(buf, ultoa(t_raise - AppBeginTime, temp, 10));
    strcat(buf, " ");
    strcat(buf, ultoa(t_decline - t_raise, temp, 10));
    strcat(buf, "\n");
    Serial.print(buf);
}

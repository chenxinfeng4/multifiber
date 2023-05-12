String rstr = "";
double argsbuf[10];
void waittingPannel_root_paramload();
void addCounterOutputChannel(int channelID, float Frequency, float InitialDelay, float DutyCycle); //添加TTL脉冲通道
void addAnalogInputChannel(double a);
void removeAllChannels();     // 重置parameters
void waittingPannel_root(){
  while(true){
    if(!Serial.available()){ continue;}
    rstr = Serial.readStringUntil('\n');
    if(rstr == "<-b>"){ break;}
    if(rstr == "<-h>"){
      Serial.print("[Arduino daq for Matlab]\n");
    }
    else if(rstr == "<-p^>"){
      Serial.print("[Parameters: Adding Channel Begin]\n");
      waittingPannel_root_paramload(); //parameters setting
    }
    else{
      Serial.print("[Error: No such commond]\n");
    }
  }
}

int argpaser(String str, double * buf){
  int n = 0;
  int i = str.indexOf('(');
  int e = str.indexOf(')', i+1);
  str = str.substring(i+1, e);
  int delim = str.indexOf(',');
  while(delim!=-1){
    buf[n] = (str.substring(0, delim)).toFloat();
    n++;
    str=str.substring(delim+1, str.length());
    delim = str.indexOf(',');
  }
  
  str.trim();
  if(str.length()){
    buf[n] = (str.substring(0, delim)).toFloat();
    n++;
  }
  return n;
}

char bufchar[100];

String double2string(double a){
  int a_int = int(a);
  double df = a-int(a);
  if(a==0){
    return String('0');
  }
  else if(df<0.0001){
    return String(a_int);
  }
  else if(abs(a)>10){
    return String(a, 2);
  }
  else{ //dynamic LIKE 0.123567 -> "0.12345"
    int i = 1; double ax=a;
    for(i=1; i<5; ++i){
      ax *= 10;
      df = ax - int(ax);
      if(abs(df)<0.0001){
        break;
      }
    }
    return String(a, i);
  }
}

void waittingPannel_root_paramload(){
  String rstr = "";
  removeAllChannels();
  while(true ){
    if(!Serial.available()){ continue;}
    rstr = Serial.readStringUntil('\n');
    if (rstr == "<-pv>"){break;}
    int narg; String strprint;
    if(rstr.startsWith("addAI")){
       narg = argpaser(rstr, argsbuf); //narg == 1;
       strprint = String("[addAI(") + int(argsbuf[0]) + ")]";
       addAnalogInputChannel(argsbuf[0]);
    }
    else if(rstr.startsWith("addCO")){
       narg = argpaser(rstr, argsbuf);
       strprint = String("[addCO(") + int(argsbuf[0]) + ',' + double2string(argsbuf[1])
                          + ','  + double2string(argsbuf[2]) + ',' + double2string(argsbuf[3]) + ")]";
       addCounterOutputChannel(argsbuf[0], argsbuf[1], argsbuf[2], argsbuf[3]);
    }
    else{
      strprint = "[Error: No such function supported!]";
    }
    Serial.println(strprint);
  }
  Serial.print("[Parameters: Adding Channel End]\n");
}

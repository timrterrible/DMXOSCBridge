import oscP5.*;
import netP5.*;

import dmxP512.*;
import processing.serial.*;

/*
* OSX to DMX Bridge for the LHS Bikeshed / Halloween Open Day 01/11/2013
 * 
 * DMX Library: http://motscousus.com/stuff/2011-01_dmxP512/
 * OSC Library: http://www.sojamo.de/libraries/oscP5/
 *
 * ==DMX Info ==
 * 
 * Ch1 = Red
 * Ch2 = Green
 * Ch3 = Blue
 * Ch4 = Brightness
 * Ch5 = Strobe Speed
 *
 * PAR1 = 01,02,03,04,05
 * PAR2 = 06,07,08,09,10
 * PAR3 = 11,12,13,14,15
 * PAR4 = 16,17,18,19,20
 *
 * == Shortcut keys ==
 * Q - Quit. Use this to avoid hanging the serial port.
 * K - Kill ALl. Forces all DMX channels to zero. 
 *
 */

DmxP512 dmxOutput;
boolean KILLED=false;
OscP5 oscP5;
NetAddress myRemoteLocation;                            
String serverIP = "127.0.0.1";

int Light1=01; //Start address of fixture.
int Light2=06; //Start address of fixture. 
int Light3=11; //Start address of fixture. 
int Light4=16; //Start address of fixture.

int OSCPORT=12006; //OSC listening Port - Next port in sequence from maingame/assets/config.xml is 12006
int universeSize=32; //Our universe is only 32 channels. 
boolean DEBUG=false; //Disables DMX Interface
String DMXPRO_PORT="COM4"; //Change this. 
int DMXPRO_BAUDRATE=115000; //Do not change this. 

void setup() { 
  myRemoteLocation = new NetAddress(serverIP, 12000);
  oscP5 = new OscP5(this,OSCPORT);
  size(128, 128, JAVA2D);

  if (!DEBUG) {
    dmxOutput=new DmxP512(this, universeSize, false);
    dmxOutput.setupDmxPro(DMXPRO_PORT, DMXPRO_BAUDRATE);
  }
}

void draw() {
  if (!KILLED)
  {
    fill(0, 255, 0); //Green
  } 
  else
  {
    fill(255, 0, 0); //Red
  }

  rect(4, 4, 120, 120, 8, 8, 8, 8); //Giant traffic light showing DMX output state.  

  if (!DEBUG) {
    //Manipulate lights here.
    //UpdateLight(LightNum,Red,Green,Blue,Shutter,Strobe);
  }
}

void keyPressed() {
  if (key == 'q' || key == 'Q') {
    exit();
  } 
  else if (key == 'k' || key == 'K') {
    if (KILLED)
    {
      KILLED=false;
    } 
    else if (!KILLED) {
      KILLED=true;
      KillAll();
    }
  }
}

void KillAll() { 
  int i=0;
  while (i <= universeSize)
  {
    dmxOutput.set(i, 0);
    ++i;
  }
}

void UpdateLight (int startAddr, int r, int g, int b, int shutter, int strobe) {
  if (!KILLED) {
    dmxOutput.set(startAddr, r);
    dmxOutput.set(startAddr+1, g);
    dmxOutput.set(startAddr+2, b);
    dmxOutput.set(startAddr+3, shutter);
    dmxOutput.set(startAddr+4, strobe);
  }
}

void oscEvent(OscMessage theOscMessage) {
  print("### received an osc message.");
  print(" addrpattern: "+theOscMessage.addrPattern());
  println(" typetag: "+theOscMessage.typetag());
}


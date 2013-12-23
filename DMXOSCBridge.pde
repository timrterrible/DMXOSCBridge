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
 *
 * == Getting things done == 
 *
 * UpdatedmxLight(dmxLightNum, Red, Green, Blue, Shutter, Strobe);
 *
 */

boolean DMX=false;  //Enables DMX Interface
boolean LOG=true; //Logs all DMX and OSC traffic
String dmxPort="COM4";  //Change this to match the virtual COM port created by the DMX interface.
int dmxBaudrate=115000;  //Change this to match the baud rate of the DMX interface. 
int dmxUniverse=32;  //Number of channels in DMX universe. 
boolean dmxKilled=false;  //DMX blackout toggle.
int dmxLight1=01;  //Starting address of fixture.
int dmxLight2=06;  //Starting address of fixture.
int dmxLight3=11;  //Starting address of fixture.
int dmxLight4=16;  //Starting address of fixture.
DmxP512 dmxOutput;  //DMX output object.
PrintWriter debuglog; //Debug logging object 
char debugLogFile=""  //Debug log filename
OscP5 oscListener;  //OSC listener object.
int oscPort=12006;  //OSC listening Port - Next port in sequence from maingame/assets/config.xml is 12006

void setup() { 
  oscListener = new OscP5(this, oscPort);
  size(128, 128, JAVA2D);

  if (DMX) {
    dmxOutput=new DmxP512(this, dmxUniverse, false);
    dmxOutput.setupDmxPro(dmxPort, dmxBaudrate);
  } 
  if (LOG) {
    //Magic to make debugLogFile timestamped to stop overwrites. Processing, you piece of shit. 
    debuglog = createWriter(debugLogFile);
    debuglog.println("Started debug log");
  }
}

void draw() {
  if (!dmxKilled) {
    fill(0, 255, 0); //Red
  } 
  else
    fill(255, 0, 0); //Green

  rect(4, 4, 120, 120, 8, 8, 8, 8); //Giant traffic light showing DMX output state.

  if (LOG)
    debuglog.flush();
}

void keyPressed() {
  if (key == 'q' || key == 'Q') { //Quit
    if (LOG) {
      debuglog.flush();
      debuglog.close();
    }
    exit();
  } 
  else if (key == 'k' || key == 'K') { //Kill DMX
    if (dmxKilled)
    {
      dmxKilled=false;
    } 
    else if (!dmxKilled) {
      dmxKilled=true;
      KillAll();
    }
  }
}

void KillAll() { 
  if (DMX) {
    int i=0;
    while (i <= dmxUniverse)
    {
      dmxOutput.set(i, 0);
      ++i;
    }
  }
}

void UpdateLight (int startAddr, int r, int g, int b, int shutter, int strobe) {
  if (LOG) {
    debuglog.print("DMX: StartAddr:");
    debuglog.print(startAddr);
    debuglog.print(" Red:");
    debuglog.print(r);
    debuglog.print(" Green:");
    debuglog.print(g);
    debuglog.print(" Blue:");
    debuglog.print(b);
    debuglog.print(" Shutter:");
    debuglog.print(shutter);
    debuglog.print(" Strobe:");
    debuglog.println(strobe);
  }

  if (DMX && !dmxKilled) {
    dmxOutput.set(startAddr, r);
    dmxOutput.set(startAddr+1, g);
    dmxOutput.set(startAddr+2, b);
    dmxOutput.set(startAddr+3, shutter);
    dmxOutput.set(startAddr+4, strobe);
  }
}

void oscEvent(OscMessage theOscMessage) {
  if (LOG) {
    debuglog.print("OSC: addrpattern: "+theOscMessage.addrPattern());
    debuglog.println(" typetag: "+theOscMessage.typetag());
  }
}


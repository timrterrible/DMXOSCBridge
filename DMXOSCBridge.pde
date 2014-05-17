import java.util.Map;
import oscP5.*;
import netP5.*;
import dmxP512.*;
import processing.serial.*;

/*
* OSC to DMX Bridge for the LHS Bikeshed
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
 * T - Test a few sequences.
 *
 */

// DMX
boolean DMX=false;  //Enables DMX Interface
boolean LOG=true; //Logs all DMX and OSC traffic
String dmxPort="COM4";  //Change this to match the virtual COM port created by the DMX interface.
int dmxBaudrate=115000;  //Change this to match the baud rate of the DMX interface. 
int dmxUniverse=20;  //Number of channels in DMX universe. 
boolean dmxKilled=false;  //DMX blackout toggle.
int dmxLight1=01;  //Starting address of fixture.
int dmxLight2=06;  //Starting address of fixture.
int dmxLight3=11;  //Starting address of fixture.
int dmxLight4=16;  //Starting address of fixture.
DmxP512 dmxOutput;  //DMX output object.

// LOGGING
PrintWriter debuglog; //Debug logging object 
String debugLogFile;  //Debug log filename

// OSC
OscP5 oscListener;  //OSC listener object.
int oscPort=12006;  //OSC listening Port - Next port in sequence from maingame/assets/config.xml is 12006

//SEQUENCE HANDLING
String seqBackground; //Current background sequence.
String seqOverlay; //Current overlay sequence. 
int seqDuration; //Duraton of last overlay.
int lastTime; //Last frame time.
int currentTime; //Current time.
int diffTime; //Diff between frames in ms
int stepTime = 100; //Delay between steps in ms
int driftTime;  //Drift form perfect step in ms.
HashMap<String, Table> mapSequences = new HashMap<String, Table>();


void setup() { 
  oscListener = new OscP5(this, oscPort);
  size(128, 128, JAVA2D);

  if (DMX) {
    dmxOutput=new DmxP512(this, dmxUniverse, false);
    dmxOutput.setupDmxPro(dmxPort, dmxBaudrate);
  } 
  if (LOG) {
    int day = day();
    int mon = month();
    int yr = year();
    int hr = hour();
    int min = minute();
    int sec = second();

    debugLogFile="logs/"+day+"-"+mon+"-"+yr+"-"+hr+"."+min+"."+sec+".log";
    debuglog = createWriter(debugLogFile);
    debuglog.println("Log: Started debug log");
  }
  setupSequences();
  lastTime = millis();
}

void draw() {
  if (!dmxKilled) {
    fill(0, 255, 0);
  } 
  else { 
    fill(255, 0, 0);
  }
  rect(4, 4, 120, 120, 8, 8, 8, 8);

  if (LOG)
    debuglog.flush();

  diffTime = millis() - lastTime;
  driftTime = diffTime - stepTime;

  if (diffTime >= stepTime) {
    /*
     ) Check active background seq
     ) Advance active background seq by one step
     
     ) Check active overlay seq3
     ) Advance active overlay seq by one step
     
     ) Work out who has priority
     ) Run current step   
     */

    println("Trying to trigger every "+stepTime+"ms with a drift of "+driftTime);
    lastTime = millis();
  }
}

void keyPressed() {
  if (key == 'q' || key == 'Q') {
    if (LOG) {
      debuglog.println("Log: Exiting, stopping debug log");
      debuglog.flush();
      debuglog.close();
    }
    exit();
  } 
  else if (key == 'k' || key == 'K') {
    if (dmxKilled)
    {
      dmxKilled=false;
      if (LOG) debuglog.println("DMX: Resurrected");
    } 
    else if (!dmxKilled) {
      dmxKilled=true;
      KillAll();
      if (LOG) debuglog.println("DMX: Killed");
    }
  }  
  else if (key == 't' || key == 'T') {
    testSequence("death");
    testSequence("damage");
    testSequence("missilehit");
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

/*
void UpdateLight (int startAddr, int r, int g, int b, int shutter, int strobe) {
 if (LOG) debuglog.println("DMX: StartAddr: "+startAddr+" Red:"+r+" Green:"+g+" Blue:"+b+" Shutter:"+shutter+" Strobe:"+strobe);
 if (DMX && !dmxKilled) {
 dmxOutput.set(startAddr, r);
 dmxOutput.set(startAddr+1, g);
 dmxOutput.set(startAddr+2, b);
 dmxOutput.set(startAddr+3, shutter);
 dmxOutput.set(startAddr+4, strobe);
 }
 }
 */

void playSequence (String sequence, boolean background, int duration) {
  if (background) {
    if (LOG) debuglog.println("Seq: Playing overlay "+sequence+" for "+duration+"ms");
    seqBackground = sequence;
  }
  else {
    if (LOG) debuglog.println("Seq: Playing background "+sequence);
    seqOverlay = sequence;
    seqDuration = duration;
  }
}

File[] listFiles(String dir) {
  File file = new File(dir);
  if (file.isDirectory()) {
    File[] files = file.listFiles(seqFilter);
    return files;
  } 
  else {
    return null;
  }
}
void testSequence (String sequenceName) {
  Table sequenceTable = mapSequences.get(sequenceName);
  int sequenceOverflow;
  int sequenceChannels;
  int sequenceSteps;

  sequenceChannels = sequenceTable.getColumnCount();
  sequenceSteps = sequenceTable.getRowCount(); 
  print("Sequence "+sequenceName+" has "+sequenceSteps+" steps covering "+sequenceChannels+" channels. ");

  if (sequenceChannels > dmxUniverse ) {
    sequenceOverflow = sequenceChannels-dmxUniverse;
    println("Sequence has "+sequenceOverflow+" too many channels, and will be truncated to "+dmxUniverse);
  } 
  else {
    println("");
  }
}

void setupSequences() {
  String seqPath = sketchPath("")+"sequences/";
  File[] sequences = listFiles(seqPath);
  if (LOG) debuglog.println("Seq: "+sequences.length+" sequences found.");

  int i = 0;
  while (i < sequences.length)
  {
    if (!sequences[i].isDirectory()) {
      String name = split(sequences[i].getName(), ".")[0];
      if (LOG) debuglog.println("Seq: Loading "+name+" from "+sequences[i].getName());
      Table table = loadTable(sequences[i].getAbsolutePath(), "header, csv");
      mapSequences.put(name, table);
      ++i;
    }
  }
  if (LOG) debuglog.println("Seq: "+sequences.length+" Sequences loaded");
}

java.io.FilenameFilter seqFilter = new java.io.FilenameFilter() {
  boolean accept(File dir, String name) {
    return name.endsWith(".seq");
  }
};

void oscEvent(OscMessage theOscMessage) {
  if (LOG) {
    debuglog.print("OSC: addrpattern: "+theOscMessage.addrPattern());
    debuglog.println(" typetag: "+theOscMessage.typetag());
  }

  if (theOscMessage.addrPattern() == "/ship/poweron") {
    playSequence("reactoridle", true, 0);
  } 
  else if (theOscMessage.addrPattern() == "/ship/damage") {
    playSequence("damage", false, 10);
  }
} 


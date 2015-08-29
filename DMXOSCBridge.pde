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
 * Q - Quit. 
 * B - Blackout. 
 * T - Test some loaded sequences.
 * D - Print DMX universe channel values
 *
 */

//MISC
boolean LOG=false; //Enables logging.
boolean DEBUG=false; //Enable debug spam.

// DMX
boolean DMX=false;  //Enables DMX Interface
String dmxPort="COM4";  //Change this to match the virtual COM port created by the DMX interface.
int dmxBaudrate=115000;  //Change this to match the baud rate of the DMX interface. 
int dmxUniverseSize=20;  //Number of channels in DMX universe.
int[] dmxUniverse = new int[dmxUniverseSize]; //DMX Universe.
boolean dmxBlackout;  //DMX blackout toggle.
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
int seqBackgroundStep; //Current step in background sequence.
int seqOverlayStep; //Current step in overlay sequence.
int seqOverlayActive; //Overlay state.
int lastTime; //Last frame time.
int currentTime; //Current time.
int diffTime; //Diff between frames in ms
int stepTime = 100; //Delay between steps in ms
int driftTime;  //Drift form perfect step in ms.
HashMap<String, Table> mapSequences = new HashMap<String, Table>();


//DISPLAY
PFont font;

void setup() { 
  oscListener = new OscP5(this, oscPort);
  size(320, 240);
  font = createFont("Eurostile", 64);

  if (DMX) {
    dmxOutput=new DmxP512(this, dmxUniverseSize, false);
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
  if (LOG)
    debuglog.flush();

  diffTime = millis() - lastTime;
  driftTime = diffTime - stepTime;

  if (diffTime >= stepTime) {

    if (DEBUG)
      println("Trying to trigger every " + stepTime + "ms with a drift of " + driftTime);

    if (DMX)
      outputDMX();

    lastTime = millis();
  }
  drawInterface();
}

void drawInterface() {

  color background = color(0, 0, 0);
  color enabled = color(0, 255, 0);
  color disabled = color(50, 50, 50);
  color title = color(255, 255, 255);

  background(background);
  textAlign(CENTER, CENTER);
  rectMode(CENTER);

  textFont(font, 24);
  fill(title);
  text("DMX Bridge Status", width/2, 15);

  textFont(font, 32);
  if (dmxBlackout) {
    fill(255, 0, 0);
    rect(width/2, 60, 250, 40, 9);
    fill(background);
    text("!! BLACKOUT !!", width/2, 60);
  } else {
    fill(0, 0, 0);
    textFont(font, 32);
    text("!! BLACKOUT !!", width/2, 60);
  }

  textFont(font, 24);

  if (DMX) {
    fill(enabled);
    text("DMX Enabled", width/2, 110);
  } else {
    fill(disabled);
    text("DMX Disabled", width/2, 110);
  }

  if (DEBUG) {
    fill(enabled);
    text("Debug Enabled", width/2, 135);
  } else {
    fill(disabled);
    text("Debug Disabled", width/2, 135);
  }

  if (LOG) {
    fill(enabled);
    text("Logging Enabled", width/2, 160);
  } else {
    fill(disabled);
    text("Logging Disabled", width/2, 160);
  }
}

void keyPressed() {
  if (key == 'q' || key == 'Q') {  //QUIT
    if (LOG) {
      debuglog.println("Log: Exiting, stopping debug log");
      debuglog.flush();
      debuglog.close();
    }
    exit();
  } else if (key == 'b' || key == 'B') {  //BLACKOUT TOGGLE
    if (dmxBlackout)
    {
      dmxBlackout=false;
      if (LOG) debuglog.println("DMX: Blackout OFF");
    } else if (!dmxBlackout) {
      dmxBlackout=true;
      if (LOG) debuglog.println("DMX: Blackout ON");
    }
  } else if (key == 't' || key == 'T') {  //TEST
    testSequence("death");
    testSequence("damage");
    testSequence("missilehit");
  } else if (key == 'd' || key == 'D') {  //DMX DUMP
    println("DMX Universe Dump START");
    int i=0;
    while (i <= dmxUniverseSize-1)
    {
      print(i+1+"="+dmxUniverse[i]+" ");
      ++i;
    }
    println();
    println("DMX Universe Dump END");
  } else if (key == 'f' || key == 'F') {  //ONE SHOT FULLBRIGHT
    int i=0;
    while (i <= dmxUniverseSize-1)
    {
      dmxUniverse[i] = 255;
      ++i;
    }
  }
}

void outputDMX() {

  if (dmxBlackout) {
    int i=0;
    while (i <= dmxUniverseSize-1)
    {
      dmxUniverse[i] = 0;
      ++i;
    }
  }

  //) Background sequences loop forever until changed. Continue to animiate even when overlay has priority.
  //) Overlays play once and override background. 

  //) Find active background seq and length.
  //) Check current step, are we on the last step? If so;
  //) Advance active background seq by one step OR loop to start.

  //) Do we have an active overlay? If not, do nothing
  //) Find active overlay seq and length
  //) Check current step, are we on the last step?
  //) Advance active overlay seq by one step. If at end, set overlay as inactive.

  //) Work out who has priority
  //) Output current step

  //Push universe to DMX interface.
  dmxOutput.set(0, dmxUniverse);
  dmxOutput.run();
}

void setSequence (String sequence, boolean background, int duration) {
  if (background) {
    if (LOG) debuglog.println("Seq: Playing background "+sequence);
    seqBackground = sequence;
    seqBackgroundStep = 0;
  } else {
    if (LOG) debuglog.println("Seq: Playing  "+sequence+" for "+duration+"ms");
    seqOverlay = sequence;
    seqOverlayStep = 0;
    seqOverlayActive = 1;
  }
}

File[] listFiles(String dir) {
  File file = new File(dir);
  if (file.isDirectory()) {
    File[] files = file.listFiles(seqFilter);
    return files;
  } else {
    return null;
  }
}

//Test given sequence name and report.
void testSequence (String sequenceName) {
  Table sequenceTable = mapSequences.get(sequenceName);
  int sequenceOverflow;
  int sequenceChannels;
  int sequenceSteps;

  sequenceChannels = sequenceTable.getColumnCount();
  sequenceSteps = sequenceTable.getRowCount(); 
  print("Sequence "+sequenceName+" has "+sequenceSteps+" steps covering "+sequenceChannels+" channels. ");

  if (sequenceChannels > dmxUniverseSize ) {
    sequenceOverflow = sequenceChannels-dmxUniverseSize;
    println("Sequence has "+sequenceOverflow+" too many channels, and will be truncated to "+dmxUniverseSize);
  } else {
    println("");
  }
}

//Load all sequence files from disk.
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
    setSequence("reactoridle", true, 0);
  } else if (theOscMessage.addrPattern() == "/ship/damage") {
    setSequence("damage", false, 10);
  }
} 

// ======================== LEGACY BULLSHIT BELOW. DO NOT USE. ===============================

/*

 void UpdateLight (int startAddr, int r, int g, int b, int shutter, int strobe) {
 if (LOG) debuglog.println("DMX: StartAddr: "+startAddr+" Red:"+r+" Green:"+g+" Blue:"+b+" Shutter:"+shutter+" Strobe:"+strobe);
 if (DMX && !dmxBlackout) {
 dmxOutput.set(startAddr, r);
 dmxOutput.set(startAddr+1, g);
 dmxOutput.set(startAddr+2, b);
 dmxOutput.set(startAddr+3, shutter);
 dmxOutput.set(startAddr+4, strobe);
 }
 }
 */

/*
  if (!dmxBlackout) {
 fill(0, 255, 0);
 } else { 
 fill(255, 0, 0);
 }
 rect(4, 4, 120, 120, 8, 8, 8, 8);
 
 */
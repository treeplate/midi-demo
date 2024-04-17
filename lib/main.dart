// NOTE: this is untested due to me losing my cable connecting to my piano

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_midi_command/flutter_midi_command.dart';
import 'package:flutter_midi_command/flutter_midi_command_messages.dart';
import 'package:flutter_midi_pro/flutter_midi_pro.dart';
import 'package:flutter_virtual_piano/flutter_virtual_piano.dart';
import 'parser.dart';

void main() {
  runApp(const App());
}

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

const bool doChannelPreview = false;

class _AppState extends State<App> {
  MidiPro pro = MidiPro();
  List<MidiDevice> devices = [];
  StreamSubscription? incomingMessages;
  Map<int, Map<int, bool>> incomingNotes = {};
  Map<int, int> incomingDevices = {};
  int outgoingDevice = 0;
  static const List<Color> channelColors = [
    Colors.grey,
    Colors.purple,
    Colors.green,
    Color(0xFFBE2633),
    Color(0xFFE06F8B),
    Color(0xFF493C2B),
    Color(0xFFA46422),
    Color(0xFFEB8931),
    Color(0xFFF7E26B),
    Color(0xFF2F484E),
    Color(0xFF44891A),
    Color(0xFFA3CE27),
    Color(0xFF1B2632),
    Color(0xFF005784),
    Color(0xFF31A2F2),
    Color(0xFFB2DCEF),
  ];

  @override
  void initState() {
    MidiCommand().devices.then((value) {
      setState(() {
        devices = value!;
      });
    });
    MidiCommand().onMidiSetupChanged!.listen((event) {
      MidiCommand().devices.then((value) {
        setState(() {
          devices = value!;
        });
      });
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    pro.playMidiNote(midi: 60, velocity: 127);
    print('fff');
    if (doChannelPreview) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: GridView.count(
        crossAxisCount: 8,
        children: List.generate(
          16,
          (e) => Container(
            color: channelColors[e],
            width: 20,
            height: 20,
            child: Text(
              "$e",
              style: TextStyle(
                color: Color(~channelColors[e].value | 0xff000000),
              ),
            ),
          ),
        ).toList(),
      ),
    );
    }
    
    if (devices.length > 1) {
      return Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
            child: Text(
                'Please disconnect all but one of the following MIDI devices:\n${devices.map((e) => e.name).join('\n')}')),
      );
    }
    if (devices.isEmpty) {
      return const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: Text('Please connect at least one MIDI device via USB.'),
        ),
      );
    }
    if (incomingMessages == null || !devices.single.connected) {
      incomingMessages?.cancel();
      incomingMessages = MidiCommand().onMidiDataReceived!.listen((event) {
        MidiMessage msg = parseMidiMessage(event.data);
        setState(() {
          if (msg is NoteOnMessage) {
            (incomingNotes[msg.channel] ??= {})[msg.note] = true;
            print('BEEP');
            pro.playMidiNote(midi: msg.note, velocity: msg.velocity);
          } else if (msg is NoteOffMessage) {
            incomingNotes[msg.channel]![msg.note] = false;
            pro.stopMidiNote(midi: msg.note, velocity: msg.velocity);
          } else if (msg is PCMessage) {
            incomingDevices[msg.channel] = msg.program;
          } else {
            print(prettyPrintMidiMessage(msg));
          }
        });
      });
    }
    if (!devices.single.connected) {
      MidiCommand().connectToDevice(devices.single);
    }
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ...incomingDevices.entries.map((e) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("incoming channel "),
                  Container(
                    width: 10,
                    height: 10,
                    color: channelColors[e.key],
                  ),
                  Text("${e.key} device: ${e.value}"),
                ],
              )),
          SizedBox(
            height: 100,
            child: VirtualPiano(
              noteRange: const RangeValues(21, 108),
              highlightedNoteSets: incomingNotes.entries
                  .map((e) => HighlightedNoteSet(
                      Set.of(e.value.entries
                          .where((element) => element.value)
                          .map((e) => e.key)),
                      channelColors[e.key]))
                  .toList(),
              onNotePressed: (note, vel) {
                NoteOnMessage(note: note, velocity: (vel * 50).toInt()).send();
              },
              onNoteReleased: (note) {
                NoteOffMessage(note: note, velocity: 0).send();
              },
            ),
          ),
          Text("outgoing device: $outgoingDevice"),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              10,
              (index) => TextButton(
                  onPressed: () {
                    setState(() {
                      PCMessage(program: index).send();
                      outgoingDevice = index;
                    });
                  },
                  child: Text("switch to device $index")),
            ),
          ),
        ],
      ),
    );
  }
}

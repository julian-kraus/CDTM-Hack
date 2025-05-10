import 'package:flutter_tts/flutter_tts.dart';

class TTSService {
  late FlutterTts flutterTts;
  late List<dynamic> voices;
  dynamic currentVoice;

  void initTTS() async {
    flutterTts = FlutterTts();
    voices = await flutterTts.getVoices;
    voices = voices.where((voice) => voice['name'].contains('en')).toList();
    currentVoice = voices.first;
    flutterTts.setVoice(currentVoice);
  }

  void setVoice(Map<String, dynamic> voice) {
    currentVoice = voice;
    flutterTts.setVoice(currentVoice);
  }
}

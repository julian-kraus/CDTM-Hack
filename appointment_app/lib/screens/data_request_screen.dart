import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform, File;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
// ignore: avoid_web_libraries_in_flutter
import 'package:universal_html/html.dart' as html;
import '../models/appointment.dart';
import '../models/chat_message.dart';
import '../services/chat_api_service.dart';

class DataRequestScreen extends StatefulWidget {
  final String reason;
  final DateTime? appointmentDate;

  const DataRequestScreen(
      {Key? key, required this.reason, this.appointmentDate})
      : super(key: key);

  @override
  _DataRequestScreenState createState() => _DataRequestScreenState();
}

enum TtsState { playing, stopped, paused, continued }

class _DataRequestScreenState extends State<DataRequestScreen> {
  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  late String _patientName;
  late DateTime _patientBirthdate;

  // Speech-to-text
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _voiceInput = '';

  // Text-to-speech
  late FlutterTts _flutterTts;
  String? language;
  bool _ttsPrimed = false;
  String? engine;
  double volume = 0.5;
  double pitch = 1.0;
  double rate = 0.5;
  bool isCurrentLanguageInstalled = false;

  bool shownCheckIn = false;

  String? _newVoiceText;
  int? _inputLength;

  TtsState ttsState = TtsState.stopped;

  bool get isPlaying => ttsState == TtsState.playing;
  bool get isStopped => ttsState == TtsState.stopped;
  bool get isPaused => ttsState == TtsState.paused;
  bool get isContinued => ttsState == TtsState.continued;

  bool get isIOS => !kIsWeb && Platform.isIOS;
  bool get isAndroid => !kIsWeb && Platform.isAndroid;
  bool get isWindows => !kIsWeb && Platform.isWindows;
  bool get isWeb => kIsWeb;

  // Image picker
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();

    _speech = stt.SpeechToText();
    _flutterTts = FlutterTts();
    _initSpeech();
    _initTts();
    _loadPatientInfo(); // <-- new
  }

  /// 1) Load name & birthdate, 2) then show the welcome dialog.
  Future<void> _loadPatientInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('name') ?? 'Patient';
    final birthStr =
        prefs.getString('birthdate') ?? DateTime.now().toIso8601String();
    setState(() {
      _patientName = name;
      _patientBirthdate = DateTime.parse(birthStr);
    });
    // Wait until after build to show the dialog:
    if (!shownCheckIn) {
      shownCheckIn = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showWelcomeDialog();
      });
    }
  }

  /// 2) The initial pop-up
  void _showWelcomeDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // force them to tap "Check In"
      builder: (ctx) => AlertDialog(
        title: Text('Hello $_patientName!'),
        content: const Text('Welcome to the AVI Online Checking.\n\n'
            'Press "Check In" to start.'),
        actions: [
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              // ── PRIME THE ENGINE ──────────────────────────────────
              await _flutterTts.setVolume(volume);
              await _flutterTts.setSpeechRate(rate);
              await _flutterTts.setPitch(pitch);
              await _flutterTts.speak(_newVoiceText ?? ''); // silent or real
              // ─────────────────────────────────────────────────────
              _loadPatientAndStart(); // <-- now kickoff your chat logic
            },
            child: const Text('Check In'),
          ),
        ],
      ),
    );
  }

  Future<void> _initSpeech() async {
    await _speech.initialize(
      onStatus: (status) => debugPrint('Speech status: $status'),
      onError: (error) => debugPrint('Speech error: $error'),
    );
  }

  dynamic _initTts() {
    _flutterTts = FlutterTts();

    _setAwaitOptions();

    if (isAndroid) {
      _getDefaultEngine();
      _getDefaultVoice();
    }

    _flutterTts.setStartHandler(() {
      setState(() {
        print("Playing");
        ttsState = TtsState.playing;
      });
    });
    _flutterTts.setCompletionHandler(() {
      setState(() {
        print("Complete");
        ttsState = TtsState.stopped;
      });
    });
    _flutterTts.setCancelHandler(() {
      setState(() {
        print("Cancel");
        ttsState = TtsState.stopped;
      });
    });
    _flutterTts.setPauseHandler(() {
      setState(() {
        print("Paused");
        ttsState = TtsState.paused;
      });
    });
    _flutterTts.setContinueHandler(() {
      setState(() {
        print("Continued");
        ttsState = TtsState.continued;
      });
    });
    _flutterTts.setErrorHandler((msg) {
      setState(() {
        print("error: $msg");
        ttsState = TtsState.stopped;
      });
    });
  }

  void _onChange(String text) {
    setState(() {
      _newVoiceText = text;
    });
  }

  Future<void> _setAwaitOptions() async {
    await _flutterTts.awaitSpeakCompletion(true);
  }

  Future<void> _loadPatientAndStart() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('name') ?? 'Patient';
    final birthStr =
        prefs.getString('birthdate') ?? DateTime.now().toIso8601String();
    setState(() {
      _patientName = name;
      _patientBirthdate = DateTime.parse(birthStr);
      _isLoading = true;
    });
    final responses = await ChatApi.instance.startConversation(
      name: _patientName,
      birthdate: _patientBirthdate,
      reason: widget.reason,
      appointmentDate: widget.appointmentDate,
    );
    setState(() {
      _messages.addAll(responses);
      _isLoading = false;
    });
    _handleSpecialMessages(responses);
    _speakBotMessages(responses);
  }

  void _handleSpecialMessages(List<ChatMessage> msgs) {
    for (var msg in msgs) {
      if (msg.isBot && msg.requestDocument && msg.onlyApp && kIsWeb) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Download App'),
              content:
                  const Text('Please download our app to import documents.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel')),
                ElevatedButton(onPressed: () {}, child: const Text('Download')),
              ],
            ),
          );
        });
      }
    }
  }

  Future<void> _sendMessage(String text) async {
    setState(() {
      _messages.add(ChatMessage(text: text, isBot: false));
      _isLoading = true;
    });
    final responses = await ChatApi.instance.sendMessage(_messages);
    setState(() {
      _messages.addAll(responses);
      _isLoading = false;
    });
    _handleSpecialMessages(responses);
    _speakBotMessages(responses);
  }

  Future<void> _speak() async {
    await _flutterTts.setVolume(volume);
    await _flutterTts.setSpeechRate(rate);
    await _flutterTts.setPitch(pitch);

    if (_newVoiceText != null) {
      if (_newVoiceText!.isNotEmpty) {
        await _flutterTts.speak(_newVoiceText!);
      }
    }
  }

  void _speakBotMessages(List<ChatMessage> msgs) {
    for (var msg in msgs) {
      if (msg.isBot) {
        _flutterTts.speak(msg.text);
      }
    }
  }

  Future<void> _toggleListening() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (status) => debugPrint('Speech status: $status'),
        onError: (error) => debugPrint('Speech error: $error'),
      );
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
            onResult: (val) =>
                setState(() => _voiceInput = val.recognizedWords));
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();

      // 2) do a silent utterance in this tap
      if (!_ttsPrimed) {
        await _flutterTts.setVolume(1.0);
        await _flutterTts.speak('');
        _ttsPrimed = true;
      }

      // 3) now safe to send your voice input off and later TTS will work
      if (_voiceInput.isNotEmpty) {
        _sendMessage(_voiceInput);
        _voiceInput = '';
      }
    }
  }

  Future<void> _takePhoto() async {
    final XFile? picked = await _picker.pickImage(source: ImageSource.camera);
    if (picked != null) {
      await _sendDocument(File(picked.path));
    }
  }

  Future<void> _getDefaultEngine() async {
    var engine = await _flutterTts.getDefaultEngine;
    if (engine != null) {
      print(engine);
    }
  }

  Future<void> _getDefaultVoice() async {
    var voice = await _flutterTts.getDefaultVoice;
    if (voice != null) {
      print(voice);
    }
  }

  Future<void> _uploadPhoto() async {
    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      await _sendDocument(File(picked.path));
    }
  }

  Future<void> _sendDocument(File file) async {
    setState(() {
      _isLoading = true;
      _messages.add(ChatMessage(text: 'Uploading document...', isBot: false));
    });
    final responses = await ChatApi.instance.sendDocument(file);
    setState(() {
      _messages.removeWhere((m) => m.text == 'Uploading document...');
      _messages.addAll(responses);
      _isLoading = false;
    });
    _speakBotMessages(responses);
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                if (kIsWeb ||
                    Platform.isWindows ||
                    Platform.isLinux ||
                    Platform.isMacOS) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Camera not supported on desktop. Please upload a photo.'),
                    ),
                  );
                } else {
                  _takePhoto();
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Upload Photo'),
              onTap: () {
                Navigator.pop(context);
                _uploadPhoto();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Chat for ${widget.reason}')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return msg.isBot
                    ? _buildBotMessage(msg)
                    : _buildUserMessage(msg);
              },
            ),
          ),
          if (_isLoading) const LinearProgressIndicator(),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                IconButton(
                    icon: Icon(_isListening ? Icons.mic_off : Icons.mic),
                    onPressed: () async {
                      if (!_isLoading) {
                        // ── PRIME THE ENGINE ──────────────────────────────────
                        await _flutterTts.setVolume(volume);
                        await _flutterTts.setSpeechRate(rate);
                        await _flutterTts.setPitch(pitch);
                        await _flutterTts
                            .speak(_newVoiceText ?? ''); // silent or real
                        // ─────────────────────────────────────────────────────
                        _toggleListening();
                      }
                    }),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isListening ? 'Listening...' : 'Tap the mic and speak',
                    style: TextStyle(
                        color: _isLoading ? Colors.grey : Colors.black),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBotMessage(ChatMessage msg) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const CircleAvatar(child: Icon(Icons.android)),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(msg.text),
              ),
            ),
          ],
        ),
        if (msg.requestDocument && !msg.onlyApp)
          Padding(
            padding: const EdgeInsets.only(left: 48.0, top: 4),
            child: ElevatedButton(
              onPressed: _showPhotoOptions,
              child: const Text('Add Photo'),
            ),
          ),
        if (msg.requestDocument && msg.onlyApp && !kIsWeb && Platform.isIOS)
          Padding(
            padding: const EdgeInsets.only(left: 48.0, top: 4),
            child: ElevatedButton(
                onPressed: () {}, child: const Text('Import Data')),
          ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildUserMessage(ChatMessage msg) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.blue[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(msg.text),
        ),
      ],
    );
  }
}

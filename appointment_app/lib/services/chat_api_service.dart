import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/chat_message.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

abstract class ChatApiService {
  Future<List<ChatMessage>> startConversation({
    required String name,
    required DateTime birthdate,
    required String reason,
    DateTime? appointmentDate,
  });

  Future<List<ChatMessage>> sendMessage(List<ChatMessage> messages);

  /// Uploads a document file and returns the AI responses.
  Future<List<ChatMessage>> sendDocument(File file);
}

class MockChatApiService implements ChatApiService {
  int _step = 0;

  @override
  Future<List<ChatMessage>> startConversation({
    required String name,
    required DateTime birthdate,
    required String reason,
    DateTime? appointmentDate,
  }) async {
    _step = 0;
    await Future.delayed(const Duration(seconds: 1));
    return [
      ChatMessage(
        text: 'Hi $name, I see your appointment reason is "$reason".',
        isBot: true,
      ),
      ChatMessage(
        text: appointmentDate != null
            ? 'Your appointment date is ${appointmentDate.toLocal().toString().split(' ')[0]}. '
            : 'When would you like to schedule this appointment?',
        isBot: true,
        requestDocument: false,
      ),
    ];
  }

  @override
  Future<List<ChatMessage>> sendMessage(List<ChatMessage> messages) async {
    _step++;
    await Future.delayed(const Duration(seconds: 1));
    if (_step == 1) {
      return [
        ChatMessage(text: 'Got it. Thanks!', isBot: true),
        ChatMessage(
          text: 'Please upload your ID document.',
          isBot: true,
          requestDocument: true,
          onlyApp: false,
        ),
      ];
    } else if (_step == 2) {
      return [
        ChatMessage(
          text: 'Alternatively, you can import your documents via our app.',
          isBot: true,
          requestDocument: true,
          onlyApp: true,
        ),
      ];
    } else {
      return [
        ChatMessage(text: 'All done. Have a great day!', isBot: true),
      ];
    }
  }

  @override
  Future<List<ChatMessage>> sendDocument(File file) async {
    await Future.delayed(const Duration(seconds: 1));
    return [
      ChatMessage(text: 'Document received. Thanks!', isBot: true),
      ChatMessage(text: 'Let me process that for you.', isBot: true),
    ];
  }
}

class RealChatApiService implements ChatApiService {
  String url = "https://6d8c-217-111-104-75.ngrok-free.app/api/generate_answer";

  @override
  Future<List<ChatMessage>> startConversation({
    required String name,
    required DateTime birthdate,
    required String reason,
    DateTime? appointmentDate,
  }) async {
    // 1) Build a single ChatMessage whose `text` is our JSON payload:
    final payload = <String, dynamic>{
      'name': name,
      'birthdate': birthdate.toIso8601String(),
      'reason': reason,
      if (appointmentDate != null)
        'appointmentDate': appointmentDate.toIso8601String(),
    };

    final initialMessage = ChatMessage(
      text: jsonEncode(payload),
      isBot: false, // this is coming *from* the user
    );

    // 2) Delegate to sendMessage (which handles headers, JSON-wrapping,
    //    parsing, etc.)
    return sendMessage([initialMessage]);
  }

  @override
  Future<List<ChatMessage>> sendMessage(List<ChatMessage> messages) async {
    final uri = Uri.parse(url);

    // 1) Build headers
    final headers = <String, String>{
      'Authorization': 'Basic dXNlcjpwYXNzd29yZD1=', // your Basic creds
      'x-api-key': '123',
      'Content-Type': 'application/json',
    };

    // 2) Build the body exactly as your API expects
    final body = jsonEncode({
      'Chat History': messages.map((m) => m.toJson()).toList(),
    });

    // 3) POST
    final resp = await http.post(uri, headers: headers, body: body);

    if (resp.statusCode != 200) {
      throw Exception(
        'Chat API error ${resp.statusCode}: ${resp.body}',
      );
    }

    // 4) Decode the JSON response
    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;

    // 5) Extract the list and convert to ChatMessage
    final history = decoded['Chat History'] as List<dynamic>;
    return history
        .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<ChatMessage>> sendDocument(File file) async {
    throw UnimplementedError();

    final uri = Uri.parse('https://your.api/upload');
    final request = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath('document', file.path));
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode == 200) {
      final data = json.decode(response.body) as List;
      return data.map((e) => ChatMessage.fromJson(e)).toList();
    } else {
      throw Exception('Document upload failed: ${response.statusCode}');
    }
  }
}

class ChatApi {
  // Switch to RealChatApiService() when ready
  static final ChatApiService instance = RealChatApiService();
}

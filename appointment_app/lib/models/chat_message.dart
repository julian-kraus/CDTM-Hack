class ChatMessage {
  final String text;
  final bool isBot;
  final bool requestDocument;
  final bool onlyApp;

  ChatMessage({
    required this.text,
    this.isBot = false,
    this.requestDocument = false,
    this.onlyApp = false,
  });

  /// Add this factory:
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      text: json['content'] as String,
      isBot: json['isBot'] == 'system' ? true : false,
      requestDocument: json['requestDocument'] as bool? ?? false,
      onlyApp: json['onlyApp'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'content': text,
        'role': isBot ? 'system' : 'user',
        'requestDocument': requestDocument,
        'onlyApp': onlyApp,
      };
}

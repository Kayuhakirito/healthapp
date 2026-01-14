import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  // --- DÁN API KEY MỚI VÀO ĐÂY ---
  final String apiKey = "AIzaSyAUwsVlB1CXypXKIbA6XYq-Ti1QAabCTyY";
  // ------------------------------

  late final GenerativeModel _model;
  late final ChatSession _chat;
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initAI();
  }

  void _initAI() {
    try {
      _model = GenerativeModel(
        model: 'gemini-1.5-flash', // Model này cần gói google_generative_ai: ^0.4.0
        apiKey: apiKey,
        generationConfig: GenerationConfig(temperature: 0.7),
      );
      _chat = _model.startChat();
    } catch (e) {
      setState(() => _messages.add({"role": "ai", "text": "Lỗi khởi tạo: $e"}));
    }
  }

  Future<void> _sendMessage() async {
    final message = _textController.text.trim();
    if (message.isEmpty) return;

    setState(() {
      _messages.add({"role": "user", "text": message});
      _isLoading = true;
      _textController.clear();
    });
    _scrollToBottom();

    try {
      final response = await _chat.sendMessage(Content.text(message));
      final text = response.text;
      if (text != null) {
        setState(() => _messages.add({"role": "ai", "text": text}));
      }
    } catch (e) {
      setState(() => _messages.add({"role": "ai", "text": "Lỗi: $e"}));
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Trợ lý Sức khỏe AI")),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(15),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['role'] == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    padding: const EdgeInsets.all(12),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.blue : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: isUser
                        ? Text(msg['text']!, style: const TextStyle(color: Colors.white))
                        : MarkdownBody(data: msg['text']!),
                  ),
                );
              },
            ),
          ),
          if (_isLoading) const LinearProgressIndicator(),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(child: TextField(controller: _textController, decoration: const InputDecoration(hintText: "Nhập tin nhắn...", border: OutlineInputBorder()))),
                IconButton(icon: const Icon(Icons.send), onPressed: _sendMessage),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
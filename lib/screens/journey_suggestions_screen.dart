// lib/screens/journey_suggestions_screen.dart
import 'package:flutter/material.dart';

class Message {
  final String content;
  final bool isUser;
  final DateTime timestamp;
  Message({required this.content, required this.isUser, required this.timestamp});
}

class JourneySuggestionsScreen extends StatefulWidget {
  const JourneySuggestionsScreen({super.key});

  @override
  State<JourneySuggestionsScreen> createState() => _JourneySuggestionsScreenState();
}

class _JourneySuggestionsScreenState extends State<JourneySuggestionsScreen> {
  final List<Message> _messages = [
    Message(
      content: "Hi! I'm your AI travel assistant powered by Gemini. I can help you plan your journey across East Africa.",
      isUser: false,
      timestamp: DateTime.now(),
    ),
  ];
  final TextEditingController _controller = TextEditingController();

  void _sendMessage() {
    if (_controller.text.isEmpty) return;
    setState(() {
      _messages.add(Message(content: _controller.text, isUser: true, timestamp: DateTime.now()));
      _controller.clear();
    });
    // Simulate AI delay
    Future.delayed(const Duration(seconds: 1), () {
      setState(() {
        _messages.add(Message(
          content: "That sounds like a great trip! For that route, I'd recommend the SGR First Class for comfort.",
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Journey Planner'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color.fromARGB(255, 197, 200, 243), Color(0xFF3949AB)]),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return Align(
                  alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    padding: const EdgeInsets.all(16),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                    decoration: BoxDecoration(
                      color: msg.isUser ? const Color(0xFF1A237E) : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(msg.isUser ? 16 : 0),
                        bottomRight: Radius.circular(msg.isUser ? 0 : 16),
                      ),
                      boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 5)],
                    ),
                    child: Text(
                      msg.content,
                      style: TextStyle(color: msg.isUser ? Colors.white : const Color(0xFF1A237E)),
                    ),
                  ),
                );
              },
            ),
          ),
          // Input Area
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.black12))),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Ask about routes, prices...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: const Color(0xFFFF6D00),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
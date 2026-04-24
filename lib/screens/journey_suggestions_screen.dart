// lib/screens/journey_suggestions_screen.dart
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:safaripass/env/env.dart';

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
  final List<Message> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  bool _isLoading = false;
  late final GenerativeModel _model;
  late final ChatSession _chat;

  
  final String apiKey = Env.geminiApiKey;

  @override
  void initState() {
    super.initState();
    _initializeGemini();
    
  }

  void _initializeGemini() {
    // 1. Setup the Model with instructions on how to behave
    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: apiKey,
      systemInstruction: Content.system(
        "You are an expert travel assistant for East Africa named SafariTravel AI. "
        "You are the SafariPass assistant. You must use your internal tools to search for the latest 2026 SGR schedules and bus prices for the Nairobi-Mombasa route before responding."
        "Help users plan journeys, suggest routes (SGR, flights, buses like Modern Coast, Mash East Africa, Tahmeed Coach and Trinity Express), "
        "estimate costs in KES/UGX/TZS, and suggest tourist destinations. Keep answers concise, "
        "friendly, and formatted nicely. Do not use bold/markdown formatting if the app cannot render it."
      ),
    );

    // 2. Start a "Chat Session" so it remembers context
    _chat = _model.startChat();

    // 3. Add the initial welcome message
    _messages.add(
      Message(
        content: "Hi! I'm your AI travel assistant powered by Gemini. I can help you plan your journey across East Africa. Ask me about destinations, routes, travel times, or budget estimates!",
        isUser: false,
        timestamp: DateTime.now(),
      )
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final userText = _controller.text.trim();
    if (userText.isEmpty) return;

    // 1. Add user message to UI
    setState(() {
      _messages.add(Message(content: userText, isUser: true, timestamp: DateTime.now()));
      _isLoading = true; // Show loading indicator
    });
    
    _controller.clear();
    _scrollToBottom();

    try {
      // 2. Send message to Gemini API
      final response = await _chat.sendMessage(Content.text(userText));
      final aiText = response.text;

      if (aiText != null) {
        setState(() {
          _messages.add(Message(content: aiText, isUser: false, timestamp: DateTime.now()));
        });
      }
    } catch (e) {
        // Handle network errors or API limits gracefully
         String errorMessage = "An unexpected error occurred.";
            
          if (e.toString().contains('not found')) {
            errorMessage = "Model ID mismatch. Check your model string.";
          } else if (e.toString().contains('API_KEY_INVALID')) {
            errorMessage = "Invalid API Key. Check your .env setup.";
          }

          setState(() {
            _messages.add(Message(content: errorMessage, isUser: false, timestamp: DateTime.now()));
          });
          print("Detailed Gemini Error: $e");
      } finally {
        setState(() {
          _isLoading = false;
        });
        _scrollToBottom();
      }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Journey Planner',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF1A2151), Color(0xFF2A3477)]),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return Align(
                  alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    padding: const EdgeInsets.all(16),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.80),
                    decoration: BoxDecoration(
                      color: msg.isUser ? const Color(0xFF1A2151) : Colors.white,
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
                      style: TextStyle(
                        color: msg.isUser ? Colors.white : const Color(0xFF1A2151),
                        height: 1.4, // Improves readability of long AI responses
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
          // AI Loading Indicator
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  const SizedBox(
                    width: 16, 
                    height: 16, 
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFF27121))
                  ),
                  const SizedBox(width: 12),
                  Text('SafariTravel AI is thinking...', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                ],
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
                    enabled: !_isLoading, // Disable typing while waiting for AI
                    decoration: InputDecoration(
                      hintText: 'Ask about routes, prices...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                    onSubmitted: (_) => _sendMessage(), // Send on keyboard "Enter"
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: _isLoading ? Colors.grey : const Color(0xFFF27121),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _isLoading ? null : _sendMessage,
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
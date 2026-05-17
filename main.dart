import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AuraApp());
}

class AuraApp extends StatelessWidget {
  const AuraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AURA AI',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        primaryColor: Colors.redAccent,
        colorScheme: const ColorScheme.dark(
          primary: Colors.redAccent,
          secondary: Colors.redAccent,
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      ),
      home: const MainShell(),
    );
  }
}

class ChatMessage {
  final String role;
  final String text;
  final String? imagePath;

  ChatMessage({required this.role, required this.text, this.imagePath});

  Map<String, dynamic> toJson() => {
    'role': role, 'text': text, 'imagePath': imagePath,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    role: json['role'], text: json['text'], imagePath: json['imagePath'],
  );
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  // PUBLIC CONFIGURATION TEMPLATE
  // Replace these placeholders with your domain deployment routing setups
  final String _apiUrl = 'https://YOUR_ROUTING_DOMAIN_OR_IP:8443/chat';
  final String _apiKey = 'YOUR_SECURE_API_KEY_HERE';

  List<ChatMessage> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  late ScrollController _scrollController;

  http.Client? _httpClient;
  bool _isLoading = false;
  File? _selectedImage;

  String _userName = "User";
  String _language = "Deutsch";

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _loadData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('user_name') ?? "User";
      _language = prefs.getString('language') ?? "Deutsch";
      String? savedHistory = prefs.getString('chat_history');
      if (savedHistory != null) {
        Iterable l = json.decode(savedHistory);
        _messages = List<ChatMessage>.from(l.map((model) => ChatMessage.fromJson(model)));
      }
    });
    _scrollToBottom();
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('chat_history', json.encode(_messages.map((e) => e.toJson()).toList()));
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (img != null) {
      setState(() => _selectedImage = File(img.path));
    }
  }

  Future<void> _sendMessage() async {
    if (_inputController.text.isEmpty && _selectedImage == null) return;

    final promptText = _inputController.text;
    final tempImg = _selectedImage;

    setState(() {
      _messages.add(ChatMessage(role: "user", text: promptText, imagePath: tempImg?.path));
      _isLoading = true;
      _selectedImage = null;
    });

    _inputController.clear();
    _scrollToBottom();
    _httpClient = http.Client();

    try {
      var request = http.MultipartRequest('POST', Uri.parse(_apiUrl));
      request.headers['x-api-key'] = _apiKey;

      String finalPrompt = "User: $_userName, Lang: $_language. Prompt: $promptText";
      request.fields['prompt'] = finalPrompt;

      if (tempImg != null) {
        request.files.add(await http.MultipartFile.fromPath('image', tempImg.path));
      }

      var streamedResponse = await _httpClient!.send(request).timeout(const Duration(seconds: 120));
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        setState(() => _messages.add(ChatMessage(role: "ai", text: data['response'])));
      }
    } catch (e) {
      if (!e.toString().contains("closed")) {
        String errorMsg = e.toString().contains("Timeout")
            ? "⚠️ Timeout: Server needs more time."
            : "⚠️ Connection failed.";
        setState(() => _messages.add(ChatMessage(role: "ai", text: errorMsg)));
      }
    } finally {
      setState(() => _isLoading = false);
      _saveHistory();
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _buildDrawer(),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text("AURA AI", style: GoogleFonts.orbitron(letterSpacing: 2, fontWeight: FontWeight.bold, color: Colors.redAccent)),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white38),
            onPressed: () => _confirmDeleteAll(),
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildChatList()),
          if (_selectedImage != null) _buildImagePreview(),
          if (_isLoading) _buildCancelStrip(),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      alignment: Alignment.centerLeft,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.file(_selectedImage!, height: 80, width: 80, fit: BoxFit.cover),
          ),
          Positioned(
            right: 0, top: 0,
            child: GestureDetector(
              onTap: () => setState(() => _selectedImage = null),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.close, size: 16, color: Colors.white),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildChatList() {
    return ListView.builder(
      controller: _scrollController,
      itemCount: _messages.length,
      itemBuilder: (context, i) {
        final m = _messages[i];
        bool isAi = m.role == "ai";
        return Dismissible(
          key: UniqueKey(),
          direction: DismissDirection.endToStart,
          onDismissed: (_) {
            setState(() => _messages.removeAt(i));
            _saveHistory();
          },
          background: Container(
            color: Colors.red.withValues(alpha: 0.1),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: const Icon(Icons.delete, color: Colors.redAccent),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 20),
            color: isAi ? Colors.white.withValues(alpha: 0.02) : Colors.transparent,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(isAi : Icons.auto_awesome : Icons.person_outline,
                    color: isAi ? Colors.redAccent : Colors.white38, size: 20),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (m.imagePath != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(File(m.imagePath!), width: 250),
                          ),
                        ),
                      Text(m.text, style: const TextStyle(fontSize: 16, height: 1.6, color: Colors.white)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCancelStrip() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
      color: Colors.redAccent.withValues(alpha: 0.05),
      child: Row(
        children: [
          const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.redAccent)),
          const SizedBox(width: 15),
          const Text("Aura is thinking...", style: TextStyle(fontSize: 12, color: Colors.white54)),
          const Spacer(),
          GestureDetector(
            onTap: () => _httpClient?.close(),
            child: const Text("STOP", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: const Color(0xFF0A0A0A),
      child: SafeArea(
        child: Container(
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(28)),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.add_a_photo_outlined, color: _selectedImage != null ? Colors.redAccent : Colors.white38),
                onPressed: _pickImage,
              ),
              Expanded(
                child: TextField(
                  controller: _inputController,
                  onSubmitted: (_) => _sendMessage(),
                  decoration: const InputDecoration(hintText: "Message Aura...", border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 10)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FloatingActionButton.small(
                  elevation: 0, backgroundColor: Colors.redAccent,
                  onPressed: _sendMessage,
                  child: const Icon(Icons.arrow_upward, color: Colors.black),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF111111),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 60),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Settings", style: GoogleFonts.orbitron(fontSize: 22, color: Colors.redAccent, fontWeight: FontWeight.bold)),
            const SizedBox(height: 40),
            _settingField("Display Name", _userName, (val) => _updatePref('user_name', val)),
            _settingField("AI Language", _language, (val) => _updatePref('language', val)),
          ],
        ),
      ),
    );
  }

  Widget _settingField(String label, String current, Function(String) onSave) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 25),
      child: TextField(
        onSubmitted: onSave,
        decoration: InputDecoration(
          labelText: label, labelStyle: const TextStyle(color: Colors.redAccent),
          enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white12)),
        ),
        controller: TextEditingController(text: current),
      ),
    );
  }

  Future<void> _updatePref(String key, String val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, val);
    _loadData();
  }

  void _confirmDeleteAll() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Clear History?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("No")),
          TextButton(onPressed: () { setState(() => _messages.clear()); _saveHistory(); Navigator.pop(context); }, child: const Text("Yes", style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
  }
}

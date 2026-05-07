import 'package:flutter/material.dart';

class ChatbotScreen extends StatefulWidget {
  @override
  _ChatbotScreenState createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {

  List<Map<String, String>> messages = [
    {
      "id": "1",
      "text": "Hello 👋 I am your AI Meeting Assistant. How can I help you today?",
      "sender": "bot"
    }
  ];

  TextEditingController controller = TextEditingController();
  bool loading = false;

  // ===== AI RESPONSE =====
  String generateAIResponse(String userText) {
    String text = userText.toLowerCase();

    if (text.contains("meeting")) {
      return "You can create or join a meeting from the home screen. I can also generate summaries for you.";
    }

    if (text.contains("summary")) {
      return "Meeting summaries are automatically generated using AI after your meeting ends.";
    }

    if (text.contains("hello") || text.contains("hi")) {
      return "Hello 😊 How can I assist you with your meeting today?";
    }

    return "I understand. Let me know if you need help with meetings, summaries, or app features.";
  }

  // ===== SEND MESSAGE =====
  void sendMessage() {
    if (controller.text.trim().isEmpty) return;

    String userText = controller.text;

    setState(() {
      messages.add({
        "id": DateTime.now().toString(),
        "text": userText,
        "sender": "user"
      });
      controller.clear();
      loading = true;
    });

    Future.delayed(Duration(seconds: 1), () {
      setState(() {
        messages.add({
          "id": DateTime.now().toString(),
          "text": generateAIResponse(userText),
          "sender": "bot"
        });
        loading = false;
      });
    });
  }

  // ===== UI =====
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF4F6F8),

      appBar: AppBar(
        backgroundColor: Color(0xFF39A935),
        title: Text("AI Assistant"),
        centerTitle: true,
      ),

      body: Column(
        children: [

          // CHAT LIST
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(15),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                var msg = messages[index];
                bool isUser = msg["sender"] == "user";

                return Row(
                  mainAxisAlignment: isUser
                      ? MainAxisAlignment.end
                      : MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [

                    if (!isUser)
                      Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: Icon(Icons.smart_toy,
                            color: Color(0xFF39A935), size: 28),
                      ),

                    Container(
                      constraints: BoxConstraints(maxWidth: 250),
                      margin: EdgeInsets.only(bottom: 14),
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isUser
                            ? Color(0xFF39A935)
                            : Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                          bottomLeft:
                              Radius.circular(isUser ? 16 : 4),
                          bottomRight:
                              Radius.circular(isUser ? 4 : 16),
                        ),
                        boxShadow: isUser
                            ? []
                            : [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 2,
                                )
                              ],
                      ),
                      child: Text(
                        msg["text"]!,
                        style: TextStyle(
                          color: isUser ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // LOADING
          if (loading)
            Padding(
              padding: EdgeInsets.only(left: 15, bottom: 10),
              child: Row(
                children: [
                  SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text("AI typing..."),
                ],
              ),
            ),

          // INPUT AREA
          Container(
            padding: EdgeInsets.all(10),
            color: Colors.white,
            child: Row(
              children: [

                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: "Ask something...",
                      filled: true,
                      fillColor: Color(0xFFF1F3F6),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 15),
                    ),
                  ),
                ),

                SizedBox(width: 8),

                GestureDetector(
                  onTap: sendMessage,
                  child: Container(
                    height: 45,
                    width: 45,
                    decoration: BoxDecoration(
                      color: Color(0xFF39A935),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.send, color: Colors.white),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';

class TranslateScreen extends StatefulWidget {
  @override
  _TranslateScreenState createState() => _TranslateScreenState();
}

class _TranslateScreenState extends State<TranslateScreen> {

  final List<String> languages = [
    'English','Urdu','Arabic','Chinese','French',
    'Spanish','German','Hindi','Turkish','Russian'
  ];

  String inputText = '';
  String translatedText = '';
  bool loading = false;

  String sourceLang = 'English';
  String targetLang = 'Urdu';

  // ===== TRANSLATE =====
  void handleTranslate() {
    if (inputText.isEmpty) return;

    setState(() => loading = true);

    Future.delayed(Duration(seconds: 1), () {
      setState(() {
        translatedText = "($targetLang) $inputText";
        loading = false;
      });
    });
  }

  // ===== SWAP =====
  void swapLanguages() {
    setState(() {
      String temp = sourceLang;
      sourceLang = targetLang;
      targetLang = temp;
    });
  }

  // ===== LANGUAGE PICKER =====
  void openLanguagePicker(String type) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Container(
          padding: EdgeInsets.all(20),
          height: 350,
          child: Column(
            children: [
              Text("Select Language",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 10),

              Expanded(
                child: ListView.builder(
                  itemCount: languages.length,
                  itemBuilder: (_, i) {
                    return ListTile(
                      title: Text(languages[i]),
                      onTap: () {
                        setState(() {
                          if (type == 'source') {
                            sourceLang = languages[i];
                          } else {
                            targetLang = languages[i];
                          }
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              )
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF4F6FA),

      body: Column(
        children: [

          // ===== HEADER =====
          Container(
            padding: EdgeInsets.fromLTRB(16, 40, 16, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF39A935), Color(0xFF2D8E2A)],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [

                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(Icons.arrow_back, color: Colors.white),
                ),

                Column(
                  children: [
                    Text("AI Translator",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                    Text("Real-time multilingual communication",
                        style: TextStyle(color: Color(0xFFE8FFE6), fontSize: 12)),
                  ],
                ),

                Icon(Icons.smart_toy, color: Colors.white)
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [

                  // ===== LANGUAGE PANEL =====
                  Padding(
                    padding: EdgeInsets.all(20),
                    child: Row(
                      children: [

                        Expanded(
                          child: _langCard("FROM", sourceLang, () {
                            openLanguagePicker('source');
                          }),
                        ),

                        GestureDetector(
                          onTap: swapLanguages,
                          child: Container(
                            margin: EdgeInsets.symmetric(horizontal: 10),
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Color(0xFF39A935),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.swap_horiz, color: Colors.white),
                          ),
                        ),

                        Expanded(
                          child: _langCard("TO", targetLang, () {
                            openLanguagePicker('target');
                          }),
                        ),
                      ],
                    ),
                  ),

                  // ===== INPUT =====
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        Text("Enter Text",
                            style: TextStyle(fontWeight: FontWeight.bold)),

                        SizedBox(height: 10),

                        TextField(
                          maxLines: 4,
                          onChanged: (val) => inputText = val,
                          decoration: InputDecoration(
                            hintText: "Type or use voice input...",
                            border: InputBorder.none,
                          ),
                        ),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [

                            _circleBtn(Icons.mic, Color(0xFF39A935)),

                            _circleBtn(Icons.close, Colors.red, onTap: () {
                              setState(() {
                                inputText = '';
                                translatedText = '';
                              });
                            }),
                          ],
                        )
                      ],
                    ),
                  ),

                  // ===== TRANSLATE BUTTON =====
                  GestureDetector(
                    onTap: handleTranslate,
                    child: Container(
                      margin: EdgeInsets.symmetric(horizontal: 20),
                      padding: EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Color(0xFF39A935),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: loading
                            ? CircularProgressIndicator(color: Colors.white)
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.translate, color: Colors.white),
                                  SizedBox(width: 8),
                                  Text("Translate",
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                      ),
                    ),
                  ),

                  SizedBox(height: 20),

                  // ===== RESULT =====
                  if (translatedText.isNotEmpty)
                    _card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Translation Result",
                                  style: TextStyle(fontWeight: FontWeight.bold)),

                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Color(0xFFE8FFE6),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text("AI Generated",
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF39A935),
                                        fontWeight: FontWeight.w600)),
                              )
                            ],
                          ),

                          SizedBox(height: 10),

                          Text(translatedText,
                              style: TextStyle(fontSize: 16)),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              _circleBtn(Icons.copy, Color(0xFF39A935)),
                              _circleBtn(Icons.volume_up, Color(0xFF39A935)),
                            ],
                          )
                        ],
                      ),
                    ),

                  SizedBox(height: 20),

                  Text("Powered by AI Translation Engine",
                      style: TextStyle(color: Colors.grey, fontSize: 12)),

                  SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===== WIDGETS =====

  Widget _langCard(String label, String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 3)],
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey)),
            Text(text,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: child,
    );
  }

  Widget _circleBtn(IconData icon, Color color, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(left: 10),
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Color(0xFFF1F3F6),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color),
      ),
    );
  }
}



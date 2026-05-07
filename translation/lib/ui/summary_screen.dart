import 'package:flutter/material.dart';

class SummaryScreen extends StatelessWidget {
  final String? title;
  final String? duration;
  final List<String>? participants;
  final String? transcript;

  const SummaryScreen({
    super.key,
    this.title,
    this.duration,
    this.participants,
    this.transcript,
  });

  // ===== AI SUMMARY =====
  Map<String, dynamic> generateSummary() {
    if (transcript == null || transcript!.isEmpty) {
      return {
        "overview": "No summary available.",
        "keyPoints": [],
        "actionItems": [],
        "confidence": 0
      };
    }

    List<String> sentences = transcript!.split(".");

    return {
      "overview": sentences.take(2).join("."),
      "keyPoints": sentences.take(3).toList(),
      "actionItems": [
        "Complete pending tasks",
        "Start backend integration",
        "Testing next week"
      ],
      "confidence": 92
    };
  }

  @override
  Widget build(BuildContext context) {
    final summary = generateSummary();

    return Scaffold(
      backgroundColor: Color(0xFFF4F6F8),

      // ===== HEADER =====
      body: Column(
        children: [

          Container(
            padding: EdgeInsets.fromLTRB(16, 40, 16, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF39A935), Color(0xFF2E8B2B)],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(25),
                bottomRight: Radius.circular(25),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [

                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(Icons.arrow_back, color: Colors.white),
                ),

                Text(
                  "AI Meeting Summary",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                Icon(Icons.smart_toy, color: Colors.white)
              ],
            ),
          ),

          // ===== BODY =====
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [

                  // ===== CARD =====
                  Container(
                    margin: EdgeInsets.all(20),
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.black12, blurRadius: 4)
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        // Badge
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Color(0xFFE8F8E6),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.psychology, size: 16, color: Color(0xFF39A935)),
                              SizedBox(width: 6),
                              Text("AI Generated",
                                  style: TextStyle(
                                      color: Color(0xFF39A935),
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),

                        SizedBox(height: 10),

                        Text(
                          title ?? "Meeting",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),

                        SizedBox(height: 10),

                        Row(
                          children: [
                            _chip(Icons.access_time, duration ?? ""),
                            SizedBox(width: 8),
                            _chip(Icons.group,
                                "${participants?.length ?? 0} Participants"),
                          ],
                        ),

                        SizedBox(height: 5),

                        Text(
                          participants?.join(", ") ?? "",
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),

                  // ===== OVERVIEW =====
                  _section(
                    icon: Icons.text_snippet,
                    title: "Overview",
                    child: Text(summary["overview"]),
                  ),

                  // ===== KEY POINTS =====
                  _section(
                    icon: Icons.star_border,
                    title: "Key Points",
                    child: Column(
                      children: (summary["keyPoints"] as List<String>)
                          .map((e) => Row(
                                children: [
                                  Icon(Icons.check_circle, color: Color(0xFF39A935)),
                                  SizedBox(width: 6),
                                  Expanded(child: Text(e)),
                                ],
                              ))
                          .toList(),
                    ),
                  ),

                  // ===== ACTION ITEMS =====
                  _section(
                    icon: Icons.assignment_turned_in,
                    title: "Action Items",
                    child: Column(
                      children: (summary["actionItems"] as List<String>)
                          .map((e) => Container(
                                margin: EdgeInsets.only(bottom: 8),
                                padding: EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Color(0xFFF7FBF6),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.check_circle_outline,
                                        color: Color(0xFF39A935)),
                                    SizedBox(width: 8),
                                    Text(e),
                                  ],
                                ),
                              ))
                          .toList(),
                    ),
                  ),

                  // ===== CONFIDENCE =====
                  _section(
                    icon: Icons.show_chart,
                    title: "AI Confidence",
                    child: Text(
                        "${summary["confidence"]}% accuracy based on speech clarity"),
                  ),

                  // ===== TRANSCRIPT =====
                  _section(
                    icon: Icons.description,
                    title: "Full Transcript",
                    child: Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Color(0xFFF1F3F6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(transcript ?? ""),
                    ),
                  ),

                  // ===== BUTTONS =====
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _button(Icons.download, "Export"),
                        _button(Icons.share, "Share"),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===== Widgets =====

  Widget _section({required IconData icon, required String title, required Widget child}) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 3)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Color(0xFF39A935)),
              SizedBox(width: 6),
              Text(title,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          SizedBox(height: 10),
          child
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Color(0xFFF1F3F6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          SizedBox(width: 5),
          Text(text),
        ],
      ),
    );
  }

  Widget _button(IconData icon, String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 25, vertical: 12),
      decoration: BoxDecoration(
        color: Color(0xFF39A935),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white),
          SizedBox(width: 6),
          Text(text,
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
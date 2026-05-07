import 'package:flutter/material.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {

    List<Map<String, String>> historyData = [];

    return Scaffold(
      backgroundColor: Color(0xFFF4F6F8),

      // ===== HEADER =====
      appBar: AppBar(
        backgroundColor: Color(0xFF39A935),
        elevation: 4,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "History",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),

      // ===== BODY =====
      body: historyData.isEmpty
          ? _emptyState()
          : ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: historyData.length,
              itemBuilder: (context, index) {
                final item = historyData[index];

                return GestureDetector(
                  onTap: () {},
                  child: Container(
                    margin: EdgeInsets.only(bottom: 14),
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(color: Colors.black12, blurRadius: 3)
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        // HEADER
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              item['title'] ?? '',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF222222)),
                            ),
                            Text(
                              item['date'] ?? '',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),

                        SizedBox(height: 6),

                        // SUMMARY
                        Text(
                          item['summary'] ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 14, color: Color(0xFF555555)),
                        ),

                        SizedBox(height: 6),

                        // FOOTER
                        Row(
                          children: [
                            Icon(Icons.language,
                                size: 18, color: Colors.grey),
                            SizedBox(width: 6),
                            Text(
                              item['language'] ?? '',
                              style: TextStyle(
                                  fontSize: 13, color: Colors.grey),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  // ===== EMPTY STATE =====
  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [

          Icon(Icons.history, size: 80, color: Colors.grey.shade400),

          SizedBox(height: 10),

          Text(
            "No History Yet",
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF444444)),
          ),

          SizedBox(height: 4),

          Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              "Your meeting summaries will appear here.",
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14, color: Color(0xFF777777)),
            ),
          )
        ],
      ),
    );
  }
}
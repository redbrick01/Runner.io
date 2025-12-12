import 'package:flutter/material.dart';

class RankingPanel extends StatefulWidget {
  final ScrollController scrollController;

  const RankingPanel({super.key, required this.scrollController});

  @override
  State<RankingPanel> createState() => _RankingPanelState();
}

class _RankingPanelState extends State<RankingPanel>
    with SingleTickerProviderStateMixin {
  int _tabIndex = 0; // 0 = 개인랭킹, 1 = 팀랭킹
  int _modeIndex = 0; // 0 = PVP, 1 = PVE

  // 🔥 가짜 랭킹 데이터 (UI만 확인용)
  final dummyRanking = [
    {"name": "김러너", "km": 127.5, "rank": 1, "point": 40},
    {"name": "박달리기", "km": 118.3, "rank": 2, "point": 50},
    {"name": "이스트프린트", "km": 112.8, "rank": 3, "point": 25},
    {"name": "최러닝", "km": 98.2, "rank": 4, "point": 20},
    {"name": "정호진", "km": 95.6, "rank": 5, "point": 20},
    {"name": "강마라톤", "km": 87.4, "rank": 6, "point": 19},
    {"name": "윤알러미", "km": 82.1, "rank": 7, "point": 18},
    {"name": "홍스피드", "km": 78.5, "rank": 8, "point": 17},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: ListView(
        controller: widget.scrollController, // ⭐ 여기 하나만!
        padding: EdgeInsets.zero,
        children: [
          const SizedBox(height: 10),

          // 손잡이
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),

          const SizedBox(height: 15),

          // "랭킹" 제목
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "랭킹",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          const SizedBox(height: 10),

          _buildTabBar(),
          const SizedBox(height: 15),
          _buildModeButtons(),
          const SizedBox(height: 15),

          // 랭킹 아이템들
          ...dummyRanking.map((item) => _buildRankingItem(item)).toList(),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // --------------------------------------------
  // 개인랭킹 / 팀랭킹 탭 UI
  // --------------------------------------------
  Widget _buildTabBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildTabButton("개인랭킹", 0),
        const SizedBox(width: 20),
        _buildTabButton("팀랭킹", 1),
      ],
    );
  }

  Widget _buildTabButton(String text, int index) {
    final bool isSelected = _tabIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _tabIndex = index),
      child: Column(
        children: [
          Text(
            text,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.blue : Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 60,
            height: 3,
            color: isSelected ? Colors.blue : Colors.transparent,
          ),
        ],
      ),
    );
  }

  // --------------------------------------------
  // PVP / PVE 모드 버튼 UI
  // --------------------------------------------
  Widget _buildModeButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildModeButton("PVP", 0),
        const SizedBox(width: 12),
        _buildModeButton("PVE", 1),
      ],
    );
  }

  Widget _buildModeButton(String label, int index) {
    final bool isSelected = _modeIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _modeIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black54,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // --------------------------------------------
  // 🔥 랭킹 리스트 아이템
  // --------------------------------------------
  Widget _buildRankingItem(dynamic item) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // 프로필 아이콘
          const CircleAvatar(radius: 20, backgroundColor: Colors.amber),
          const SizedBox(width: 16),

          // 이름 + 거리
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item["name"],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "${item["km"]} km",
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),

          // 순위 표시
          Text(
            "#${item["rank"]}",
            style: const TextStyle(
              fontSize: 18,
              color: Colors.blue,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(width: 16),

          // 포인트 표시
          Text(
            "${item["point"]}P",
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }
}

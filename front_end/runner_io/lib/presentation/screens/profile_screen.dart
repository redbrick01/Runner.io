import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('내 정보', style: TextStyle(color: Colors.black)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Column(
        children: [
          const SizedBox(height: 24),
          const CircleAvatar(
            radius: 40,
            backgroundColor: Colors.grey,
            // backgroundImage: NetworkImage('...'), // 나중에 실제 프로필 이미지
          ),
          const SizedBox(height: 16),
          const Text(
            '권민지 서울 서초구',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 24),

          // WEIGHT 카드
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF315B9A),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'WEIGHT',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: 0.3, // TODO: 실제 값으로 변경
                      minHeight: 10,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation(Colors.white),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      _WeightLabel(title: 'Start', value: '00kg'),
                      _WeightLabel(title: 'Current', value: '00kg'),
                      _WeightLabel(title: 'Target', value: '00kg'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 프로필 편집 버튼들
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                _ProfileButton(text: '내 프로필 편집하기'),
                const SizedBox(height: 12),
                _ProfileButton(text: '내 프로필 편집하기'),
                const SizedBox(height: 12),
                _ProfileButton(text: '내 프로필 편집하기'),
              ],
            ),
          ),
          const Spacer(),
          const Text(
            '로그아웃',
            style: TextStyle(decoration: TextDecoration.underline),
          ),
          const SizedBox(height: 8),
          const Text(
            '회원 탈퇴',
            style: TextStyle(decoration: TextDecoration.underline),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _WeightLabel extends StatelessWidget {
  final String title;
  final String value;

  const _WeightLabel({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(title, style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _ProfileButton extends StatelessWidget {
  final String text;

  const _ProfileButton({required this.text});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE4ECFF),
          foregroundColor: const Color(0xFF315B9A),
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        onPressed: () {
          // TODO: 수정보기 화면으로 이동
        },
        child: Text(text),
      ),
    );
  }
}

class AppFormatters {
  const AppFormatters._();

  static String distance(double metres) {
    final km = metres / 1000;
    return '${km.toStringAsFixed(km >= 10 ? 1 : 2)} km';
  }

  static String duration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  static String pace(double secondsPerKm) {
    if (!secondsPerKm.isFinite || secondsPerKm <= 0) return "-'--\"";
    final totalSeconds = secondsPerKm.round();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return "$minutes'${seconds.toString().padLeft(2, '0')}\"";
  }

  static String point(double point) {
    if (point == point.roundToDouble()) {
      return '${point.toInt()} P';
    }
    return '${point.toStringAsFixed(1)} P';
  }

  static String area(double metres) {
    if (metres <= 0) return '0 km²';
    final km2 = metres / 1000000;
    return '${km2.toStringAsFixed(km2 >= 10 ? 1 : 2)} km²';
  }
}

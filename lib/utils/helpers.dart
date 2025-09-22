import 'package:intl/intl.dart';

class TimeHelper {
  // Format waktu untuk tampil di UI (waktu lokal)
  static String formatTimeForDisplay(String? timeString) {
    if (timeString == null || timeString.isEmpty) return '--:--';
    
    try {
      // Parse time dari server (format HH:mm:ss)
      final timeParts = timeString.split(':');
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      
      // Buat DateTime hari ini dengan jam tersebut
      final now = DateTime.now();
      final dateTime = DateTime(now.year, now.month, now.day, hour, minute);
      
      // Format untuk tampilan (24 jam)
      return DateFormat('HH:mm').format(dateTime);
    } catch (e) {
      return timeString; // Return original jika gagal parse
    }
  }
  
  // Get current time dalam format yang dikirim ke server
  static String getCurrentTimeForServer() {
    final now = DateTime.now();
    return DateFormat('HH:mm:ss').format(now);
  }
}
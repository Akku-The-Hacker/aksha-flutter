import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class QuoteService {
  static const String _quoteKey = 'daily_quote';
  static const String _quoteDateKey = 'quote_date';
  static const String _apiUrl = 'https://zenquotes.io/api/today';

  // Fallback quotes for offline mode
  static const List<String> _fallbackQuotes = [
    'The only way to do great work is to love what you do.',
    'Success is not final, failure is not fatal: it is the courage to continue that counts.',
    'Believe you can and you\'re halfway there.',
    'The future depends on what you do today.',
    'Don\'t watch the clock; do what it does. Keep going.',
    'The best time to plant a tree was 20 years ago. The second best time is now.',
    'Your limitation—it\'s only your imagination.',
    'Great things never come from comfort zones.',
    'Dream it. Wish it. Do it.',
    'Success doesn\'t just find you. You have to go out and get it.',
  ];

  /// Get daily motivational quote
  static Future<String> getDailyQuote() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now().toIso8601String().split('T')[0]; // YYYY-MM-DD
      final cachedDate = prefs.getString(_quoteDateKey);
      final cachedQuote = prefs.getString(_quoteKey);

      // Return cached quote if it's from today
      if (cachedDate == today && cachedQuote != null) {
        return cachedQuote;
      }

      // Fetch new quote
      try {
        final response = await http.get(Uri.parse(_apiUrl)).timeout(
          const Duration(seconds: 5),
        );

        if (response.statusCode == 200) {
          final List<dynamic> data = jsonDecode(response.body);
          if (data.isNotEmpty) {
            final quote = data[0]['q'] as String;
            final author = data[0]['a'] as String;
            final fullQuote = '"$quote" — $author';

            // Cache the quote
            await prefs.setString(_quoteKey, fullQuote);
            await prefs.setString(_quoteDateKey, today);

            return fullQuote;
          }
        }
      } catch (e) {
        // Network error, use cache or fallback
        print('Error fetching quote: $e');
      }

      // If fetch failed, return cached quote or fallback
      if (cachedQuote != null) {
        return cachedQuote;
      }

      // Return random fallback quote
      final randomIndex = DateTime.now().day % _fallbackQuotes.length;
      return _fallbackQuotes[randomIndex];
    } catch (e) {
      print('Quote service error: $e');
      // Return a safe fallback
      return 'Ready to track your routines?';
    }
  }

  /// Clear cached quote (for testing)
  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_quoteKey);
    await prefs.remove(_quoteDateKey);
  }
}

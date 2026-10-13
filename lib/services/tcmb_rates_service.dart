import 'dart:convert';
import 'dart:io';

class TcmbRatesService {
  TcmbRatesService._();

  static const _todayUrl = 'https://www.tcmb.gov.tr/kurlar/today.xml';

  /// Returns TCMB's indicative forex buying rates in TRY for USD and EUR.
  static Future<Map<String, double>> fetchBuyingRates() async {
    final http = HttpClient()..connectionTimeout = const Duration(seconds: 12);
    try {
      final request = await http.getUrl(Uri.parse(_todayUrl));
      request.headers.set(HttpHeaders.acceptHeader, 'application/xml');
      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('TCMB returned HTTP ${response.statusCode}.');
      }

      final xml = await utf8.decoder.bind(response).join().timeout(
        const Duration(seconds: 15),
      );
      final rates = <String, double>{};
      for (final code in ['USD', 'EUR']) {
        final currency = RegExp(
          '<Currency\\b(?=[^>]*CurrencyCode="$code")[^>]*>(.*?)</Currency>',
          caseSensitive: false,
          dotAll: true,
        ).firstMatch(xml);
        final buying = currency == null
            ? null
            : RegExp(r'<ForexBuying>\s*([^<]+)\s*</ForexBuying>')
                  .firstMatch(currency.group(1)!)
                  ?.group(1)
                  ?.trim();
        final value = buying == null ? null : double.tryParse(buying);
        if (value == null || value <= 0) {
          throw const FormatException('TCMB kur verisi okunamadı.');
        }
        rates[code] = value;
      }
      return rates;
    } finally {
      http.close(force: true);
    }
  }
}

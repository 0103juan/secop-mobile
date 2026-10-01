import 'dart:convert';

import 'package:http/http.dart' as http;

/// Where secop-api runs. Override at build time with --dart-define=API_URL=https://...
/// An Android emulator reaches the host machine at http://10.0.2.2:3000.
const apiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://localhost:3000');

class Entity {
  const Entity({required this.nit, required this.name, required this.department, required this.contracts});

  Entity.fromJson(Map<String, dynamic> json)
    : nit = json['nit'] as int,
      name = json['name'] as String,
      department = json['department'] as String,
      contracts = json['contracts'] as int;

  final int nit;
  final String name;
  final String department;
  final int contracts;
}

class YearCount {
  YearCount.fromJson(Map<String, dynamic> json) : year = json['year'] as int, contracts = json['contracts'] as int;

  final int year;
  final int contracts;
}

class EntityDetail {
  EntityDetail.fromJson(Map<String, dynamic> json)
    : name = json['name'] as String,
      years = [for (final row in json['years'] as List) YearCount.fromJson(row)];

  final String name;
  final List<YearCount> years;
}

/// A supplier or a contracting modality with what it adds up to.
class Ranked {
  Ranked.fromJson(Map<String, dynamic> json, String nameKey)
    : name = json[nameKey] as String,
      contracts = json['contracts'] as int,
      total = (json['total'] as num).toDouble();

  final String name;
  final int contracts;
  final double total;
}

class Overview {
  Overview.fromJson(Map<String, dynamic> json)
    : year = json['year'] as int,
      contracts = json['contracts'] as int,
      suppliers = json['suppliers'] as int,
      total = (json['total'] as num).toDouble(),
      largest = (json['largest'] as num).toDouble(),
      topSuppliers = [for (final row in json['topSuppliers'] as List) Ranked.fromJson(row, 'name')],
      byModality = [for (final row in json['byModality'] as List) Ranked.fromJson(row, 'modality')];

  final int year;
  final int contracts;
  final int suppliers;
  final double total;
  final double largest;
  final List<Ranked> topSuppliers;
  final List<Ranked> byModality;

  /// The share of the year explained by its largest contract, when that is half or more.
  ///
  /// Contract values are typed by hand in SECOP and some are wrong by orders of magnitude,
  /// so a total dominated by one contract is shown with a warning instead of as a fact.
  double get dominantShare => total > 0 && largest / total >= 0.5 ? largest / total : 0;
}

class Contract {
  Contract.fromJson(Map<String, dynamic> json)
    : id = json['id'] as String,
      object = json['object'] as String,
      supplier = json['supplier'] as String,
      modality = json['modality'] as String,
      signedOn = json['signedOn'] as String,
      value = (json['value'] as num).toDouble(),
      url = json['url'] as String?;

  final String id;
  final String object;
  final String supplier;
  final String modality;
  final String signedOn;
  final double value;
  final String? url;
}

class ContractPage {
  ContractPage.fromJson(Map<String, dynamic> json)
    : hasMore = json['hasMore'] as bool,
      items = [for (final row in json['items'] as List) Contract.fromJson(row)];

  final bool hasMore;
  final List<Contract> items;
}

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SecopApi {
  SecopApi({http.Client? client, this.baseUrl = apiUrl}) : _client = client ?? http.Client();

  final http.Client _client;
  final String baseUrl;

  Future<dynamic> _get(String path, [Map<String, String>? query]) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final http.Response response;
    try {
      // The API waits up to 60 seconds for datos.gov.co, which is slow on a cold query.
      response = await _client.get(uri).timeout(const Duration(seconds: 70));
    } on Exception {
      throw const ApiException('No se pudo conectar con la API.');
    }
    if (response.statusCode != 200) {
      throw ApiException(
        response.statusCode == 504
            ? 'datos.gov.co no respondió a tiempo. Inténtalo de nuevo.'
            : 'La API respondió con el error ${response.statusCode}.',
      );
    }
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  Future<List<Entity>> search(String query) async {
    final json = await _get('/entities', {'q': query});
    return [for (final row in json['items'] as List) Entity.fromJson(row)];
  }

  Future<EntityDetail> entity(int nit) async => EntityDetail.fromJson(await _get('/entities/$nit'));

  Future<Overview> overview(int nit, int year) async =>
      Overview.fromJson(await _get('/entities/$nit/overview', {'year': '$year'}));

  Future<ContractPage> contracts(int nit, int year, int page) async =>
      ContractPage.fromJson(await _get('/entities/$nit/contracts', {'year': '$year', 'page': '$page'}));
}

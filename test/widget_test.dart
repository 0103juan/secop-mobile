import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secop_mobile/api.dart';
import 'package:secop_mobile/format.dart';
import 'package:secop_mobile/main.dart';

/// A fake secop-api. 2019 holds one mistyped contract that dwarfs the rest of the year.
final _client = MockClient((request) async {
  final year = request.url.queryParameters['year'];
  final Object body = switch (request.url.path) {
    '/entities' => {
      'items': [
        {
          'nit': 890905211,
          'name': 'DISTRITO DE MEDELLÍN',
          'department': 'Antioquia',
          'level': 'Territorial',
          'contracts': 20384,
        },
      ],
    },
    '/entities/890905211' => {
      'name': 'DISTRITO DE MEDELLÍN',
      'years': [
        {'year': 2019, 'contracts': 1290, 'total': 7.6e20},
        {'year': 2024, 'contracts': 2316, 'total': 4307107568617.5},
      ],
    },
    '/entities/890905211/overview' => {
      'year': int.parse(year!),
      'contracts': 2316,
      'suppliers': 1439,
      'total': year == '2019' ? 7.6e20 + 1.1e12 : 4307107568617.5,
      'largest': year == '2019' ? 7.6e20 : 491372098658,
      'topSuppliers': [
        {'name': 'BANCOLOMBIA', 'contracts': 1, 'total': 491372098658},
      ],
      'byModality': [
        {'modality': 'Contratación directa', 'contracts': 1623, 'total': 1423858737423.97},
      ],
    },
    '/entities/890905211/contracts' => {
      'hasMore': request.url.queryParameters['page'] == '1',
      'items': [
        {
          'id': 'CO1.PCCNTR.${request.url.queryParameters['page']}',
          'object': 'Contrato de empréstito ${request.url.queryParameters['page']}',
          // A filtered list shows a different supplier, so the test can tell the two requests apart.
          'supplier': request.url.queryParameters['modality'] == 'Contratación directa'
              ? 'PROVEEDOR DIRECTO'
              : 'BANCO ${request.url.queryParameters['page']}',
          'modality': 'Contratación directa',
          'signedOn': '2024-11-21',
          'value': 491372098658,
          'url': null,
        },
      ],
    },
    _ => throw StateError('unexpected request ${request.url}'),
  };
  return http.Response.bytes(utf8.encode(jsonEncode(body)), 200);
});

void main() {
  test('amounts are said the Colombian way, where a billón is a million millions', () {
    expect(formatCop(4307107568617.5), r'$4,3 billones');
    expect(formatCop(491372098658), r'$491 mil millones');
    expect(formatCop(2000000), r'$2 millones');
    expect(formatCop(850000), r'$850.000');
    expect(formatCop(7.6e20), r'$760.000.000 billones');
    expect(formatNumber(20384), '20.384');
  });

  testWidgets('search, open an entity, page through contracts, and get warned about a mistyped year', (tester) async {
    await tester.pumpWidget(
      SecopApp(
        api: SecopApi(client: _client, baseUrl: 'http://api.test'),
      ),
    );

    await tester.enterText(find.byType(TextField), 'medellin');
    await tester.pump(const Duration(milliseconds: 300)); // the search waits for a pause in typing
    await tester.pumpAndSettle();
    expect(find.text('Antioquia · 20.384 contratos'), findsOneWidget);

    await tester.tap(find.text('DISTRITO DE MEDELLÍN'));
    await tester.pumpAndSettle();
    expect(tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '2024')).selected, isTrue); // latest year
    expect(find.text(r'$4,3 BILLONES'), findsOneWidget);
    expect(find.textContaining('Un solo contrato explica'), findsNothing);

    await tester.scrollUntilVisible(find.text('Cargar más contratos'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('BANCO 1'), findsOneWidget);
    await tester.tap(find.text('Cargar más contratos'));
    await tester.pumpAndSettle();
    expect(find.text('BANCO 2'), findsOneWidget);
    expect(find.text('Cargar más contratos'), findsNothing); // the second page was the last

    // Tapping a modality lists only its contracts; deleting the chip brings the whole year back.
    await tester.scrollUntilVisible(
      find.text('Contratación directa').first,
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Contratación directa').first);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('PROVEEDOR DIRECTO'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Solo Contratación directa'), findsOneWidget);
    expect(find.text('BANCO 1'), findsNothing);
    await tester.tap(find.byTooltip('Quitar filtro'));
    await tester.pumpAndSettle();
    expect(find.text('Solo Contratación directa'), findsNothing);
    expect(find.text('BANCO 1'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.widgetWithText(ChoiceChip, '2019'),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.widgetWithText(ChoiceChip, '2019'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Un solo contrato explica el 100 % del total de 2019'), findsOneWidget);
    expect(find.textContaining(r'el total sería $1,1 billones'), findsOneWidget);
  });
}

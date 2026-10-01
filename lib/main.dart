import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api.dart';
import 'format.dart';

void main() => runApp(SecopApp(api: SecopApi()));

class SecopApp extends StatelessWidget {
  const SecopApp({super.key, required this.api});

  final SecopApi api;

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF0F766E);
    return MaterialApp(
      title: 'Contratos a la vista',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: .fromSeed(seedColor: seed)),
      darkTheme: ThemeData(colorScheme: .fromSeed(seedColor: seed, brightness: .dark)),
      home: SearchScreen(api: api),
      // Entities have their own route, so that on the web an entity has a link that can be shared.
      onGenerateRoute: (settings) {
        final nit = int.tryParse(_entityRoute.firstMatch(settings.name ?? '')?.group(1) ?? '');
        if (nit == null) return null;
        return MaterialPageRoute<void>(settings: settings, builder: (_) => EntityScreen(api: api, nit: nit));
      },
    );
  }
}

final _entityRoute = RegExp(r'^/entidad/(\d{5,12})$');

const _examples = [
  Entity(nit: 890905211, name: 'Distrito de Medellín', department: 'Antioquia', contracts: 0),
  Entity(nit: 899999001, name: 'Ministerio de Educación Nacional', department: 'Bogotá', contracts: 0),
  Entity(nit: 890102018, name: 'Distrito de Barranquilla', department: 'Atlántico', contracts: 0),
];

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, required this.api});

  final SecopApi api;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  Timer? _debounce;
  String _query = '';
  Future<List<Entity>>? _results;

  void _onChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      final query = text.trim();
      setState(() {
        _query = query;
        _results = query.length >= 3 ? widget.api.search(query) : null;
      });
    });
  }

  void _open(Entity entity) => Navigator.of(context).pushNamed('/entidad/${entity.nit}');

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Contratos a la vista')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SearchBar(
              hintText: 'Busca una entidad pública',
              leading: const Icon(Icons.search),
              elevation: const WidgetStatePropertyAll(0),
              onChanged: _onChanged,
            ),
          ),
          Expanded(
            child: _results == null
                ? ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text('¿En qué gasta una entidad pública?', style: theme.textTheme.headlineSmall),
                      const SizedBox(height: 8),
                      Text(
                        'Cuánto contrató cada año, con quién y por qué modalidad, sobre los datos abiertos de SECOP II.',
                        style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final example in _examples)
                            ActionChip(label: Text(example.name), onPressed: () => _open(example)),
                        ],
                      ),
                    ],
                  )
                : FutureBuilder(
                    future: _results,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) return _Message('${snapshot.error}');
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final entities = snapshot.data!;
                      if (entities.isEmpty) return _Message('Ninguna entidad coincide con "$_query".');
                      return ListView.builder(
                        itemCount: entities.length,
                        itemBuilder: (context, index) {
                          final entity = entities[index];
                          return ListTile(
                            title: Text(entity.name),
                            subtitle: Text('${entity.department} · ${formatNumber(entity.contracts)} contratos'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _open(entity),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class EntityScreen extends StatefulWidget {
  const EntityScreen({super.key, required this.api, required this.nit});

  final SecopApi api;
  final int nit;

  @override
  State<EntityScreen> createState() => _EntityScreenState();
}

class _EntityScreenState extends State<EntityScreen> {
  late final Future<EntityDetail> _entity = widget.api.entity(widget.nit).then((entity) {
    if (mounted) {
      setState(() => _name = entity.name);
      if (entity.years.isNotEmpty) _select(entity.years.last.year); // open on the latest year with contracts
    }
    return entity;
  });
  String _name = '';
  int? _year;
  Future<Overview>? _overview;
  final List<Contract> _contracts = [];
  int _page = 0;
  bool _hasMore = false;
  bool _loadingContracts = false;
  String? _contractsError;

  void _select(int year) {
    setState(() {
      _year = year;
      _overview = widget.api.overview(widget.nit, year);
      _contracts.clear();
      _page = 0;
      _hasMore = false;
    });
    _loadContracts();
  }

  Future<void> _loadContracts() async {
    final year = _year!;
    setState(() {
      _loadingContracts = true;
      _contractsError = null;
    });
    try {
      final page = await widget.api.contracts(widget.nit, year, _page + 1);
      if (!mounted || year != _year) return; // the user moved to another year meanwhile
      setState(() {
        _contracts.addAll(page.items);
        _page++;
        _hasMore = page.hasMore;
      });
    } on ApiException catch (error) {
      if (mounted && year == _year) setState(() => _contractsError = error.message);
    } finally {
      if (mounted && year == _year) setState(() => _loadingContracts = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(_name, style: theme.textTheme.titleMedium, maxLines: 2)),
      body: FutureBuilder(
        future: _entity,
        builder: (context, snapshot) {
          if (snapshot.hasError) return _Message('${snapshot.error}');
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          final years = snapshot.data!.years;
          if (years.isEmpty) return const _Message('Esta entidad no tiene contratos firmados en SECOP II.');
          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              SizedBox(
                height: 56,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  reverse: true, // the latest year first, at the right edge
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    for (final y in years.reversed)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text('${y.year}'),
                          selected: y.year == _year,
                          onSelected: (_) => _select(y.year),
                        ),
                      ),
                  ],
                ),
              ),
              FutureBuilder(
                future: _overview,
                builder: (context, snapshot) {
                  if (snapshot.hasError) return _Message('${snapshot.error}');
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()));
                  }
                  return _OverviewView(snapshot.data!);
                },
              ),
              _SectionTitle('Contratos de $_year, del más grande al más pequeño'),
              for (final contract in _contracts) _ContractTile(contract),
              if (_contractsError != null) _Message(_contractsError!),
              if (_loadingContracts)
                const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
              else if (_hasMore || _contractsError != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: OutlinedButton(
                    onPressed: _loadContracts,
                    child: Text(_contractsError != null ? 'Reintentar' : 'Cargar más contratos'),
                  ),
                )
              else if (_contracts.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Fuente: SECOP II en datos.gov.co. Solo incluye lo publicado en SECOP II.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _OverviewView extends StatelessWidget {
  const _OverviewView(this.overview);

  final Overview overview;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final share = overview.dominantShare;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (share > 0)
          Card(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            color: scheme.tertiaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                'Un solo contrato explica el ${(100 * share).round()} % del total de ${overview.year}. '
                'Los valores de SECOP se digitan a mano y algunos tienen errores. '
                'Sin ese contrato, el total sería ${formatCop(overview.total - overview.largest)}.',
                style: TextStyle(color: scheme.onTertiaryContainer),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Column(
            children: [
              Row(
                children: [
                  _Kpi('Total contratado', formatCop(overview.total)),
                  _Kpi('Contratos', formatNumber(overview.contracts)),
                ],
              ),
              Row(
                children: [
                  _Kpi('Contratistas', formatNumber(overview.suppliers)),
                  _Kpi('Contrato más grande', formatCop(overview.largest)),
                ],
              ),
            ],
          ),
        ),
        const _SectionTitle('Mayores contratistas'),
        for (final supplier in overview.topSuppliers) _RankedRow(supplier, overview.topSuppliers.first.total),
        const _SectionTitle('Por modalidad'),
        for (final modality in overview.byModality) _RankedRow(modality, overview.byModality.first.total),
      ],
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Card.outlined(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A name, its amount, and a bar as long as its share of the biggest row.
class _RankedRow extends StatelessWidget {
  const _RankedRow(this.row, this.biggest);

  final Ranked row;
  final double biggest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(row.name)),
              const SizedBox(width: 12),
              Text(formatCop(row.total), style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: biggest > 0 ? row.total / biggest : 0,
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
          const SizedBox(height: 4),
          Text(
            '${formatNumber(row.contracts)} ${row.contracts == 1 ? 'contrato' : 'contratos'}',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _ContractTile extends StatelessWidget {
  const _ContractTile(this.contract);

  final Contract contract;

  @override
  Widget build(BuildContext context) {
    final url = contract.url;
    return ListTile(
      isThreeLine: true,
      title: Text(contract.supplier, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${contract.object.replaceAll(RegExp(r'\s+'), ' ')}\n${contract.signedOn} · ${contract.modality}',
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(formatCop(contract.value), style: const TextStyle(fontWeight: FontWeight.w700)),
      // The API only passes through links to secop.gov.co; the expediente opens in the browser.
      onTap: url == null ? null : () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 6),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, letterSpacing: 0.8),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(child: Text(text, textAlign: TextAlign.center)),
    );
  }
}

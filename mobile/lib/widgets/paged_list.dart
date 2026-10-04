import 'dart:async';

import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import 'common.dart';

/// Liste paginée avec recherche, filtres, défilement infini et « tirer pour rafraîchir ».
class PagedList<T> extends StatefulWidget {
  const PagedList({
    super.key,
    required this.fetch,
    required this.itemBuilder,
    this.searchHint = 'Rechercher…',
    this.filters,
    this.header,
    this.headerBuilder,
    this.emptyIcon = Icons.inbox_outlined,
    this.emptyTitle = 'Aucun élément',
    this.emptyMessage,
    this.onScan,
    this.separated = true,
    this.showSearch = true,
    this.padding = const EdgeInsets.only(bottom: 96),
    this.initialSearch = '',
  });

  final Future<Paginated<T>> Function(int page, String search) fetch;
  final Widget Function(BuildContext context, T item, VoidCallback reload) itemBuilder;
  final String searchHint;
  final Widget? filters;
  final Widget? header;

  /// En-tête construit à partir de la réponse brute (stats, résumé…).
  final Widget? Function(BuildContext context, Json raw)? headerBuilder;
  final IconData emptyIcon;
  final String emptyTitle;
  final String? emptyMessage;
  final VoidCallback? onScan;
  final bool separated;
  final bool showSearch;
  final EdgeInsets padding;
  final String initialSearch;

  @override
  State<PagedList<T>> createState() => PagedListState<T>();
}

class PagedListState<T> extends State<PagedList<T>> {
  final _items = <T>[];
  final _scroll = ScrollController();
  late final _search = TextEditingController(text: widget.initialSearch);
  Timer? _debounce;
  int _page = 0;
  bool _hasMore = true;
  bool _loading = false;
  Object? _error;
  int _total = 0;
  int _generation = 0;
  Json _raw = const {};

  List<T> get items => _items;
  String get search => _search.text.trim();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 400) _loadMore();
    });
    reload();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  /// Recharge depuis la première page (après création, modification, changement de filtre…).
  Future<void> reload() async {
    _generation++;
    setState(() {
      _items.clear();
      _page = 0;
      _hasMore = true;
      _error = null;
      _loading = false;
    });
    await _loadMore();
  }

  void setSearch(String value) {
    _search.text = value;
    reload();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    final gen = _generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await widget.fetch(_page + 1, _search.text.trim());
      if (!mounted || gen != _generation) return;
      setState(() {
        _items.addAll(res.items);
        _page = res.currentPage;
        _hasMore = res.hasMore && res.items.isNotEmpty;
        _total = res.total;
        if (res.currentPage <= 1) _raw = res.raw;
      });
    } catch (e) {
      if (mounted && gen == _generation) setState(() => _error = e);
    } finally {
      if (mounted && gen == _generation) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      if (widget.showSearch)
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: tr(widget.searchHint),
              prefixIcon: const Icon(Icons.search),
              fillColor: AppColors.surface,
              isDense: true,
              suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
                if (_search.text.isNotEmpty) IconButton(icon: const Icon(Icons.close), onPressed: () => setSearch('')),
                if (widget.onScan != null)
                  IconButton(
                    icon: const Icon(Icons.qr_code_scanner, color: AppColors.primary),
                    tooltip: tr('Scanner'),
                    onPressed: widget.onScan,
                  ),
              ]),
            ),
            onChanged: (_) {
              setState(() {});
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 400), reload);
            },
            onSubmitted: (_) {
              _debounce?.cancel();
              reload();
            },
          ),
        ),
      if (widget.filters != null)
        Container(
          color: Colors.white,
          width: double.infinity,
          padding: const EdgeInsets.only(bottom: 10),
          child: widget.filters,
        ),
      if (widget.showSearch || widget.filters != null) const Divider(height: 1),
      Expanded(child: _body()),
    ]);
  }

  Widget? _header(BuildContext context) {
    final built = widget.headerBuilder?.call(context, _raw);
    if (built == null) return widget.header;
    if (widget.header == null) return built;
    return Column(children: [widget.header!, built]);
  }

  Widget _body() {
    final header = _header(context);
    if (_items.isEmpty && _loading) {
      return Column(children: [
        if (header != null && _raw.isNotEmpty) header,
        const Expanded(child: SkeletonList()),
      ]);
    }
    if (_items.isEmpty && _error != null) {
      return RefreshIndicator(
        onRefresh: reload,
        child: ListView(children: [SizedBox(height: 420, child: ErrorState(error: _error!, onRetry: reload))]),
      );
    }
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: reload,
        child: ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
          ?header,
          SizedBox(
            height: 360,
            child: EmptyState(
              icon: widget.emptyIcon,
              title: _search.text.isEmpty ? tr(widget.emptyTitle) : tr('Aucun résultat'),
              message: _search.text.isEmpty
                  ? (widget.emptyMessage == null ? null : tr(widget.emptyMessage!))
                  : tr('Aucun élément ne correspond à « {q} ».', {'q': _search.text}),
            ),
          ),
        ]),
      );
    }
    final extra = header != null ? 1 : 0;
    return RefreshIndicator(
      onRefresh: reload,
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: widget.padding,
        itemCount: _items.length + extra + 1,
        itemBuilder: (context, i) {
          if (header != null && i == 0) return header;
          final idx = i - extra;
          if (idx == _items.length) {
            if (_error != null) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: TextButton.icon(onPressed: _loadMore, icon: const Icon(Icons.refresh), label: Text(tr('Charger la suite'))),
                ),
              );
            }
            if (_hasMore) {
              return const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()));
            }
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(_total > 1 ? tr('{n} éléments', {'n': _total}) : tr('{n} élément', {'n': _total}), style: const TextStyle(color: AppColors.muted, fontSize: 12)),
              ),
            );
          }
          final tile = widget.itemBuilder(context, _items[idx], reload);
          if (!widget.separated) return tile;
          return DecoratedBox(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: tile,
          );
        },
      ),
    );
  }
}

/// Rangée de puces de filtre défilable.
class FilterChips<V> extends StatelessWidget {
  const FilterChips({super.key, required this.options, required this.value, required this.onChanged, this.leading});

  final List<(V?, String)> options;
  final V? value;
  final ValueChanged<V?> onChanged;
  final List<Widget>? leading;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          ...?leading,
          for (final (v, label) in options)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: ChoiceChip(
                label: Text(tr(label)),
                selected: v == value,
                showCheckmark: false,
                selectedColor: AppColors.primary.withValues(alpha: 0.12),
                side: BorderSide(color: v == value ? AppColors.primary : AppColors.border),
                labelStyle: TextStyle(
                  color: v == value ? AppColors.primary : AppColors.ink,
                  fontWeight: v == value ? FontWeight.w700 : FontWeight.w500,
                ),
                onSelected: (_) => onChanged(v),
              ),
            ),
        ],
      ),
    );
  }
}

// Caddie book — VSP Mobile App
//
// Vietnamese courses require a caddie, and golfers ask for good ones back by
// number at the desk — every photographed card this project holds has caddie
// numbers written in the corner, next to a "Caddies Rating" box the clubs
// themselves print. This is that memory, kept: private per golfer, a notebook
// rather than a review site.

import 'package:flutter/material.dart';
import 'package:mobile_theme/mobile_theme.dart';

import 'package:vsp_mobile/core/network/api_client.dart';
import 'package:vsp_mobile/l10n/app_localizations.dart';

class CaddieNote {
  const CaddieNote({
    required this.caddieNumber,
    this.name,
    this.rating,
    this.note,
  });

  final String caddieNumber;
  final String? name;
  final int? rating;
  final String? note;

  factory CaddieNote.fromJson(Map<String, dynamic> json) => CaddieNote(
    caddieNumber: json['caddieNumber'] as String,
    name: json['name'] as String?,
    rating: json['rating'] as int?,
    note: json['note'] as String?,
  );
}

class CaddieApi {
  CaddieApi({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<List<CaddieNote>> list(int facilityId) async {
    final json = await _apiClient.get('/facilities/$facilityId/caddies');
    return (json as List<dynamic>)
        .map((e) => CaddieNote.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> save(int facilityId, CaddieNote note) => _apiClient.put(
        '/facilities/$facilityId/caddies/${Uri.encodeComponent(note.caddieNumber)}',
        body: {
          if (note.name?.isNotEmpty == true) 'name': note.name,
          if (note.rating != null) 'rating': note.rating,
          if (note.note?.isNotEmpty == true) 'note': note.note,
        },
      );

  Future<void> forget(int facilityId, String caddieNumber) => _apiClient
      .delete('/facilities/$facilityId/caddies/${Uri.encodeComponent(caddieNumber)}');
}

class CaddieBookScreen extends StatefulWidget {
  const CaddieBookScreen({
    super.key,
    required this.facilityId,
    required this.facilityName,
    this.api,
  });

  final int facilityId;
  final String facilityName;
  final CaddieApi? api;

  @override
  State<CaddieBookScreen> createState() => _CaddieBookScreenState();
}

class _CaddieBookScreenState extends State<CaddieBookScreen> {
  late final CaddieApi _api = widget.api ?? CaddieApi();
  List<CaddieNote> _notes = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final notes = await _api.list(widget.facilityId);
      if (!mounted) return;
      setState(() {
        _notes = notes;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _edit([CaddieNote? existing]) async {
    final saved = await showDialog<CaddieNote>(
      context: context,
      builder: (_) => _CaddieDialog(existing: existing),
    );
    if (saved == null) return;
    await _api.save(widget.facilityId, saved);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('${l10n.caddieBookTitle} — ${widget.facilityName}'),
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('caddie_add'),
        onPressed: () => _edit(),
        child: const Icon(Icons.person_add_alt),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notes.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(VspSpacing.lg),
                    child: Text(
                      l10n.caddieBookEmpty,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(VspSpacing.md),
                  itemCount: _notes.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final n = _notes[i];
                    return Dismissible(
                      key: Key('caddie_${n.caddieNumber}'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        color: Theme.of(context).colorScheme.error,
                        padding: const EdgeInsets.only(right: VspSpacing.md),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (_) async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (dctx) => AlertDialog(
                            content: Text(
                              l10n.caddieDeleteConfirm(n.caddieNumber),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(dctx, false),
                                child: Text(l10n.commonCancel),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(dctx, true),
                                child: Text(l10n.commonDelete),
                              ),
                            ],
                          ),
                        );
                        if (ok == true) {
                          await _api.forget(widget.facilityId, n.caddieNumber);
                        }
                        return ok ?? false;
                      },
                      onDismissed: (_) =>
                          setState(() => _notes = List.of(_notes)..removeAt(i)),
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          child: Text(
                            n.caddieNumber.length > 3
                                ? n.caddieNumber.substring(0, 3)
                                : n.caddieNumber,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        title: Text(
                          n.name?.isNotEmpty == true
                              ? '${n.caddieNumber} — ${n.name}'
                              : n.caddieNumber,
                        ),
                        subtitle: n.note?.isNotEmpty == true
                            ? Text(n.note!,
                                maxLines: 2, overflow: TextOverflow.ellipsis)
                            : null,
                        trailing: n.rating == null
                            ? null
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (var s = 1; s <= 5; s++)
                                    Icon(
                                      s <= n.rating!
                                          ? Icons.star
                                          : Icons.star_border,
                                      size: 16,
                                      color: Theme.of(context).colorScheme.secondary,
                                    ),
                                ],
                              ),
                        onTap: () => _edit(n),
                      ),
                    );
                  },
                ),
    );
  }
}

class _CaddieDialog extends StatefulWidget {
  const _CaddieDialog({this.existing});

  final CaddieNote? existing;

  @override
  State<_CaddieDialog> createState() => _CaddieDialogState();
}

class _CaddieDialogState extends State<_CaddieDialog> {
  late final _number =
      TextEditingController(text: widget.existing?.caddieNumber ?? '');
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _note = TextEditingController(text: widget.existing?.note ?? '');
  late int _rating = widget.existing?.rating ?? 0;

  @override
  void dispose() {
    _number.dispose();
    _name.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.caddieBookTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('caddie_number_field'),
            controller: _number,
            enabled: widget.existing == null,
            decoration: InputDecoration(labelText: l10n.caddieNumber),
          ),
          TextField(
            controller: _name,
            decoration: InputDecoration(labelText: l10n.caddieName),
          ),
          const SizedBox(height: VspSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var s = 1; s <= 5; s++)
                IconButton(
                  key: Key('caddie_star_$s'),
                  onPressed: () => setState(() => _rating = s),
                  icon: Icon(
                    s <= _rating ? Icons.star : Icons.star_border,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
            ],
          ),
          TextField(
            controller: _note,
            maxLines: 2,
            decoration: InputDecoration(labelText: l10n.caddieNote),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const Key('caddie_save'),
          onPressed: _number.text.trim().isEmpty && widget.existing == null
              ? null
              : () => Navigator.pop(
                    context,
                    CaddieNote(
                      caddieNumber: widget.existing?.caddieNumber ??
                          _number.text.trim(),
                      name: _name.text.trim(),
                      rating: _rating == 0 ? null : _rating,
                      note: _note.text.trim(),
                    ),
                  ),
          child: Text(l10n.caddieSave),
        ),
      ],
    );
  }
}

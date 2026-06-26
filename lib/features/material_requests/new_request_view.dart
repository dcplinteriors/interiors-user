import 'package:dcpl_shared/dcpl_shared.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';

import '../../app/routes/app_routes.dart';
import '../../l10n/l10n.dart';
import '../work_orders/data/work_order_repository.dart';
import 'data/upload_service.dart';
import 'material_requests_controller.dart';

/// Full-screen multi-item submit form. Entered from a work order (workOrderId locked) or
/// globally from "New request" (work-order picker).
class NewRequestView extends StatefulWidget {
  const NewRequestView({super.key, this.workOrderId});

  final String? workOrderId;

  @override
  State<NewRequestView> createState() => _NewRequestViewState();
}

class _NewRequestViewState extends State<NewRequestView> {
  final _formKey = GlobalKey<FormState>();
  final List<_ItemDraft> _items = [_ItemDraft()];
  String? _workOrderId;
  bool _submitting = false;
  String? _formError;

  MaterialRequestsController get _requests =>
      Get.find<MaterialRequestsController>();

  bool get _locked => widget.workOrderId != null;

  /// The supervisor's active (assignable) work orders — loaded here directly so the Work Orders
  /// tab's project filter can't hide options in the picker. `null` while loading.
  List<WorkOrder>? _activeWorkOrders;
  String? _loadError;

  /// True while any item still has an attachment uploading — submit waits for it.
  bool get _uploading => _items.any((d) => d.busy);

  /// True if any attachment failed to upload — submit is blocked until the user retries or
  /// removes it, so a failed attachment is never silently dropped.
  bool get _hasFailedUploads => _items.any((d) => d.hasFailedUpload);

  @override
  void initState() {
    super.initState();
    _workOrderId = widget.workOrderId;
    _loadWorkOrders();
  }

  Future<void> _loadWorkOrders() async {
    try {
      final all = await Get.find<WorkOrderRepository>().listAll();
      if (!mounted) return;
      setState(
        () => _activeWorkOrders = all
            .where((w) => w.status == WorkOrderStatus.active)
            .toList(),
      );
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _activeWorkOrders = const [];
          _loadError = e.message;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _activeWorkOrders = const []);
    }
  }

  @override
  void dispose() {
    for (final d in _items) {
      d.dispose();
    }
    super.dispose();
  }

  bool get _dirty =>
      _items.any(
        (d) =>
            d.particular.text.isNotEmpty ||
            d.make.text.isNotEmpty ||
            d.qty.text.isNotEmpty ||
            d.photos.isNotEmpty ||
            d.audio != null,
      ) ||
      (!_locked && _workOrderId != null);

  Future<void> _close() async {
    final l10n = AppLocalizations.of(context);
    if (!_dirty) {
      context.pop();
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.discardTitle),
        content: Text(l10n.discardBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.keepEditing),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.discard),
          ),
        ],
      ),
    );
    if (discard == true && mounted) context.pop();
  }

  void _addItem() => setState(() {
    // Collapse the items already entered so the new one is the focus.
    for (final d in _items) {
      d.expanded = false;
    }
    _items.add(_ItemDraft());
  });

  void _removeItem(int i) => setState(() => _items.removeAt(i).dispose());

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    if (!_formKey.currentState!.validate()) {
      // Expand every item so the offending fields (which may be in a collapsed item) show.
      setState(() {
        for (final d in _items) {
          d.expanded = true;
        }
        _formError = l10n.fixFields;
      });
      return;
    }
    // With no assignable work orders there's no picker (so no validator) — guard the null.
    if (_workOrderId == null) {
      setState(() => _formError = l10n.noWorkOrdersAssigned);
      return;
    }
    setState(() {
      _submitting = true;
      _formError = null;
    });
    try {
      final created = await _requests.submit(
        _workOrderId!,
        _items
            .map(
              (d) => MaterialRequestItemInput(
                particular: d.particular.text.trim(),
                make: d.make.text.trim(),
                size: d.size.text.trim(),
                quantity: num.parse(d.qty.text.trim()),
                unit: d.unit!,
                attachments: d.attachments,
              ),
            )
            .toList(),
      );
      if (!mounted) return;
      final message = l10n.requestSubmitted(created.length);
      context.go(AppRoutes.requests);
      showAppSnackbar(message);
    } on ApiException catch (e) {
      if (mounted) setState(() => _formError = l10n.couldntSubmit(e.message));
    } catch (_) {
      if (mounted) {
        setState(() => _formError = 'Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final submitDisabled = _submitting || _uploading || _hasFailedUploads;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _submitting ? null : _close,
        ),
        title: Text(l10n.newRequestTitle),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: context.pagePadding,
              children: [
                _WorkOrderSection(
                  locked: _locked,
                  lockedWorkOrderId: widget.workOrderId,
                  workOrders: _activeWorkOrders,
                  loadError: _loadError,
                  selectedId: _workOrderId,
                  onChanged: (v) => setState(() => _workOrderId = v),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Text(
                      l10n.itemsLabel,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.countItems(_items.length),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < _items.length; i++) ...[
                  _ItemCard(
                    // Identity key so per-row State (recorder, in-flight uploads) follows its
                    // draft when an earlier item is removed.
                    key: ObjectKey(_items[i]),
                    index: i,
                    draft: _items[i],
                    canDelete: _items.length > 1,
                    expanded: _items[i].expanded,
                    onToggleExpand: () => setState(
                      () => _items[i].expanded = !_items[i].expanded,
                    ),
                    onDelete: () => _removeItem(i),
                    onUnitChanged: (u) => setState(() => _items[i].unit = u),
                    onChanged: () {
                      if (mounted) setState(() {});
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                OutlinedButton.icon(
                  onPressed: _addItem,
                  icon: const Icon(Icons.add),
                  label: Text(l10n.addItem),
                ),
                const SizedBox(height: 24),
                if (_formError != null) ...[
                  ErrorStrip(_formError!),
                  const SizedBox(height: 16),
                ],
                if (_hasFailedUploads) ...[
                  ErrorStrip(l10n.attachmentsFailedFix),
                  const SizedBox(height: 16),
                ],
                GradientButton(
                  expand: true,
                  icon: Icons.check_rounded,
                  loading: _submitting,
                  onPressed: submitDisabled ? null : _submit,
                  label: l10n.submitRequest,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The work-order picker at the top of the form. When [locked] (opened from a specific work
/// order) it shows that order read-only; otherwise it's a dropdown over the active [workOrders]
/// ([workOrders] == null means still loading; empty + [loadError] means the load failed).
class _WorkOrderSection extends StatelessWidget {
  const _WorkOrderSection({
    required this.locked,
    required this.lockedWorkOrderId,
    required this.workOrders,
    required this.loadError,
    required this.selectedId,
    required this.onChanged,
  });

  final bool locked;
  final String? lockedWorkOrderId;
  final List<WorkOrder>? workOrders;
  final String? loadError;
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  WorkOrder? _find(String? id) =>
      id == null ? null : workOrders?.firstWhereOrNull((w) => w.id == id);

  /// "Project · Client" context line under the selected work order.
  String _woContext(WorkOrder w) => [
    w.projectName,
    w.clientName,
  ].where((s) => s != null && s.isNotEmpty).join(' · ');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final loading = workOrders == null;
    if (locked) {
      final wo = _find(lockedWorkOrderId);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InputDecorator(
            decoration: InputDecoration(labelText: l10n.workOrderLabel),
            child: Text(wo?.name ?? (loading ? l10n.loadingWorkOrders : '…')),
          ),
          if (wo != null) ...[
            const SizedBox(height: 6),
            Text(_woContext(wo), style: TextStyle(color: muted)),
          ],
        ],
      );
    }
    final options = workOrders ?? const <WorkOrder>[];
    // Distinguish loading / load-failed / genuinely-none from a ready picker.
    if (options.isEmpty) {
      final scheme = Theme.of(context).colorScheme;
      final (String text, Color color) = loading
          ? (l10n.loadingWorkOrders, muted)
          : loadError != null
          ? (l10n.couldntLoadWorkOrders, scheme.error)
          : (l10n.noWorkOrdersAssigned, muted);
      return InputDecorator(
        decoration: InputDecoration(labelText: l10n.workOrderLabel),
        child: Text(text, style: TextStyle(color: color)),
      );
    }
    final selected = _find(selectedId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue: selectedId,
          decoration: InputDecoration(labelText: l10n.workOrderLabel),
          hint: Text(l10n.selectWorkOrder),
          items: [
            for (final w in options)
              DropdownMenuItem(value: w.id, child: Text(w.name)),
          ],
          onChanged: onChanged,
          validator: (v) => v == null ? 'Select a work order.' : null,
        ),
        if (selected != null) ...[
          const SizedBox(height: 6),
          Text(_woContext(selected), style: TextStyle(color: muted)),
        ],
      ],
    );
  }
}

/// A photo attachment in progress: its preview bytes plus its upload outcome.
/// `path` is set when the upload completes; `failed` flags a retryable failure.
class _PhotoUpload {
  _PhotoUpload({required this.bytes, required this.contentType});
  final Uint8List bytes;
  final String contentType;
  String? path;
  bool failed = false;

  bool get uploading => path == null && !failed;
}

/// The single audio note in progress. Keeps the bytes so a failed upload can be retried
/// without re-recording.
class _AudioUpload {
  _AudioUpload({required this.bytes, required this.contentType});
  final Uint8List bytes;
  final String contentType;
  String? path;
  bool failed = false;

  bool get uploading => path == null && !failed;
}

/// Mutable form state for one item row.
class _ItemDraft {
  final particular = TextEditingController();
  final make = TextEditingController();
  final size = TextEditingController();
  final qty = TextEditingController();
  String? unit;

  /// Whether this item's form body is expanded. Adding a new item collapses the earlier ones
  /// so the form stays focused on what's being filled in.
  bool expanded = true;

  final List<_PhotoUpload> photos = [];
  _AudioUpload? audio;

  /// True while any attachment on this item is still uploading.
  bool get busy =>
      photos.any((p) => p.uploading) || (audio?.uploading ?? false);

  /// True if any attachment on this item failed to upload.
  bool get hasFailedUpload =>
      photos.any((p) => p.failed) || (audio?.failed ?? false);

  /// The successfully-uploaded object paths (failed/in-flight uploads are excluded).
  Attachments get attachments => Attachments(
    photos: [
      for (final p in photos)
        if (p.path != null) p.path!,
    ],
    audio: audio?.path,
  );

  void dispose() {
    particular.dispose();
    make.dispose();
    size.dispose();
    qty.dispose();
  }
}

const int _maxPhotos = 3;

class _ItemCard extends StatefulWidget {
  const _ItemCard({
    super.key,
    required this.index,
    required this.draft,
    required this.canDelete,
    required this.expanded,
    required this.onToggleExpand,
    required this.onDelete,
    required this.onUnitChanged,
    required this.onChanged,
  });

  final int index;
  final _ItemDraft draft;
  final bool canDelete;

  /// Whether the item's form body is shown. Collapsed items show a summary; the body stays
  /// mounted (offstage) so it still validates on submit.
  final bool expanded;
  final VoidCallback onToggleExpand;
  final VoidCallback onDelete;
  final ValueChanged<String?> onUnitChanged;

  /// Asks the parent to rebuild so submit-enabled state re-evaluates as uploads start/finish.
  final VoidCallback onChanged;

  @override
  State<_ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<_ItemCard> {
  late final UploadService _uploads = Get.find();
  final ImagePicker _picker = ImagePicker();
  final AudioRecorder _recorder = AudioRecorder();
  bool _recording = false;

  _ItemDraft get _draft => widget.draft;

  @override
  void dispose() {
    // Release the mic before disposing if a capture is still running.
    if (_recording) _recorder.cancel();
    _recorder.dispose();
    super.dispose();
  }

  // ---- Photos ---------------------------------------------------------------

  Future<void> _addPhoto(ImageSource source) async {
    final l10n = AppLocalizations.of(context);
    final _PhotoUpload up;
    try {
      final file = await _picker.pickImage(source: source, maxWidth: 2400);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      up = _PhotoUpload(
        bytes: bytes,
        contentType: photoContentType(
          bytes,
          mimeType: file.mimeType,
          fileName: file.name,
        ),
      );
    } catch (_) {
      showAppSnackbar(l10n.photoPickFailed);
      return;
    }
    _draft.photos.add(up);
    widget.onChanged();
    await _runPhotoUpload(up);
  }

  Future<void> _runPhotoUpload(_PhotoUpload up) async {
    up
      ..failed = false
      ..path = null;
    widget.onChanged();
    try {
      up.path = await _uploads.upload(
        kind: AttachmentKind.photo,
        bytes: up.bytes,
        contentType: up.contentType,
      );
    } catch (_) {
      up.failed = true;
    }
    widget.onChanged();
  }

  void _removePhoto(_PhotoUpload up) {
    _draft.photos.remove(up);
    widget.onChanged();
  }

  // ---- Audio ----------------------------------------------------------------

  Future<void> _toggleRecording() async {
    final l10n = AppLocalizations.of(context);
    if (_recording) {
      String? url;
      try {
        url = await _recorder.stop();
      } catch (_) {
        showAppSnackbar(l10n.recordingFailed);
      } finally {
        if (mounted) setState(() => _recording = false);
      }
      if (url == null) {
        showAppSnackbar(l10n.recordingFailed); // no clip captured
        return;
      }
      await _startAudioUpload(url);
      return;
    }
    try {
      if (!await _recorder.hasPermission()) {
        showAppSnackbar(l10n.micPermissionNeeded);
        return;
      }
      // RecordConfig() defaults to AAC, which Chrome/Firefox MediaRecorder can't
      // encode on web — recording captures nothing and stop() returns null. Use
      // Opus (WebM) on web; AAC stays the native default. Path is ignored on web
      // (records to an in-memory blob); native uses it later.
      const config = kIsWeb
          ? RecordConfig(encoder: AudioEncoder.opus)
          : RecordConfig();
      await _recorder.start(config, path: '');
      if (mounted) setState(() => _recording = true);
    } catch (_) {
      showAppSnackbar(l10n.recordingFailed);
    }
  }

  Future<void> _startAudioUpload(String url) async {
    final _AudioUpload up;
    try {
      final recording = await _uploads.readRecording(url);
      up = _AudioUpload(
        bytes: recording.bytes,
        contentType: recording.contentType,
      );
    } catch (_) {
      // A failed read used to throw silently — no chip appeared and the clip was
      // lost. Surface it instead.
      if (mounted) showAppSnackbar(AppLocalizations.of(context).recordingFailed);
      return;
    }
    _draft.audio = up;
    widget.onChanged();
    await _runAudioUpload(up);
  }

  Future<void> _runAudioUpload(_AudioUpload up) async {
    up
      ..failed = false
      ..path = null;
    widget.onChanged();
    try {
      up.path = await _uploads.upload(
        kind: AttachmentKind.audio,
        bytes: up.bytes,
        contentType: up.contentType,
      );
    } catch (_) {
      up.failed = true;
    }
    widget.onChanged();
  }

  void _removeAudio() {
    _draft.audio = null;
    widget.onChanged();
  }

  // ---- Build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ItemHeader(
            index: widget.index,
            expanded: widget.expanded,
            summary: widget.expanded ? '' : _summary(),
            canDelete: widget.canDelete,
            onToggle: widget.onToggleExpand,
            onDelete: widget.onDelete,
          ),
          // Kept mounted (not removed) when collapsed so it still validates.
          Offstage(
            offstage: !widget.expanded,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _draft.particular,
                    decoration: InputDecoration(
                      labelText: l10n.particularLabel,
                      hintText: l10n.particularHint,
                    ),
                    textInputAction: TextInputAction.next,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Enter the item name.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _draft.make,
                    decoration: InputDecoration(
                      labelText: l10n.makeLabel,
                      hintText: l10n.makeHint,
                    ),
                    textInputAction: TextInputAction.next,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Enter the make or spec.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _draft.size,
                    decoration: InputDecoration(
                      labelText: l10n.sizeLabel,
                      hintText: l10n.sizeHint,
                    ),
                    textInputAction: TextInputAction.next,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Enter the size.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: _draft.qty,
                          decoration: InputDecoration(labelText: l10n.qtyLabel),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.]'),
                            ),
                          ],
                          validator: _validateQty,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          initialValue: _draft.unit,
                          decoration: InputDecoration(
                            labelText: l10n.unitLabel,
                          ),
                          items: [
                            for (final u in MaterialUnits.all)
                              DropdownMenuItem(value: u, child: Text(u)),
                          ],
                          onChanged: widget.onUnitChanged,
                          validator: (v) => v == null ? 'Select a unit.' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _AttachmentsSection(
                    photos: _draft.photos,
                    recording: _recording,
                    audio: _draft.audio,
                    onAddPhoto: _addPhoto,
                    onRemovePhoto: _removePhoto,
                    onRetryPhoto: _runPhotoUpload,
                    onToggleRecording: _toggleRecording,
                    onRemoveAudio: _removeAudio,
                    onRetryAudio: _runAudioUpload,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// A compact "particular · qty unit" line for the collapsed header.
  String _summary() {
    final name = _draft.particular.text.trim();
    final qty = _draft.qty.text.trim();
    final unit = _draft.unit;
    return [
      if (name.isNotEmpty) name,
      if (qty.isNotEmpty) unit != null ? '$qty $unit' : qty,
    ].join(' · ');
  }

  String? _validateQty(String? v) {
    final text = v?.trim() ?? '';
    if (text.isEmpty) return 'Enter a quantity.';
    final n = num.tryParse(text);
    if (n == null) return 'Enter a valid number.';
    if (n <= 0) return 'Quantity must be greater than 0.';
    return null;
  }
}

/// One item row's tappable header: number, collapsed summary, delete, expand chevron.
class _ItemHeader extends StatelessWidget {
  const _ItemHeader({
    required this.index,
    required this.expanded,
    required this.summary,
    required this.canDelete,
    required this.onToggle,
    required this.onDelete,
  });

  final int index;
  final bool expanded;
  final String summary;
  final bool canDelete;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    // GestureDetector (no ink/hover) + opaque so the whole heading — including the
    // card's top/side padding, which now lives inside this tap target — toggles.
    return GestureDetector(
      onTap: onToggle,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.itemN(index + 1),
                    style: theme.textTheme.titleSmall,
                  ),
                  if (summary.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: l10n.removeItem,
              onPressed: canDelete ? onDelete : null,
              icon: const Icon(Icons.delete_outline),
            ),
            Icon(
              expanded ? Icons.expand_less : Icons.expand_more,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// One item's attachments: up to 3 photos + a single voice note, each with its upload state.
class _AttachmentsSection extends StatelessWidget {
  const _AttachmentsSection({
    required this.photos,
    required this.recording,
    required this.audio,
    required this.onAddPhoto,
    required this.onRemovePhoto,
    required this.onRetryPhoto,
    required this.onToggleRecording,
    required this.onRemoveAudio,
    required this.onRetryAudio,
  });

  final List<_PhotoUpload> photos;
  final bool recording;
  final _AudioUpload? audio;
  final ValueChanged<ImageSource> onAddPhoto;
  final ValueChanged<_PhotoUpload> onRemovePhoto;
  final ValueChanged<_PhotoUpload> onRetryPhoto;
  final VoidCallback onToggleRecording;
  final VoidCallback onRemoveAudio;
  final ValueChanged<_AudioUpload> onRetryAudio;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.attachmentsLabel,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(color: muted),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in photos)
              _PhotoTile(
                upload: p,
                onRemove: () => onRemovePhoto(p),
                onRetry: () => onRetryPhoto(p),
              ),
            if (photos.length < _maxPhotos)
              _AddPhotoTile(onSelected: onAddPhoto),
          ],
        ),
        const SizedBox(height: 12),
        _AudioControl(
          recording: recording,
          audio: audio,
          onToggle: onToggleRecording,
          onRemove: onRemoveAudio,
          onRetry: onRetryAudio,
        ),
      ],
    );
  }
}

/// The "add photo" tile — a camera/gallery popup over a square placeholder.
class _AddPhotoTile extends StatelessWidget {
  const _AddPhotoTile({required this.onSelected});

  final ValueChanged<ImageSource> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return PopupMenuButton<ImageSource>(
      tooltip: l10n.addPhoto,
      onSelected: onSelected,
      itemBuilder: (_) => [
        PopupMenuItem(
          value: ImageSource.camera,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.photo_camera_outlined),
            title: Text(l10n.takePhoto),
          ),
        ),
        PopupMenuItem(
          value: ImageSource.gallery,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.folder_outlined),
            title: Text(l10n.chooseFromFiles),
          ),
        ),
      ],
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_a_photo_outlined,
              color: scheme.onSurfaceVariant,
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.addPhoto,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// The voice-note control: record / stop, or the recorded note's chip.
class _AudioControl extends StatelessWidget {
  const _AudioControl({
    required this.recording,
    required this.audio,
    required this.onToggle,
    required this.onRemove,
    required this.onRetry,
  });

  final bool recording;
  final _AudioUpload? audio;
  final VoidCallback onToggle;
  final VoidCallback onRemove;
  final ValueChanged<_AudioUpload> onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    if (recording) {
      return OutlinedButton.icon(
        onPressed: onToggle,
        icon: Icon(Icons.stop_circle_outlined, color: scheme.error),
        label: Text(l10n.recordingInProgress),
        style: OutlinedButton.styleFrom(foregroundColor: scheme.error),
      );
    }
    final a = audio;
    if (a == null) {
      return OutlinedButton.icon(
        onPressed: onToggle,
        icon: const Icon(Icons.mic_none),
        label: Text(l10n.recordVoiceNote),
      );
    }
    return _AudioChip(upload: a, onRemove: onRemove, onRetry: () => onRetry(a));
  }
}

/// An 80×80 photo thumbnail with an upload-state overlay (spinner / tap-to-retry) and a remove
/// button.
class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.upload,
    required this.onRemove,
    required this.onRetry,
  });

  final _PhotoUpload upload;
  final VoidCallback onRemove;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 80,
      height: 80,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(upload.bytes, fit: BoxFit.cover),
          ),
          if (upload.uploading)
            Container(
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          if (upload.failed)
            InkWell(
              onTap: onRetry,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                decoration: BoxDecoration(
                  color: scheme.errorContainer.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.refresh, color: scheme.onErrorContainer),
              ),
            ),
          Positioned(
            top: -6,
            right: -6,
            child: IconButton(
              tooltip: AppLocalizations.of(context).removeAttachment,
              iconSize: 18,
              visualDensity: VisualDensity.compact,
              style: IconButton.styleFrom(
                backgroundColor: scheme.surface,
                foregroundColor: scheme.onSurface,
              ),
              onPressed: onRemove,
              icon: const Icon(Icons.close),
            ),
          ),
        ],
      ),
    );
  }
}

/// A pill showing the recorded voice note with its upload state + a remove button.
class _AudioChip extends StatelessWidget {
  const _AudioChip({
    required this.upload,
    required this.onRemove,
    required this.onRetry,
  });

  final _AudioUpload upload;
  final VoidCallback onRemove;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    Widget trailing;
    if (upload.uploading) {
      trailing = const SizedBox(
        height: 16,
        width: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else if (upload.failed) {
      trailing = InkWell(
        onTap: onRetry,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.refresh, size: 16, color: scheme.error),
            const SizedBox(width: 4),
            Text(l10n.uploadFailedRetry, style: TextStyle(color: scheme.error)),
          ],
        ),
      );
    } else {
      trailing = Icon(Icons.check_circle, size: 18, color: scheme.primary);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.mic, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(l10n.voiceNote),
          const SizedBox(width: 10),
          trailing,
          const SizedBox(width: 4),
          IconButton(
            tooltip: l10n.removeAttachment,
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            onPressed: onRemove,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

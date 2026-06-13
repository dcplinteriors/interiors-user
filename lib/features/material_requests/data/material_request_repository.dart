import 'package:dcpl_shared/dcpl_shared.dart';

/// One line item in a new material-request submission (the supervisor's input).
class NewRequestItem {
  const NewRequestItem({
    required this.particular,
    required this.make,
    required this.size,
    required this.quantity,
    required this.unit,
    this.attachments = const Attachments(),
  });

  final String particular;
  final String make;
  final String size;
  final num quantity;
  final String unit;

  /// Uploaded attachment object paths (photos + optional audio). Defaulted to none
  /// so existing callers/tests are unaffected.
  final Attachments attachments;

  Map<String, dynamic> toJson() => {
        'particular': particular,
        'make': make,
        'size': size,
        'quantity': quantity,
        'unit': unit,
        if (attachments.isNotEmpty) 'attachments': attachments.toJson(),
      };
}

/// One page of requests plus the cursor for the next page (null = last page).
typedef RequestPage = ({List<MaterialRequest> items, String? nextCursor});

abstract class MaterialRequestRepository {
  /// The supervisor's own requests (backend scopes `/material-requests` to the caller),
  /// cursor-paginated and optionally filtered by [status] (null = all) server-side.
  Future<RequestPage> list({String? status, String? cursor});

  /// Submits a multi-item request against one project; the backend returns one
  /// record per item (sharing a batchId), each with a generated Job number.
  Future<List<MaterialRequest>> submit({
    required String projectId,
    required List<NewRequestItem> items,
  });

  /// Cancels the supervisor's own request while it is still `requested`.
  Future<MaterialRequest> cancel(String id);
}

class ApiMaterialRequestRepository implements MaterialRequestRepository {
  ApiMaterialRequestRepository(this._api);

  final ApiClient _api;

  @override
  Future<RequestPage> list({String? status, String? cursor}) async {
    final data = await _api.get(
      '/material-requests',
      query: {'status': ?status, 'cursor': ?cursor},
    ) as Map<String, dynamic>;
    final items = (data['items'] as List)
        .map((e) => MaterialRequest.fromJson(e as Map<String, dynamic>))
        .toList();
    return (items: items, nextCursor: data['nextCursor'] as String?);
  }

  @override
  Future<List<MaterialRequest>> submit({
    required String projectId,
    required List<NewRequestItem> items,
  }) async {
    final data = await _api.post('/material-requests', body: {
      'projectId': projectId,
      'items': items.map((e) => e.toJson()).toList(),
    }) as List;
    return data.map((e) => MaterialRequest.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<MaterialRequest> cancel(String id) async {
    final data = await _api.post('/material-requests/$id/cancel');
    return MaterialRequest.fromJson(data as Map<String, dynamic>);
  }
}

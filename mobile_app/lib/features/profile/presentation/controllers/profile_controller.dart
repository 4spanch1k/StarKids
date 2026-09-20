import 'package:flutter/material.dart';

import '../../../../core/utils/result.dart';
import '../../../request_history/domain/request_history_item.dart';
import '../../../request_history/domain/request_history_repository.dart';
import '../../domain/profile_repository.dart';
import '../../domain/profile_update_payload.dart';
import '../../domain/user_profile.dart';

enum ProfileViewStatus { loading, error, empty, success }

enum ProfileRequestsStatus { loading, error, empty, success }

class ProfileController extends ChangeNotifier {
  ProfileController({
    required ProfileRepository profileRepository,
    required RequestHistoryRepository requestHistoryRepository,
  })  : _profileRepository = profileRepository,
        _requestHistoryRepository = requestHistoryRepository;

  final ProfileRepository _profileRepository;
  final RequestHistoryRepository _requestHistoryRepository;

  ProfileViewStatus _status = ProfileViewStatus.loading;
  UserProfile? _profile;
  String? _errorMessage;
  bool _isSaving = false;
  bool _isUploadingAvatar = false;

  String _firstNameDraft = '';
  String _lastNameDraft = '';
  String _emailDraft = '';

  ProfileRequestsStatus _requestsStatus = ProfileRequestsStatus.loading;
  List<RequestHistoryItem> _previewRequests = const [];
  int _totalRequests = 0;
  String? _requestsErrorMessage;
  int _loadGeneration = 0;
  int _requestPreviewGeneration = 0;
  bool _preserveHydratedProfileForNextLoad = false;

  ProfileViewStatus get status => _status;
  UserProfile? get profile => _profile;
  String? get errorMessage => _errorMessage;
  bool get isSaving => _isSaving;
  bool get isUploadingAvatar => _isUploadingAvatar;

  String get firstNameDraft => _firstNameDraft;
  String get lastNameDraft => _lastNameDraft;
  String get emailDraft => _emailDraft;

  ProfileRequestsStatus get requestsStatus => _requestsStatus;
  List<RequestHistoryItem> get previewRequests => _previewRequests;
  int get totalRequests => _totalRequests;
  String? get requestsErrorMessage => _requestsErrorMessage;

  /// Hydrates the shared profile state from the atomic onboarding response.
  ///
  /// The profile page may be opened immediately after onboarding completes,
  /// before its normal network refresh finishes. Applying the authoritative
  /// response here avoids showing the previous/empty draft in that window.
  void hydrate(UserProfile profile) {
    _loadGeneration++;
    _preserveHydratedProfileForNextLoad = true;
    _profile = profile;
    _applyProfileToDrafts(profile);
    _status = ProfileViewStatus.success;
    _errorMessage = null;
    _isSaving = false;
    _isUploadingAvatar = false;
    notifyListeners();
  }

  /// Clears all account-scoped state when the authenticated identity changes.
  ///
  /// Incrementing both generations makes responses from the previous account
  /// harmless even when their requests are still in flight.
  void resetForAccountChange() {
    _loadGeneration++;
    _requestPreviewGeneration++;
    _preserveHydratedProfileForNextLoad = false;
    _profile = null;
    _firstNameDraft = '';
    _lastNameDraft = '';
    _emailDraft = '';
    _status = ProfileViewStatus.loading;
    _errorMessage = null;
    _isSaving = false;
    _isUploadingAvatar = false;
    _previewRequests = const [];
    _totalRequests = 0;
    _requestsStatus = ProfileRequestsStatus.loading;
    _requestsErrorMessage = null;
    notifyListeners();
  }

  String? get firstNameError {
    final name = _firstNameDraft.trim();
    if (name.isEmpty) return null;
    if (name.length > 50) return 'Не более 50 символов.';
    return null;
  }

  String? get lastNameError {
    final name = _lastNameDraft.trim();
    if (name.isEmpty) return null;
    if (name.length > 50) return 'Не более 50 символов.';
    return null;
  }

  String? get emailError {
    final e = _emailDraft.trim();
    if (e.isEmpty) return null;
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(e)) {
      return 'Введите корректный email.';
    }
    return null;
  }

  bool get _hasValidationErrors =>
      firstNameError != null || lastNameError != null || emailError != null;

  bool get hasChanges {
    if (_profile == null) return false;
    final p = _profile!;
    return _firstNameDraft.trim() != (p.firstName ?? '') ||
        _lastNameDraft.trim() != (p.lastName ?? '') ||
        _emailDraft.trim() != (p.email ?? '');
  }

  bool get canSave =>
      _status == ProfileViewStatus.success &&
      !_isSaving &&
      !_isUploadingAvatar &&
      hasChanges &&
      !_hasValidationErrors;

  Future<void> load() async {
    final generation = ++_loadGeneration;
    final preserveHydratedProfile = _preserveHydratedProfileForNextLoad;
    _preserveHydratedProfileForNextLoad = false;
    _requestPreviewGeneration++;
    _status = ProfileViewStatus.loading;
    _errorMessage = null;
    if (!preserveHydratedProfile) {
      _profile = null;
    }
    _isSaving = false;
    _isUploadingAvatar = false;
    _previewRequests = const [];
    _totalRequests = 0;
    _requestsStatus = ProfileRequestsStatus.loading;
    _requestsErrorMessage = null;
    notifyListeners();

    final result = await _profileRepository.fetchProfile();
    if (!_isCurrentLoad(generation)) return;

    if (result is Success<UserProfile>) {
      _profile = result.data;
      _applyProfileToDrafts(result.data);
      _status = ProfileViewStatus.success;
      notifyListeners();
      await loadRequestPreview(generation: generation);
    } else {
      _errorMessage = (result as Failure<UserProfile>).message;
      _status = ProfileViewStatus.error;
      notifyListeners();
    }
  }

  Future<void> loadRequestPreview({int? generation}) async {
    final loadGeneration = generation ?? _loadGeneration;
    final previewGeneration = ++_requestPreviewGeneration;
    _requestsStatus = ProfileRequestsStatus.loading;
    _requestsErrorMessage = null;
    notifyListeners();

    try {
      final result = await _requestHistoryRepository.fetchMyRequests();
      if (!_isCurrentLoad(loadGeneration) ||
          previewGeneration != _requestPreviewGeneration) {
        return;
      }

      if (result is RequestHistoryFetchSuccess) {
        _previewRequests = result.items.take(3).toList(growable: false);
        _totalRequests = result.total;
        _requestsStatus = _previewRequests.isEmpty
            ? ProfileRequestsStatus.empty
            : ProfileRequestsStatus.success;
      } else if (result is RequestHistoryFetchUnauthenticated) {
        _previewRequests = const [];
        _totalRequests = 0;
        _requestsStatus = ProfileRequestsStatus.empty;
      } else if (result is RequestHistoryFetchFailure) {
        _requestsErrorMessage = result.message;
        _requestsStatus = ProfileRequestsStatus.error;
      }
    } catch (_) {
      if (!_isCurrentLoad(loadGeneration) ||
          previewGeneration != _requestPreviewGeneration) {
        return;
      }
      _requestsErrorMessage = 'Не удалось загрузить заявки. Попробуйте снова.';
      _requestsStatus = ProfileRequestsStatus.error;
    }

    notifyListeners();
  }

  Future<void> saveChanges() async {
    if (!canSave) return;

    final generation = _loadGeneration;
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    final payload = ProfileUpdatePayload(
      firstName: _firstNameDraft.trim().isEmpty ? null : _firstNameDraft.trim(),
      lastName: _lastNameDraft.trim().isEmpty ? null : _lastNameDraft.trim(),
      email: _emailDraft.trim().isEmpty ? null : _emailDraft.trim(),
    );

    final result = await _profileRepository.updateProfile(payload);

    if (!_isCurrentLoad(generation)) return;

    _isSaving = false;

    if (result is Success<UserProfile>) {
      _profile = result.data;
      _applyProfileToDrafts(result.data);
      _status = ProfileViewStatus.success;
    } else {
      _errorMessage = (result as Failure<UserProfile>).message;
    }

    notifyListeners();
  }

  Future<void> uploadAvatar(
    List<int> bytes,
    String fileName,
    String contentType,
  ) async {
    final generation = _loadGeneration;
    _isUploadingAvatar = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _profileRepository.uploadAvatar(
      bytes: bytes,
      fileName: fileName,
      contentType: contentType,
    );

    if (!_isCurrentLoad(generation)) return;

    _isUploadingAvatar = false;

    if (result is Success<UserProfile>) {
      _profile = result.data;
    } else {
      _errorMessage = (result as Failure<UserProfile>).message;
    }

    notifyListeners();
  }

  Future<void> deleteAvatar() async {
    final generation = _loadGeneration;
    _isUploadingAvatar = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _profileRepository.deleteAvatar();

    if (!_isCurrentLoad(generation)) return;

    _isUploadingAvatar = false;

    if (result is Success<void>) {
      _profile = _profile?.copyWith(clearAvatarUrl: true);
    } else {
      _errorMessage = (result as Failure<void>).message;
    }

    notifyListeners();
  }

  void updateFirstName(String value) {
    _firstNameDraft = value;
    notifyListeners();
  }

  void updateLastName(String value) {
    _lastNameDraft = value;
    notifyListeners();
  }

  void updateEmail(String value) {
    _emailDraft = value;
    notifyListeners();
  }

  Future<void> retry() async {
    await load();
  }

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  void _applyProfileToDrafts(UserProfile profile) {
    // Every authoritative load must replace local drafts. This controller is
    // intentionally shared by the app, so a later authenticated account must
    // never inherit fields from the previous account.
    _firstNameDraft = profile.firstName ?? '';
    _lastNameDraft = profile.lastName ?? '';
    _emailDraft = profile.email ?? '';
  }

  bool _isCurrentLoad(int generation) => generation == _loadGeneration;
}

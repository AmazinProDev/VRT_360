export 'src/scene/scene_view.dart';
export 'src/view/amz_360_view.dart';
export 'src/models/response_vt_list_project.dart';
export 'src/models/response_vt_project.dart';
export 'src/models/vt_hotspot.dart';
export 'src/service/api_service.dart'
    show OnError, OnSuccess, OnTokensChanged, OnUploadProgressCallback;

import 'dart:async';
import 'dart:io';

import 'package:amz_360/src/models/response_vt_list_project.dart';
import 'package:amz_360/src/models/response_vt_project.dart';
import 'package:amz_360/src/service/api_service.dart';

import 'src/models/vt_hotspot.dart';
import 'src/utils/utils.dart';

/// The VirtualTour client: sign in with the user's account, then read and edit their
/// projects. Tokens refresh by themselves; keep them with [onTokensChanged] and give them
/// back with [setTokens] on the next launch.
class Amz360 {
  static final Amz360 instance = Amz360();

  final ApiService api = ApiService();
  String? currentImageId;
  final StreamController<VTHotspotLable> hotspotLableStreamController =
      StreamController.broadcast();
  final StreamController<VTHotspotLink> hotspotLinkStreamController =
      StreamController.broadcast();

  /// The API, https://apivirtualtour.amazinsolution.com/api/v1 by default.
  void setBaseUrl(String url) => api.baseUrl = url;

  /// Called with the new pair after sign in and each refresh, and with nulls after sign out.
  set onTokensChanged(OnTokensChanged? callback) =>
      api.onTokensChanged = callback;

  /// Restores a session saved from [onTokensChanged].
  void setTokens({required String accessToken, required String refreshToken}) =>
      api.setTokens(accessToken, refreshToken);

  bool get isSignedIn => api.accessToken != null;

  // ---------- auth ----------

  /// Signs in with email and password; returns the user (id, email, role, ...).
  Future<Map<String, dynamic>> login(
          {required String email,
          required String password,
          OnError? onError,
          OnSuccess? onSuccess}) =>
      api.login(
          email: email,
          password: password,
          onError: onError,
          onSuccess: onSuccess);

  /// Signs in with the ID token of a Firebase Google sign-in.
  Future<Map<String, dynamic>> loginWithGoogle(
          {required String idToken, OnError? onError, OnSuccess? onSuccess}) =>
      api.loginWithProvider(
          provider: "google",
          idToken: idToken,
          onError: onError,
          onSuccess: onSuccess);

  /// Signs in with the ID token of a Firebase Apple sign-in.
  Future<Map<String, dynamic>> loginWithApple(
          {required String idToken, OnError? onError, OnSuccess? onSuccess}) =>
      api.loginWithProvider(
          provider: "apple",
          idToken: idToken,
          onError: onError,
          onSuccess: onSuccess);

  /// Revokes the tokens on the server and forgets them.
  Future<void> logout({OnError? onError, OnSuccess? onSuccess}) =>
      api.logout(onError: onError, onSuccess: onSuccess);

  // ---------- projects ----------

  Future<ResponseVtProject> getProject(
      {required String id, OnError? onError, OnSuccess? onSuccess}) {
    _requireSignIn();
    return api.getProject(id: id, onError: onError, onSuccess: onSuccess);
  }

  Future<ResponseVtListProject> getListProject(
      {OnError? onError, OnSuccess? onSuccess}) {
    _requireSignIn();
    return api.getListProject(onError: onError, onSuccess: onSuccess);
  }

  /// Creates a project from one or more 360° images; the title must be unique.
  Future<ResponseVtProject> create(
      {required String title,
      required String descrition,
      required List<File> images,
      OnUploadProgressCallback? progressCallback,
      OnError? onError,
      OnSuccess? onSuccess}) {
    _requireSignIn();
    return api.create(
        describe: descrition,
        images: images,
        title: title,
        progressCallback: progressCallback,
        onError: onError,
        onSuccess: onSuccess);
  }

  /// Sets both the title and the description.
  Future<ResponseVtProject> updateInfoProject(
      {required String idProject,
      required String title,
      required String description,
      OnError? onError,
      OnSuccess? onSuccess}) {
    _requireSignIn();
    return api.updateProject(
        projectId: idProject,
        title: title,
        description: description,
        onError: onError,
        onSuccess: onSuccess);
  }

  /// Adds the images after the last one; returns the project.
  Future<ResponseVtProject> uploadImageToProject(
      {required String idProject,
      required List<File> images,
      OnUploadProgressCallback? progressCallback,
      OnError? onError,
      OnSuccess? onSuccess}) {
    _requireSignIn();
    return api.addImageToProject(
        projectId: idProject,
        images: images,
        onError: onError,
        progressCallback: progressCallback,
        onSuccess: onSuccess);
  }

  /// Deletes the image with its spots; returns the project.
  Future<ResponseVtProject> deleteImageFromProject(
      {required String idProject,
      required String idImage,
      OnError? onError,
      OnSuccess? onSuccess}) {
    _requireSignIn();
    return api.deleteImageFromProject(
        projectId: idProject,
        imageId: idImage,
        onError: onError,
        onSuccess: onSuccess);
  }

  Future<ResponseVtProject> deleteProject(
      {required String id, OnError? onError, OnSuccess? onSuccess}) {
    _requireSignIn();
    return api.deleteProject(id: id, onError: onError, onSuccess: onSuccess);
  }

  // ---------- hotspots ----------

  /// Adds an infospot at the viewer's [x] (longitude) and [y] (latitude); open viewers
  /// show it at once.
  Future<VTHotspotLable> addHotspotLable(
      {required String idImage,
      required String title,
      String? text,
      File? image,
      List<File>? images,
      File? video,
      required double x,
      required double y,
      OnUploadProgressCallback? progressCallback,
      OnError? onError,
      OnSuccess? onSuccess}) async {
    _requireSignIn();
    final hotspot = await api.addHospotLable(
        imageId: idImage,
        title: title,
        x: Amz360Utils.shared.convertXtoServer(x, y),
        y: Amz360Utils.shared.convertYtoServer(y),
        z: Amz360Utils.shared.convertZtoServer(x, y),
        text: text,
        images: [if (image != null) image, ...?images],
        video: video,
        progressCallback: progressCallback,
        onError: onError,
        onSuccess: onSuccess);
    // At the exact place picked, not the rounded one the server keeps
    hotspot
      ..x = x
      ..y = y;
    hotspotLableStreamController.add(hotspot);
    return hotspot;
  }

  Future<bool> deleteHotspotLable(
      {required String hotspotId, OnError? onError, OnSuccess? onSuccess}) {
    _requireSignIn();
    return api.deleteHotspotLable(
        hotspotId: hotspotId, onError: onError, onSuccess: onSuccess);
  }

  /// Adds an arrow on image [idImage] that opens image [toImageId] of the same project
  /// (read it first with [getProject]); [title] shows on hover on the website.
  Future<VTHotspotLink> addHotspotToOtherImage(
      {required String idImage,
      required String toImageId,
      String? title,
      required double x,
      required double y,
      OnError? onError,
      OnSuccess? onSuccess}) async {
    _requireSignIn();
    final hotspot = await api.addHotspotLink(
        imageId: idImage,
        x: Amz360Utils.shared.convertXtoServer(x, y),
        y: Amz360Utils.shared.convertYtoServer(y),
        z: Amz360Utils.shared.convertZtoServer(x, y),
        title: title,
        onError: onError,
        onSuccess: onSuccess,
        toImageId: toImageId);
    hotspot
      ..x = x
      ..y = y
      ..toImage = toImageId;
    hotspotLinkStreamController.add(hotspot);
    return hotspot;
  }

  Future<bool> deleteHotspotToOtherImage(
      {required String hotspotId, OnError? onError, OnSuccess? onSuccess}) {
    _requireSignIn();
    return api.deleteHotspotLink(
        hotspotId: hotspotId, onError: onError, onSuccess: onSuccess);
  }

  void _requireSignIn() {
    if (!isSignedIn) {
      throw Exception("Sign in first with Amz360.instance.login");
    }
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:amz_360/src/models/response_vt_list_project.dart';
import 'package:amz_360/src/models/response_vt_project.dart';
import 'package:amz_360/src/models/vt_hotspot.dart';
import 'package:dio/dio.dart';

typedef OnUploadProgressCallback = void Function(int sentBytes, int totalBytes);
typedef OnSuccess = void Function();
typedef OnError = void Function(int statusCode, String message);

/// Called whenever the token pair changes (sign in, refresh, sign out: both null),
/// so the app can store it and give it back with [ApiService.setTokens] on the next launch.
typedef OnTokensChanged = void Function(
    String? accessToken, String? refreshToken);

const defaultBaseUrl = "https://apivirtualtour.amazinsolution.com/api/v1/";

/// Calls the VirtualTour API (VirtualTourBe) with the signed-in user's token.
///
/// Auth answers `{ success, message, data }` and errors as 4xx; project, label and
/// link calls answer `{ status: "success" | "fail", message, data }`.
class ApiService {
  ApiService() {
    dio.interceptors.add(QueuedInterceptorsWrapper(
      onRequest: (options, handler) {
        if (accessToken != null && !options.path.startsWith("auth/")) {
          options.headers["Authorization"] = "Bearer $accessToken";
        }
        handler.next(options);
      },
      // An expired access token: refresh once, then send the call again
      onError: (error, handler) async {
        final options = error.requestOptions;
        if (error.response?.statusCode != 401 ||
            refreshToken == null ||
            options.path.startsWith("auth/") ||
            options.extra["retried"] == true) {
          return handler.next(error);
        }
        try {
          await refresh();
          options.extra["retried"] = true;
          options.headers["Authorization"] = "Bearer $accessToken";
          // Not through [dio]: its queued interceptors would wait on this very handler
          handler.resolve(await _plainDio().fetch(options));
        } on DioException catch (e) {
          handler.next(e);
        }
      },
    ));
  }

  final dio = Dio(BaseOptions(
      baseUrl: defaultBaseUrl, headers: {"Accept": "application/json"}));

  String? accessToken;
  String? refreshToken;
  OnTokensChanged? onTokensChanged;

  /// Image id → URL of every image of the projects read so far: linkspots point at the
  /// target image by URL, the SDK by id
  final Map<String, String> imageUrls = {};

  set baseUrl(String url) =>
      dio.options.baseUrl = url.endsWith("/") ? url : "$url/";

  void setTokens(String? access, String? refresh) {
    accessToken = access;
    refreshToken = refresh;
    onTokensChanged?.call(access, refresh);
  }

  // ---------- auth ----------

  /// Signs in with email and password; returns the user.
  Future<Map<String, dynamic>> login(
      {required String email,
      required String password,
      OnSuccess? onSuccess,
      OnError? onError}) {
    return _signIn("auth/login", {"email": email, "password": password},
        onSuccess, onError);
  }

  /// Signs in with a Firebase ID token from Google or Apple; returns the user.
  Future<Map<String, dynamic>> loginWithProvider(
      {required String provider,
      required String idToken,
      OnSuccess? onSuccess,
      OnError? onError}) {
    return _signIn("auth/$provider", {"idToken": idToken}, onSuccess, onError);
  }

  Future<Map<String, dynamic>> _signIn(String path, Map<String, dynamic> body,
      OnSuccess? onSuccess, OnError? onError) async {
    final data = await _call(() => dio.post(path, data: body), onError);
    setTokens(data["data"]["accessToken"], data["data"]["refreshToken"]);
    onSuccess?.call();
    return Map<String, dynamic>.from(data["data"]["user"]);
  }

  /// A new token pair; each refresh token works once.
  Future<void> refresh() async {
    final response = await _plainDio()
        .post("auth/refresh", data: {"refreshToken": refreshToken});
    final data = _decode(response);
    setTokens(data["data"]["accessToken"], data["data"]["refreshToken"]);
  }

  Future<void> logout({OnSuccess? onSuccess, OnError? onError}) async {
    try {
      if (refreshToken != null) {
        await _call(
            () => dio.post("auth/logout",
                data: {"refreshToken": refreshToken},
                options:
                    Options(headers: {"Authorization": "Bearer $accessToken"})),
            onError);
      }
    } finally {
      // Signed out locally even when the server call fails
      setTokens(null, null);
    }
    onSuccess?.call();
  }

  // ---------- projects ----------

  Future<ResponseVtProject> create(
      {required String title,
      required String describe,
      required List<File> images,
      OnUploadProgressCallback? progressCallback,
      OnSuccess? onSuccess,
      OnError? onError}) async {
    final body = FormData.fromMap({"title": title, "describe": describe});
    for (final file in images) {
      body.files.add(MapEntry("img[]", await MultipartFile.fromFile(file.path)));
    }
    final data = await _call(
        () => dio.post("project",
            data: body, onSendProgress: progressCallback),
        onError);
    onSuccess?.call();
    return ResponseVtProject.fromJson(data);
  }

  Future<ResponseVtListProject> getListProject(
      {OnSuccess? onSuccess, OnError? onError}) async {
    final data = await _call(() => dio.get("project"), onError);
    final list = ResponseVtListProject.fromJson(data);
    for (final project in (data["data"] as List? ?? [])) {
      _rememberImages(project);
    }
    onSuccess?.call();
    return list;
  }

  /// The project with its images, infospots and linkspots.
  Future<ResponseVtProject> getProject(
      {required String id, OnSuccess? onSuccess, OnError? onError}) async {
    final data = await _call(() => dio.get("project/$id"), onError);
    // The API answers a list holding the one project
    final list = data["data"] as List? ?? [];
    if (list.isEmpty) {
      onError?.call(404, "Project not found");
      throw Exception("Project not found");
    }
    _rememberImages(list.first);
    onSuccess?.call();
    return ResponseVtProject.fromJson({...data, "data": list.first});
  }

  Future<ResponseVtProject> updateProject(
      {required String projectId,
      required String title,
      required String description,
      OnSuccess? onSuccess,
      OnError? onError}) async {
    final data = await _call(
        () => dio.put("project/$projectId", data: {
              "action": "edit_infomation",
              "title": title,
              "describe": description,
            }),
        onError);
    onSuccess?.call();
    return ResponseVtProject.fromJson(data);
  }

  /// Uploads each image, adds it to the project, then returns the project.
  Future<ResponseVtProject> addImageToProject(
      {required String projectId,
      required List<File> images,
      OnUploadProgressCallback? progressCallback,
      OnSuccess? onSuccess,
      OnError? onError}) async {
    for (final file in images) {
      final upload = FormData.fromMap({
        "project_id": projectId,
        "img": await MultipartFile.fromFile(file.path),
      });
      // POST /image answers the image itself, not { status, data }
      final image = await _call(
          () => dio.post("image",
              data: upload, onSendProgress: progressCallback),
          onError,
          raw: true);
      await _call(
          () => dio.put("project/$projectId",
              data: {"action": "add_image", "images_id": image["id"]}),
          onError);
    }
    return getProject(id: projectId, onSuccess: onSuccess, onError: onError);
  }

  /// Deletes the image and its spots, then returns the project.
  Future<ResponseVtProject> deleteImageFromProject(
      {required String projectId,
      required String imageId,
      OnSuccess? onSuccess,
      OnError? onError}) async {
    await _call(
        () => dio.put("project/$projectId",
            data: {"action": "remove_image", "image_id": imageId}),
        onError);
    return getProject(id: projectId, onSuccess: onSuccess, onError: onError);
  }

  Future<ResponseVtProject> deleteProject(
      {required String id, OnSuccess? onSuccess, OnError? onError}) async {
    final data = await _call(() => dio.delete("project/$id"), onError);
    onSuccess?.call();
    return ResponseVtProject.fromJson(data);
  }

  // ---------- infospots (label) ----------

  /// [x], [y], [z] are server coordinates (see Amz360Utils.convert*toServer).
  Future<VTHotspotLable> addHospotLable(
      {required String imageId,
      required String title,
      required double x,
      required double y,
      required double z,
      String? text,
      File? video,
      List<File>? images,
      OnUploadProgressCallback? progressCallback,
      OnSuccess? onSuccess,
      OnError? onError}) async {
    final body = FormData.fromMap({
      "image_id": imageId,
      "title": title,
      "positions_x": x.toStringAsFixed(2),
      "positions_y": y.toStringAsFixed(2),
      "positions_z": z.toStringAsFixed(2),
      if (text != null) "text": text,
    });
    for (final file in images ?? <File>[]) {
      body.files.add(MapEntry("img[]", await MultipartFile.fromFile(file.path)));
    }
    if (video != null) {
      body.files
          .add(MapEntry("video", await MultipartFile.fromFile(video.path)));
    }
    final data = await _call(
        () => dio.post("label", data: body, onSendProgress: progressCallback),
        onError);
    onSuccess?.call();
    return VTHotspotLable.fromJson(data["data"]);
  }

  Future<bool> deleteHotspotLable(
      {required String hotspotId,
      OnSuccess? onSuccess,
      OnError? onError}) async {
    await _call(() => dio.delete("label/$hotspotId"), onError);
    onSuccess?.call();
    return true;
  }

  // ---------- linkspots (link) ----------

  /// [x], [y], [z] are server coordinates. Both images must belong to a project read
  /// with [getProject] or [getListProject], which gives their URLs.
  Future<VTHotspotLink> addHotspotLink(
      {required String imageId,
      required String toImageId,
      required double x,
      required double y,
      required double z,
      String? title,
      OnSuccess? onSuccess,
      OnError? onError}) async {
    final from = imageUrls[imageId];
    final to = imageUrls[toImageId];
    if (from == null || to == null) {
      onError?.call(0, "Unknown image: read its project first");
      throw Exception("Unknown image: read its project first");
    }
    final data = await _call(
        () => dio.post("link", data: {
              "image_id": from,
              "link": to,
              "title": title ?? "",
              "positions_x": x.toStringAsFixed(2),
              "positions_y": y.toStringAsFixed(2),
              "positions_z": z.toStringAsFixed(2),
            }),
        onError);
    onSuccess?.call();
    return VTHotspotLink.fromJson(data["data"], imageIdOf: imageIdOf);
  }

  Future<bool> deleteHotspotLink(
      {required String hotspotId,
      OnSuccess? onSuccess,
      OnError? onError}) async {
    await _call(() => dio.delete("link/$hotspotId"), onError);
    onSuccess?.call();
    return true;
  }

  /// The id of the image with this URL, among the projects read so far.
  String? imageIdOf(String? url) {
    for (final entry in imageUrls.entries) {
      if (entry.value == url) return entry.key;
    }
    return null;
  }

  void _rememberImages(dynamic project) {
    for (final image in (project["images"] as List? ?? [])) {
      imageUrls[image["id"].toString()] = image["url"].toString();
    }
  }

  // ---------- helpers ----------

  /// Same base URL and headers as [dio], without its interceptors
  Dio _plainDio() => Dio(dio.options.copyWith());

  Map<String, dynamic> _decode(Response response) {
    final body = response.data;
    if (body is Map<String, dynamic>) return body;
    return Map<String, dynamic>.from(jsonDecode(body.toString()));
  }

  /// Runs a call and returns its body; a failure (a 4xx, or a 200 saying fail) goes to
  /// [onError] and throws. With [raw], any 2xx body counts as success.
  Future<Map<String, dynamic>> _call(
      Future<Response> Function() send, OnError? onError,
      {bool raw = false}) async {
    try {
      final response = await send();
      final data = _decode(response);
      final ok = raw ||
          data["status"] == "success" ||
          data["code"] == "success" ||
          data["success"] == true;
      if (!ok) {
        final message = (data["message"] ?? "Request failed").toString();
        onError?.call(response.statusCode ?? 0, message);
        throw Exception(message);
      }
      return data;
    } on DioException catch (e) {
      final body = e.response?.data;
      final message = body is Map && body["message"] != null
          ? body["message"].toString()
          : (e.message ?? "Network error");
      onError?.call(e.response?.statusCode ?? 0, message);
      throw Exception(message);
    }
  }
}

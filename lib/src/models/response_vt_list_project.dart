import 'package:amz_360/src/models/response_vt_project.dart';

class ResponseVtListProject {
  String? status;
  String? message;
  List<VTProjectOnList>? data;

  ResponseVtListProject({this.status, this.message, this.data});

  ResponseVtListProject.fromJson(Map<String, dynamic> json) {
    status = json["status"];
    message = json["message"];
    data = json["data"] == null
        ? null
        : (json["data"] as List)
            .map((e) => VTProjectOnList.fromJson(e))
            .toList();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data["status"] = status;
    data["message"] = message;
    if (this.data != null) {
      data["data"] = this.data?.map((e) => e.toJson()).toList();
    }
    return data;
  }
}

class VTProjectOnList {
  String? id;
  String? slug;
  String? title;
  String? describe;
  /// The first image, as the cover
  VTImageDetails? images;

  VTProjectOnList({this.id, this.slug, this.title, this.describe, this.images});

  VTProjectOnList.fromJson(Map<String, dynamic> json) {
    id = json["id"]?.toString();
    slug = json["slug"];
    title = json["title"];
    describe = json["describe"];
    final list = json["images"] as List?;
    images = list == null || list.isEmpty ? null : VTImageDetails.fromJson(list.first);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data["id"] = id;
    data["slug"] = slug;
    data["title"] = title;
    data["describe"] = describe;
    if (images != null) {
      data["images"] = images?.toJson();
    }
    return data;
  }
}

import 'dart:convert';

import 'package:amz_360/src/utils/utils.dart';
import 'package:flutter/material.dart';

/// A linkspot: an arrow on a 360° image that opens another image of the project.
class VTHotspotLink {
  String? id;
  HotspotPosition? _positions;

  /// Id of the image it opens (the API gives its URL, see [url])
  String? toImage;

  /// URL of the image it opens
  String? url;
  String? title;
  double? x;
  double? y;
  Widget? widget;
  Widget? icon;

  VTHotspotLink(
      {this.id,
      this.toImage,
      this.url,
      this.title,
      this.x = 0.0,
      this.y = 0.0,
      this.icon});

  /// [imageIdOf] turns the target image's URL into its id, when the images are known.
  VTHotspotLink.fromJson(Map<String, dynamic> json,
      {String? Function(String? url)? imageIdOf}) {
    id = json["id"]?.toString();
    _positions = HotspotPosition.fromServer(json["positions"]);
    url = json["url"]?.toString();
    title = json["title"]?.toString();
    toImage = imageIdOf?.call(url);
    if (_positions != null) {
      x = Amz360Utils.shared
          .convertXfromServer(_positions!.x!, _positions!.y!, _positions!.z!);
      y = Amz360Utils.shared
          .convertYfromServer(_positions!.x!, _positions!.y!, _positions!.z!);
    } else {
      x = 0;
      y = 0;
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data["id"] = id;
    data["url"] = url;
    data["title"] = title;
    return data;
  }
}

/// An infospot: a card with a title and text, images or a video.
class VTHotspotLable {
  String? id;
  String? title;
  String? text;

  /// The first of [imageUrls]
  String? imageUrl;
  List<String> imageUrls = [];
  String? videoUrl;
  String? imageId;
  HotspotPosition? _position;
  double? x;
  double? y;
  Widget? icon;

  VTHotspotLable(
      {this.id,
      this.title,
      this.text,
      this.imageUrl,
      List<String>? imageUrls,
      this.videoUrl,
      this.imageId,
      this.x = 0,
      this.y = 0,
      this.icon}) {
    this.imageUrls = imageUrls ?? (imageUrl == null ? [] : [imageUrl!]);
  }

  VTHotspotLable.fromJson(Map<String, dynamic> json) {
    id = json["id"]?.toString();
    title = json["title"];
    text = json["text"];
    // image_urls is null on infospots saved before it existed
    imageUrls = (json["image_urls"] as List?)?.map((e) => e.toString()).toList() ??
        (json["image_url"] == null ? [] : [json["image_url"].toString()]);
    imageUrl = imageUrls.isEmpty ? null : imageUrls.first;
    videoUrl = json["video_url"];
    imageId = json["image_id"]?.toString();
    _position = HotspotPosition.fromServer(json["positions"]);

    if (_position != null) {
      x = Amz360Utils.shared
          .convertXfromServer(_position!.x!, _position!.y!, _position!.z!);
      y = Amz360Utils.shared
          .convertYfromServer(_position!.x!, _position!.y!, _position!.z!);
    } else {
      x = 0;
      y = 0;
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data["id"] = id;
    data["title"] = title;
    data["text"] = text;
    data["image_url"] = imageUrl;
    data["image_urls"] = imageUrls;
    data["video_url"] = videoUrl;
    data["image_id"] = imageId;
    return data;
  }
}

class HotspotPosition {
  double? x;
  double? y;
  double? z;

  HotspotPosition({this.x, this.y, this.z});

  HotspotPosition.fromJson(Map<String, dynamic> json) {
    x = double.parse(json["x"].toString());
    y = double.parse(json["y"].toString());
    z = double.parse(json["z"].toString());
  }

  /// The API keeps positions as the JSON text "[x, y, z]"; a list or {x, y, z} also works.
  static HotspotPosition? fromServer(dynamic value) {
    try {
      final decoded = value is String ? jsonDecode(value) : value;
      if (decoded is List && decoded.length >= 3) {
        return HotspotPosition(
            x: double.parse(decoded[0].toString()),
            y: double.parse(decoded[1].toString()),
            z: double.parse(decoded[2].toString()));
      }
      if (decoded is Map<String, dynamic>) return HotspotPosition.fromJson(decoded);
    } on FormatException {
      return null;
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data["x"] = x.toString();
    data["y"] = y.toString();
    data["z"] = z.toString();
    return data;
  }
}

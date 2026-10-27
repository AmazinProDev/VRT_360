import 'package:amz_360/amz_360.dart';
import 'package:flutter_test/flutter_test.dart';

// One project as GET /project/{id} gives it (inside its data list)
final project = {
  "id": "p1",
  "slug": "bo-song",
  "title": "Bờ sông",
  "describe": "River",
  "owner": {"id": "u1", "fullName": "Minh"},
  "images": [
    {
      "id": "i1",
      "url": "https://cdn/a.jpg",
      "thumbnail_url": "https://cdn/a_t.jpg",
      "label": [
        {
          "id": "l1",
          "image_id": "i1",
          "title": "Cầu",
          "text": null,
          "image_url": "https://cdn/x.jpg",
          "image_urls": ["https://cdn/x.jpg", "https://cdn/y.jpg"],
          "video_url": null,
          "positions": "[\"120.50\",\"-30.20\",\"480.00\"]"
        }
      ],
      "link": [
        {
          "id": "k1",
          "image_id": "i1",
          "url": "https://cdn/b.jpg",
          "title": "Bãi tàu",
          "positions": "[1, 2, 3]"
        }
      ]
    },
    {
      "id": "i2",
      "url": "https://cdn/b.jpg",
      "thumbnail_url": null,
      "label": [],
      "link": []
    }
  ]
};

void main() {
  test('reads a project in the API shape', () {
    final p = VTProject.fromJson(project);
    expect(p.id, "p1");
    expect(p.description, "River");
    expect(p.author, "Minh");
    expect(p.currentImage!.image!.url, "https://cdn/a.jpg");

    final label = p.images![0].label!.single;
    expect(label.imageUrls, ["https://cdn/x.jpg", "https://cdn/y.jpg"]);
    expect(label.imageUrl, "https://cdn/x.jpg");
    expect(label.imageId, "i1");

    // The linkspot names its target by URL; the viewer needs its id
    final link = p.images![0].link!.single;
    expect(link.toImage, "i2");
    expect(link.title, "Bãi tàu");
    expect(p.images![0].totalHospot!.length, 2);
  });

  test('reads positions as JSON text, a list or a map', () {
    final fromText = HotspotPosition.fromServer("[\"1.5\",\"2\",\"3\"]")!;
    expect([fromText.x, fromText.y, fromText.z], [1.5, 2.0, 3.0]);
    expect(HotspotPosition.fromServer([4, 5, 6])!.z, 6.0);
    expect(HotspotPosition.fromServer({"x": 7, "y": 8, "z": 9})!.x, 7.0);
    expect(HotspotPosition.fromServer("not json"), isNull);
    expect(HotspotPosition.fromServer(null), isNull);
  });

  test('uses the first image as the cover of a listed project', () {
    final p = VTProjectOnList.fromJson(project);
    expect(p.id, "p1");
    expect(p.images!.thumbnailUrl, "https://cdn/a_t.jpg");
  });
}

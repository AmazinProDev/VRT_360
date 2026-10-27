# AMZ 360

AMZ 360 is a plugin that provides a 360 degree image visualizer in Flutter.

* Display via Assets.
* Display via URL.
* Display and edit the tours of a VirtualTour account (sign in, projects, infospots, linkspots).

# Screenshot
 **Overview**

https://user-images.githubusercontent.com/52748825/151189698-1763c681-e7d7-465b-ba9d-1e1cbe4f495b.mp4


# Getting Started

## Install

In `pubspec.yaml` add to `dependencies`:

```yaml
dependencies:
    amz_360:
        git:
            url: git@github.com:AmazinProDev/VRT_360.git
            ref: 2.0.0 #(version)
```
* **Android**: `minSdkVersion 19` and add support for `androidx` (see [AndroidX Migration](https://flutter.dev/docs/development/androidx-migration))
* **iOS**: `--ios-language swift`, Xcode version `>= 11`


## Import

```dart
import 'package:amz_360/amz_360.dart';
```

## Usage

* To display 360 image from assets

```dart
Amz360View.asset(
          imageAsset: "assets/images/panorama.jpeg", // Link from assets
          autoRotationSpeed: 1,
          enableSensorControl: false,
          displayMode: Amz360ViewType.view360,
        )
```

* To display 360 image from url

```dart
Amz360View.url(
          imageUrl: "https://cdn.eso.org/images/publicationjpg/ESO_Hotel_Paranal_360_Marcio_Cabral_Chile_02-CC.jpg",
          autoRotationSpeed: 1,
          enableSensorControl: false,
          displayMode: Amz360ViewType.view360,
        )
```

* To display and edit the tours of a VirtualTour account

The SDK calls the VirtualTour API (`https://apivirtualtour.amazinsolution.com/api/v1`; change it with `Amz360.instance.setBaseUrl(...)`). Ids are strings (UUIDs).

1. Sign in with a VirtualTour account. The SDK sends the access token with every call and refreshes it by itself when it expires.

```dart
final user = await Amz360.instance.login(email: email, password: password);
// or, with the ID token of a Firebase Google / Apple sign-in:
await Amz360.instance.loginWithGoogle(idToken: idToken);
await Amz360.instance.loginWithApple(idToken: idToken);
```

To stay signed in across launches, keep the tokens and give them back:

```dart
Amz360.instance.onTokensChanged = (access, refresh) {
  // save both (null, null after logout)
};
Amz360.instance.setTokens(accessToken: savedAccess, refreshToken: savedRefresh);
```

Sign out:

```dart
await Amz360.instance.logout();
```

2. To create new project (the title must be unique):

```dart
await Amz360.instance.create(
  title: "This is title of project",
  descrition: "This is descriptions of project",
  images: listfile,
  progressCallback: (sentBytes, totalBytes) {
    print("Progress: $sentBytes/$totalBytes");
  },
);
```

3. To get all your projects:

```dart
final data = await Amz360.instance.getListProject();
print(data.data![0].id);
```

4. To display a project

```dart
Amz360View.client(
  id: id, // id of the project
  autoRotationSpeed: 0.0,
  enableSensorControl: true,
  showControl: true,
  onTap: (x, y, project) {
    log("$x   $y");
  },
  onLongPressStart: (x, y, project) async {
    log("$x   $y");
  },
)
```

5. Update the title and description (both are needed):

```dart
await Amz360.instance.updateInfoProject(
  idProject: id,
  title: "New title",
  description: "New description");
```

6. Upload images to a project:

```dart
await Amz360.instance.uploadImageToProject(
  idProject: id,
  images: listImage,
  progressCallback: (sentBytes, totalBytes) {
    print(sentBytes / totalBytes);
  },
);
```

7. Delete an image (and its hotspots) from a project:

```dart
await Amz360.instance.deleteImageFromProject(idProject: id, idImage: idImage);
```

8. Delete a project:

```dart
await Amz360.instance.deleteProject(id: id);
```

9. Add an infospot (text, one or more images, or a video) where the user pressed:

```dart
onLongPressStart: (x, y, project) async {
  await Amz360.instance.addHotspotLable(
    idImage: project!.currentImage!.image!.id!,
    title: "Title",
    text: "Text",        // or images: [file1, file2], or video: videoFile
    x: x,
    y: y);
},
```

10. Add a linkspot that opens another image of the same project (read the project first, as `Amz360View.client` does); `title` shows on hover on the website, "Go to Scene N" when left out:

```dart
await Amz360.instance.addHotspotToOtherImage(
  idImage: project.currentImage!.image!.id!,
  toImageId: otherImageId,
  title: "Kitchen",
  x: x,
  y: y);
```

11. Delete a hotspot: set `showControl: true`, press and hold the hotspot icon, then press Delete. In code:

```dart
await Amz360.instance.deleteHotspotLable(hotspotId: id);
await Amz360.instance.deleteHotspotToOtherImage(hotspotId: id);
```

Errors: every call takes `onError: (statusCode, message) {...}` and also throws an `Exception` with the message.

## Basic properties

| Properties          | Value              |                                                |
| -----------------   | ------------------ | ---------------------------------------------- |
| autoRotationSpeed   | `double`           | visualizer auto rotation speed. default to 0.0 |
| enableSensorControl | `bool`             | use sensor to display                          |
| displayMode         | `Amz360ViewType`   | `.view360` 360 display mode, `.viewOriginalImage` Original image display mode, `.viewOnlyImageInScene` only image in Scene |
| showControl         | `bool`             | enable / disable show Control                  |





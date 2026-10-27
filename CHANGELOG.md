## 2.0.0

Works with the current VirtualTour API (VirtualTourBe); breaking changes:

* Sign in with a VirtualTour account (`login`, `loginWithGoogle`, `loginWithApple`, `logout`) instead of `setClient(apiKey)`; tokens refresh by themselves, `onTokensChanged` / `setTokens` keep the session across launches.
* Base URL `https://apivirtualtour.amazinsolution.com/api/v1/`, changeable with `setBaseUrl`.
* Ids are `String` (UUID) everywhere: projects, images, hotspots.
* `updateInfoProject` needs both `title` and `description`.
* `deleteHotspotLable` / `deleteHotspotToOtherImage` take only `hotspotId`.
* Infospots can hold several images (`imageUrls`; `addHotspotLable(images: [...])`); linkspots have a `title`.
* Image URLs keep https.
* Dart 3, dio 5, flutter_html 3.

## 0.0.1

* TODO: Describe initial release.

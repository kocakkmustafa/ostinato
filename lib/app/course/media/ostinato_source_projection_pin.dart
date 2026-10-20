/// App-owned first-course source identity. These bytes do not grant media
/// release or prove a learner's playing quality.
abstract final class OstinatoSourceProjectionPin {
  static const appId = 'ostinato';
  static const coursePath = 'assets/content/guitar_journey.v1.json';
  static const slicePath =
      'assets/motion_content/ostinato.source-slice.v1.json';
  static const projectionPath =
      'assets/motion_content/ostinato.source-projection.v1.json';

  static const courseSha256 =
      '9e8f01c2ebffbd28ffaf8203be0bce036867d857c3e009a79bf2cf43a75a1f96';
  static const sliceSha256 =
      '4fe8bf84d44a05e4d863cbbfd618c8d001ddcefed6fccbe7173418ad731acf38';
  static const projectionSha256 =
      '07a6f9d37ae96cec4c3b74c8e9582fa64ed14a9d631167bea689a75364c3cf68';
  static const sourceCatalogSha256 =
      'f1f19ee459a818ef61c7fd6f18bd87dbb2852bee7b1e32498c17a32b006b50c9';
  // Preproduction source manifest; not a media release root.
  static const sourceManifestSha256 =
      '3f8419ac1b07a75fd51bd17f15c97e1df3488d3253a9425b8155c613f36582ea';

  static const lessonCount = 60;
  static const sceneCount = 420;
  static const variantCount = 420;
  static const heldCount = 0;
}

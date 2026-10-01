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
      'bf553f62d91927be66b88210103b982bed17c357b4b643cb9b50f57a3e105a18';
  static const sliceSha256 =
      'a1bcfcbe28f8f8c518b24faca593f8ff2e9bc5e92e3e1ca22b693dffda2dcbe0';
  static const projectionSha256 =
      'a5213f9447d5aac10c5bea96c1d8eb5717d5eafb976c069833b9003e235afb20';
  static const sourceCatalogSha256 =
      '791bfea8e1479307794bcf8799cf703a7a840bcd3058c1a0d7fdf065d32d8594';
  // Preproduction source manifest; not a media release root.
  static const sourceManifestSha256 =
      'd887683c9a9b9bdb8d4ab7c51cdc5a5b4b4de6a918079e4cfd9cf543e9751e60';

  static const lessonCount = 60;
  static const sceneCount = 420;
  static const variantCount = 420;
  static const heldCount = 0;
}

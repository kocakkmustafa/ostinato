/// What the camera does in a v1 camera lesson (`K` / engine step A7).
///
/// Only the trunk tilt has teacher data behind it
/// (`config/references/guitar-posture-setup.v1.json`, 7 guitar teachers);
/// the arm chain was measured and declared coached-only. So a hint exists
/// only where trunk tilt is what the lesson asks about, and no threshold is
/// invented for hands or wrists.
enum CameraPart {
  /// Trunk-tilt observation from [PostureEvaluator]; no score.
  trunkHint,
}

/// A camera lesson's part and how long the position is held.
typedef CameraLesson = ({CameraPart part, int holdSeconds});

/// The camera lessons this build runs, by lesson id. The hold time is the
/// one the lesson's task names.
const Map<String, CameraLesson> v1CameraLessons = {
  // "Sit with the guitar in view of the camera and hold the position for
  // 60 seconds."
  'gtr-s1-m01-02': (part: CameraPart.trunkHint, holdSeconds: 60),
};

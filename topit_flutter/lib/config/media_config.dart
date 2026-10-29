const kMaxVideoRecordingDuration = Duration(seconds: 5);

const kMaxVideoDurationTolerance = Duration(milliseconds: 200);

bool isVideoTooLong(Duration duration) {
  return duration > kMaxVideoRecordingDuration + kMaxVideoDurationTolerance;
}

(function () {
  let landmarker = null;
  let initPromise = null;
  let videoElement = null;
  let mediaStream = null;
  let lastVideoTime = -1;

  const VISION_BUNDLE =
    'https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@0.10.21/vision_bundle.mjs';
  const WASM_PATH =
    'https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@0.10.21/wasm';
  const MODEL_URL =
    'https://storage.googleapis.com/mediapipe-models/pose_landmarker/pose_landmarker_full/float16/latest/pose_landmarker_full.task';

  function landmarksFromResult(result) {
    if (!result.landmarks || result.landmarks.length === 0) {
      return null;
    }

    const pose = result.landmarks[0];
    const landmarks = [];
    for (let i = 0; i < pose.length; i++) {
      const point = pose[i];
      landmarks.push({
        x: point.x,
        y: point.y,
        visibility: point.visibility ?? 1,
      });
    }
    return landmarks;
  }

  async function ensureInit() {
    if (landmarker) {
      return;
    }
    if (initPromise) {
      return initPromise;
    }

    initPromise = (async () => {
      const vision = await import(VISION_BUNDLE);
      const fileset = await vision.FilesetResolver.forVisionTasks(WASM_PATH);
      landmarker = await vision.PoseLandmarker.createFromOptions(fileset, {
        baseOptions: {
          modelAssetPath: MODEL_URL,
        },
        runningMode: 'VIDEO',
        numPoses: 1,
        minPoseDetectionConfidence: 0.55,
        minPosePresenceConfidence: 0.55,
        minTrackingConfidence: 0.55,
      });
    })();

    return initPromise;
  }

  async function attachVideoElement(video) {
    await ensureInit();

    videoElement = video;
    videoElement.autoplay = true;
    videoElement.muted = true;
    videoElement.playsInline = true;
    videoElement.style.width = '100%';
    videoElement.style.height = '100%';
    videoElement.style.objectFit = 'cover';

    if (mediaStream) {
      mediaStream.getTracks().forEach((track) => track.stop());
    }

    mediaStream = await navigator.mediaDevices.getUserMedia({
      video: {
        facingMode: 'user',
        width: { ideal: 1280 },
        height: { ideal: 720 },
      },
      audio: false,
    });

    videoElement.srcObject = mediaStream;
    await videoElement.play();
    lastVideoTime = -1;
  }

  function detectVideoFrame() {
    if (!videoElement || !landmarker) {
      return null;
    }
    if (videoElement.readyState < HTMLMediaElement.HAVE_CURRENT_DATA) {
      return null;
    }
    if (videoElement.currentTime === lastVideoTime) {
      return null;
    }

    lastVideoTime = videoElement.currentTime;
    const timestampMs = Math.round(performance.now());
    const result = landmarker.detectForVideo(videoElement, timestampMs);
    return landmarksFromResult(result);
  }

  function stopVideo() {
    if (mediaStream) {
      mediaStream.getTracks().forEach((track) => track.stop());
      mediaStream = null;
    }
    if (videoElement) {
      videoElement.srcObject = null;
      videoElement = null;
    }
    lastVideoTime = -1;
  }

  window.repquestPoseBridge = {
    init: ensureInit,
    attachVideoElement,
    detectVideoFrame,
    stopVideo,
  };
})();

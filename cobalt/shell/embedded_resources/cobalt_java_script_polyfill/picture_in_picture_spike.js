// TEMPORARY SPIKE CODE. Do not merge.
(() => {
  if (typeof MediaSource === 'undefined' || window.dedtubeSpike) {
    return;
  }

  const realIsTypeSupported = MediaSource.isTypeSupported.bind(MediaSource);
  let isMseAllowed = true;
  MediaSource.isTypeSupported = (type) =>
      isMseAllowed && realIsTypeSupported(type);

  const log = [];
  const note = (text) => {
    log.push(new Date().toISOString().slice(11, 23) + ' ' + text);
    if (log.length > 60) {
      log.shift();
    }
  };

  const player = () => document.querySelector('.html5-video-player');
  const video = () => document.querySelector('video');

  const sourceKind = () => {
    const source = video()?.src ?? '';
    if (source.startsWith('data:application/x-mpegurl')) {
      return 'HLS';
    }
    if (source.startsWith('blob:')) {
      return 'MSE';
    }
    return source.slice(0, 40) || 'none';
  };

  const hlsVariants = () => {
    const source = video()?.src ?? '';
    if (!source.startsWith('data:')) {
      return [];
    }
    const playlist = decodeURIComponent(source.slice(source.indexOf(',') + 1));
    return playlist.split('\n')
        .filter((line) => line.startsWith('#EXT-X-STREAM-INF'))
        .map((line) => {
          const codecs = /CODECS="([^"]*)"/.exec(line)?.[1];
          const resolution = /RESOLUTION=([0-9x]*)/.exec(line)?.[1];
          const range = /VIDEO-RANGE=([A-Z0-9]*)/.exec(line)?.[1];
          return [resolution, codecs, range].join(' ');
        });
  };

  const waitUntilPlaying = (position, started) => {
    let checks = 0;
    const timer = setInterval(() => {
      const element = video();
      const isPlaying = element && !element.paused &&
          element.readyState >= 3 && element.currentTime > position + 0.3;
      checks++;
      if (isPlaying) {
        note('plays as ' + sourceKind() + ' after ' +
             Math.round(performance.now() - started) + ' ms at ' +
             element.currentTime.toFixed(2) + ' s, ' + element.videoWidth +
             'x' + element.videoHeight);
      }
      if (isPlaying || checks > 150) {
        clearInterval(timer);
      }
    }, 100);
  };

  const isOnVideoPage = () => location.hash.startsWith('#/watch');
  let detachedVideoId = null;
  let mseLoudness = null;

  const contentLoudness = () => {
    const text = player()?.getStatsForNerds?.().volume ?? '';
    const match = /cont\.(-?[\d.]+)dB/.exec(text);
    return match ? Number(match[1]) : null;
  };

  const use = (kind) => {
    const api = player();
    isMseAllowed = kind !== 'hls';
    if (!api?.loadVideoById || !isOnVideoPage()) {
      note('no reload for ' + kind + ', not on a video page');
      return 'flag only';
    }
    const position = api.getCurrentTime();
    const videoId = api.getVideoData().video_id;
    isMseAllowed = kind !== 'hls';
    if (kind === 'hls') {
      mseLoudness = contentLoudness();
    }
    note('switch from ' + sourceKind() + ' to ' + kind + ' at ' +
         position.toFixed(2) + ' s');
    api.loadVideoById({videoId, startSeconds: position});
    waitUntilPlaying(position, performance.now());
    return 'ok';
  };

  const release = () => {
    const api = player();
    detachedVideoId = api.getVideoData().video_id;
    isMseAllowed = true;
    const hlsLoudness = contentLoudness();
    const hasLoudness = mseLoudness !== null && hlsLoudness !== null;
    const gain = hasLoudness ?
        Math.min(1, Math.pow(10, (mseLoudness - hlsLoudness) / 20)) : 1;
    const volume = (video()?.volume ?? 1) * gain;
    api.pauseVideo();
    note('released ' + detachedVideoId + ' to the app player at ' +
         api.getCurrentTime().toFixed(2) + ' s, loudness MSE ' + mseLoudness +
         ' HLS ' + hlsLoudness + ', volume ' + volume.toFixed(3));
    return 'gain:' + volume.toFixed(3);
  };

  const resume = (position) => {
    const api = player();
    isMseAllowed = true;
    const isSameVideo = isOnVideoPage() &&
        api?.getVideoData?.().video_id === detachedVideoId;
    note('resume ' + detachedVideoId + ' at ' + position.toFixed(2) +
         ' s, same video page ' + isSameVideo);
    if (!isSameVideo) {
      return 'link:https://www.youtube.com/tv?v=' + detachedVideoId + '&t=' +
          Math.floor(position);
    }
    api.loadVideoById({videoId: detachedVideoId, startSeconds: position});
    waitUntilPlaying(position, performance.now());
    return 'reload on the video page';
  };

  const state = () => {
    const element = video();
    const api = player();
    return JSON.stringify({
      href: location.href.slice(0, 80),
      visibility: document.visibilityState,
      source: sourceKind(),
      time: element?.currentTime,
      paused: element?.paused,
      readyState: element?.readyState,
      size: element && element.videoWidth + 'x' + element.videoHeight,
      error: element?.error && element.error.code + ' ' + element.error.message,
      quality: api?.getPlaybackQuality?.(),
      playerState: api?.getPlayerState?.(),
      hlsVariants: hlsVariants(),
      canPlayHlsVp9: element?.canPlayType(
          'application/x-mpegURL; codecs="vp09.00.51.08, mp4a.40.2"'),
      log,
    });
  };

  document.addEventListener('visibilitychange',
                            () => note('visibility ' + document.visibilityState));
  document.addEventListener('freeze', () => note('freeze'));
  document.addEventListener('resume', () => note('resume'));

  window.dedtubeSpike = {use, state, release, resume};
})();

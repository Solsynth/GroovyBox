// Kuwo Music provider for GroovyBox.
//
// Contract: every function is synchronous. To reach the network it returns
// {http: {...}}; the host performs the request and calls the same function
// again with args.__response = {status, headers, body}.
//
// Endpoints (all verified 2026-11):
//   search     https://search.kuwo.cn/r.s?...&all=<kw>
//              -> content[1].musicpage.abslist[] with SONGNAME, ARTIST, ALBUM,
//                 ALBUMID, MUSICRID ('MUSIC_<numeric>'), DURATION (seconds),
//                 web_albumpic_short ('120/xx/yy/<file>.jpg').
//              The body has also been served as a single-quoted object literal,
//              so parseLoose() falls back to eval() in this sandbox.
//   stream     https://antiserver.kuwo.cn/anti.s?type=convert_url&format=mp3&response=url&rid=<MUSICRID>
//              -> plain text mp3 URL (https://kw-bj.kuwo.cn/...). A VIP-gated
//              id answers a shared ~11 s placeholder instead; a HEAD decides
//              by Content-Length and a placeholder becomes previewUrl.
//   lyrics     https://m.kuwo.cn/newh5/singles/songinfoandlrc?musicId=<numeric>
//              -> data.lrclist[] {time (seconds, string float), lineLyric}.

// Numeric id: 'MUSIC_228908' -> '228908'; a bare '228908' passes through.
function numericId(song) {
  var raw = song && song.id != null ? String(song.id) : '';
  var i = raw.lastIndexOf('_');
  return i >= 0 ? raw.slice(i + 1) : raw;
}

function rid(song) {
  var raw = song && song.id != null ? String(song.id) : '';
  return raw.indexOf('MUSIC_') === 0 ? raw : 'MUSIC_' + numericId(song);
}

// web_albumpic_short starts with its own '120/' size segment; drop it so the
// app-supplied {size} is the only size in the path.
function cover(short) {
  if (!short) return undefined;
  var path = String(short).replace(/^\d+\//, '');
  return 'https://img1.kuwo.cn/star/albumcover/{size}/' + path;
}

// Kuwo durations are whole seconds as strings.
function durationMs(value) {
  var n = parseInt(value, 10);
  return n > 0 ? n * 1000 : undefined;
}

// The body is normally valid JSON, but Kuwo has also served a single-quoted
// object literal, so fall back to eval (safe here: the text came from the
// network, never from the host, and the sandbox holds no host objects).
function parseLoose(body) {
  try {
    return JSON.parse(body);
  } catch (e) {
    return eval('(' + body + ')');
  }
}

function str(value) {
  return value == null ? '' : String(value);
}

function toSong(item) {
  var song = {
    id: str(item.MUSICRID) || ('MUSIC_' + str(item.DC_TARGETID)),
    title: str(item.SONGNAME) || str(item.NAME),
    artist: str(item.ARTIST),
  };
  if (item.ARTISTID) song.artistId = str(item.ARTISTID);
  if (item.ALBUM) song.album = str(item.ALBUM);
  if (item.ALBUMID && str(item.ALBUMID) !== '0') song.albumId = str(item.ALBUMID);
  var art = cover(item.web_albumpic_short);
  if (art) song.artId = art;
  var ms = durationMs(item.DURATION);
  if (ms) song.durationMs = ms;
  return song;
}

function search(args) {
  var limit = args.limit > 0 ? args.limit : 30;
  if (!args.__response) {
    return {http: {
      method: 'GET',
      url: 'https://search.kuwo.cn/r.s?&correct=1&vipver=1&stype=comprehensive' +
           '&encoding=utf8&rformat=json&mobi=1&show_copyright_off=1&searchapi=6' +
           '&pn=0&rn=' + limit +
           '&all=' + encodeURIComponent(args.query || ''),
    }};
  }
  var body = args.__response.body || '';
  var data;
  try {
    data = parseLoose(body);
  } catch (e) {
    return {ok: false, error: 'Kuwo search returned an unexpected body.'};
  }
  var pages = data && data.content;
  var page = null;
  for (var i = 0; pages && i < pages.length; i++) {
    if (pages[i] && pages[i].musicpage) { page = pages[i].musicpage; break; }
  }
  var list = page && page.abslist ? page.abslist : [];
  var songs = [];
  for (var j = 0; j < list.length && songs.length < limit; j++) {
    if (!list[j]) continue;
    var song = toSong(list[j]);
    if (song.id && song.title) songs.push(song);
  }
  return {ok: true, songs: songs};
}

// anti.s answers a URL for every id, but a VIP-gated track gets a shared
// placeholder file (~11 s, 181 KB, the same object for every gated id)
// instead of the song. A HEAD tells them apart: a real track is several MB.
// The app turns previewUrl into a paywall fallback through findCopies, the
// same path NetEase's 30 s trial takes.
//
// The resolved URL has to survive the round trip in this sandbox, not on
// args — the host re-encodes its own copy of args, so a field written there
// is lost. The host serialises calls per plugin, so one slot is safe.
var pendingStreamUrl = null;

function streamUri(args) {
  var song = args.song || {};
  var id = rid(song);
  if (!args.__response) {
    pendingStreamUrl = null;
    if (!id || id === 'MUSIC_') return {ok: false, error: 'Kuwo track id is missing.'};
    return {http: {
      method: 'GET',
      url: 'https://antiserver.kuwo.cn/anti.s?type=convert_url&format=mp3' +
           '&response=url&rid=' + encodeURIComponent(id),
    }};
  }
  if (!pendingStreamUrl) {
    var body = (args.__response.body || '').replace(/^\s+|\s+$/g, '');
    // Misses answer an empty body (or an error sentence), never a URL.
    if (body.indexOf('http') !== 0) {
      return {ok: false, error: 'Kuwo has no stream for this track.'};
    }
    pendingStreamUrl = body;
    return {http: {method: 'HEAD', url: body}};
  }
  var headers = args.__response.headers || {};
  var length = parseInt(headers['content-length'] || headers['Content-Length'], 10);
  var url = pendingStreamUrl;
  pendingStreamUrl = null;
  var seconds = (song.durationMs || 0) / 1000;
  // The placeholder is 181 KB for an 11 s clip; a real song cannot be smaller
  // than 4 KB per second of playing time (that is 32 kbps).
  var floor = seconds > 0 ? seconds * 4000 : 512 * 1024;
  if (length > 0 && length < floor) {
    return {ok: true, previewUrl: url};
  }
  // Kuwo's CDN plays bare: no Referer, no Range gate.
  return {ok: true, url: url};
}

// '[mm:ss.xx]line' — Kuwo gives time as a float string of seconds.
function stamp(seconds) {
  var t = parseFloat(seconds);
  if (!isFinite(t) || t < 0) t = 0;
  var total = Math.round(t * 100) / 100;
  var minutes = Math.floor(total / 60);
  var rest = total - minutes * 60;
  var secs = Math.floor(rest);
  var cents = Math.round((rest - secs) * 100);
  if (cents === 100) { cents = 0; secs += 1; }
  if (secs === 60) { secs = 0; minutes += 1; }
  function pad(n) { return n < 10 ? '0' + n : '' + n; }
  return '[' + pad(minutes) + ':' + pad(secs) + '.' + pad(cents) + ']';
}

// The lyric endpoint unpredictably answers {"data":null,"status":301,
// "msg":"音乐查询失败"} for a track that has lyrics (measured ~1 in 2 first
// tries on 2026-11-19); an immediate retry usually answers. Retry a few
// times, then treat it as "no lyrics" rather than failing the row.
//
// The attempt count lives in this sandbox, not in args: the host re-encodes
// its own copy of args for every call, so a field the plugin writes onto args
// is not carried to the next round trip. The host serialises calls per plugin,
// so one counter is safe.
var lyricRetries = 0;

function lyrics(args) {
  var song = args.song || {};
  var musicId = numericId(song);
  if (!args.__response) {
    lyricRetries = 0;
    if (!musicId) return {ok: true, lrc: ''};
    return {http: {
      method: 'GET',
      url: 'https://m.kuwo.cn/newh5/singles/songinfoandlrc?musicId=' +
           encodeURIComponent(musicId),
    }};
  }
  var data = null;
  try {
    data = JSON.parse(args.__response.body || '');
  } catch (e) {
    data = null;
  }
  var list = data && data.data && data.data.lrclist;
  if (!list && lyricRetries < 3) {
    lyricRetries++;
    return {http: {
      method: 'GET',
      url: 'https://m.kuwo.cn/newh5/singles/songinfoandlrc?musicId=' +
           encodeURIComponent(musicId),
    }};
  }
  if (!list || !list.length) return {ok: true, lrc: ''};
  var lines = [];
  for (var i = 0; i < list.length; i++) {
    var line = list[i];
    if (!line || line.lineLyric == null) continue;
    var text = String(line.lineLyric);
    if (!text.replace(/\s+/g, '')) continue;
    lines.push(stamp(line.time) + text);
  }
  return {ok: true, lrc: lines.join('\n')};
}

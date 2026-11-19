// Kugou Music provider for GroovyBox.
//
// Contract: every function is synchronous. To reach the network it returns
// {http: {...}}; the host performs the request and calls the same function
// again with args.__response = {status, headers, body}. The host re-encodes
// its own args for every round trip, so anything a chain has to remember
// between steps lives in a module global here (the host serialises calls per
// plugin, which is what makes that safe).
//
// Endpoints (all verified 2026-11-19):
//   search      https://mobileservice.kugou.com/api/v3/search/song?keyword=&page=1&pagesize=
//               -> data.info[] with hash, sqhash, 320hash, songname,
//                  singername, album_id, album_name, duration (seconds) and
//                  trans_param.union_cover (a cover URL containing {size}).
//   albumSongs  https://mobileservice.kugou.com/api/v3/album/song?albumid=&page=1&pagesize=
//               -> data.info[] with filename ("ARTIST - TITLE"), songname
//                  (null here), hash, duration, album_id.
//   stream      https://trackercdn.kugou.com/i/v2/?key=md5(hash + 'kgcloudv2')
//               &hash=&appid=1005&pid=2&cmd=25&behavior=play&album_id=
//               -> status 1 with url[] for a playable quality, status 2 with
//                  no url for one this client may not have. Tried sq -> 320
//                  -> 128, then the 60-second clip hash as the trial.
//   lyrics      https://krcs.kugou.com/search?...&hash= -> candidates[0]
//               {id, accesskey} -> http://lyrics.kugou.com/download?...
//               whose content is base64 LRC.

var API = 'https://mobileservice.kugou.com/api/v3';
var TRACKER = 'https://trackercdn.kugou.com/i/v2/';
var LYRICS = 'https://lyrics.kugou.com/download';
// The salt Kugou appends before hashing a tracker key.
var SALT = 'kgcloudv2';

// Which hash the next __response answers, and what the chain has tried.
// {step: 'sq'|'320'|'128'|'clip', tried: [...], song: {...}}
var STREAM = null;

// ---- host helpers ----------------------------------------------------------

function md5(value) {
  return sendMessage('api:groovybox:md5', JSON.stringify({value: value}));
}

// The tracker only answers for the lower-case spelling of a hash.
function lower(value) {
  return String(value === null || value === undefined ? '' : value).toLowerCase();
}

function text(value) {
  return value === null || value === undefined ? '' : String(value);
}

function trimmed(value) {
  return text(value).replace(/^\s+|\s+$/g, '');
}

// ---- mapping ---------------------------------------------------------------

// `trans_param.union_cover` is the one cover the API always fills in, and it
// already carries a {size} token; `album_sizable_cover` is the fallback for
// the answers that still include it.
function coverOf(item) {
  var trans = item.trans_param || {};
  var cover = trans.union_cover || item.album_sizable_cover ||
              item.album_cover || trans.union_cover_big;
  if (!cover) return null;
  var url = String(cover);
  if (url.indexOf('//') === 0) url = 'https:' + url;
  // Cover images answer on both schemes; https keeps the app free of a
  // cleartext exception on platforms that have none.
  if (url.indexOf('http://') === 0) url = 'https://' + url.substring(7);
  return url;
}

function seconds(value) {
  var n = parseInt(value, 10);
  return n > 0 ? n * 1000 : undefined;
}

// Kugou's album listing has no song title, only `filename` in
// "Artist - Title" form. A filename without a separator is the whole title.
function splitFilename(item) {
  var name = trimmed(item.filename);
  if (!name) return {title: trimmed(item.songname), artist: trimmed(item.singername)};
  var dash = name.indexOf(' - ');
  if (dash < 0) return {title: name, artist: trimmed(item.singername)};
  return {
    artist: name.substring(0, dash),
    title: name.substring(dash + 3),
  };
}

// The three qualities encoded in one opaque id, because the song model has no
// field for them: `<hash>|<sqhash>|<320hash>|<album_id>|<clip_hash>`. Ids are
// opaque to the app, and `|` never appears in a Kugou hash.
function encodeId(item) {
  return [
    lower(item.hash),
    lower(item.sqhash),
    lower(item['320hash']),
    text(item.album_id),
    lower((item.trans_param || {}).hash_offset
      ? (item.trans_param.hash_offset || {}).clip_hash
      : item.clip_hash),
  ].join('|');
}

function decodeId(id) {
  var parts = text(id).split('|');
  return {
    hash: parts[0] || '',
    sqhash: parts[1] || '',
    hash320: parts[2] || '',
    albumId: parts[3] || '',
    clip: parts[4] || '',
  };
}

function toSong(item) {
  var named = splitFilename(item);
  var song = {
    id: encodeId(item),
    title: trimmed(item.songname) || named.title,
    artist: trimmed(item.singername) || named.artist,
  };
  if (!song.title) return null;
  var hash = (item.trans_param || {}).hash_offset || {};
  if (hash.artist_id) song.artistId = text(hash.artist_id);
  var album = trimmed(item.album_name);
  if (album) song.album = album;
  if (item.album_id && text(item.album_id) !== '0') song.albumId = text(item.album_id);
  var cover = coverOf(item);
  if (cover) song.artId = cover;
  var ms = seconds(item.duration);
  if (ms) song.durationMs = ms;
  var year = parseInt(item.publish_time ? new Date(item.publish_time * 1000).getFullYear() : 0, 10);
  if (year > 1900) song.year = year;
  return song;
}

function songsOf(body, limit) {
  var json;
  try {
    json = JSON.parse(body);
  } catch (error) {
    return {ok: false, error: 'Kugou returned an unreadable answer.'};
  }
  var rows = json && json.data && json.data.info ? json.data.info : [];
  var songs = [];
  for (var i = 0; i < rows.length; i++) {
    if (!rows[i]) continue;
    var song = toSong(rows[i]);
    if (song && song.id && song.title) songs.push(song);
    if (limit > 0 && songs.length >= limit) break;
  }
  return {ok: true, songs: songs};
}

// ---- search ----------------------------------------------------------------

function search(args) {
  var limit = args.limit > 0 ? args.limit : 30;
  if (!args.__response) {
    return {http: {
      method: 'GET',
      url: API + '/search/song?keyword=' + encodeURIComponent(args.query || '') +
           '&page=1&pagesize=' + limit,
    }};
  }
  return songsOf(args.__response.body, limit);
}

// ---- albumSongs ------------------------------------------------------------

function albumSongs(args) {
  if (!args.__response) {
    var albumId = text(args.albumId);
    if (!albumId) return {ok: true, songs: []};
    return {http: {
      method: 'GET',
      url: API + '/album/song?albumid=' + encodeURIComponent(albumId) +
           '&page=1&pagesize=100',
    }};
  }
  return songsOf(args.__response.body, 0);
}

// ---- streamUri -------------------------------------------------------------

function trackerUrl(hash, albumId) {
  return TRACKER + '?key=' + md5(hash + SALT) + '&hash=' + hash +
         '&appid=1005&pid=2&cmd=25&behavior=play&album_id=' +
         encodeURIComponent(albumId || '0');
}

// The qualities in the order they are tried: the best first, because a
// provider that holds the track should not hand over the worst copy of it.
function qualities(song) {
  var list = [];
  if (song.sqhash) list.push({step: 'sq', hash: song.sqhash});
  if (song.hash320) list.push({step: '320', hash: song.hash320});
  if (song.hash) list.push({step: '128', hash: song.hash});
  return list;
}

// Reads one tracker answer: a playable quality carries `url[0]`, a refused one
// carries `status: 2` and nothing else.
function urlOf(body) {
  var json;
  try {
    json = JSON.parse(body);
  } catch (error) {
    return null;
  }
  var urls = json && json.url ? json.url : [];
  for (var i = 0; i < urls.length; i++) {
    if (!urls[i]) continue;
    var url = String(urls[i]);
    // Kugou hands out `http://` file hosts that answer the same over TLS;
    // https keeps playback clear of a cleartext exception.
    if (url.indexOf('http://') === 0) url = 'https://' + url.substring(7);
    return url;
  }
  return null;
}

function streamUri(args) {
  var song = args.song || {};

  if (!args.__response) {
    STREAM = null;
    var id = decodeId(song.id);
    if (!id.hash && !id.clip) return {ok: false, error: 'This Kugou track has no hash.'};
    STREAM = {song: id, queue: qualities(id), step: 'quality'};
    return nextStreamRequest();
  }

  if (!STREAM) return {ok: false, error: 'Kugou answered a request this stream did not make.'};
  var url = urlOf(args.__response.body);

  if (STREAM.step === 'quality') {
    if (url) {
      STREAM = null;
      return {ok: true, url: url};
    }
    return nextStreamRequest();
  }

  // The clip is Kugou's own trial excerpt: the track is behind its paywall but
  // the first sixty seconds are playable, which is what the app falls back
  // past when another connected library has the whole recording.
  STREAM = null;
  if (url) return {ok: true, previewUrl: url};
  return {ok: false, error: 'Kugou has no stream for this track.'};
}

// The next request the chain owes: the next untried quality, then the clip.
function nextStreamRequest() {
  while (STREAM.queue.length > 0) {
    var next = STREAM.queue.shift();
    if (next.hash) {
      STREAM.step = 'quality';
      return {http: {
        method: 'GET',
        url: trackerUrl(next.hash, STREAM.song.albumId),
      }};
    }
  }
  if (STREAM.song.clip) {
    STREAM.step = 'clip';
    return {http: {
      method: 'GET',
      url: trackerUrl(STREAM.song.clip, '0'),
    }};
  }
  STREAM = null;
  return {ok: false, error: 'Kugou has no stream for this track.'};
}

// ---- lyrics ----------------------------------------------------------------

var LYRICS_STATE = null;

// `[mm:ss.xx]line`: the download endpoint already answers LRC, so this only
// has to hand the decoded text on.
function lyrics(args) {
  var song = args.song || {};

  if (!args.__response) {
    LYRICS_STATE = null;
    var id = decodeId(song.id);
    if (!id.hash) return {ok: true, lrc: ''};
    LYRICS_STATE = {hash: id.hash, id: null, accesskey: null, step: 'search'};
    return {http: {
      method: 'GET',
      url: 'https://krcs.kugou.com/search?ver=1&man=yes&client=mobi&keyword=' +
           '&duration=&hash=' + encodeURIComponent(id.hash),
    }};
  }

  if (!LYRICS_STATE) return {ok: true, lrc: ''};

  if (LYRICS_STATE.step === 'search') {
    var found = null;
    try {
      var json = JSON.parse(args.__response.body);
      var candidates = json && json.candidates ? json.candidates : [];
      found = candidates.length ? candidates[0] : null;
    } catch (error) {
      found = null;
    }
    if (!found || !found.id || !found.accesskey) {
      LYRICS_STATE = null;
      return {ok: true, lrc: ''};
    }
    LYRICS_STATE.id = text(found.id);
    LYRICS_STATE.accesskey = text(found.accesskey);
    LYRICS_STATE.step = 'download';
    return {http: {
      method: 'GET',
      url: LYRICS + '?ver=1&client=pc&id=' + encodeURIComponent(LYRICS_STATE.id) +
           '&accesskey=' + encodeURIComponent(LYRICS_STATE.accesskey) +
           '&fmt=lrc&charset=utf8',
    }};
  }

  // The download answers base64 in `content`. Neither engine exposes
  // `base64Decode`/`atob` in the sandbox (checked on JavaScriptCore and
  // QuickJS), so the bytes are read here and decoded as UTF-8: an LRC body is
  // text, and a percent-escape round trip would mangle CJK.
  var lrc = '';
  try {
    var body = JSON.parse(args.__response.body);
    var content = body && body.content ? String(body.content) : '';
    if (content) lrc = utf8FromBase64(content);
  } catch (error) {
    lrc = '';
  }
  LYRICS_STATE = null;
  return {ok: true, lrc: lrc};
}

var B64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';

function utf8FromBase64(input) {
  var clean = String(input).replace(/[^A-Za-z0-9+/=]/g, '');
  var bytes = [];
  var buffer = 0;
  var bits = 0;
  for (var i = 0; i < clean.length; i++) {
    var ch = clean.charAt(i);
    if (ch === '=') break;
    var value = B64.indexOf(ch);
    if (value < 0) continue;
    buffer = (buffer << 6) | value;
    bits += 6;
    if (bits >= 8) {
      bits -= 8;
      bytes.push((buffer >> bits) & 0xff);
    }
  }

  var out = '';
  var index = 0;
  while (index < bytes.length) {
    var byte = bytes[index++];
    if (byte < 0x80) {
      out += String.fromCharCode(byte);
    } else if (byte < 0xe0) {
      out += String.fromCharCode(((byte & 0x1f) << 6) | (bytes[index++] & 0x3f));
    } else if (byte < 0xf0) {
      out += String.fromCharCode(
        ((byte & 0x0f) << 12) |
        ((bytes[index++] & 0x3f) << 6) |
        (bytes[index++] & 0x3f),
      );
    } else {
      var point =
        ((byte & 0x07) << 18) |
        ((bytes[index++] & 0x3f) << 12) |
        ((bytes[index++] & 0x3f) << 6) |
        (bytes[index++] & 0x3f);
      point -= 0x10000;
      out += String.fromCharCode(0xd800 | (point >> 10), 0xdc00 | (point & 0x3ff));
    }
  }
  return out;
}

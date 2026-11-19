// Bilibili plugin — search music uploads and stream their DASH audio.
//
// Bilibili has no music API: a "track" here is a video, because music uploads
// are ordinary videos. Search therefore answers with videos and streamUri reads
// the video's audio track, which is what makes a track paywalled elsewhere
// playable as the copy someone uploaded there.
//
// Both the search and the playurl endpoint are WBI-signed: the query carries
// `wts` (unix seconds) and `w_rid` (md5 of the sorted query + a mixin key), and
// the mixin key is derived from the two image keys in `/x/web-interface/nav`.
//
// Every function is a generator of requests: with no `args.__response` it
// answers `{http: ...}`, the host performs that and calls the function again
// with the answer in `args.__response`. The host re-sends `args` fresh each
// round trip, so a multi-step chain tracks its own progress in the global
// `PENDING`; the host serialises calls per plugin, which makes that safe.

// The desktop UA every request uses, also sent with the stream so the CDN sees
// the same client that asked for the URL.
var UA = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
  + '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

var API = 'https://api.bilibili.com';
var REFERER = 'https://www.bilibili.com/';

// The WBI image keys are stable for a whole session; re-reading them on every
// search would cost a round trip for nothing. The sandbox keeps this global
// across calls.
var KEY_CACHE = {key: '', at: 0};
var KEY_TTL_MS = 30 * 60 * 1000;

// Which request the next `__response` answers: 'nav', 'search', 'view', 'play'.
var PENDING = null;

// The published permutation table: concatenate img_key + sub_key (64 chars),
// keep the 64 characters the table points at, then take the first 32.
var MIXIN_TABLE = [
  46, 47, 18, 2, 53, 8, 23, 32, 15, 50, 10, 31, 58, 3, 45, 35,
  27, 43, 5, 49, 33, 9, 42, 19, 29, 28, 14, 39, 12, 38, 41, 13,
  37, 48, 7, 16, 24, 55, 40, 61, 26, 17, 0, 1, 60, 51, 30, 4,
  22, 25, 54, 21, 56, 59, 6, 63, 57, 62, 11, 36, 20, 34, 44, 52
];

// ---- host helpers ----------------------------------------------------------

// md5 is computed in Dart: the sandbox has no crypto, and the digest must be
// available before the JS call returns.
function md5(value) {
  return sendMessage('api:groovybox:md5', JSON.stringify({value: value}));
}

function log(message) {
  try {
    sendMessage('api:groovybox:log', JSON.stringify({level: 'info', message: message}));
  } catch (error) {
    // Logging is best-effort: a missing channel must not fail a read.
  }
}

// ---- WBI signing -----------------------------------------------------------

// `https://i0.hdslb.com/bfs/wbi/7cd0....png` -> `7cd0...`
function keyOf(url) {
  var path = String(url || '').split('?')[0];
  var name = path.substring(path.lastIndexOf('/') + 1);
  var dot = name.indexOf('.');
  return dot < 0 ? name : name.substring(0, dot);
}

function mixinKey(imgUrl, subUrl) {
  var raw = keyOf(imgUrl) + keyOf(subUrl);
  var out = '';
  for (var i = 0; i < MIXIN_TABLE.length; i++) {
    var index = MIXIN_TABLE[i];
    if (index < raw.length) out += raw.charAt(index);
    if (out.length === 32) break;
  }
  return out;
}

// Bilibili strips `!'()*` from values before hashing and encodes keys and
// values itself; matching both keeps the signature valid for a query that
// carries punctuation (`Don't Stop`) or a space.
function cleaned(value) {
  return String(value).replace(/[!'()*]/g, '');
}

// Answers `k=v&...&w_rid=<md5(query + mixin)>`, keys sorted, values encoded.
function sign(params, mixin) {
  var values = {};
  for (var key in params) {
    if (Object.prototype.hasOwnProperty.call(params, key)) values[key] = params[key];
  }
  values.wts = String(Math.floor(Date.now() / 1000));
  var names = [];
  for (var name in values) {
    if (Object.prototype.hasOwnProperty.call(values, name)) names.push(name);
  }
  names.sort();
  var query = '';
  for (var i = 0; i < names.length; i++) {
    if (i > 0) query += '&';
    query += encodeURIComponent(names[i]) + '=' + encodeURIComponent(cleaned(values[names[i]]));
  }
  return query + '&w_rid=' + md5(query + mixin);
}

function headers() {
  return {'User-Agent': UA, 'Referer': REFERER};
}

function navRequest() {
  PENDING = 'nav';
  return {http: {method: 'GET', url: API + '/x/web-interface/nav', headers: headers()}};
}

// Reads the wbi keys out of a nav answer. `/nav` answers `code:-101` (not signed
// in) while still carrying them, so a non-zero code is not an error here.
function readKeys(body) {
  var json;
  try {
    json = JSON.parse(body);
  } catch (error) {
    return {ok: false, error: 'Bilibili did not return its signing keys.'};
  }
  var img = json.data && json.data.wbi_img ? json.data.wbi_img : null;
  if (!img || !img.img_url || !img.sub_url) {
    return {ok: false, error: 'Bilibili did not return its signing keys.'};
  }
  KEY_CACHE = {key: mixinKey(img.img_url, img.sub_url), at: Date.now()};
  return {ok: true};
}

// True while the cached key is fresh enough to skip the nav round trip.
function hasKey() {
  return !!KEY_CACHE.key && (Date.now() - KEY_CACHE.at) < KEY_TTL_MS;
}

// Decodes a JSON answer whose `code` must be 0; any other answer is the error
// the read reports.
function decode(answer, what) {
  var status = answer && answer.status ? answer.status : 0;
  if (status >= 400) {
    return {ok: false, error: 'Bilibili returned HTTP ' + status + ' for ' + what + '.'};
  }
  var json;
  try {
    json = JSON.parse(answer ? answer.body : '');
  } catch (error) {
    return {ok: false, error: 'Bilibili returned an unreadable answer for ' + what + '.'};
  }
  if (json.code !== 0) {
    return {ok: false, error: 'Bilibili said: ' + (json.message || ('code ' + json.code)) + '.'};
  }
  return {ok: true, data: json.data || {}};
}

// ---- mapping helpers -------------------------------------------------------

// Search titles carry `<em class="keyword">` around the matched words and HTML
// entities where the uploader typed punctuation.
function plainText(html) {
  return String(html === undefined || html === null ? '' : html)
    .replace(/<[^>]*>/g, '')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&nbsp;/g, ' ')
    .replace(/&amp;/g, '&')
    .trim();
}

// `4:30` or `1:04:30` -> milliseconds; a bare number is already seconds.
function durationMs(value) {
  if (value === null || value === undefined || value === '') return null;
  var text = String(value).trim();
  if (text.indexOf(':') < 0) {
    var seconds = Number(text);
    return isFinite(seconds) && seconds > 0 ? Math.round(seconds * 1000) : null;
  }
  var parts = text.split(':');
  var total = 0;
  for (var i = 0; i < parts.length; i++) total = total * 60 + (Number(parts[i]) || 0);
  return total > 0 ? Math.round(total * 1000) : null;
}

// Protocol-relative covers (`//i0.hdslb.com/...`) become https URLs. Bilibili
// serves one image size, so the URL carries no `{size}` token.
function coverUrl(pic) {
  if (!pic) return null;
  var url = String(pic);
  if (url.indexOf('//') === 0) return 'https:' + url;
  if (url.indexOf('http://') === 0) return 'https://' + url.substring(7);
  return url;
}

function yearOf(pubdate) {
  var seconds = Number(pubdate);
  if (!isFinite(seconds) || seconds <= 0) return null;
  return new Date(seconds * 1000).getFullYear();
}

// One `data.result[]` entry -> the contract's song shape.
function toSong(item) {
  var song = {id: String(item.bvid), title: plainText(item.title), artist: plainText(item.author)};
  if (item.mid) song.artistId = String(item.mid);
  var art = coverUrl(item.pic);
  if (art) song.artId = art;
  var ms = durationMs(item.duration);
  if (ms) song.durationMs = ms;
  var year = yearOf(item.pubdate);
  if (year) song.year = year;
  return song;
}

// ---- search ----------------------------------------------------------------

function searchRequest(query) {
  PENDING = 'search';
  var signed = sign({search_type: 'video', keyword: query, page: 1}, KEY_CACHE.key);
  return {http: {
    method: 'GET',
    url: API + '/x/web-interface/wbi/search/type?' + signed,
    headers: headers()
  }};
}

function search(args) {
  var query = args.query === undefined || args.query === null ? '' : String(args.query);

  if (!args.__response) {
    PENDING = null;
    if (!hasKey()) return navRequest();
    return searchRequest(query);
  }

  if (PENDING === 'nav') {
    var keys = readKeys(args.__response.body);
    if (!keys.ok) return keys;
    return searchRequest(query);
  }
  if (PENDING !== 'search') {
    return {ok: false, error: 'Bilibili answered a request this search did not make.'};
  }

  var answer = decode(args.__response, 'the search');
  if (!answer.ok) return answer;
  var rows = answer.data.result || [];
  var songs = [];
  for (var i = 0; i < rows.length; i++) {
    // The endpoint can also answer with a non-video row; only videos stream.
    if (rows[i] && rows[i].bvid && rows[i].type === 'video') songs.push(toSong(rows[i]));
  }
  var limit = Number(args.limit);
  if (limit > 0 && songs.length > limit) songs = songs.slice(0, limit);
  log('search "' + query + '" -> ' + songs.length + ' videos');
  return {ok: true, songs: songs};
}

// ---- streamUri -------------------------------------------------------------

function viewRequest(bvid) {
  PENDING = 'view';
  return {http: {
    method: 'GET',
    url: API + '/x/web-interface/view?bvid=' + encodeURIComponent(bvid),
    headers: headers()
  }};
}

function playRequest(bvid, cid) {
  PENDING = 'play';
  var signed = sign({bvid: bvid, cid: cid, fnval: 16}, KEY_CACHE.key);
  return {http: {
    method: 'GET',
    url: API + '/x/player/wbi/playurl?' + signed,
    headers: headers()
  }};
}

// Picks the richest audio track: `audio[0]` is the smallest quality (64 kbps)
// and the list is unordered in practice, so the highest `bandwidth` is the one
// worth playing. Its `baseUrl` is the address; `backupUrl[0]` is used only
// when the base is empty.
function audioUrl(dash) {
  var audio = dash && dash.audio ? dash.audio : [];
  var pick = null;
  for (var i = 0; i < audio.length; i++) {
    var track = audio[i] || {};
    if (!pick || (track.bandwidth || 0) > pick.bandwidth) {
      pick = {track: track, bandwidth: track.bandwidth || 0};
    }
  }
  if (!pick) return null;
  var url = pick.track.baseUrl || pick.track.base_url || '';
  if (!url) {
    var backups = pick.track.backupUrl || pick.track.backup_url || [];
    url = backups.length ? backups[0] : '';
  }
  if (!url) return null;
  // The CDN hands out http addresses; https answers the same and plays in every
  // client without an ATS exception.
  return url.indexOf('http://') === 0 ? 'https://' + url.substring(7) : String(url);
}

function streamUri(args) {
  var song = args.song || {};
  var bvid = song.id ? String(song.id) : '';

  if (!args.__response) {
    PENDING = null;
    if (!bvid) return {ok: false, error: 'This copy has no Bilibili video id.'};
    if (!hasKey()) return navRequest();
    return viewRequest(bvid);
  }

  if (PENDING === 'nav') {
    var keys = readKeys(args.__response.body);
    if (!keys.ok) return keys;
    return viewRequest(bvid);
  }
  if (PENDING === 'view') {
    var view = decode(args.__response, 'the video');
    if (!view.ok) return view;
    var pages = view.data.pages || [];
    var cid = view.data.cid || (pages.length ? pages[0].cid : null);
    if (!cid) return {ok: false, error: 'This video has no playable part.'};
    return playRequest(bvid, String(cid));
  }
  if (PENDING === 'play') {
    var play = decode(args.__response, 'the audio');
    if (!play.ok) return play;
    var url = audioUrl(play.data.dash);
    if (!url) {
      return {ok: false, error: 'Bilibili offers this video without a streamable audio track.'};
    }
    // The CDN answered 206 without these headers, but a bare request is the
    // shape that gets refused when Bilibili tightens its hotlink rules.
    return {ok: true, url: url, headers: {'Referer': REFERER, 'User-Agent': UA}};
  }

  return {ok: false, error: 'Bilibili answered a request this stream did not make.'};
}

# GroovyBox plugins

Example library plugins. **None of these are bundled with the app.** The
binary contains no third-party resolver: `plugins/` is not listed under
`flutter.assets`, so `flutter build` never ships it. If someone adds it there,
the app would ship resolvers it cannot licence, which is the one thing this
folder exists to avoid.

A plugin is a folder with `manifest.json` and `main.js`. Install one from
**Settings → Plugins → Install from folder…**; the app copies it into its own
plugins directory (`{appSupport}/plugins/<plugin id>`), loads it, and every
provider it declares becomes a library you can connect like any other.

## The three examples

|Folder|Provider|What it does|
|---|---|---|
|`kugou/`|Kugou Music|Search, stream (sq → 320 → 128), lyrics|
|`kuwo/`|Kuwo Music|Search, stream, lyrics|
|`bilibili/`|Bilibili|WBI-signed video search, DASH audio stream with a `Referer` header|

Each was written against the live service in November 2026 and answers today.
A service that changes its API breaks its plugin, not the app: the row shows
the plugin's own failure and every other library keeps working.

## Writing your own

### manifest.json

```json
{
  "id": "dev.example.myprovider",
  "name": "My provider",
  "version": "1.0.0",
  "entry": "main.js",
  "permissions": ["networkInternet"],
  "providers": [
    {
      "id": "myprovider",
      "name": "My provider",
      "requiresAuth": false,
      "functions": ["search", "streamUri", "lyrics"]
    }
  ]
}
```

The first four keys are the runtime's own manifest. `providers` is GroovyBox's
addition: one entry per connectable library. `functions` names the contract
functions you implement — omit it to mean "all of them", or list a subset so
the app answers the rest with emptiness instead of calling a function you never
wrote. The ids under `dev.groovybox.*` belong to the plugins above; pick your
own reverse-domain id.

### main.js

JS runs in a sandbox and is **synchronous**: no `await`, no `fetch`, no
`XMLHttpRequest`. To reach the network, a function returns a request; the host
performs it and calls the same function again with the answer attached:

```js
function search(args) {
  if (!args.__response) {
    return {http: {
      method: 'GET',
      url: 'https://api.example.com/search?q=' + encodeURIComponent(args.query),
    }};
  }
  var body = JSON.parse(args.__response.body);
  return {ok: true, songs: body.results.map(function (row) {
    return {
      id: String(row.id),
      title: row.title,
      artist: row.artist,
      durationMs: row.duration * 1000,
      artId: row.cover,           // a full URL; `{size}` is replaced by the app
    };
  })};
}
```

`args.__response` is `{status, headers, body}`; the body is always plain text,
because not every service answers JSON (Kuwo answers a JavaScript object
literal, Bilibili strips punctuation from signed queries). A call may make up
to 8 requests; keep a multi-step chain in a module-level variable or in your
own field on `args` (`args.__step = 2`), which the host re-sends on every round
trip.

Answers are `{ok: true, ...}` or `{ok: false, error: 'human text'}`. Never
throw: the app shows the error string under the library row.

### Contract

|Function|Argument|Answer|
|---|---|---|
|`search`|`{query, limit}`|`{ok, songs}`|
|`albumSongs`|`{albumId}`|`{ok, songs}`|
|`albums`|`{limit, offset}`|`{ok, albums}`|
|`album`|`{albumId}`|`{ok, album}`|
|`playlists`|`{}`|`{ok, playlists}`|
|`playlistSongs`|`{playlistId}`|`{ok, songs}`|
|`artists`|`{}`|`{ok, artists}`|
|`artistAlbums`|`{artistId}`|`{ok, albums}`|
|`recentlyAdded`|`{limit}`|`{ok, albums}`|
|`randomSongs`|`{size}`|`{ok, songs}`|
|`streamUri`|`{song}`|`{ok, url, headers?}` or `{ok, previewUrl}`|
|`lyrics`|`{song}`|`{ok, lrc}` (`''` = none)|
|`connect`|`{baseUrl, username, password}`|`{ok, auth}`|
|`digest`|`{}`|`{ok, tracks?}`|

Shapes: `song` is `{id, title, artist, artistId?, album?, albumId?, artId?,
durationMs?, track?, discNumber?, year?}`; `album` is `{id, name, artist?,
artistId?, artId?, songCount?, durationMs?, year?}`; `artist` is `{id, name,
artId?, albumCount?}`; `playlist` is `{id, name, owner?, songCount?,
durationMs?, artId?}`.

`streamUri` answering `previewUrl` instead of `url` is how a provider says "the
track is behind a paywall": the app plays that excerpt only when no other
connected library has the full recording, which is the same path a NetEase
paywall takes.

`artId` is a full cover URL, with an optional literal `{size}` that the app
replaces with the pixel size it needs. Bilibili serves a single size, so its
urls carry no token.

### Host calls

Two synchronous functions are available besides your own JS:

```js
sendMessage('api:groovybox:md5', JSON.stringify({value: text})); // hex md5
sendMessage('api:groovybox:log', JSON.stringify({level: 'info', message: text}));
```

`md5` exists because a signature (Kugou's, Bilibili's WBI) has to be computed
before the call returns, and the sandbox has no crypto. Kugou uses it for
`md5(hash + 'kgcloudv2')`; Bilibili for its `w_rid`.

Two globals are set before every call `__groovybox_auth__` (the auth map the
`connect` function returned and the app persisted) and `__groovybox_config__`
(`{baseUrl}`). A plugin that needs a cookie or a token keeps it there:

```js
function connect(args) {
  return {ok: true, auth: {cookie: 'the cookie you signed in with'}};
}
function search(args) {
  var me = __groovybox_auth__ || {};
  ...
}
```

## What a plugin can reach

Only its own sandbox and the two host calls above. It cannot read the user's
other libraries, the filesystem, or the app's database. Its network requests
are made by the app with a 12 s connect / 25 s receive timeout, and each call
is serialised per plugin so two providers cannot interleave their state.

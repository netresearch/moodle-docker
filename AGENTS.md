# Working on this repository

Notes that are not derivable from the code and have each cost a wrong
conclusion at least once.

## Verifying against a running stack

Most checks here are run through Moodle itself, and three of them cannot
return the answer you are looking for unless you set them up correctly. Each
one reported the opposite of the truth before it was noticed.

**Run Moodle's checks as `www-data`, not as root.** `docker exec` defaults to
root, and the `configrw` check calls `is_writable()` on `config.php`, which is
true for root whatever the file mode says. The check can then never pass:

```bash
docker compose exec -T -u www-data moodle php /var/www/html/admin/cli/checks.php
```

**Give the container a `wwwroot` it can resolve.** The `publicpaths` check
fetches `$CFG->wwwroot . '/' . $path` over HTTP. With `MOODLE_URL=http://localhost:8099`,
`localhost` inside the container is the container itself, every request fails,
and a refused path is indistinguishable from a reachable one. In a local test
stack use a name the compose network resolves, such as `http://nginx`.

**`get_update_info()` does not answer "is an update still pending" for a
plugin.** The version comparison in `lib/classes/update/checker.php` sits
behind `if ($component === 'core')`; for plugins the cached API response is
returned unfiltered. Use the plugin manager instead:

```php
\core_plugin_manager::instance()->get_plugin_info($component)->available_updates()
```

**A status code does not say who answered.** When checking whether nginx
refuses a path or hands it to PHP, compare the presence of the `X-Powered-By`
header, not the status: a `pluginfile.php` URL for a file that does not exist
is a 404 either way. This is how two regressions in the deny rules were found
before they shipped.

## nginx

The deny rules in `docker/nginx/nginx.conf` mirror the patterns core's
`report_security` public-paths check probes for — the list lives in
`lib/classes/check/environment/publicpaths.php`, and its own comment suggests
generating web server config from it. When core adds a pattern, add it here.

Two constraints those rules must keep:

- Every rule carries `(?!.*\.php/)`. Moodle serves user content through slash
  arguments on a script, so `/pluginfile.php/.../readme.pdf` and a course
  folder named `behat` are ordinary downloads.
- Refuse the `tests/` tree rather than anything named `behat` or `fixtures`.
  `admin/tool/behat` is an admin tool whose stylesheet and JavaScript are
  served.

`$CFG->routerconfigured` and the `try_files … /r.php` fallback are one setting
in two places and only work together — with the flag off the router prefixes
its own base path with `/r.php` and an unprefixed request no longer matches,
so the rewrite alone answers 404.

The other half fails without an error. With the flag on and no fallback,
Moodle emits links without `/r.php` that never reach the router: depending on
the web server they end in a 404 or, where unknown paths fall back to
`index.php`, on the front page with status 200. The fallback sits in three
locations here: `location /`, the static-file block below, and the `.php`
regex location, because Moodle routes some paths that end in `.php` without a
file behind them (`/lib/exampleshimroute2.php`) and that location wins over
`location /` for them. Change the flag and all three locations together, then
run `admin/cli/checks.php` as described above: its router check requests five
URLs, routed paths and two shims among them, through `$CFG->wwwroot`, so it
needs the resolvable `wwwroot` too. None of those five URLs ends in a static
file extension, so the check passes with the static-file fallback broken;
request a routed `.js` path as well, as the CI step below does.

**A file extension does not mean a file.** Since 5.3 Moodle serves its ES
modules through the router under `.js` paths (`/core/esm/<rev>/bootstrap/bootstrap.js`),
so the static-file location must fall back to `r.php` too, never to `=404`.
With `=404` every page still loads its HTML while bootstrap, the design system
and the navigation fail - visible only in the browser console, not in a status
check of the page. The "Test that module URLs reach the router" step in CI
guards this.

## Database dumps

**Dump from inside the database container over the socket, without `-h`.**
At initialisation the hardened MariaDB image creates accounts for the
container's own hostname (`root@<container id>` and an anonymous
`''@<container id>`) next to `root@%`. A TCP connection from the container to
its own service name (`-h database`) is matched against those rows. On a
long-lived volume it failed with `ERROR 1045 (28000): Access denied for user
'root'@'<container id>'` while the password in `.env` was right; a freshly
initialised `dhi.io/mariadb:12.3` volume accepted it, so the outcome depends
on the volume's history. Moodle and the `pre_start` hook are not affected:
they connect from their own containers. Without `-h` the client uses the
local socket, and `MYSQL_PWD` keeps the password off the command line:

```bash
(umask 077 && docker compose exec -T database sh -c \
  'MYSQL_PWD="$MARIADB_ROOT_PASSWORD" exec mariadb-dump -u root --single-transaction --quick --default-character-set=utf8mb4 "$1"' \
  _ moodle > moodle.sql.part)
tail -n 1 moodle.sql.part   # must read "-- Dump completed on ..."
mv moodle.sql.part moodle.sql   # only after that line checked out
```

Replace `moodle` with `DB_NAME` from `.env` if you changed it. The dump holds
user data, hence `umask 077`; writing to `moodle.sql.part` first keeps an
earlier `moodle.sql` intact when the dump fails. Keep stderr visible and check
the last line: with `2>/dev/null` this failure once left a
20-byte compressed dump that `gzip -t` accepted, because an empty gzip stream
is valid.

## Upgrades

The Moodle sources ship inside the image, so an upgrade is a new image. The
entrypoint copies them into the code volume and runs
`admin/cli/upgrade.php --non-interactive` itself; a failure aborts the
entrypoint rather than serving a half-upgraded site.

**A new version replaces the code, it is never copied over it.** Moodle's
upgrade refuses to run while files the new version deleted are still on disk
("Mixed Moodle versions detected", `upgrade_stale_php_files_present()` in
`public/lib/upgradelib.php`). An overlay copy passes a patch upgrade and fails every
major one; 5.2.3 to 5.3.0 failed this way. The old tree is moved to
`.moodle-previous` in the code volume, and `moodle-addons.php` decides which of
its plugin directories are add-ons to carry over: absent from the new sources
and not listed as `standard` in the OLD tree's `lib/plugins.json`. The
`deleted` list is the wrong test: it names core plugins removed long ago, such
as `mod_chat`, which a site may have installed again as an add-on. Test an
upgrade on volumes filled by the previous image with an add-on registered in
the database - a fresh install never takes this path, and a lost add-on shows
up only in `admin/cli/uninstall_plugins.php --show-missing` (or as "to be
deleted" when its name is on the `deleted` list).

Code from before 5.1 (a root `lib/` but no `public/version.php`) and a
directory mounted below `/var/www/html` are refused before anything moves; the
volume stays as it was. When `moodle-addons.php` refuses later, after the swap
(no `lib/plugins.json` in the old tree), every start stops at that point with
the old code intact in `.moodle-previous`. The way out is to fix the cause and
start the same image again. Rolling back to the previous image does not help:
its entrypoint ignores `.moodle-previous` and copies its own sources over the
new ones.

**"There is a newer Moodle version available: 5.2.3+" is not an error.** The
notice names the version on offer, not the installed one. The `+` marks a
weekly build of the stable branch after the release tag: `v5.2.3` carries
`2026042003.00` / `5.2.3 (Build: 20260914)`, the `MOODLE_502_STABLE` tip
`2026042003.03` / `5.2.3+ (Build: 20260928)` (measured 2026-09-30, the tag on
the running academy site). No tag exists for such a build, so there is no
5.2.4 to find, and neither Renovate nor the `MOODLE_COMMIT` pin in the
Dockerfile will ever move to it; the pin follows tags on purpose, because a
branch tip makes the image unreproducible. Read Moodle's release notes to see
whether a fix you need is already on the branch, and wait for the next tag.

**Take an add-on's archive from the URL Moodle itself records.**
`get_update_info()` lists, for each version on offer, `download` and
`downloadmd5`; the URL works without a moodle.org login, and the MD5 is the
checksum Moodle expects. It still does not say whether that update is pending
(see "Verifying against a running stack").

```php
\core\update\checker::instance()->get_update_info($component)
```

The sources that look equivalent are not:

- The download link on the plugin's web page answers an unauthenticated
  request with a login page, not a ZIP.
- A GitHub tag archive (`archive/refs/tags/<tag>.tar.gz`) leaves out
  submodules. `mod_hvp` keeps the H5P library in one; its archive was 133 KB
  instead of 59 MB, and the upgrade ran through and only afterwards failed in
  `admin_apply_default_settings()` with `Failed opening required`. A clone
  needs `--recurse-submodules`.
- A plugin's public repository can differ from the build Moodle offers under
  the same release name: another `$plugin->version`, and the site keeps
  reporting the update as available after you installed it.

Before installing, compare the archive's `md5sum` with `downloadmd5` and check
that the directories a submodule fills are not empty (for `mod_hvp`:
`library/` and `editor/`).

`download.moodle.org/api/1.3/pluginfo.php` does not answer whether a plugin
supports a Moodle branch: it returned no versions for `mod_hvp` even for the
branch the plugin was running on. Read "Supports Moodle" on the plugin's page
in the Moodle plugins directory.

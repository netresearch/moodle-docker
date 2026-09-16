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

## Upgrades

The Moodle sources ship inside the image, so an upgrade is a new image. The
entrypoint copies them into the code volume and runs
`admin/cli/upgrade.php --non-interactive` itself; a failure aborts the
entrypoint rather than serving a half-upgraded site.

<?php
// Lists the add-on plugins of a Moodle code tree, as paths relative to it.
//
//   php moodle-addons.php <new-tree> <old-tree>
//
// <new-tree> is the code about to be installed, <old-tree> the code it
// replaces. A directory in <old-tree> counts as an add-on when it is a plugin
// (it has a version.php) under a plugin type directory that <new-tree>
// declares, <new-tree> has no directory of that name there, and the
// lib/plugins.json of <old-tree> does not list it as standard. The last test
// drops a core plugin the new version removed (theme_classic in 5.3) and
// keeps one that core removed earlier and a site installed again from the
// plugins directory (mod_chat, editor_atto): Moodle treats those as add-ons
// too. Plugin types come from lib/components.json and, for subplugin types,
// from each plugin's db/subplugins.json - core plugins and add-ons alike.

if ($argc !== 3) {
    fwrite(STDERR, "usage: php moodle-addons.php <new-tree> <old-tree>\n");
    exit(2);
}
[, $new, $old] = $argv;

function read_json(string $file): array
{
    return json_decode(file_get_contents($file), true, 512, JSON_THROW_ON_ERROR);
}

// Without the old tree's list of standard plugins there is no telling a core
// plugin from an add-on, so refuse rather than guess - unless there is nothing
// to tell apart (a fresh install).
$standard = is_file("$old/lib/plugins.json")
    ? (read_json("$old/lib/plugins.json")['standard'] ?? [])
    : null;

// Plugin type => directory relative to the tree root.
$types = read_json("$new/lib/components.json")['plugintypes'];

// Which tree a subplugin type was taken from. A type declared by a core
// plugin in <new-tree> wins over the same name declared by an add-on.
$origin = array_fill_keys(array_keys($types), 'new');

$addons = [];
$queue = $types;
while ($queue) {
    $type = array_key_first($queue);
    $path = $queue[$type];
    unset($queue[$type]);

    // Collect the subplugin types of every plugin of this type, in whichever
    // tree carries it: a core plugin is in <new-tree>, an add-on only in
    // <old-tree>.
    foreach ([$new, $old] as $tree) {
        foreach (glob("$tree/$path/*/db/subplugins.json") ?: [] as $file) {
            $plugindir = dirname($file, 2);
            $relative = substr($plugindir, strlen($tree) + 1);
            foreach (read_json($file)['subplugintypes'] ?? [] as $subtype => $subpath) {
                $from = $tree === $new ? 'new' : 'old';
                if (!isset($types[$subtype]) || ($origin[$subtype] === 'old' && $from === 'new')) {
                    $types[$subtype] = $queue[$subtype] = "$relative/$subpath";
                    $origin[$subtype] = $from;
                }
            }
        }
    }

    foreach (glob("$old/$path/*", GLOB_ONLYDIR) ?: [] as $dir) {
        $name = basename($dir);
        if (!is_file("$dir/version.php")) {
            continue;
        }
        if (is_dir("$new/$path/$name")) {
            continue;
        }
        if ($standard === null) {
            fwrite(STDERR, "$old/lib/plugins.json is missing, cannot tell core plugins from add-ons\n");
            exit(1);
        }
        if (in_array($name, $standard[$type] ?? [], true)) {
            continue;
        }
        $addons["$path/$name"] = true;
    }
}

// An add-on inside another add-on travels with its parent.
$paths = array_keys($addons);
sort($paths);
$kept = [];
foreach ($paths as $candidate) {
    foreach ($kept as $parent) {
        if (str_starts_with($candidate, "$parent/")) {
            continue 2;
        }
    }
    $kept[] = $candidate;
}

echo $kept ? implode("\n", $kept) . "\n" : '';

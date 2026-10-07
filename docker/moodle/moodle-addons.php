<?php
// Lists the add-on plugins of a Moodle code tree, as paths relative to it.
//
//   php moodle-addons.php <new-tree> <old-tree>
//
// <new-tree> is the code about to be installed, <old-tree> the code it
// replaces. A directory in <old-tree> counts as an add-on when it is a plugin
// (it has a version.php) under a plugin type directory that <new-tree>
// declares, <new-tree> has no directory of that name there, and it is not a
// standard plugin that <new-tree> lists as deleted. Plugin types come from
// lib/components.json and, for subplugin types, from each plugin's
// db/subplugins.json - core plugins and add-ons alike.

if ($argc !== 3) {
    fwrite(STDERR, "usage: php moodle-addons.php <new-tree> <old-tree>\n");
    exit(2);
}
[, $new, $old] = $argv;

function read_json(string $file): array
{
    return json_decode(file_get_contents($file), true, 512, JSON_THROW_ON_ERROR);
}

$deleted = read_json("$new/lib/plugins.json")['deleted'] ?? [];

// Plugin type => directory relative to the tree root.
$types = read_json("$new/lib/components.json")['plugintypes'];

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
                if (!isset($types[$subtype])) {
                    $types[$subtype] = $queue[$subtype] = "$relative/$subpath";
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
        if (in_array($name, $deleted[$type] ?? [], true)) {
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

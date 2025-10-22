#!/usr/bin/env php
<?php
/**
 * Configure Valkey/Redis as Moodle Universal Cache (MUC) store
 *
 * This script programmatically sets up Valkey for application caching
 * Run after Moodle installation: make configure-cache
 */

define('CLI_SCRIPT', true);

require_once('/var/www/html/config.php');
require_once($CFG->libdir.'/clilib.php');

// Get Valkey credentials from environment
$valkey_host = getenv('VALKEY_HOST') ?: 'valkey';
$valkey_port = getenv('VALKEY_PORT') ?: 6379;
$valkey_password = getenv('VALKEY_PASSWORD') ?: '';

cli_heading('Configuring Valkey/Redis for Moodle Universal Cache (MUC)');

// Load cache configuration
$factory = cache_factory::instance();
$config = cache_config::instance();

// Define the Redis store instance
$store_config = array(
    'name' => 'valkey',
    'plugin' => 'redis',
    'configuration' => array(
        'server' => $valkey_host . ':' . $valkey_port,
        'password' => $valkey_password,
        'prefix' => 'muc_',
        'serializer' => 1, // PHP serializer (1), or igbinary (2) if available
        'compressor' => 0, // No compression (0), gzip (1), or zstd (2)
    ),
    'features' => 31, // All features enabled
    'modes' => 3, // Application (1) + Session (2) = 3
    'mappingsonly' => false,
    'class' => 'cachestore_redis',
    'default' => true,
);

// Check if Valkey store already exists
$stores = $config->get_all_stores();
$valkey_exists = false;

foreach ($stores as $store) {
    if ($store['name'] === 'valkey') {
        $valkey_exists = true;
        cli_writeln('Valkey cache store already exists');
        break;
    }
}

if (!$valkey_exists) {
    cli_writeln('Creating Valkey cache store...');

    // Add the store via admin/cli/cfg.php approach
    // Note: We need to manipulate the cache config file directly
    $writer = cache_config_writer::instance();
    $writer->add_store_instance('valkey', 'redis', $store_config['configuration']);

    cli_writeln('✅ Valkey cache store created successfully');
    cli_writeln('   Server: ' . $valkey_host . ':' . $valkey_port);
    cli_writeln('   Database: 1 (separate from sessions on db 0)');
} else {
    cli_writeln('ℹ️  Valkey cache store already configured');
}

// Set Valkey as default application cache
cli_writeln('');
cli_writeln('Setting Valkey as default application cache...');

$writer = cache_config_writer::instance();
$writer->set_mode_mappings(array(
    cache_store::MODE_APPLICATION => array('valkey', 'default_application'),
    cache_store::MODE_SESSION => array('default_session'),
    cache_store::MODE_REQUEST => array('default_request'),
));

cli_writeln('✅ Valkey configured as default application cache');

// Purge all caches to apply changes
cli_writeln('');
cli_writeln('Purging all caches...');
purge_all_caches();

cli_writeln('✅ Cache configuration complete!');
cli_writeln('');
cli_writeln('Verification:');
cli_writeln('  Visit: Site administration → Plugins → Caching → Configuration');
cli_writeln('  You should see Valkey/Redis listed as a cache store');
cli_writeln('');

exit(0);

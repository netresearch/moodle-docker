<?php  // Moodle configuration file

// Moodle 4.5 Configuration for Docker Stack
// This file uses environment variables from .env via docker-compose

unset($CFG);
global $CFG;
$CFG = new stdClass();

// ============================================================================
// Database Configuration
// ============================================================================
$CFG->dbtype    = getenv('DB_TYPE') ?: 'mariadb';
$CFG->dblibrary = 'native';
$CFG->dbhost    = getenv('DB_HOST') ?: 'database';
$CFG->dbname    = getenv('DB_NAME') ?: 'moodle';
$CFG->dbuser    = getenv('DB_USER') ?: 'moodleuser';
$CFG->dbpass    = getenv('DB_PASSWORD') ?: '';
$CFG->prefix    = getenv('DB_PREFIX') ?: 'mdl_';

$CFG->dboptions = array (
    'dbpersist' => 0,
    'dbport' => getenv('DB_PORT') ?: 3306,
    'dbsocket' => '',
    'dbcollation' => 'utf8mb4_unicode_ci',
);

// ============================================================================
// Site Configuration
// ============================================================================
$CFG->wwwroot   = getenv('MOODLE_SITE_URL') ?: 'http://localhost:8080';
$CFG->dataroot  = '/var/moodledata';
$CFG->admin     = 'admin';

$CFG->directorypermissions = 0750;

// ============================================================================
// Valkey Session Configuration (Redis-compatible)
// ============================================================================
$CFG->session_handler_class = '\core\session\redis';
$CFG->session_redis_host = getenv('VALKEY_HOST') ?: 'valkey';
$CFG->session_redis_port = getenv('VALKEY_PORT') ?: 6379;
$CFG->session_redis_auth = getenv('VALKEY_PASSWORD') ?: '';
$CFG->session_redis_database = 0;
$CFG->session_redis_prefix = 'moodle_sess_';
$CFG->session_redis_acquire_lock_timeout = 120;
$CFG->session_redis_lock_expire = 7200;

// Alternative: Use file-based sessions (comment out above, uncomment below)
// $CFG->session_handler_class = '\core\session\file';
// $CFG->session_file_save_path = '/var/moodledata/sessions';

// ============================================================================
// Security Settings (Production)
// ============================================================================

// Force login for all pages (optional - set to true if desired)
$CFG->forcelogin = false;

// Clean HTML input
$CFG->forceclean = true;

// Cookie security (set cookiesecure to true when using HTTPS)
$CFG->cookiesecure = false;  // Set to true when using HTTPS/Traefik
$CFG->cookiehttponly = true;

// Prevent execution path manipulation
$CFG->preventexecpath = true;

// SSL proxy support (enable when using Traefik or reverse proxy with HTTPS)
// $CFG->sslproxy = true;

// ============================================================================
// Performance Settings
// ============================================================================

// Enable caching
$CFG->enablecaching = true;

// Cache JavaScript
$CFG->cachejs = true;

// YUI combo loading
$CFG->yuicomboloading = true;

// Theme designer mode (ONLY for theme development, disable in production)
$CFG->themedesignermode = false;

// ============================================================================
// Debug Settings (Production: all disabled)
// ============================================================================
$CFG->debug = 0;                    // No debug messages
$CFG->debugdisplay = 0;             // Don't display errors
@error_reporting(E_ALL | E_STRICT); // Log all errors
@ini_set('display_errors', '0');    // Never display errors

// Development: Uncomment below to enable debugging
// $CFG->debug = (E_ALL | E_STRICT);
// $CFG->debugdisplay = 1;
// @error_reporting(E_ALL | E_STRICT);
// @ini_set('display_errors', '1');

// ============================================================================
// Valkey MUC (Moodle Universal Cache) Configuration
// ============================================================================
// Configure via: Site Administration → Plugins → Caching → Configuration
// Add Redis store with these settings:
//   - Server: valkey:6379
//   - Password: <VALKEY_PASSWORD from .env>
//   - Database: 1 (different from sessions)
//   - Serializer: PHP (or igbinary if installed)
//
// Then map application cache to the Valkey store

// ============================================================================
// Mail Configuration
// ============================================================================
// Configure SMTP via: Site Administration → Server → Email → Outgoing mail
// Or set here:
// $CFG->smtphosts = 'smtp.example.com:587';
// $CFG->smtpsecure = 'tls';
// $CFG->smtpuser = 'noreply@example.com';
// $CFG->smtppass = 'smtp_password';
// $CFG->noreplyaddress = 'noreply@example.com';

// ============================================================================
// Load Moodle Setup
// ============================================================================
require_once(__DIR__ . '/lib/setup.php');

// There is no php closing tag in this file,
// it is intentional because it prevents trailing whitespace problems!

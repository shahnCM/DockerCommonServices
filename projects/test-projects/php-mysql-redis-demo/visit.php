<?php
/**
 * php-mysql-redis-demo
 * Run inside the workstation:  php8.1 visit.php   (or php7.2, php8.3 ...)
 *
 * MySQL:  logs every run as a row (durable history)
 * Redis:  keeps a fast running counter (no DB write per hit)
 *
 * Hostnames are the docker-compose SERVICE NAMES from your repo —
 * that's the whole point of the shared `common` network.
 */

$mysqlHost = getenv('MYSQL_HOST') ?: 'mysql-8';
$redisHost = getenv('REDIS_HOST') ?: 'redis-7';

// ---- MySQL: durable log via PDO ----------------------------------
$pdo = new PDO(
    "mysql:host={$mysqlHost};dbname=app;charset=utf8mb4",
    getenv('MYSQL_USER') ?: 'dev_user',
    getenv('MYSQL_PASSWORD') ?: 'dev_password',
    [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
);

$pdo->exec("CREATE TABLE IF NOT EXISTS visits (
    id INT AUTO_INCREMENT PRIMARY KEY,
    php_version VARCHAR(20),
    visited_at DATETIME DEFAULT CURRENT_TIMESTAMP
)");

$pdo->prepare("INSERT INTO visits (php_version) VALUES (?)")
    ->execute([PHP_VERSION]);

$total = $pdo->query("SELECT COUNT(*) FROM visits")->fetchColumn();

// ---- Redis: fast counter, no schema, no disk write per hit -------
$redis = new Redis();
$redis->connect($redisHost, 6379);
$hits = $redis->incr('php-demo:hits');

// ---- report ------------------------------------------------------
echo "Running on PHP " . PHP_VERSION . "\n";
echo "MySQL  ({$mysqlHost}): {$total} visits logged (durable)\n";
echo "Redis  ({$redisHost}): {$hits} hits counted (fast, in-memory)\n";

echo "\nLast 3 visits from MySQL:\n";
$rows = $pdo->query("SELECT id, php_version, visited_at FROM visits ORDER BY id DESC LIMIT 3");
foreach ($rows as $row) {
    echo "  #{$row['id']}  php {$row['php_version']}  {$row['visited_at']}\n";
}

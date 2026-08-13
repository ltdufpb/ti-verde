<?php
declare(strict_types=1);

/**
 * Green PHP Lab
 *
 * A deliberately small application with function-level hotspots.
 * The slow and fast implementations produce equivalent results.
 */

header('Content-Type: application/json; charset=utf-8');

const MAX_SCALE = 5;

function jsonResponse(array $data, int $status = 200): never
{
    http_response_code($status);
    echo json_encode($data, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES);
    exit;
}

function positiveInt(string $name, int $default, int $max): int
{
    $value = filter_input(INPUT_GET, $name, FILTER_VALIDATE_INT);

    if ($value === false || $value === null) {
        return $default;
    }

    return max(1, min($value, $max));
}

function isPrimeSlow(int $number): bool
{
    if ($number < 2) {
        return false;
    }

    // Intentionally inefficient: tests every possible divisor.
    for ($divisor = 2; $divisor < $number; $divisor++) {
        if ($number % $divisor === 0) {
            return false;
        }
    }

    return true;
}

function isPrimeFast(int $number): bool
{
    if ($number < 2) {
        return false;
    }

    if ($number === 2) {
        return true;
    }

    if ($number % 2 === 0) {
        return false;
    }

    $limit = (int) floor(sqrt($number));

    for ($divisor = 3; $divisor <= $limit; $divisor += 2) {
        if ($number % $divisor === 0) {
            return false;
        }
    }

    return true;
}

function calculatePrimeChecksumSlow(int $limit): array
{
    $sum = 0;
    $count = 0;

    for ($number = 2; $number <= $limit; $number++) {
        if (isPrimeSlow($number)) {
            $sum += $number;
            $count++;
        }
    }

    return ['count' => $count, 'checksum' => $sum];
}

function calculatePrimeChecksumFast(int $limit): array
{
    $sum = 0;
    $count = 0;

    for ($number = 2; $number <= $limit; $number++) {
        if (isPrimeFast($number)) {
            $sum += $number;
            $count++;
        }
    }

    return ['count' => $count, 'checksum' => $sum];
}

function buildTextCorpus(int $paragraphs): array
{
    $base = [
        'Green software reduces unnecessary computation and resource usage.',
        'Repeatable workloads make performance and energy comparisons fair.',
        'A profiler helps developers locate expensive functions in the code.',
        'Energy measurements should be interpreted together with latency and throughput.',
        'Optimizing an algorithm can reduce execution time and operational emissions.',
    ];

    $corpus = [];

    for ($i = 0; $i < $paragraphs; $i++) {
        $corpus[] = $base[$i % count($base)] . ' Sample=' . $i;
    }

    return $corpus;
}

function normalizeSentence(string $sentence): array
{
    $normalized = strtolower($sentence);
    $normalized = preg_replace('/[^a-z0-9\s=]/', ' ', $normalized) ?? '';
    $words = preg_split('/\s+/', trim($normalized)) ?: [];

    return array_values(array_filter(
        $words,
        static fn(string $word): bool => $word !== ''
    ));
}

function countWordsSlow(array $corpus): array
{
    $allWords = [];

    foreach ($corpus as $sentence) {
        foreach (normalizeSentence($sentence) as $word) {
            $allWords[] = $word;
        }
    }

    $uniqueWords = array_values(array_unique($allWords));
    $frequencies = [];

    // Intentionally inefficient: rescans all words for every unique word.
    foreach ($uniqueWords as $uniqueWord) {
        $count = 0;

        foreach ($allWords as $word) {
            if ($word === $uniqueWord) {
                $count++;
            }
        }

        $frequencies[$uniqueWord] = $count;
    }

    ksort($frequencies);

    return $frequencies;
}

function countWordsFast(array $corpus): array
{
    $frequencies = [];

    foreach ($corpus as $sentence) {
        foreach (normalizeSentence($sentence) as $word) {
            $frequencies[$word] = ($frequencies[$word] ?? 0) + 1;
        }
    }

    ksort($frequencies);

    return $frequencies;
}

function textChecksum(array $frequencies): string
{
    return hash('sha256', json_encode($frequencies, JSON_UNESCAPED_SLASHES));
}

function executeCpuWorkload(string $implementation, int $scale): array
{
    $limit = 2500 * $scale;

    $result = $implementation === 'slow'
        ? calculatePrimeChecksumSlow($limit)
        : calculatePrimeChecksumFast($limit);

    return [
        'limit' => $limit,
        'prime_count' => $result['count'],
        'checksum' => (string) $result['checksum'],
    ];
}

function executeTextWorkload(string $implementation, int $scale): array
{
    $paragraphs = 300 * $scale;
    $corpus = buildTextCorpus($paragraphs);

    $frequencies = $implementation === 'slow'
        ? countWordsSlow($corpus)
        : countWordsFast($corpus);

    return [
        'paragraphs' => $paragraphs,
        'unique_words' => count($frequencies),
        'checksum' => textChecksum($frequencies),
    ];
}

function wpLoadAllOptionsSlow(int $count): array
{
    $options = [];
    for ($i = 0; $i < $count; $i++) {
        $key = 'wp_option_autoload_' . $i;
        $val = serialize(['id' => $i, 'data' => str_repeat('wp_setting_', 20), 'autoload' => true]);
        $unserialized = unserialize($val);
        $options[$key] = $unserialized['data'];
    }
    return $options;
}

function wpLoadAllOptionsFast(int $count): array
{
    static $cached = null;
    if ($cached !== null) {
        return $cached;
    }
    $options = [];
    for ($i = 0; $i < $count; $i++) {
        $options['wp_option_autoload_' . $i] = 'wp_setting_20';
    }
    $cached = $options;
    return $cached;
}

function wpQueryGetPostsSlow(int $postsCount): array
{
    $posts = [];
    for ($i = 0; $i < $postsCount; $i++) {
        $meta = [];
        for ($m = 0; $m < 15; $m++) {
            $meta['key_' . $m] = hash('sha256', 'post_meta_' . $i . '_' . $m);
        }
        $posts[] = [
            'id' => $i,
            'title' => 'WordPress Post Title ' . $i,
            'content' => '<!-- wp:paragraph --><p>Welcome to WordPress post ' . $i . ' with [custom_shortcode id=' . $i . ']</p><!-- /wp:paragraph -->',
            'meta' => $meta,
        ];
    }
    return $posts;
}

function wpQueryGetPostsFast(int $postsCount): array
{
    static $cached = null;
    if ($cached !== null) {
        return $cached;
    }
    $posts = [];
    for ($i = 0; $i < $postsCount; $i++) {
        $posts[] = [
            'id' => $i,
            'title' => 'WordPress Post Title ' . $i,
            'content' => '<!-- wp:paragraph --><p>Welcome to WordPress post ' . $i . ' with [custom_shortcode id=' . $i . ']</p><!-- /wp:paragraph -->',
            'meta' => ['key_0' => hash('sha256', 'post_meta_' . $i . '_0')],
        ];
    }
    $cached = $posts;
    return $cached;
}

function wpApplyFiltersSlow(string $tag, string $value, int $iterations): string
{
    for ($i = 0; $i < $iterations; $i++) {
        $value = preg_replace('/\[custom_shortcode id=(\d+)\]/', '<strong>Shortcode Rendered $1</strong>', $value) ?? $value;
        $value = strtolower(trim($value));
    }
    return $value;
}

function wpApplyFiltersFast(string $tag, string $value, int $iterations): string
{
    static $cache = [];
    $cacheKey = md5($tag . $value);
    if (isset($cache[$cacheKey])) {
        return $cache[$cacheKey];
    }
    $rendered = str_replace('[custom_shortcode id=', '<strong>Shortcode Rendered ', $value);
    $rendered = str_replace(']', '</strong>', $rendered);
    $rendered = strtolower(trim($rendered));
    $cache[$cacheKey] = $rendered;
    return $rendered;
}

function executeWordpressWorkload(string $implementation, int $scale): array
{
    $optionsCount = 100 * $scale;
    $postsCount = 15 * $scale;
    $filterIterations = 200 * $scale;

    if ($implementation === 'slow') {
        $options = wpLoadAllOptionsSlow($optionsCount);
        $posts = wpQueryGetPostsSlow($postsCount);
        $renderedContent = '';
        foreach ($posts as $post) {
            $renderedContent .= wpApplyFiltersSlow('the_content', $post['content'], $filterIterations);
        }
    } else {
        $options = wpLoadAllOptionsFast($optionsCount);
        $posts = wpQueryGetPostsFast($postsCount);
        $renderedContent = '';
        foreach ($posts as $post) {
            $renderedContent .= wpApplyFiltersFast('the_content', $post['content'], $filterIterations);
        }
    }

    $checksum = hash('sha256', count($options) . count($posts) . strlen($renderedContent));

    return [
        'options_loaded' => count($options),
        'posts_queried' => count($posts),
        'rendered_length' => strlen($renderedContent),
        'checksum' => $checksum,
    ];
}

function executeMixedWorkload(string $implementation, int $scale): array
{
    $cpu = executeCpuWorkload($implementation, $scale);
    $text = executeTextWorkload($implementation, $scale);

    return [
        'cpu' => $cpu,
        'text' => $text,
        'checksum' => hash('sha256', $cpu['checksum'] . $text['checksum']),
    ];
}

$path = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH) ?: '/';

if ($path === '/health') {
    jsonResponse([
        'application' => 'Green PHP Lab',
        'status' => 'ok',
        'php_version' => PHP_VERSION,
    ]);
}

if ($path === '/api/results') {
    $resultsDir = dirname(__DIR__) . '/results';
    $runs = [];
    if (is_dir($resultsDir)) {
        $files = scandir($resultsDir);
        foreach ($files as $file) {
            if ($file !== '.' && $file !== '..' && str_starts_with($file, 'comparison-')) {
                if (is_file("$resultsDir/$file/slow/summary.json") && is_file("$resultsDir/$file/fast/summary.json")) {
                    $runs[] = $file;
                }
            }
        }
    }
    rsort($runs);
    jsonResponse(['runs' => $runs]);
}

if ($path === '/api/file') {
    $fileParam = $_GET['path'] ?? '';
    if (strpos($fileParam, '..') !== false || empty($fileParam)) {
        jsonResponse(['error' => 'Acesso negado'], 403);
    }
    $resultsDir = dirname(__DIR__) . '/results';
    $fullPath = realpath($resultsDir . '/' . $fileParam);
    if (!$fullPath || !str_starts_with($fullPath, $resultsDir) || !is_file($fullPath)) {
        jsonResponse(['error' => 'Arquivo nao encontrado'], 404);
    }
    $ext = pathinfo($fullPath, PATHINFO_EXTENSION);
    $contentTypes = [
        'svg'  => 'image/svg+xml',
        'json' => 'application/json',
        'md'   => 'text/markdown; charset=utf-8',
    ];
    if (!isset($contentTypes[$ext])) {
        jsonResponse(['error' => 'Tipo de arquivo nao suportado'], 400);
    }
    header('Content-Type: ' . $contentTypes[$ext]);
    readfile($fullPath);
    exit;
}

if ($path === '/') {
    header('Content-Type: text/html; charset=utf-8');
    ?>
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Green PHP Lab — Painel Interativo</title>
    <style>
        @import url('https://fonts.googleapis.com/css2?family=Outfit:wght@300;400;500;600;700&display=swap');

        :root {
            --bg-dark: #0b0f19;
            --bg-card: #111827;
            --border-color: rgba(255, 255, 255, 0.06);
            --text-primary: #f3f4f6;
            --text-secondary: #9ca3af;
            --color-green: #10b981;
            --color-blue: #3b82f6;
            --color-red: #ef4444;
        }

        * {
            box-sizing: border-box;
            margin: 0;
            padding: 0;
        }

        body {
            font-family: 'Outfit', sans-serif;
            background-color: var(--bg-dark);
            color: var(--text-primary);
            display: flex;
            height: 100vh;
            overflow: hidden;
        }

        .sidebar {
            width: 320px;
            background-color: #0d1321;
            border-right: 1px solid var(--border-color);
            display: flex;
            flex-direction: column;
            height: 100%;
        }

        .sidebar-header {
            padding: 24px;
            border-bottom: 1px solid var(--border-color);
            display: flex;
            align-items: center;
            gap: 12px;
        }

        .sidebar-header svg {
            width: 28px;
            height: 28px;
            fill: var(--color-green);
        }

        .sidebar-header h1 {
            font-size: 1.25rem;
            font-weight: 600;
            letter-spacing: -0.025em;
            background: linear-gradient(135deg, #34d399 0%, #3b82f6 100%);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
        }

        .runs-list {
            flex: 1;
            overflow-y: auto;
            padding: 16px;
            display: flex;
            flex-direction: column;
            gap: 8px;
        }

        .run-item {
            padding: 14px;
            background-color: var(--bg-card);
            border: 1px solid var(--border-color);
            border-radius: 8px;
            cursor: pointer;
            transition: all 0.2s ease;
            display: flex;
            flex-direction: column;
            gap: 4px;
        }

        .run-item:hover {
            border-color: rgba(16, 185, 129, 0.4);
            background-color: rgba(16, 185, 129, 0.03);
        }

        .run-item.active {
            border-color: var(--color-green);
            background-color: rgba(16, 185, 129, 0.08);
        }

        .run-name {
            font-size: 0.9rem;
            font-weight: 500;
            word-break: break-all;
        }

        .run-date {
            font-size: 0.75rem;
            color: var(--text-secondary);
        }

        .main-content {
            flex: 1;
            display: flex;
            flex-direction: column;
            height: 100%;
            overflow: hidden;
        }

        .top-bar {
            padding: 20px 32px;
            border-bottom: 1px solid var(--border-color);
            display: flex;
            justify-content: space-between;
            align-items: center;
        }

        .top-bar h2 {
            font-size: 1.5rem;
            font-weight: 600;
        }

        .meta-info {
            display: flex;
            gap: 16px;
            font-size: 0.85rem;
        }

        .meta-badge {
            padding: 4px 10px;
            background-color: rgba(255, 255, 255, 0.05);
            border: 1px solid var(--border-color);
            border-radius: 4px;
            color: var(--text-secondary);
        }

        .meta-badge span {
            color: var(--text-primary);
            font-weight: 500;
        }

        .dashboard-grid {
            flex: 1;
            overflow-y: auto;
            padding: 32px;
            display: flex;
            flex-direction: column;
            gap: 32px;
        }

        .metrics-row {
            display: grid;
            grid-template-columns: repeat(4, 1fr);
            gap: 20px;
        }

        .metric-card {
            background-color: var(--bg-card);
            border: 1px solid var(--border-color);
            border-radius: 12px;
            padding: 20px;
            position: relative;
            overflow: hidden;
        }

        .metric-card::before {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            width: 100%;
            height: 3px;
            background: linear-gradient(to right, var(--color-blue), var(--color-green));
            opacity: 0.8;
        }

        .metric-card.reduction::before {
            background: linear-gradient(to right, var(--color-green), #34d399);
        }

        .metric-title {
            font-size: 0.8rem;
            text-transform: uppercase;
            letter-spacing: 0.05em;
            color: var(--text-secondary);
            margin-bottom: 12px;
        }

        .metric-value-container {
            display: flex;
            align-items: baseline;
            justify-content: space-between;
        }

        .metric-value {
            font-size: 1.8rem;
            font-weight: 700;
            color: var(--text-primary);
        }

        .metric-badge {
            font-size: 0.85rem;
            font-weight: 600;
            padding: 2px 8px;
            border-radius: 999px;
            background-color: rgba(16, 185, 129, 0.1);
            color: var(--color-green);
            border: 1px solid rgba(16, 185, 129, 0.2);
        }

        .metric-details {
            margin-top: 14px;
            font-size: 0.8rem;
            color: var(--text-secondary);
            display: flex;
            flex-direction: column;
            gap: 4px;
            border-top: 1px solid rgba(255, 255, 255, 0.03);
            padding-top: 10px;
        }

        .detail-line {
            display: flex;
            justify-content: space-between;
        }

        .tabs-row {
            display: flex;
            justify-content: space-between;
            align-items: center;
            border-bottom: 1px solid var(--border-color);
            padding-bottom: 12px;
        }

        .tab-buttons {
            display: flex;
            gap: 12px;
        }

        .tab-btn {
            padding: 8px 18px;
            background: none;
            border: 1px solid transparent;
            color: var(--text-secondary);
            cursor: pointer;
            font-family: inherit;
            font-size: 0.9rem;
            font-weight: 500;
            border-radius: 6px;
            transition: all 0.2s;
        }

        .tab-btn:hover {
            color: var(--text-primary);
            background-color: rgba(255, 255, 255, 0.03);
        }

        .tab-btn.active {
            color: var(--text-primary);
            background-color: rgba(16, 185, 129, 0.1);
            border-color: rgba(16, 185, 129, 0.3);
        }

        .search-tip {
            font-size: 0.8rem;
            color: var(--text-secondary);
            display: flex;
            align-items: center;
            gap: 6px;
            background-color: rgba(59, 130, 246, 0.06);
            border: 1px solid rgba(59, 130, 246, 0.15);
            padding: 6px 12px;
            border-radius: 6px;
        }

        .search-tip svg {
            width: 14px;
            height: 14px;
            fill: var(--color-blue);
        }

        .flamegraphs-container {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 24px;
            flex: 1;
            min-height: 520px;
        }

        .flamegraph-panel {
            background-color: var(--bg-card);
            border: 1px solid var(--border-color);
            border-radius: 12px;
            display: flex;
            flex-direction: column;
            overflow: hidden;
            box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.3);
        }

        .panel-header {
            padding: 14px 20px;
            background: linear-gradient(to right, rgba(255, 255, 255, 0.02), transparent);
            border-bottom: 1px solid var(--border-color);
            display: flex;
            justify-content: space-between;
            align-items: center;
        }

        .panel-title {
            font-size: 0.95rem;
            font-weight: 600;
        }

        .panel-badge {
            font-size: 0.75rem;
            font-weight: 500;
            padding: 2px 8px;
            border-radius: 4px;
        }

        .panel-badge.slow {
            background-color: rgba(239, 68, 68, 0.1);
            color: var(--color-red);
            border: 1px solid rgba(239, 68, 68, 0.2);
        }

        .panel-badge.fast {
            background-color: rgba(16, 185, 129, 0.1);
            color: var(--color-green);
            border: 1px solid rgba(16, 185, 129, 0.2);
        }

        .flamegraph-body {
            flex: 1;
            background-color: #1e1e24;
            display: flex;
            align-items: center;
            justify-content: center;
            position: relative;
            min-height: 400px;
        }

        .flamegraph-body object {
            width: 100%;
            height: 100%;
            border: none;
            display: block;
        }

        .welcome-container {
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            height: 100%;
            padding: 48px;
            text-align: center;
        }

        .welcome-icon {
            width: 64px;
            height: 64px;
            fill: var(--color-green);
            margin-bottom: 24px;
        }

        .welcome-title {
            font-size: 1.8rem;
            font-weight: 700;
            margin-bottom: 12px;
        }

        .welcome-desc {
            color: var(--text-secondary);
            max-width: 480px;
            font-size: 0.95rem;
            line-height: 1.5;
        }
    </style>
</head>
<body>
    <div class="sidebar">
        <div class="sidebar-header">
            <svg viewBox="0 0 24 24">
                <path d="M17,8C8,10 5.9,16.17 3.82,21.34L5.71,22L6.66,19.7C7.14,19.87 7.64,20 8,20C19,20 22,3 22,3C22,3 21,5 17,8M16,11C13.5,12.38 10.74,14.24 8.71,16.27C8.13,16.85 7.67,17.47 7.31,18.1L12.05,13.36C12.44,12.97 12.44,12.33 12.05,11.95C11.66,11.56 11.03,11.56 10.64,11.95L5.9,16.69C5.74,15.75 5.86,14.63 6.38,13.5C7.94,10.06 11.5,8.25 15,7.3C15.6,8.5 16,9.8 16,11Z" />
            </svg>
            <h1>Green PHP Lab</h1>
        </div>
        <div class="runs-list" id="runsList">
            <!-- Rodadas carregadas dinamicamente -->
        </div>
    </div>
    <div class="main-content" id="mainContent">
        <div class="welcome-container" id="welcomeView">
            <svg class="welcome-icon" viewBox="0 0 24 24">
                <path d="M17,8C8,10 5.9,16.17 3.82,21.34L5.71,22L6.66,19.7C7.14,19.87 7.64,20 8,20C19,20 22,3 22,3C22,3 21,5 17,8M16,11C13.5,12.38 10.74,14.24 8.71,16.27C8.13,16.85 7.67,17.47 7.31,18.1L12.05,13.36C12.44,12.97 12.44,12.33 12.05,11.95C11.66,11.56 11.03,11.56 10.64,11.95L5.9,16.69C5.74,15.75 5.86,14.63 6.38,13.5C7.94,10.06 11.5,8.25 15,7.3C15.6,8.5 16,9.8 16,11Z" />
            </svg>
            <h2 class="welcome-title">Painel de Performance e Energia</h2>
            <p class="welcome-desc">Selecione uma execução no menu lateral para visualizar os dados de consumo de energia, emissão de carbono e interagir com os Flamegraphs de CPU e Energia.</p>
        </div>

        <div class="top-bar" style="display: none;" id="dashboardHeader">
            <div>
                <h2 id="runTitle">rodada</h2>
                <div class="meta-info" style="margin-top: 8px;">
                    <div class="meta-badge">Workload: <span id="metaWorkload">-</span></div>
                    <div class="meta-badge">Scale: <span id="metaScale">-</span></div>
                    <div class="meta-badge">Rate: <span id="metaRate">-</span></div>
                    <div class="meta-badge">Duration: <span id="metaDuration">-</span></div>
                </div>
            </div>
        </div>

        <div class="dashboard-grid" style="display: none;" id="dashboardGrid">
            <div class="metrics-row">
                <div class="metric-card reduction">
                    <div class="metric-title">Latência p95</div>
                    <div class="metric-value-container">
                        <div class="metric-value" id="valLatencyPct">-0%</div>
                        <div class="metric-badge">Redução</div>
                    </div>
                    <div class="metric-details">
                        <div class="detail-line"><span>Slow:</span> <span id="valLatencySlow">0 ms</span></div>
                        <div class="detail-line"><span>Fast:</span> <span id="valLatencyFast">0 ms</span></div>
                    </div>
                </div>

                <div class="metric-card reduction">
                    <div class="metric-title">Energia PHP (Processo)</div>
                    <div class="metric-value-container">
                        <div class="metric-value" id="valEnergyPct">-0%</div>
                        <div class="metric-badge">Redução</div>
                    </div>
                    <div class="metric-details">
                        <div class="detail-line"><span>Slow:</span> <span id="valEnergySlow">0 J</span></div>
                        <div class="detail-line"><span>Fast:</span> <span id="valEnergyFast">0 J</span></div>
                    </div>
                </div>

                <div class="metric-card reduction">
                    <div class="metric-title">Emissões de CO2e</div>
                    <div class="metric-value-container">
                        <div class="metric-value" id="valCarbonPct">-0%</div>
                        <div class="metric-badge">Redução</div>
                    </div>
                    <div class="metric-details">
                        <div class="detail-line"><span>Slow:</span> <span id="valCarbonSlow">0 g</span></div>
                        <div class="detail-line"><span>Fast:</span> <span id="valCarbonFast">0 g</span></div>
                    </div>
                </div>

                <div class="metric-card">
                    <div class="metric-title">Requisições & Potência</div>
                    <div class="metric-value-container">
                        <div class="metric-value" id="valRequests">0</div>
                        <div class="metric-badge" style="background-color:rgba(59,130,246,0.1);color:var(--color-blue);border-color:rgba(59,130,246,0.2)">Sucesso</div>
                    </div>
                    <div class="metric-details">
                        <div class="detail-line"><span>Potência Média (Slow):</span> <span id="valPowerSlow">0 W</span></div>
                        <div class="detail-line"><span>Potência Média (Fast):</span> <span id="valPowerFast">0 W</span></div>
                    </div>
                </div>
            </div>

            <div class="tabs-row">
                <div class="tab-buttons">
                    <button class="tab-btn active" onclick="switchTab('cpu')" id="tabBtnCpu">Profiling de CPU</button>
                    <button class="tab-btn" onclick="switchTab('energy')" id="tabBtnEnergy">Profiling de Energia</button>
                </div>
                <div class="search-tip">
                    <svg viewBox="0 0 24 24"><path d="M11,18A7,7 0 0,1 4,11A7,7 0 0,1 11,4A7,7 0 0,1 18,11A7,7 0 0,1 11,18M11,2A9,9 0 0,0 2,11A9,9 0 0,0 11,20C12.44,20 13.8,19.64 15,19L20.5,24.5L22,23L16.5,17.5C17.64,16.3 18,14.94 18,13.5A9,9 0 0,0 11,2M11,5A6,6 0 0,1 17,11A6,6 0 0,1 11,17A6,6 0 0,1 5,11A6,6 0 0,1 11,5Z"/></svg>
                    <span>Dica: clique em "Search" no canto superior direito do Flamegraph para buscar funções (ou aperte Ctrl+F/Cmd+F dentro dele).</span>
                </div>
            </div>

            <div class="flamegraphs-container">
                <div class="flamegraph-panel">
                    <div class="panel-header">
                        <span class="panel-title">Slow (Implementação Lenta)</span>
                        <span class="panel-badge slow">Não Otimizado</span>
                    </div>
                    <div class="flamegraph-body">
                        <object id="fgSlow" type="image/svg+xml" data=""></object>
                    </div>
                </div>

                <div class="flamegraph-panel">
                    <div class="panel-header">
                        <span class="panel-title">Fast (Implementação Otimizada)</span>
                        <span class="panel-badge fast">Otimizado</span>
                    </div>
                    <div class="flamegraph-body">
                        <object id="fgFast" type="image/svg+xml" data=""></object>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <script>
        let currentRun = "";
        let currentType = "cpu";

        async function loadRuns() {
            try {
                const response = await fetch('/api/results');
                const data = await response.json();
                const list = document.getElementById('runsList');
                list.innerHTML = '';
                
                if (data.runs.length === 0) {
                    list.innerHTML = '<div style="color:var(--text-secondary);text-align:center;padding:20px;">Nenhuma medição encontrada. Execute ./measurement/run-comparison.sh para medir.</div>';
                    return;
                }

                data.runs.forEach(run => {
                    const item = document.createElement('div');
                    item.className = 'run-item';
                    
                    const parts = run.split('-');
                    let dateStr = run;
                    if (parts.length === 3) {
                        const yyyymmdd = parts[1];
                        const hhmmss = parts[2];
                        const year = yyyymmdd.substring(0, 4);
                        const month = yyyymmdd.substring(4, 6);
                        const day = yyyymmdd.substring(6, 8);
                        const hour = hhmmss.substring(0, 2);
                        const min = hhmmss.substring(2, 4);
                        const sec = hhmmss.substring(4, 6);
                        dateStr = `${day}/${month}/${year} às ${hour}:${min}:${sec}`;
                    }

                    item.innerHTML = `
                        <div class="run-name">${run}</div>
                        <div class="run-date">${dateStr}</div>
                    `;
                    item.onclick = () => selectRun(run, item);
                    list.appendChild(item);
                });
            } catch (e) {
                console.error("Erro ao buscar resultados:", e);
            }
        }

        async function selectRun(run, element) {
            document.querySelectorAll('.run-item').forEach(el => el.classList.remove('active'));
            element.classList.add('active');
            
            currentRun = run;
            
            document.getElementById('welcomeView').style.display = 'none';
            document.getElementById('dashboardHeader').style.display = 'flex';
            document.getElementById('dashboardGrid').style.display = 'flex';
            
            document.getElementById('runTitle').innerText = run;
            
            try {
                const [slowRes, fastRes] = await Promise.all([
                    fetch(`/api/file?path=${run}/slow/summary.json`),
                    fetch(`/api/file?path=${run}/fast/summary.json`)
                ]);
                const slow = await slowRes.json();
                const fast = await fastRes.json();
                
                document.getElementById('metaWorkload').innerText = slow.workload.workload;
                document.getElementById('metaScale').innerText = slow.workload.scale;
                document.getElementById('metaRate').innerText = slow.workload.rate_requests_per_second + ' rps';
                document.getElementById('metaDuration').innerText = Math.round(slow.measurement_window.duration_seconds) + 's';
                
                const slowLat = slow.workload.request_duration_ms.p95;
                const fastLat = fast.workload.request_duration_ms.p95;
                const latReduction = ((slowLat - fastLat) / slowLat * 100).toFixed(1);
                
                document.getElementById('valLatencySlow').innerText = slowLat.toFixed(2) + ' ms';
                document.getElementById('valLatencyFast').innerText = fastLat.toFixed(2) + ' ms';
                document.getElementById('valLatencyPct').innerText = latReduction + '%';
                
                const slowEnergy = slow.energy.php_process_total_j;
                const fastEnergy = fast.energy.php_process_total_j;
                const energyReduction = ((slowEnergy - fastEnergy) / slowEnergy * 100).toFixed(1);
                
                document.getElementById('valEnergySlow').innerText = slowEnergy.toFixed(4) + ' J';
                document.getElementById('valEnergyFast').innerText = fastEnergy.toFixed(4) + ' J';
                document.getElementById('valEnergyPct').innerText = energyReduction + '%';
                
                const slowCarbon = slow.carbon.php_process_total_g_co2e;
                const fastCarbon = fast.carbon.php_process_total_g_co2e;
                const carbonReduction = ((slowCarbon - fastCarbon) / slowCarbon * 100).toFixed(1);
                
                document.getElementById('valCarbonSlow').innerText = slowCarbon.toFixed(6) + ' g';
                document.getElementById('valCarbonFast').innerText = fastCarbon.toFixed(6) + ' g';
                document.getElementById('valCarbonPct').innerText = carbonReduction + '%';
                
                document.getElementById('valRequests').innerText = slow.workload.successful_requests;
                document.getElementById('valPowerSlow').innerText = slow.energy.php_average_power_w.toFixed(4) + ' W';
                document.getElementById('valPowerFast').innerText = fast.energy.php_average_power_w.toFixed(4) + ' W';
                
                renderFlamegraphs();
                
            } catch (e) {
                console.error("Erro ao carregar dados da rodada:", e);
            }
        }

        function renderFlamegraphs() {
            if (!currentRun) return;
            
            const fgSlow = document.getElementById('fgSlow');
            const fgFast = document.getElementById('fgFast');
            
            fgSlow.setAttribute('data', '');
            fgFast.setAttribute('data', '');
            
            setTimeout(() => {
                if (currentType === 'cpu') {
                    fgSlow.setAttribute('data', `/api/file?path=${currentRun}/slow/cpu-flamegraph.svg`);
                    fgFast.setAttribute('data', `/api/file?path=${currentRun}/fast/cpu-flamegraph.svg`);
                } else {
                    fgSlow.setAttribute('data', `/api/file?path=${currentRun}/slow/energy-flamegraph.svg`);
                    fgFast.setAttribute('data', `/api/file?path=${currentRun}/fast/energy-flamegraph.svg`);
                }
            }, 50);
        }

        function switchTab(type) {
            currentType = type;
            document.getElementById('tabBtnCpu').classList.toggle('active', type === 'cpu');
            document.getElementById('tabBtnEnergy').classList.toggle('active', type === 'energy');
            renderFlamegraphs();
        }

        window.onload = loadRuns;
    </script>
</body>
</html>
    <?php
    exit;
}

if ($path !== '/work') {
    jsonResponse(['error' => 'Route not found'], 404);
}

$workload = $_GET['workload'] ?? 'mixed';
$implementation = $_GET['implementation'] ?? 'slow';
$scale = positiveInt('scale', 1, MAX_SCALE);

if (!in_array($workload, ['cpu', 'text', 'mixed', 'wordpress'], true)) {
    jsonResponse(['error' => 'Invalid workload. Use cpu, text, mixed or wordpress.'], 400);
}

if (!in_array($implementation, ['slow', 'fast'], true)) {
    jsonResponse(['error' => 'Invalid implementation. Use slow or fast.'], 400);
}

$start = hrtime(true);
$memoryBefore = memory_get_usage(true);

$result = match ($workload) {
    'cpu' => executeCpuWorkload($implementation, $scale),
    'text' => executeTextWorkload($implementation, $scale),
    'wordpress' => executeWordpressWorkload($implementation, $scale),
    default => executeMixedWorkload($implementation, $scale),
};

$elapsedNanoseconds = hrtime(true) - $start;
$memoryAfter = memory_get_usage(true);

jsonResponse([
    'workload' => $workload,
    'implementation' => $implementation,
    'scale' => $scale,
    'duration_ms' => round($elapsedNanoseconds / 1_000_000, 3),
    'memory_delta_bytes' => $memoryAfter - $memoryBefore,
    'peak_memory_bytes' => memory_get_peak_usage(true),
    'result' => $result,
]);

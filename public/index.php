<?php
declare(strict_types=1);

/**
 * Green PHP Lab
 *
 * Micro-aplicação de teste e painel interativo de perfilamento energético.
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

function isPrime(int $number): bool
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

function calculatePrimeChecksum(int $limit): array
{
    $sum = 0;
    $count = 0;

    for ($number = 2; $number <= $limit; $number++) {
        if (isPrime($number)) {
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

function countWords(array $corpus): array
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

function executeCpuWorkload(int $scale): array
{
    $limit = 2500 * $scale;
    $result = calculatePrimeChecksum($limit);

    return [
        'limit' => $limit,
        'prime_count' => $result['count'],
        'checksum' => (string) $result['checksum'],
    ];
}

function executeTextWorkload(int $scale): array
{
    $paragraphs = 300 * $scale;
    $corpus = buildTextCorpus($paragraphs);
    $frequencies = countWords($corpus);

    return [
        'paragraphs' => $paragraphs,
        'unique_words' => count($frequencies),
        'checksum' => textChecksum($frequencies),
    ];
}

function wpLoadAllOptions(int $count): array
{
    $options = [];
    for ($i = 0; $i < $count; $i++) {
        $options['wp_option_autoload_' . $i] = 'wp_setting_' . $i;
    }
    return $options;
}

function wpQueryGetPosts(int $postsCount): array
{
    $posts = [];
    for ($i = 0; $i < $postsCount; $i++) {
        $posts[] = [
            'id' => $i,
            'title' => 'WordPress Post Title ' . $i,
            'content' => '<!-- wp:paragraph --><p>Welcome to WordPress post ' . $i . ' with [custom_shortcode id=' . $i . ']</p><!-- /wp:paragraph -->',
            'meta' => ['key_0' => hash('sha256', 'post_meta_' . $i . '_0')],
        ];
    }
    return $posts;
}

function wpApplyFilters(string $tag, string $value, int $iterations): string
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

function executeWordpressWorkload(int $scale): array
{
    $optionsCount = 100 * $scale;
    $postsCount = 15 * $scale;
    $filterIterations = 200 * $scale;

    $options = wpLoadAllOptions($optionsCount);
    $posts = wpQueryGetPosts($postsCount);
    $renderedContent = '';
    foreach ($posts as $post) {
        $renderedContent .= wpApplyFilters('the_content', $post['content'], $filterIterations);
    }

    $checksum = hash('sha256', count($options) . count($posts) . strlen($renderedContent));

    return [
        'options_loaded' => count($options),
        'posts_queried' => count($posts),
        'rendered_length' => strlen($renderedContent),
        'checksum' => $checksum,
    ];
}

function executeMixedWorkload(int $scale): array
{
    $cpu = executeCpuWorkload($scale);
    $text = executeTextWorkload($scale);

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
            if ($file !== '.' && $file !== '..' && is_dir("$resultsDir/$file")) {
                if (is_file("$resultsDir/$file/summary.json")) {
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
        'csv'  => 'text/csv; charset=utf-8',
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
    <title>Green Energy Lab — Painel de Medição</title>
    <style>
        @import url('https://fonts.googleapis.com/css2?family=Outfit:wght@300;400;500;600;700&display=swap');

        :root {
            --bg-dark: #0b0f19;
            --bg-card: #111827;
            --border-color: rgba(255, 255, 255, 0.08);
            --text-primary: #f3f4f6;
            --text-secondary: #9ca3af;
            --color-green: #10b981;
            --color-blue: #3b82f6;
            --color-amber: #f59e0b;
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
            font-size: 1.4rem;
            font-weight: 600;
        }

        .meta-info {
            display: flex;
            gap: 12px;
            font-size: 0.85rem;
            flex-wrap: wrap;
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
            gap: 28px;
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
            font-size: 0.8rem;
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

        .flamegraph-container {
            width: 100%;
            min-height: 520px;
            display: flex;
            flex-direction: column;
        }

        .flamegraph-panel {
            background-color: var(--bg-card);
            border: 1px solid var(--border-color);
            border-radius: 12px;
            display: flex;
            flex-direction: column;
            overflow: hidden;
            box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.3);
            flex: 1;
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

        .flamegraph-body {
            flex: 1;
            background-color: #1e1e24;
            display: flex;
            align-items: center;
            justify-content: center;
            position: relative;
            min-height: 480px;
        }

        .flamegraph-body object {
            width: 100%;
            height: 100%;
            min-height: 480px;
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
            max-width: 520px;
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
            <h1>Green Energy Lab</h1>
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
            <h2 class="welcome-title">Painel de Medição Energética</h2>
            <p class="welcome-desc">Selecione uma execução no menu lateral para visualizar os dados de consumo de energia, potência, emissão de carbono e interagir com os Flamegraphs de CPU e Energia.</p>
        </div>

        <div class="top-bar" style="display: none;" id="dashboardHeader">
            <div>
                <h2 id="runTitle">rodada</h2>
                <div class="meta-info" style="margin-top: 8px;">
                    <div class="meta-badge">Linguagem: <span id="metaLang">PHP</span></div>
                    <div class="meta-badge">Duração: <span id="metaDuration">-</span></div>
                    <div class="meta-badge">PID Alvo: <span id="metaPid">-</span></div>
                    <div class="meta-badge" id="metaWorkloadBadge" style="display:none;">Workload: <span id="metaWorkload">-</span></div>
                </div>
            </div>
        </div>

        <div class="dashboard-grid" style="display: none;" id="dashboardGrid">
            <div class="metrics-row">
                <div class="metric-card">
                    <div class="metric-title">Energia do Processo</div>
                    <div class="metric-value-container">
                        <div class="metric-value" id="valProcessEnergy">0 J</div>
                        <div class="metric-badge">Processo</div>
                    </div>
                    <div class="metric-details">
                        <div class="detail-line"><span>Dinâmica:</span> <span id="valProcessDynamic">0 J</span></div>
                        <div class="detail-line"><span>Potência Média:</span> <span id="valProcessPower">0 W</span></div>
                    </div>
                </div>

                <div class="metric-card">
                    <div class="metric-title">Energia do Host Total</div>
                    <div class="metric-value-container">
                        <div class="metric-value" id="valHostEnergy">0 J</div>
                        <div class="metric-badge" style="background-color:rgba(59,130,246,0.1);color:var(--color-blue);border-color:rgba(59,130,246,0.2)">Host</div>
                    </div>
                    <div class="metric-details">
                        <div class="detail-line"><span>Host Dinâmico:</span> <span id="valHostDynamic">0 J</span></div>
                        <div class="detail-line"><span>Potência Host:</span> <span id="valHostPower">0 W</span></div>
                    </div>
                </div>

                <div class="metric-card">
                    <div class="metric-title">Emissões de CO2e</div>
                    <div class="metric-value-container">
                        <div class="metric-value" id="valCarbon">0 g</div>
                        <div class="metric-badge" style="background-color:rgba(245,158,11,0.1);color:var(--color-amber);border-color:rgba(245,158,11,0.2)">Carbono</div>
                    </div>
                    <div class="metric-details">
                        <div class="detail-line"><span>Processo:</span> <span id="valCarbonProc">0 g</span></div>
                        <div class="detail-line"><span>Host Total:</span> <span id="valCarbonHost">0 g</span></div>
                    </div>
                </div>

                <div class="metric-card">
                    <div class="metric-title">Carga de Trabalho (k6)</div>
                    <div class="metric-value-container">
                        <div class="metric-value" id="valRequests">N/A</div>
                        <div class="metric-badge">Reqs</div>
                    </div>
                    <div class="metric-details">
                        <div class="detail-line"><span>Latência p95:</span> <span id="valLatencyP95">N/A</span></div>
                        <div class="detail-line"><span>Energia/Req:</span> <span id="valEnergyReq">N/A</span></div>
                    </div>
                </div>
            </div>

            <div class="tabs-row">
                <div class="tab-buttons">
                    <button class="tab-btn active" onclick="switchTab('energy')" id="tabBtnEnergy">Flamegraph de Energia</button>
                    <button class="tab-btn" onclick="switchTab('cpu')" id="tabBtnCpu">Flamegraph de CPU</button>
                </div>
                <div class="search-tip">
                    <svg viewBox="0 0 24 24"><path d="M11,18A7,7 0 0,1 4,11A7,7 0 0,1 11,4A7,7 0 0,1 18,11A7,7 0 0,1 11,18M11,2A9,9 0 0,0 2,11A9,9 0 0,0 11,20C12.44,20 13.8,19.64 15,19L20.5,24.5L22,23L16.5,17.5C17.64,16.3 18,14.94 18,13.5A9,9 0 0,0 11,2M11,5A6,6 0 0,1 17,11A6,6 0 0,1 11,17A6,6 0 0,1 5,11A6,6 0 0,1 11,5Z"/></svg>
                    <span>Dica: clique em "Search" no canto superior direito do Flamegraph para buscar funções (ou aperte Ctrl+F/Cmd+F dentro dele).</span>
                </div>
            </div>

            <div class="flamegraph-container">
                <div class="flamegraph-panel">
                    <div class="panel-header">
                        <span class="panel-title" id="fgPanelTitle">Flamegraph de Energia Atribuída (Microjoules)</span>
                    </div>
                    <div class="flamegraph-body">
                        <object id="fgObject" type="image/svg+xml" data=""></object>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <script>
        let currentRun = "";
        let currentType = "energy";

        async function loadRuns() {
            try {
                const response = await fetch('/api/results');
                const data = await response.json();
                const list = document.getElementById('runsList');
                list.innerHTML = '';
                
                if (!data.runs || data.runs.length === 0) {
                    list.innerHTML = '<div style="color:var(--text-secondary);text-align:center;padding:20px;">Nenhuma medição encontrada. Execute ./run-meter.sh para medir.</div>';
                    return;
                }

                data.runs.forEach(run => {
                    const item = document.createElement('div');
                    item.className = 'run-item';
                    item.innerHTML = `<div class="run-name">${run}</div>`;
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
                const res = await fetch(`/api/file?path=${run}/summary.json`);
                const summary = await res.json();
                
                const win = summary.measurement_window || {};
                const energy = summary.energy || {};
                const carbon = summary.carbon || {};
                const workload = summary.workload || {};
                
                document.getElementById('metaDuration').innerText = (win.duration_seconds ? win.duration_seconds.toFixed(2) + 's' : '-');
                document.getElementById('metaPid').innerText = win.target_pid || '-';
                document.getElementById('metaLang').innerText = (win.language ? win.language.toUpperCase() : 'PHP');
                
                if (workload && workload.workload) {
                    document.getElementById('metaWorkloadBadge').style.display = 'inline-block';
                    document.getElementById('metaWorkload').innerText = workload.workload;
                } else {
                    document.getElementById('metaWorkloadBadge').style.display = 'none';
                }
                
                document.getElementById('valProcessEnergy').innerText = (energy.php_process_total_j || energy.process_total_j || 0).toFixed(4) + ' J';
                document.getElementById('valProcessDynamic').innerText = (energy.php_process_dynamic_j || energy.process_dynamic_j || 0).toFixed(4) + ' J';
                document.getElementById('valProcessPower').innerText = (energy.php_average_power_w || energy.process_average_power_w || 0).toFixed(4) + ' W';
                
                document.getElementById('valHostEnergy').innerText = (energy.host_total_j || 0).toFixed(4) + ' J';
                document.getElementById('valHostDynamic').innerText = (energy.host_dynamic_j || 0).toFixed(4) + ' J';
                document.getElementById('valHostPower').innerText = (energy.host_average_power_w || 0).toFixed(4) + ' W';
                
                const procCarbon = (carbon.php_process_total_g_co2e || carbon.process_total_g_co2e || 0);
                document.getElementById('valCarbon').innerText = procCarbon.toFixed(6) + ' g';
                document.getElementById('valCarbonProc').innerText = procCarbon.toFixed(6) + ' g';
                document.getElementById('valCarbonHost').innerText = (carbon.host_total_g_co2e || 0).toFixed(6) + ' g';
                
                if (workload && workload.successful_requests !== undefined && workload.successful_requests > 0) {
                    document.getElementById('valRequests').innerText = workload.successful_requests;
                    const p95 = workload.request_duration_ms ? workload.request_duration_ms.p95 : null;
                    document.getElementById('valLatencyP95').innerText = p95 ? p95.toFixed(2) + ' ms' : 'N/A';
                    const jPerReq = energy.php_j_per_successful_request || energy.process_j_per_successful_request;
                    document.getElementById('valEnergyReq').innerText = jPerReq ? jPerReq.toFixed(6) + ' J' : 'N/A';
                } else {
                    document.getElementById('valRequests').innerText = 'Carga Externa';
                    document.getElementById('valLatencyP95').innerText = 'N/A';
                    document.getElementById('valEnergyReq').innerText = 'N/A';
                }
                
                renderFlamegraph();
                
            } catch (e) {
                console.error("Erro ao carregar dados da rodada:", e);
            }
        }

        function renderFlamegraph() {
            if (!currentRun) return;
            const fgObject = document.getElementById('fgObject');
            fgObject.setAttribute('data', '');
            
            setTimeout(() => {
                if (currentType === 'cpu') {
                    document.getElementById('fgPanelTitle').innerText = 'Flamegraph de CPU (Amostras de Call Stacks)';
                    fgObject.setAttribute('data', `/api/file?path=${currentRun}/cpu-flamegraph.svg`);
                } else {
                    document.getElementById('fgPanelTitle').innerText = 'Flamegraph de Energia Atribuída (Microjoules)';
                    fgObject.setAttribute('data', `/api/file?path=${currentRun}/energy-flamegraph.svg`);
                }
            }, 50);
        }

        function switchTab(type) {
            currentType = type;
            document.getElementById('tabBtnCpu').classList.toggle('active', type === 'cpu');
            document.getElementById('tabBtnEnergy').classList.toggle('active', type === 'energy');
            renderFlamegraph();
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
$scale = positiveInt('scale', 1, MAX_SCALE);

if (!in_array($workload, ['cpu', 'text', 'mixed', 'wordpress'], true)) {
    jsonResponse(['error' => 'Invalid workload. Use cpu, text, mixed or wordpress.'], 400);
}

$start = hrtime(true);
$memoryBefore = memory_get_usage(true);

$result = match ($workload) {
    'cpu' => executeCpuWorkload($scale),
    'text' => executeTextWorkload($scale),
    'wordpress' => executeWordpressWorkload($scale),
    default => executeMixedWorkload($scale),
};

$elapsedNanoseconds = hrtime(true) - $start;
$memoryAfter = memory_get_usage(true);

jsonResponse([
    'workload' => $workload,
    'scale' => $scale,
    'duration_ms' => round($elapsedNanoseconds / 1_000_000, 3),
    'memory_delta_bytes' => $memoryAfter - $memoryBefore,
    'peak_memory_bytes' => memory_get_peak_usage(true),
    'result' => $result,
]);

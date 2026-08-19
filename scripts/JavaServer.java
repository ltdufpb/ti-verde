import java.io.IOException;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.*;
import java.util.concurrent.Executors;
import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpHandler;
import com.sun.net.httpserver.HttpServer;

public class JavaServer {

    private static final int MAX_SCALE = 5;

    public static void main(String[] args) throws IOException {
        String host = "127.0.0.1";
        int port = 8080;

        if (args.length > 0) {
            try {
                port = Integer.parseInt(args[0]);
            } catch (NumberFormatException ignored) {}
        }
        if (args.length > 1) {
            host = args[1];
        }

        HttpServer server = HttpServer.create(new InetSocketAddress(host, port), 0);
        server.createContext("/health", new HealthHandler());
        server.createContext("/work", new WorkHandler());
        server.createContext("/", new DefaultHandler());
        server.setExecutor(Executors.newFixedThreadPool(10));

        System.out.println("Starting Green Java Lab at http://" + host + ":" + port);
        server.start();
    }

    private static boolean isPrime(long number) {
        if (number < 2) return false;
        if (number == 2) return true;
        if (number % 2 == 0) return false;
        long limit = (long) Math.sqrt(number);
        for (long divisor = 3; divisor <= limit; divisor += 2) {
            if (number % divisor == 0) return false;
        }
        return true;
    }

    private static Map<String, Object> calculatePrimeChecksum(int limit) {
        long sum = 0;
        int count = 0;
        for (int i = 2; i <= limit; i++) {
            if (isPrime(i)) {
                sum += i;
                count++;
            }
        }
        Map<String, Object> res = new LinkedHashMap<>();
        res.put("count", count);
        res.put("checksum", sum);
        return res;
    }

    private static List<String> buildTextCorpus(int paragraphs) {
        String[] base = {
            "Green software reduces unnecessary computation and resource usage.",
            "Repeatable workloads make performance and energy comparisons fair.",
            "A profiler helps developers locate expensive functions in the code.",
            "Energy measurements should be interpreted together with latency and throughput.",
            "Optimizing an algorithm can reduce execution time and operational emissions."
        };
        List<String> corpus = new ArrayList<>(paragraphs);
        for (int i = 0; i < paragraphs; i++) {
            corpus.add(base[i % base.length] + " Sample=" + i);
        }
        return corpus;
    }

    private static List<String> normalizeSentence(String sentence) {
        String normalized = sentence.toLowerCase().replaceAll("[^a-z0-9\\s=]", " ");
        String[] parts = normalized.trim().split("\\s+");
        List<String> words = new ArrayList<>();
        for (String p : parts) {
            if (!p.isEmpty()) words.add(p);
        }
        return words;
    }

    private static Map<String, Integer> countWords(List<String> corpus) {
        Map<String, Integer> frequencies = new TreeMap<>();
        for (String sentence : corpus) {
            for (String word : normalizeSentence(sentence)) {
                frequencies.put(word, frequencies.getOrDefault(word, 0) + 1);
            }
        }
        return frequencies;
    }

    private static String sha256(String input) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hash = digest.digest(input.getBytes(StandardCharsets.UTF_8));
            StringBuilder hexString = new StringBuilder();
            for (byte b : hash) {
                String hex = Integer.toHexString(0xff & b);
                if (hex.length() == 1) hexString.append('0');
                hexString.append(hex);
            }
            return hexString.toString();
        } catch (NoSuchAlgorithmException e) {
            return "";
        }
    }

    private static String executeCpuWorkload(int scale) {
        int limit = 2500 * scale;
        Map<String, Object> res = calculatePrimeChecksum(limit);
        return String.format("{\"limit\":%d,\"prime_count\":%d,\"checksum\":\"%s\"}",
            limit, (int) res.get("count"), String.valueOf(res.get("checksum")));
    }

    private static String executeTextWorkload(int scale) {
        int paragraphs = 300 * scale;
        List<String> corpus = buildTextCorpus(paragraphs);
        Map<String, Integer> frequencies = countWords(corpus);
        String checksum = sha256(frequencies.toString());
        return String.format("{\"paragraphs\":%d,\"unique_words\":%d,\"checksum\":\"%s\"}",
            paragraphs, frequencies.size(), checksum);
    }

    private static String executeWordpressWorkload(int scale) {
        int optionsCount = 100 * scale;
        int postsCount = 15 * scale;
        int filterIterations = 200 * scale;

        StringBuilder rendered = new StringBuilder();
        for (int i = 0; i < postsCount; i++) {
            String content = "Welcome to WordPress post " + i + " with [custom_shortcode id=" + i + "]";
            String processed = content.replace("[custom_shortcode id=", "<strong>Shortcode Rendered ").replace("]", "</strong>").toLowerCase().trim();
            rendered.append(processed);
        }
        String raw = optionsCount + "" + postsCount + "" + rendered.length();
        String checksum = sha256(raw);
        return String.format("{\"options_loaded\":%d,\"posts_queried\":%d,\"rendered_length\":%d,\"checksum\":\"%s\"}",
            optionsCount, postsCount, rendered.length(), checksum);
    }

    private static void sendJsonResponse(HttpExchange exchange, int statusCode, String json) throws IOException {
        byte[] bytes = json.getBytes(StandardCharsets.UTF_8);
        exchange.getResponseHeaders().set("Content-Type", "application/json; charset=utf-8");
        exchange.sendResponseHeaders(statusCode, bytes.length);
        try (OutputStream os = exchange.getResponseBody()) {
            os.write(bytes);
        }
    }

    private static Map<String, String> parseQuery(URI uri) {
        Map<String, String> queryPairs = new HashMap<>();
        String query = uri.getQuery();
        if (query != null) {
            String[] pairs = query.split("&");
            for (String pair : pairs) {
                int idx = pair.indexOf("=");
                if (idx > 0) {
                    queryPairs.put(pair.substring(0, idx), pair.substring(idx + 1));
                }
            }
        }
        return queryPairs;
    }

    static class HealthHandler implements HttpHandler {
        @Override
        public void handle(HttpExchange exchange) throws IOException {
            String response = String.format("{\"application\":\"Green Java Lab\",\"status\":\"ok\",\"java_version\":\"%s\"}",
                System.getProperty("java.version"));
            sendJsonResponse(exchange, 200, response);
        }
    }

    static class WorkHandler implements HttpHandler {
        @Override
        public void handle(HttpExchange exchange) throws IOException {
            Map<String, String> query = parseQuery(exchange.getRequestURI());
            String workload = query.getOrDefault("workload", "wordpress");
            int scale = 1;
            try {
                scale = Math.max(1, Math.min(Integer.parseInt(query.getOrDefault("scale", "1")), MAX_SCALE));
            } catch (NumberFormatException ignored) {}

            String resultJson;
            if ("cpu".equals(workload)) {
                resultJson = executeCpuWorkload(scale);
            } else if ("text".equals(workload)) {
                resultJson = executeTextWorkload(scale);
            } else if ("wordpress".equals(workload)) {
                resultJson = executeWordpressWorkload(scale);
            } else if ("mixed".equals(workload)) {
                String cpu = executeCpuWorkload(scale);
                String text = executeTextWorkload(scale);
                String combinedHash = sha256(cpu + text);
                resultJson = String.format("{\"cpu\":%s,\"text\":%s,\"checksum\":\"%s\"}", cpu, text, combinedHash);
            } else {
                sendJsonResponse(exchange, 400, "{\"error\":\"Unknown workload\"}");
                return;
            }

            String response = String.format("{\"workload\":\"%s\",\"scale\":%d,\"result\":%s}", workload, scale, resultJson);
            sendJsonResponse(exchange, 200, response);
        }
    }

    static class DefaultHandler implements HttpHandler {
        @Override
        public void handle(HttpExchange exchange) throws IOException {
            String response = "{\"application\":\"Green Java Lab\",\"status\":\"running\",\"endpoints\":[\"/health\",\"/work\"]}";
            sendJsonResponse(exchange, 200, response);
        }
    }
}

<?php
// =======================
// 环境变量
// =======================
$port = getenv('PORT') ?: (getenv('SERVER_PORT') ?: 3000);
$filePath = getenv('FILE_PATH') ?: './.npm';
$openhttp = getenv('OPENHTTP') ?: '1'; // '0' or '1'

$startScriptPath = './start.sh';

// =======================
// chmod start.sh
// =======================
if (!chmod($startScriptPath, 0755)) {
    fwrite(STDERR, "Failed to chmod start.sh\n");
    exit(1);
}

// =======================
// 启动 start.sh 子进程
// =======================
$descriptorspec = [
    0 => ['pipe', 'r'],
    1 => ['pipe', 'w'],
    2 => ['pipe', 'w'],
];

$env = array_merge($_ENV, [
    'OPENHTTP' => $openhttp,
]);

$process = proc_open($startScriptPath, $descriptorspec, $pipes, null, $env);

if (!is_resource($process)) {
    fwrite(STDERR, "boot error: cannot start script\n");
    exit(1);
}

// 非阻塞
stream_set_blocking($pipes[1], false);
stream_set_blocking($pipes[2], false);

// =======================
// HTTP 服务
// =======================
if ($openhttp === '1') {
    $address = "tcp://0.0.0.0:$port";
    $server = stream_socket_server($address, $errno, $errstr);

    if (!$server) {
        fwrite(STDERR, "Server error: $errstr ($errno)\n");
        exit(1);
    }

    echo "server is listening on port $port\n";
    $subFilePath = $filePath . '/log.txt';

    while (true) {
        // 读取子进程输出
        foreach ([1 => STDOUT, 2 => STDERR] as $i => $output) {
            $data = stream_get_contents($pipes[$i]);
            if ($data !== false && $data !== '') {
                fwrite($output, $data);
            }
        }

        // 接收 HTTP 请求（非阻塞）
        $conn = @stream_socket_accept($server, 0);
        if ($conn) {
            $request = fread($conn, 1024);

            if (preg_match('#^GET\s+([^ ]+)#', $request, $matches)) {
                $path = $matches[1];

                if ($path === '/') {
                    $body = 'hello world';
                    $response = "HTTP/1.1 200 OK\r\n" .
                                "Content-Length: " . strlen($body) . "\r\n\r\n" .
                                $body;
                } elseif ($path === '/sub') {
                    if (file_exists($subFilePath)) {
                        $body = file_get_contents($subFilePath);
                        $response = "HTTP/1.1 200 OK\r\n" .
                                    "Content-Type: text/plain; charset=utf-8\r\n" .
                                    "Content-Length: " . strlen($body) . "\r\n\r\n" .
                                    $body;
                    } else {
                        $body = 'Error reading file';
                        $response = "HTTP/1.1 500 Internal Server Error\r\n" .
                                    "Content-Length: " . strlen($body) . "\r\n\r\n" .
                                    $body;
                    }
                } else {
                    $body = 'Not found';
                    $response = "HTTP/1.1 404 Not Found\r\n" .
                                "Content-Length: " . strlen($body) . "\r\n\r\n" .
                                $body;
                }

                fwrite($conn, $response);
            }
            fclose($conn);
        }

        usleep(10000); // 防止 CPU 占用过高
    }
} else {
    echo "server is listening on port $port\n";
}

// =======================
// 清理
// =======================
proc_close($process);

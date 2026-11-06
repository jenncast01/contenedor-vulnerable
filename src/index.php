<?php
$output = "";
if (isset($_GET['host'])) {
    // VULNERABLE A COMMAND INJECTION (RCE): No sanitiza la entrada del usuario
    $host = $_GET['host'];
    $output = shell_exec("ping -c 1 " . $host . " 2>&1");
}
?>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>Panel de Diagnostico - Servidor Antiguo (Vulnerable)</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #fff5f5; color: #333; }
        .box { background: white; padding: 20px; border: 1px solid #feb2b2; border-radius: 8px; max-width: 700px; }
        pre { background: #1a202c; color: #68d391; padding: 15px; border-radius: 5px; overflow-x: auto; }
        input[type=text] { width: 65%; padding: 8px; }
        button { padding: 8px 16px; background: #e53e3e; color: white; border: none; border-radius: 4px; cursor: pointer; }
    </style>
</head>
<body>
    <div class="box">
        <h2>Panel de Red - Apache 2.4.18 (Ubuntu 16.04)</h2>
        <p>Herramienta de diagnostico Ping (Vulnerable a Inyeccion de Comandos):</p>
        <form method="GET">
            <input type="text" name="host" placeholder="Ej: 127.0.0.1; id; cat /etc/passwd" value="<?php echo isset($_GET['host']) ? htmlspecialchars($_GET['host']) : '127.0.0.1'; ?>">
            <button type="submit">Ejecutar</button>
        </form>
        <?php if ($output): ?>
            <h3>Resultado del comando:</h3>
            <pre><?php echo htmlspecialchars($output); ?></pre>
        <?php endif; ?>
        <hr>
        <p><small>Rutas del servidor: <a href="/backups/">/backups/</a> | <a href="/uploads/">/uploads/</a></small></p>
    </div>
</body>
</html>

<?php
/**
 * Security helper functions for Phoniebox
 * 
 * This file contains functions for input validation, CSRF protection,
 * and secure shell command execution.
 */

namespace JukeBox\Security;

/**
 * Start session if not already started and initialize CSRF token
 */
function initSession(): void
{
    if (session_status() === PHP_SESSION_NONE) {
        session_start();
    }
    
    if (empty($_SESSION['csrf_token'])) {
        $_SESSION['csrf_token'] = bin2hex(random_bytes(32));
    }
}

/**
 * Get the current CSRF token
 */
function getCsrfToken(): string
{
    initSession();
    return $_SESSION['csrf_token'];
}

/**
 * Generate HTML input field with CSRF token
 */
function csrfField(): string
{
    return '<input type="hidden" name="csrf_token" value="' . htmlspecialchars(getCsrfToken()) . '">';
}

/**
 * Validate CSRF token from request
 */
function validateCsrfToken(): bool
{
    initSession();
    
    $token = $_POST['csrf_token'] ?? $_GET['csrf_token'] ?? '';
    
    if (empty($token) || empty($_SESSION['csrf_token'])) {
        return false;
    }
    
    return hash_equals($_SESSION['csrf_token'], $token);
}

/**
 * Validate and sanitize a card ID
 * Card IDs should only contain alphanumeric characters, dashes and underscores
 */
function validateCardId(string $cardId): ?string
{
    $cardId = trim($cardId);
    
    if (empty($cardId)) {
        return null;
    }
    
    // Only allow alphanumeric, dash, underscore
    if (!preg_match('/^[a-zA-Z0-9_-]+$/', $cardId)) {
        return null;
    }
    
    // Max length check
    if (strlen($cardId) > 100) {
        return null;
    }
    
    return $cardId;
}

/**
 * Validate and sanitize a folder path
 * Prevents directory traversal attacks
 */
function validateFolderPath(string $path, string $basePath): ?string
{
    $path = trim($path);
    
    if (empty($path)) {
        return null;
    }
    
    // Remove any null bytes
    $path = str_replace("\0", '', $path);
    
    // Check for directory traversal attempts
    if (strpos($path, '..') !== false) {
        return null;
    }
    
    // Build full path and resolve it
    $fullPath = realpath($basePath . '/' . $path);
    $basePath = realpath($basePath);
    
    // Ensure the path is within the base path
    if ($fullPath === false || strpos($fullPath, $basePath) !== 0) {
        return null;
    }
    
    return $path;
}

/**
 * Validate a URL (for streams)
 */
function validateStreamUrl(string $url): ?string
{
    $url = trim($url);
    
    if (empty($url)) {
        return null;
    }
    
    // Validate URL format
    if (!filter_var($url, FILTER_VALIDATE_URL)) {
        return null;
    }
    
    // Only allow http/https protocols
    $parsed = parse_url($url);
    if (!in_array($parsed['scheme'] ?? '', ['http', 'https'])) {
        return null;
    }
    
    return $url;
}

/**
 * Validate numeric value within range
 */
function validateNumericRange($value, int $min, int $max): ?int
{
    if (!is_numeric($value)) {
        return null;
    }
    
    $value = (int)$value;
    
    if ($value < $min || $value > $max) {
        return null;
    }
    
    return $value;
}

/**
 * Safely execute a shell command with escaped arguments
 */
function safeExec(string $command, array $args = []): ?string
{
    // Escape all arguments
    $escapedArgs = array_map('escapeshellarg', $args);
    
    // Build the command
    $fullCommand = vsprintf($command, $escapedArgs);
    
    $output = [];
    $returnCode = 0;
    
    exec($fullCommand, $output, $returnCode);
    
    if ($returnCode !== 0) {
        error_log("Command failed with code $returnCode: $fullCommand");
        return null;
    }
    
    return implode("\n", $output);
}

/**
 * Log security events
 */
function logSecurityEvent(string $event, array $context = []): void
{
    $logFile = dirname(__DIR__) . '/logs/security.log';
    $timestamp = date('Y-m-d H:i:s');
    $ip = $_SERVER['REMOTE_ADDR'] ?? 'unknown';
    $contextStr = json_encode($context);
    
    $logEntry = "[$timestamp] [$ip] $event $contextStr\n";
    
    @file_put_contents($logFile, $logEntry, FILE_APPEND | LOCK_EX);
}

/**
 * Rate limiting check (simple file-based)
 */
function checkRateLimit(string $action, int $maxAttempts = 10, int $timeWindow = 60): bool
{
    $cacheDir = '/tmp/phoniebox_ratelimit';
    
    if (!is_dir($cacheDir)) {
        @mkdir($cacheDir, 0755, true);
    }
    
    $ip = $_SERVER['REMOTE_ADDR'] ?? 'unknown';
    $key = md5($action . $ip);
    $file = "$cacheDir/$key";
    
    $now = time();
    $attempts = [];
    
    if (file_exists($file)) {
        $data = @file_get_contents($file);
        $attempts = json_decode($data, true) ?: [];
        
        // Remove old attempts
        $attempts = array_filter($attempts, fn($t) => $t > ($now - $timeWindow));
    }
    
    if (count($attempts) >= $maxAttempts) {
        logSecurityEvent('rate_limit_exceeded', ['action' => $action]);
        return false;
    }
    
    $attempts[] = $now;
    @file_put_contents($file, json_encode($attempts));
    
    return true;
}


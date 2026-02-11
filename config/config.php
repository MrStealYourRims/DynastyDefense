<?php
return [
    'db' => [
        'host' => 'localhost',
        'dbname' => 'dynasty_defense',
        'user' => 'db_user',
        'pass' => 'db_password',
        'charset' => 'utf8mb4',
    ],
    'game' => [
        'map_width' => 40,
        'map_height' => 40,
        'tick_seconds' => 300,
        'base_travel_seconds' => 120,
    ],
    'security' => [
        'session_name' => 'dynasty_session',
        'csrf_token_name' => 'csrf_token',
    ],
];

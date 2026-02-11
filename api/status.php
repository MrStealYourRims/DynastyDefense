<?php
require_once __DIR__ . '/bootstrap.php';

$buildings = get_building_levels((int) $city['id']);
$research = get_research_levels($userId);
$commanders = get_player_commanders($userId);
$researchById = [];

$userMetaStmt = db()->prepare('SELECT u.civilization_id, c.display_name AS civilization_name, c.bonus_json FROM users u LEFT JOIN civilizations c ON c.id = u.civilization_id WHERE u.id = ?');
$userMetaStmt->execute([$userId]);
$userMeta = $userMetaStmt->fetch() ?: ['civilization_id' => null, 'civilization_name' => null, 'bonus_json' => '{}'];

$buildersStmt = db()->prepare('SELECT id, slot_index, is_unlocked, unlock_cost_gems, status FROM city_builders WHERE city_id = ? ORDER BY slot_index');
$buildersStmt->execute([$city['id']]);
$builders = $buildersStmt->fetchAll();

foreach ($research as $r) {
    $researchById[(int) $r['id']] = $r;
}

$townHallLevel = 0;
$barracksLevel = 0;
foreach ($buildings as &$building) {
    if ($building['key_name'] === 'town_hall') {
        $townHallLevel = (int) $building['level'];
    }
    if ($building['key_name'] === 'barracks') {
        $barracksLevel = (int) $building['level'];
    }
}
unset($building);

$researchBonus = get_research_bonus_map($userId);

foreach ($buildings as &$building) {
    $targetLevel = (int) $building['level'] + 1;
    $costMultiplier = pow(1.22, max(0, $targetLevel - 1));
    $duration = (int) floor($building['base_duration_seconds'] * $costMultiplier);
    if (isset($researchBonus['build_speed_pct'])) {
        $duration = (int) max(20, floor($duration * (1 - ($researchBonus['build_speed_pct'] / 100))));
    }
    $costs = [
        'food' => (int) floor($building['base_food'] * $costMultiplier),
        'wood' => (int) floor($building['base_wood'] * $costMultiplier),
        'stone' => (int) floor($building['base_stone'] * $costMultiplier),
        'gold' => (int) floor($building['base_gold'] * $costMultiplier),
    ];

    $building['next_upgrade'] = [
        'target_level' => $targetLevel,
        'duration_seconds' => $duration,
        'costs' => $costs,
        'can_upgrade' => $targetLevel <= (int) $building['max_level'] && $townHallLevel >= (int) $building['required_town_hall_level'],
    ];
}
unset($building);

foreach ($research as &$tech) {
    $currentLevel = (int) $tech['level'];
    $costMultiplier = pow(1.25, $currentLevel);
    $academyLevelStmt = db()->prepare('SELECT cb.level FROM city_buildings cb JOIN building_definitions bd ON bd.id = cb.building_id WHERE cb.city_id = ? AND bd.key_name = "academy"');
    $academyLevelStmt->execute([$city['id']]);
    $academyLevel = (int) (($academyLevelStmt->fetch()['level'] ?? 0));
    $modifier = max(0.5, 1 - ($academyLevel * 0.02));
    $duration = (int) ceil($tech['duration_seconds'] * $costMultiplier * $modifier);

    $prereqMet = true;
    if (!empty($tech['prerequisite_research_id'])) {
        $prereq = $researchById[(int) $tech['prerequisite_research_id']] ?? null;
        $prereqMet = $prereq && (int) $prereq['level'] >= (int) $tech['prerequisite_level'];
    }

    $tech['next_research'] = [
        'target_level' => $currentLevel + 1,
        'duration_seconds' => $duration,
        'costs' => [
            'food' => (int) floor($tech['cost_food'] * $costMultiplier),
            'wood' => (int) floor($tech['cost_wood'] * $costMultiplier),
            'stone' => (int) floor($tech['cost_stone'] * $costMultiplier),
            'gold' => (int) floor($tech['cost_gold'] * $costMultiplier),
        ],
        'prereq_met' => $prereqMet,
        'can_research' => $currentLevel < (int) $tech['max_level'] && $prereqMet,
    ];
}
unset($tech);

$unitsStmt = db()->prepare('SELECT ud.id, ud.key_name, ud.display_name, ud.tier, ud.required_tech_id, ud.required_building_key, ud.required_building_level, ud.training_time_seconds, ud.cost_food, ud.cost_wood, ud.cost_stone, ud.cost_gold, cu.quantity, ud.attack, ud.defense, ud.speed FROM unit_definitions ud LEFT JOIN city_units cu ON cu.unit_id = ud.id AND cu.city_id = ? ORDER BY ud.tier, ud.id');
$unitsStmt->execute([$city['id']]);
$units = $unitsStmt->fetchAll();

foreach ($units as &$unit) {
    $requiredTechLevel = 0;
    if (!empty($unit['required_tech_id'])) {
        $requiredTech = $researchById[(int) $unit['required_tech_id']] ?? null;
        $requiredTechLevel = (int) ($requiredTech['level'] ?? 0);
    }

    $requiredBuildingLevel = 0;
    if (!empty($unit['required_building_key'])) {
        foreach ($buildings as $building) {
            if ($building['key_name'] === $unit['required_building_key']) {
                $requiredBuildingLevel = (int) $building['level'];
                break;
            }
        }
    }

    $trainModifier = max(0.4, 1 - ($barracksLevel * 0.02));
    $unit['training_preview'] = [
        'for_quantity' => 1,
        'duration_seconds' => (int) ceil($unit['training_time_seconds'] * $trainModifier),
        'costs' => [
            'food' => (int) $unit['cost_food'],
            'wood' => (int) $unit['cost_wood'],
            'stone' => (int) $unit['cost_stone'],
            'gold' => (int) $unit['cost_gold'],
        ],
        'requirements' => [
            'tech_met' => empty($unit['required_tech_id']) || $requiredTechLevel >= 1,
            'building_met' => empty($unit['required_building_key']) || $requiredBuildingLevel >= (int) $unit['required_building_level'],
            'required_building_key' => $unit['required_building_key'] ?: null,
            'required_building_level' => (int) $unit['required_building_level'],
            'required_tech_id' => $unit['required_tech_id'] ? (int) $unit['required_tech_id'] : null,
        ],
    ];
}
unset($unit);

$queue = [
    'build' => (function () use ($city) {
        $stmt = db()->prepare('SELECT * FROM build_queue WHERE city_id = ? AND status = "queued" ORDER BY finishes_at LIMIT 20');
        $stmt->execute([$city['id']]);
        return $stmt->fetchAll();
    })(),
    'training' => (function () use ($city) {
        $stmt = db()->prepare('SELECT * FROM training_queue WHERE city_id = ? AND status = "queued" ORDER BY finishes_at LIMIT 20');
        $stmt->execute([$city['id']]);
        return $stmt->fetchAll();
    })(),
    'research' => (function () use ($userId) {
        $stmt = db()->prepare('SELECT * FROM research_queue WHERE user_id = ? AND status = "queued" ORDER BY finishes_at LIMIT 20');
        $stmt->execute([$userId]);
        return $stmt->fetchAll();
    })(),
];

json_response([
    'city' => $city,
    'buildings' => $buildings,
    'research' => $research,
    'units' => $units,
    'commanders' => $commanders,
    'queue' => $queue,
    'civilization' => [
        'id' => $userMeta['civilization_id'] ? (int) $userMeta['civilization_id'] : null,
        'name' => $userMeta['civilization_name'],
        'bonuses' => json_decode($userMeta['bonus_json'] ?? '{}', true) ?: [],
    ],
    'builders' => $builders,
]);

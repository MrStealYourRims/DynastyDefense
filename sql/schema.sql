CREATE TABLE users (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(30) NOT NULL UNIQUE,
    email VARCHAR(120) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    empire_name VARCHAR(60) NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_login_at DATETIME NULL,
    is_admin TINYINT(1) NOT NULL DEFAULT 0
) ENGINE=InnoDB;

CREATE TABLE alliances (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(64) NOT NULL UNIQUE,
    tag VARCHAR(10) NOT NULL UNIQUE,
    leader_user_id INT UNSIGNED NOT NULL,
    description TEXT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_alliance_leader FOREIGN KEY (leader_user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE alliance_members (
    alliance_id INT UNSIGNED NOT NULL,
    user_id INT UNSIGNED NOT NULL,
    role ENUM('leader','officer','member') NOT NULL DEFAULT 'member',
    joined_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (alliance_id, user_id),
    INDEX idx_alliance_members_user (user_id),
    CONSTRAINT fk_alliance_member_alliance FOREIGN KEY (alliance_id) REFERENCES alliances(id) ON DELETE CASCADE,
    CONSTRAINT fk_alliance_member_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE world_tiles (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    x_coord INT NOT NULL,
    y_coord INT NOT NULL,
    tile_type ENUM('empty','player_city','resource_node','npc_camp') NOT NULL DEFAULT 'empty',
    owner_user_id INT UNSIGNED NULL,
    resource_type ENUM('food','wood','stone','gold') NULL,
    resource_amount INT UNSIGNED NOT NULL DEFAULT 0,
    npc_strength INT UNSIGNED NOT NULL DEFAULT 0,
    UNIQUE KEY uniq_tile_coord (x_coord, y_coord),
    INDEX idx_tile_owner (owner_user_id),
    INDEX idx_tile_type (tile_type),
    CONSTRAINT fk_tile_owner FOREIGN KEY (owner_user_id) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE cities (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id INT UNSIGNED NOT NULL UNIQUE,
    tile_id BIGINT UNSIGNED NOT NULL UNIQUE,
    city_name VARCHAR(80) NOT NULL,
    population INT UNSIGNED NOT NULL DEFAULT 100,
    morale TINYINT UNSIGNED NOT NULL DEFAULT 100,
    food BIGINT UNSIGNED NOT NULL DEFAULT 500,
    wood BIGINT UNSIGNED NOT NULL DEFAULT 500,
    stone BIGINT UNSIGNED NOT NULL DEFAULT 500,
    gold BIGINT UNSIGNED NOT NULL DEFAULT 500,
    food_capacity BIGINT UNSIGNED NOT NULL DEFAULT 3000,
    wood_capacity BIGINT UNSIGNED NOT NULL DEFAULT 3000,
    stone_capacity BIGINT UNSIGNED NOT NULL DEFAULT 3000,
    gold_capacity BIGINT UNSIGNED NOT NULL DEFAULT 3000,
    last_resource_update DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_city_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_city_tile FOREIGN KEY (tile_id) REFERENCES world_tiles(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE building_definitions (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    key_name VARCHAR(40) NOT NULL UNIQUE,
    display_name VARCHAR(80) NOT NULL,
    base_food INT UNSIGNED NOT NULL DEFAULT 0,
    base_wood INT UNSIGNED NOT NULL DEFAULT 0,
    base_stone INT UNSIGNED NOT NULL DEFAULT 0,
    base_gold INT UNSIGNED NOT NULL DEFAULT 0,
    base_duration_seconds INT UNSIGNED NOT NULL,
    required_town_hall_level TINYINT UNSIGNED NOT NULL DEFAULT 1,
    max_level TINYINT UNSIGNED NOT NULL DEFAULT 30,
    effects_json JSON NOT NULL
) ENGINE=InnoDB;

CREATE TABLE city_buildings (
    city_id INT UNSIGNED NOT NULL,
    building_id INT UNSIGNED NOT NULL,
    level INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (city_id, building_id),
    CONSTRAINT fk_city_building_city FOREIGN KEY (city_id) REFERENCES cities(id) ON DELETE CASCADE,
    CONSTRAINT fk_city_building_definition FOREIGN KEY (building_id) REFERENCES building_definitions(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE build_queue (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    city_id INT UNSIGNED NOT NULL,
    building_id INT UNSIGNED NOT NULL,
    target_level INT UNSIGNED NOT NULL,
    starts_at DATETIME NOT NULL,
    finishes_at DATETIME NOT NULL,
    status ENUM('queued','complete') NOT NULL DEFAULT 'queued',
    INDEX idx_build_queue_city_status (city_id, status, finishes_at),
    CONSTRAINT fk_build_queue_city FOREIGN KEY (city_id) REFERENCES cities(id) ON DELETE CASCADE,
    CONSTRAINT fk_build_queue_building FOREIGN KEY (building_id) REFERENCES building_definitions(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE research_definitions (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    key_name VARCHAR(50) NOT NULL UNIQUE,
    display_name VARCHAR(80) NOT NULL,
    branch_key VARCHAR(40) NOT NULL,
    description TEXT NOT NULL,
    max_level TINYINT UNSIGNED NOT NULL DEFAULT 10,
    prerequisite_research_id INT UNSIGNED NULL,
    prerequisite_level TINYINT UNSIGNED NOT NULL DEFAULT 0,
    cost_food INT UNSIGNED NOT NULL,
    cost_wood INT UNSIGNED NOT NULL,
    cost_stone INT UNSIGNED NOT NULL,
    cost_gold INT UNSIGNED NOT NULL,
    duration_seconds INT UNSIGNED NOT NULL,
    effect_json JSON NOT NULL,
    CONSTRAINT fk_research_prereq FOREIGN KEY (prerequisite_research_id) REFERENCES research_definitions(id) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE player_research (
    user_id INT UNSIGNED NOT NULL,
    research_id INT UNSIGNED NOT NULL,
    level INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (user_id, research_id),
    CONSTRAINT fk_player_research_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_player_research_definition FOREIGN KEY (research_id) REFERENCES research_definitions(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE research_queue (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id INT UNSIGNED NOT NULL,
    research_id INT UNSIGNED NOT NULL,
    target_level INT UNSIGNED NOT NULL,
    starts_at DATETIME NOT NULL,
    finishes_at DATETIME NOT NULL,
    status ENUM('queued','complete') NOT NULL DEFAULT 'queued',
    INDEX idx_research_user_status (user_id, status, finishes_at),
    CONSTRAINT fk_research_queue_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_research_queue_definition FOREIGN KEY (research_id) REFERENCES research_definitions(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE unit_definitions (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    key_name VARCHAR(40) NOT NULL UNIQUE,
    display_name VARCHAR(80) NOT NULL,
    tier TINYINT UNSIGNED NOT NULL,
    attack INT UNSIGNED NOT NULL,
    defense INT UNSIGNED NOT NULL,
    speed DECIMAL(6,2) NOT NULL,
    upkeep_food INT UNSIGNED NOT NULL,
    training_time_seconds INT UNSIGNED NOT NULL,
    cost_food INT UNSIGNED NOT NULL,
    cost_wood INT UNSIGNED NOT NULL,
    cost_stone INT UNSIGNED NOT NULL,
    cost_gold INT UNSIGNED NOT NULL,
    required_tech_id INT UNSIGNED NULL,
    required_building_key VARCHAR(40) NULL,
    required_building_level TINYINT UNSIGNED NOT NULL DEFAULT 1,
    CONSTRAINT fk_unit_required_tech FOREIGN KEY (required_tech_id) REFERENCES research_definitions(id) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE city_units (
    city_id INT UNSIGNED NOT NULL,
    unit_id INT UNSIGNED NOT NULL,
    quantity INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (city_id, unit_id),
    CONSTRAINT fk_city_units_city FOREIGN KEY (city_id) REFERENCES cities(id) ON DELETE CASCADE,
    CONSTRAINT fk_city_units_unit FOREIGN KEY (unit_id) REFERENCES unit_definitions(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE commander_definitions (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    key_name VARCHAR(40) NOT NULL UNIQUE,
    display_name VARCHAR(80) NOT NULL,
    rarity ENUM('common','rare','epic','legendary') NOT NULL DEFAULT 'common',
    attack_buff_pct TINYINT UNSIGNED NOT NULL DEFAULT 0,
    defense_buff_pct TINYINT UNSIGNED NOT NULL DEFAULT 0,
    speed_buff_pct TINYINT UNSIGNED NOT NULL DEFAULT 0,
    upkeep_reduction_pct TINYINT UNSIGNED NOT NULL DEFAULT 0
) ENGINE=InnoDB;

CREATE TABLE player_commanders (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id INT UNSIGNED NOT NULL,
    commander_definition_id INT UNSIGNED NOT NULL,
    level TINYINT UNSIGNED NOT NULL DEFAULT 1,
    experience INT UNSIGNED NOT NULL DEFAULT 0,
    status ENUM('available','on_mission','injured') NOT NULL DEFAULT 'available',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_player_commander_user_status (user_id, status),
    CONSTRAINT fk_player_commander_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_player_commander_definition FOREIGN KEY (commander_definition_id) REFERENCES commander_definitions(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE training_queue (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    city_id INT UNSIGNED NOT NULL,
    unit_id INT UNSIGNED NOT NULL,
    quantity INT UNSIGNED NOT NULL,
    starts_at DATETIME NOT NULL,
    finishes_at DATETIME NOT NULL,
    status ENUM('queued','complete') NOT NULL DEFAULT 'queued',
    INDEX idx_training_city_status (city_id, status, finishes_at),
    CONSTRAINT fk_training_city FOREIGN KEY (city_id) REFERENCES cities(id) ON DELETE CASCADE,
    CONSTRAINT fk_training_unit FOREIGN KEY (unit_id) REFERENCES unit_definitions(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE army_movements (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    owner_user_id INT UNSIGNED NOT NULL,
    source_city_id INT UNSIGNED NOT NULL,
    target_tile_id BIGINT UNSIGNED NOT NULL,
    commander_id BIGINT UNSIGNED NULL,
    mission_type ENUM('attack','scout','reinforce','gather') NOT NULL,
    units_json JSON NOT NULL,
    departs_at DATETIME NOT NULL,
    arrives_at DATETIME NOT NULL,
    status ENUM('moving','resolved') NOT NULL DEFAULT 'moving',
    INDEX idx_army_arrival (status, arrives_at),
    INDEX idx_army_owner (owner_user_id),
    CONSTRAINT fk_army_owner FOREIGN KEY (owner_user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_army_source_city FOREIGN KEY (source_city_id) REFERENCES cities(id) ON DELETE CASCADE,
    CONSTRAINT fk_army_target_tile FOREIGN KEY (target_tile_id) REFERENCES world_tiles(id) ON DELETE CASCADE,
    CONSTRAINT fk_army_commander FOREIGN KEY (commander_id) REFERENCES player_commanders(id) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE combat_reports (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    attacker_user_id INT UNSIGNED NOT NULL,
    defender_user_id INT UNSIGNED NULL,
    target_tile_id BIGINT UNSIGNED NOT NULL,
    summary VARCHAR(255) NOT NULL,
    battle_data JSON NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_combat_attacker (attacker_user_id, created_at),
    INDEX idx_combat_defender (defender_user_id, created_at),
    CONSTRAINT fk_combat_attacker FOREIGN KEY (attacker_user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_combat_defender FOREIGN KEY (defender_user_id) REFERENCES users(id) ON DELETE SET NULL,
    CONSTRAINT fk_combat_tile FOREIGN KEY (target_tile_id) REFERENCES world_tiles(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE messages (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    sender_user_id INT UNSIGNED NOT NULL,
    recipient_user_id INT UNSIGNED NULL,
    alliance_id INT UNSIGNED NULL,
    channel ENUM('global','alliance','private') NOT NULL DEFAULT 'global',
    body VARCHAR(500) NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_messages_channel_time (channel, created_at),
    INDEX idx_messages_alliance_time (alliance_id, created_at),
    CONSTRAINT fk_message_sender FOREIGN KEY (sender_user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_message_recipient FOREIGN KEY (recipient_user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_message_alliance FOREIGN KEY (alliance_id) REFERENCES alliances(id) ON DELETE CASCADE
) ENGINE=InnoDB;

INSERT INTO building_definitions (key_name, display_name, base_food, base_wood, base_stone, base_gold, base_duration_seconds, required_town_hall_level, max_level, effects_json) VALUES
('town_hall', 'Town Hall', 100, 150, 150, 100, 120, 1, 25, JSON_OBJECT('unlocks', JSON_ARRAY('all'))),
('farm', 'Farm', 60, 60, 40, 20, 90, 1, 30, JSON_OBJECT('food_per_minute', 25)),
('lumber_mill', 'Lumber Mill', 50, 80, 40, 20, 90, 1, 30, JSON_OBJECT('wood_per_minute', 25)),
('quarry', 'Quarry', 50, 60, 80, 20, 90, 2, 30, JSON_OBJECT('stone_per_minute', 22)),
('gold_mine', 'Gold Mine', 80, 80, 80, 50, 120, 3, 30, JSON_OBJECT('gold_per_minute', 15)),
('warehouse', 'Warehouse', 100, 100, 100, 50, 150, 2, 25, JSON_OBJECT('storage_per_level', 2000)),
('barracks', 'Barracks', 120, 160, 120, 80, 180, 2, 25, JSON_OBJECT('unit_train_speed_pct', 2)),
('academy', 'Academy', 120, 120, 100, 100, 180, 4, 25, JSON_OBJECT('research_speed_pct', 2)),
('walls', 'Walls', 80, 100, 220, 50, 240, 3, 25, JSON_OBJECT('city_defense_pct', 5));

INSERT INTO research_definitions (id, key_name, display_name, branch_key, description, max_level, prerequisite_research_id, prerequisite_level, cost_food, cost_wood, cost_stone, cost_gold, duration_seconds, effect_json) VALUES
(1, 'agriculture', 'Agriculture', 'economy', 'Increases food production by 5% per level.', 15, NULL, 0, 120, 100, 80, 50, 180, JSON_OBJECT('food_prod_pct', 5)),
(2, 'logging', 'Logging', 'economy', 'Increases wood production by 5% per level.', 15, NULL, 0, 100, 120, 80, 50, 180, JSON_OBJECT('wood_prod_pct', 5)),
(3, 'masonry', 'Masonry', 'economy', 'Increases stone production by 5% per level.', 15, NULL, 0, 100, 100, 120, 50, 180, JSON_OBJECT('stone_prod_pct', 5)),
(4, 'coinage', 'Coinage', 'economy', 'Increases gold production by 5% per level.', 15, 1, 3, 120, 120, 120, 120, 240, JSON_OBJECT('gold_prod_pct', 5)),
(5, 'military_drill', 'Military Drill', 'warfare', 'Increases unit attack by 3% per level.', 15, NULL, 0, 150, 120, 120, 100, 300, JSON_OBJECT('attack_pct', 3)),
(6, 'shield_wall', 'Shield Wall', 'warfare', 'Increases unit defense by 3% per level.', 15, 5, 2, 150, 100, 140, 110, 300, JSON_OBJECT('defense_pct', 3)),
(7, 'horse_breeding', 'Horse Breeding', 'warfare', 'Increases cavalry speed by 4% per level.', 10, 5, 3, 180, 120, 100, 140, 360, JSON_OBJECT('cavalry_speed_pct', 4)),
(8, 'engineering', 'Engineering', 'infrastructure', 'Improves build speed by 2% per level.', 12, 3, 2, 120, 120, 180, 90, 260, JSON_OBJECT('build_speed_pct', 2)),
(9, 'siegecraft', 'Siegecraft', 'warfare', 'Increases siege attack by 5% per level.', 10, 8, 2, 200, 160, 160, 160, 420, JSON_OBJECT('siege_attack_pct', 5)),
(10, 'logistics', 'Logistics', 'infrastructure', 'Reduces unit upkeep by 2% per level.', 12, 8, 1, 160, 160, 140, 120, 280, JSON_OBJECT('upkeep_reduction_pct', 2));

INSERT INTO unit_definitions (key_name, display_name, tier, attack, defense, speed, upkeep_food, training_time_seconds, cost_food, cost_wood, cost_stone, cost_gold, required_tech_id, required_building_key, required_building_level) VALUES
('militia', 'Militia', 1, 8, 7, 0.90, 1, 35, 12, 8, 6, 3, NULL, 'barracks', 1),
('infantry', 'Infantry', 2, 14, 12, 1.00, 1, 50, 24, 12, 12, 8, 5, 'barracks', 3),
('archer', 'Archer', 2, 18, 10, 1.10, 1, 60, 20, 28, 10, 10, 5, 'barracks', 4),
('cavalry', 'Cavalry', 3, 28, 18, 1.85, 2, 130, 56, 40, 24, 28, 7, 'barracks', 8),
('pikeman', 'Pikeman', 3, 22, 24, 0.95, 2, 120, 42, 18, 28, 20, 6, 'barracks', 7),
('siege', 'Siege Engine', 4, 46, 14, 0.70, 3, 190, 70, 50, 70, 34, 9, 'academy', 6),
('royal_guard', 'Royal Guard', 5, 60, 44, 1.20, 3, 260, 120, 80, 80, 90, 10, 'academy', 10);

INSERT INTO commander_definitions (key_name, display_name, rarity, attack_buff_pct, defense_buff_pct, speed_buff_pct, upkeep_reduction_pct) VALUES
('captain_arden', 'Captain Arden', 'common', 8, 4, 2, 0),
('marshal_lyra', 'Marshal Lyra', 'rare', 12, 8, 4, 2),
('strategos_vorn', 'Strategos Vorn', 'epic', 16, 10, 5, 4),
('empress_guardian', 'Empress Guardian', 'legendary', 22, 16, 8, 6);

-- =============================
-- Expansion pack: civilizations, builders, commanders, map meta, social & progression scaffolding
-- =============================

CREATE TABLE civilizations (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    key_name VARCHAR(30) NOT NULL UNIQUE,
    display_name VARCHAR(40) NOT NULL,
    bonus_json JSON NOT NULL,
    special_unit_key VARCHAR(40) NULL,
    starter_commander_key VARCHAR(40) NULL
) ENGINE=InnoDB;

ALTER TABLE users
    ADD COLUMN civilization_id INT UNSIGNED NULL,
    ADD COLUMN vip_points INT UNSIGNED NOT NULL DEFAULT 0,
    ADD COLUMN gems BIGINT UNSIGNED NOT NULL DEFAULT 0,
    ADD COLUMN action_points INT UNSIGNED NOT NULL DEFAULT 1000,
    ADD COLUMN kingdom_id INT UNSIGNED NOT NULL DEFAULT 1,
    ADD CONSTRAINT fk_user_civilization FOREIGN KEY (civilization_id) REFERENCES civilizations(id) ON DELETE SET NULL;

ALTER TABLE cities
    ADD COLUMN power_score BIGINT UNSIGNED NOT NULL DEFAULT 0,
    ADD COLUMN march_queue_limit TINYINT UNSIGNED NOT NULL DEFAULT 1,
    ADD COLUMN hospital_capacity INT UNSIGNED NOT NULL DEFAULT 0,
    ADD COLUMN wounded_infantry INT UNSIGNED NOT NULL DEFAULT 0,
    ADD COLUMN wounded_archer INT UNSIGNED NOT NULL DEFAULT 0,
    ADD COLUMN wounded_cavalry INT UNSIGNED NOT NULL DEFAULT 0,
    ADD COLUMN wounded_siege INT UNSIGNED NOT NULL DEFAULT 0;

ALTER TABLE world_tiles
    ADD COLUMN terrain_type ENUM('plains','forest','hill','mountain','river','lake','pass') NOT NULL DEFAULT 'plains',
    ADD COLUMN is_holy_site TINYINT(1) NOT NULL DEFAULT 0,
    ADD COLUMN fog_level TINYINT UNSIGNED NOT NULL DEFAULT 100,
    ADD COLUMN last_scouted_at DATETIME NULL;

ALTER TABLE building_definitions
    ADD COLUMN category ENUM('core','military','economy','defense','support') NOT NULL DEFAULT 'core',
    ADD COLUMN builder_slots_required TINYINT UNSIGNED NOT NULL DEFAULT 1;

ALTER TABLE build_queue
    ADD COLUMN builder_id BIGINT UNSIGNED NULL,
    ADD CONSTRAINT fk_build_queue_builder FOREIGN KEY (builder_id) REFERENCES city_builders(id) ON DELETE SET NULL;

ALTER TABLE unit_definitions
    ADD COLUMN troop_class ENUM('infantry','archer','cavalry','siege') NOT NULL DEFAULT 'infantry',
    ADD COLUMN march_capacity SMALLINT UNSIGNED NOT NULL DEFAULT 1;

ALTER TABLE commander_definitions
    MODIFY rarity ENUM('advanced','elite','epic','legendary') NOT NULL DEFAULT 'advanced',
    ADD COLUMN specialization ENUM('leadership','attacking','defending','gathering','peacekeeping','conquering','versatility') NOT NULL DEFAULT 'versatility',
    ADD COLUMN skill_1 VARCHAR(120) NULL,
    ADD COLUMN skill_2 VARCHAR(120) NULL,
    ADD COLUMN skill_3 VARCHAR(120) NULL,
    ADD COLUMN skill_4 VARCHAR(120) NULL,
    ADD COLUMN mastery_skill VARCHAR(120) NULL;

ALTER TABLE player_commanders
    ADD COLUMN secondary_commander_id BIGINT UNSIGNED NULL,
    ADD COLUMN talent_points INT UNSIGNED NOT NULL DEFAULT 0,
    ADD COLUMN gear_power INT UNSIGNED NOT NULL DEFAULT 0,
    ADD CONSTRAINT fk_secondary_commander FOREIGN KEY (secondary_commander_id) REFERENCES player_commanders(id) ON DELETE SET NULL;

ALTER TABLE army_movements
    ADD COLUMN total_march_capacity INT UNSIGNED NOT NULL DEFAULT 0;

CREATE TABLE city_builders (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    city_id INT UNSIGNED NOT NULL,
    slot_index TINYINT UNSIGNED NOT NULL,
    is_unlocked TINYINT(1) NOT NULL DEFAULT 0,
    unlock_cost_gems INT UNSIGNED NOT NULL DEFAULT 0,
    status ENUM('idle','building') NOT NULL DEFAULT 'idle',
    UNIQUE KEY uniq_city_builder_slot (city_id, slot_index),
    INDEX idx_city_builder_status (city_id, status),
    CONSTRAINT fk_city_builder_city FOREIGN KEY (city_id) REFERENCES cities(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE commander_equipment (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    player_commander_id BIGINT UNSIGNED NOT NULL,
    slot ENUM('weapon','helmet','armor','boots','accessory') NOT NULL,
    item_name VARCHAR(120) NOT NULL,
    rarity ENUM('common','uncommon','rare','epic','legendary') NOT NULL DEFAULT 'common',
    stat_json JSON NOT NULL,
    level TINYINT UNSIGNED NOT NULL DEFAULT 1,
    CONSTRAINT fk_commander_equipment_commander FOREIGN KEY (player_commander_id) REFERENCES player_commanders(id) ON DELETE CASCADE,
    UNIQUE KEY uniq_commander_slot (player_commander_id, slot)
) ENGINE=InnoDB;

CREATE TABLE player_items (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id INT UNSIGNED NOT NULL,
    item_key VARCHAR(60) NOT NULL,
    quantity INT UNSIGNED NOT NULL DEFAULT 0,
    INDEX idx_player_item_user (user_id),
    UNIQUE KEY uniq_player_item (user_id, item_key),
    CONSTRAINT fk_player_item_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE kingdoms (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(60) NOT NULL,
    season_key VARCHAR(40) NOT NULL DEFAULT 'season_1',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE kvk_seasons (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    kingdom_id INT UNSIGNED NOT NULL,
    season_number INT UNSIGNED NOT NULL,
    chapter_name VARCHAR(120) NOT NULL,
    status ENUM('preparation','active','ended') NOT NULL DEFAULT 'preparation',
    starts_at DATETIME NULL,
    ends_at DATETIME NULL,
    CONSTRAINT fk_kvk_kingdom FOREIGN KEY (kingdom_id) REFERENCES kingdoms(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE quests (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id INT UNSIGNED NOT NULL,
    quest_key VARCHAR(60) NOT NULL,
    quest_type ENUM('tutorial','daily','weekly','achievement','event') NOT NULL,
    target_value INT UNSIGNED NOT NULL DEFAULT 1,
    progress_value INT UNSIGNED NOT NULL DEFAULT 0,
    is_completed TINYINT(1) NOT NULL DEFAULT 0,
    reward_json JSON NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_quests_user_type (user_id, quest_type, is_completed),
    CONSTRAINT fk_quests_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

INSERT INTO civilizations (key_name, display_name, bonus_json, special_unit_key, starter_commander_key) VALUES
('rome','Rome', JSON_OBJECT('infantry_defense_pct',5,'build_speed_pct',5), 'infantry', 'julius_caesar'),
('germany','Germany', JSON_OBJECT('cavalry_attack_pct',5,'training_speed_pct',5), 'cavalry', 'frederick_i'),
('britain','Britain', JSON_OBJECT('archer_attack_pct',5,'research_speed_pct',5), 'archer', 'boudica'),
('france','France', JSON_OBJECT('health_pct',3,'healing_speed_pct',10), 'infantry', 'joan_of_arc'),
('spain','Spain', JSON_OBJECT('resource_gather_pct',5,'exp_gain_pct',5), 'cavalry', 'el_cid'),
('china','China', JSON_OBJECT('building_speed_pct',5,'action_point_recovery_pct',5), 'infantry', 'sun_tzu'),
('japan','Japan', JSON_OBJECT('scout_speed_pct',10,'troop_attack_pct',3), 'archer', 'tokugawa_ieyasu'),
('korea','Korea', JSON_OBJECT('research_speed_pct',8,'hospital_capacity_pct',5), 'archer', 'eulji_mundeok'),
('arabia','Arabia', JSON_OBJECT('cavalry_damage_pct',5,'barbarian_damage_pct',5), 'cavalry', 'saladin'),
('ottoman','Ottoman', JSON_OBJECT('archer_hp_pct',5,'march_speed_pct',5), 'siege', 'mehmed_ii'),
('byzantium','Byzantium', JSON_OBJECT('cavalry_defense_pct',5,'hospital_heal_pct',5), 'cavalry', 'belisarius'),
('greece','Greece', JSON_OBJECT('commander_exp_pct',8,'gather_speed_pct',4), 'infantry', 'alexander_the_great'),
('vikings','Vikings', JSON_OBJECT('infantry_attack_pct',5,'resource_raid_pct',5), 'infantry', 'ragnar_lodbrok'),
('maya','Maya', JSON_OBJECT('production_pct',5,'march_queue_bonus',1), 'archer', 'lady_six_sky');

UPDATE building_definitions SET category = 'military' WHERE key_name IN ('barracks');
UPDATE building_definitions SET category = 'economy' WHERE key_name IN ('farm','lumber_mill','quarry','gold_mine','warehouse');
UPDATE building_definitions SET category = 'support' WHERE key_name IN ('academy');
UPDATE building_definitions SET category = 'defense' WHERE key_name IN ('walls');

INSERT INTO building_definitions (key_name, display_name, base_food, base_wood, base_stone, base_gold, base_duration_seconds, required_town_hall_level, max_level, effects_json, category, builder_slots_required) VALUES
('archery_range','Archery Range',130,180,120,90,220,3,25,JSON_OBJECT('archer_train_speed_pct',3),'military',1),
('stable','Stable',160,190,150,100,240,4,25,JSON_OBJECT('cavalry_train_speed_pct',3),'military',1),
('siege_workshop','Siege Workshop',220,260,240,140,300,8,20,JSON_OBJECT('siege_train_speed_pct',4),'military',1),
('hospital','Hospital',180,150,220,120,260,4,20,JSON_OBJECT('hospital_capacity',1500),'support',1),
('tavern','Tavern',140,140,100,200,180,3,20,JSON_OBJECT('commander_recruit_chance_pct',2),'support',1),
('trading_post','Trading Post',150,220,150,130,220,5,20,JSON_OBJECT('tax_income_pct',3),'economy',1),
('watchtower','Watchtower',120,160,220,120,230,4,20,JSON_OBJECT('scout_vision_range',1),'defense',1),
('monument','Monument',300,300,300,250,420,10,15,JSON_OBJECT('power_bonus_pct',2),'core',1);

UPDATE unit_definitions SET troop_class = 'infantry' WHERE key_name IN ('militia','infantry','pikeman','royal_guard');
UPDATE unit_definitions SET troop_class = 'archer' WHERE key_name IN ('archer');
UPDATE unit_definitions SET troop_class = 'cavalry' WHERE key_name IN ('cavalry');
UPDATE unit_definitions SET troop_class = 'siege' WHERE key_name IN ('siege');
UPDATE unit_definitions SET march_capacity = CASE tier WHEN 1 THEN 1 WHEN 2 THEN 2 WHEN 3 THEN 3 WHEN 4 THEN 4 ELSE 5 END;

INSERT INTO kingdoms (name, season_key) VALUES ('Kingdom 1','season_1');
INSERT INTO kvk_seasons (kingdom_id, season_number, chapter_name, status) VALUES
(1,1,'The Lost Kingdom','preparation'),
(1,2,'The Lost Kingdom II','preparation'),
(1,3,'Light and Darkness','preparation'),
(1,4,'Season of Conquest: Heroic Anthem','preparation');

INSERT INTO commander_definitions (key_name, display_name, rarity, specialization, attack_buff_pct, defense_buff_pct, speed_buff_pct, upkeep_reduction_pct, skill_1, skill_2, skill_3, skill_4, mastery_skill) VALUES
('julius_caesar','Julius Caesar','legendary','leadership',20,14,6,4,'Conqueror''s March','Imperial Edict','Roman Discipline','Legion Command','Ave Imperator'),
('sun_tzu','Sun Tzu','epic','attacking',15,10,4,2,'Art of War','Calculated Assault','Battle Formation','Ambush Doctrine','Supreme Stratagem'),
('joan_of_arc','Joan of Arc','epic','leadership',12,12,3,3,'Inspiring Banner','Holy Charge','Field Rally','Saint''s Guard','Divine Resolve'),
('alexander_the_great','Alexander the Great','legendary','conquering',22,10,8,2,'Companion Charge','Gordian Strike','King''s Ambition','Hellenic Command','World Conqueror'),
('cleopatra','Cleopatra','legendary','gathering',8,12,5,5,'Nile Abundance','Golden Bargain','Royal Caravan','Queen''s Decree','Last Pharaoh'),
('ragnar_lodbrok','Ragnar Lodbrok','epic','attacking',16,8,6,1,'Viking Fury','Raid Leader','Sea Wolf','Northman Wrath','Valhalla Oath');


INSERT INTO commander_definitions (key_name, display_name, rarity, specialization, attack_buff_pct, defense_buff_pct, speed_buff_pct, upkeep_reduction_pct, skill_1, skill_2, skill_3, skill_4, mastery_skill) VALUES
('cmd_frederick_i','Frederick I','advanced','leadership',6,5,2,0,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran',NULL),
('cmd_boudica','Boudica','elite','attacking',7,6,3,1,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran',NULL),
('cmd_el_cid','El Cid','epic','defending',8,7,4,2,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran','Heroic Legacy'),
('cmd_tokugawa_ieyasu','Tokugawa Ieyasu','advanced','gathering',9,8,5,3,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran',NULL),
('cmd_eulji_mundeok','Eulji Mundeok','elite','peacekeeping',10,9,6,0,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran',NULL),
('cmd_saladin','Saladin','epic','conquering',11,10,2,1,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran','Heroic Legacy'),
('cmd_mehmed_ii','Mehmed II','advanced','versatility',12,11,3,2,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran',NULL),
('cmd_belisarius','Belisarius','elite','leadership',13,5,4,3,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran',NULL),
('cmd_hannibal_barca','Hannibal Barca','epic','attacking',6,6,5,0,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran','Heroic Legacy'),
('cmd_scipio_africanus','Scipio Africanus','advanced','defending',7,7,6,1,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran',NULL),
('cmd_richard_the_lionheart','Richard the Lionheart','elite','gathering',8,8,2,2,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran',NULL),
('cmd_william_wallace','William Wallace','epic','peacekeeping',9,9,3,3,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran','Heroic Legacy'),
('cmd_genghis_khan','Genghis Khan','advanced','conquering',10,10,4,0,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran',NULL),
('cmd_kublai_khan','Kublai Khan','elite','versatility',11,11,5,1,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran',NULL),
('cmd_yi_sun_sin','Yi Sun-sin','epic','leadership',12,5,6,2,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran','Heroic Legacy'),
('cmd_miyamoto_musashi','Miyamoto Musashi','advanced','attacking',13,6,2,3,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran',NULL),
('cmd_oda_nobunaga','Oda Nobunaga','elite','defending',6,7,3,0,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran',NULL),
('cmd_toyotomi_hideyoshi','Toyotomi Hideyoshi','epic','gathering',7,8,4,1,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran','Heroic Legacy'),
('cmd_arminius','Arminius','advanced','peacekeeping',8,9,5,2,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran',NULL),
('cmd_charlemagne','Charlemagne','elite','conquering',9,10,6,3,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran',NULL),
('cmd_otto_the_great','Otto the Great','epic','versatility',10,11,2,0,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran','Heroic Legacy'),
('cmd_henry_v','Henry V','advanced','leadership',11,5,3,1,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran',NULL),
('cmd_edward_iii','Edward III','elite','attacking',12,6,4,2,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran',NULL),
('cmd_napoleon_bonaparte','Napoleon Bonaparte','epic','defending',13,7,5,3,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran','Heroic Legacy'),
('cmd_marshal_ney','Marshal Ney','advanced','gathering',6,8,6,0,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran',NULL),
('cmd_duke_of_wellington','Duke of Wellington','elite','peacekeeping',7,9,2,1,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran',NULL),
('cmd_ramesses_ii','Ramesses II','epic','conquering',8,10,3,2,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran','Heroic Legacy'),
('cmd_thutmose_iii','Thutmose III','advanced','versatility',9,11,4,3,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran',NULL),
('cmd_cyrus_the_great','Cyrus the Great','elite','leadership',10,5,5,0,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran',NULL),
('cmd_darius_i','Darius I','epic','attacking',11,6,6,1,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran','Heroic Legacy'),
('cmd_xerxes_i','Xerxes I','advanced','defending',12,7,2,2,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran',NULL),
('cmd_leonidas','Leonidas','elite','gathering',13,8,3,3,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran',NULL),
('cmd_pericles','Pericles','epic','peacekeeping',6,9,4,0,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran','Heroic Legacy'),
('cmd_themistocles','Themistocles','advanced','conquering',7,10,5,1,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran',NULL),
('cmd_miltiades','Miltiades','elite','versatility',8,11,6,2,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran',NULL),
('cmd_pyrrhus','Pyrrhus','epic','leadership',9,5,2,3,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran','Heroic Legacy'),
('cmd_philip_ii','Philip II','advanced','attacking',10,6,3,0,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran',NULL),
('cmd_spartacus','Spartacus','elite','defending',11,7,4,1,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran',NULL),
('cmd_vercingetorix','Vercingetorix','epic','gathering',12,8,5,2,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran','Heroic Legacy'),
('cmd_attila','Attila','advanced','peacekeeping',13,9,6,3,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran',NULL),
('cmd_basil_ii','Basil II','elite','conquering',6,10,2,0,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran',NULL),
('cmd_constantine_xi','Constantine XI','epic','versatility',7,11,3,1,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran','Heroic Legacy'),
('cmd_nikephoros_phokas','Nikephoros Phokas','advanced','leadership',8,5,4,2,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran',NULL),
('cmd_harald_hardrada','Harald Hardrada','elite','attacking',9,6,5,3,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran',NULL),
('cmd_leif_erikson','Leif Erikson','epic','defending',10,7,6,0,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran','Heroic Legacy'),
('cmd_canute','Canute','advanced','gathering',11,8,2,1,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran',NULL),
('cmd_ivar_the_boneless','Ivar the Boneless','elite','peacekeeping',12,9,3,2,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran',NULL),
('cmd_bjorn_ironside','Bjorn Ironside','epic','conquering',13,10,4,3,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran','Heroic Legacy'),
('cmd_lagertha','Lagertha','advanced','versatility',6,11,5,0,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran',NULL),
('cmd_montezuma','Montezuma','elite','leadership',7,5,6,1,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran',NULL),
('cmd_pacal_the_great','Pacal the Great','epic','attacking',8,6,2,2,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran','Heroic Legacy'),
('cmd_lady_six_sky','Lady Six Sky','advanced','defending',9,7,3,3,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran',NULL),
('cmd_itzcoatl','Itzcoatl','elite','gathering',10,8,4,0,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran',NULL),
('cmd_moctezuma_i','Moctezuma I','epic','peacekeeping',11,9,5,1,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran','Heroic Legacy'),
('cmd_ashoka','Ashoka','advanced','conquering',12,10,6,2,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran',NULL),
('cmd_chandragupta','Chandragupta','elite','versatility',13,11,2,3,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran',NULL),
('cmd_porus','Porus','epic','leadership',6,5,3,0,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran','Heroic Legacy'),
('cmd_akbar','Akbar','advanced','attacking',7,6,4,1,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran',NULL),
('cmd_babur','Babur','elite','defending',8,7,5,2,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran',NULL),
('cmd_shaka_zulu','Shaka Zulu','epic','gathering',9,8,6,3,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran','Heroic Legacy'),
('cmd_mansa_musa','Mansa Musa','advanced','peacekeeping',10,9,2,0,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran',NULL),
('cmd_sundiata_keita','Sundiata Keita','elite','conquering',11,10,3,1,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran',NULL),
('cmd_tariq_ibn_ziyad','Tariq ibn Ziyad','epic','versatility',12,11,4,2,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran','Heroic Legacy'),
('cmd_khalid_ibn_al_walid','Khalid ibn al-Walid','advanced','leadership',13,5,5,3,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran',NULL),
('cmd_nur_ad_din','Nur ad-Din','elite','attacking',6,6,6,0,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran',NULL),
('cmd_baibars','Baibars','epic','defending',7,7,2,1,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran','Heroic Legacy'),
('cmd_nader_shah','Nader Shah','advanced','gathering',8,8,3,2,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran',NULL),
('cmd_tamerlane','Tamerlane','elite','peacekeeping',9,9,4,3,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran',NULL),
('cmd_aurangzeb','Aurangzeb','epic','conquering',10,10,5,0,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran','Heroic Legacy'),
('cmd_rani_lakshmibai','Rani Lakshmibai','advanced','versatility',11,11,6,1,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran',NULL),
('cmd_subutai','Subutai','elite','leadership',12,5,2,2,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran',NULL),
('cmd_jebe','Jebe','epic','attacking',13,6,3,3,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran','Heroic Legacy'),
('cmd_batu_khan','Batu Khan','advanced','defending',6,7,4,0,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran',NULL),
('cmd_timur_qutlugh','Timur Qutlugh','elite','gathering',7,8,5,1,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran',NULL),
('cmd_isabella_i','Isabella I','epic','peacekeeping',8,9,6,2,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran','Heroic Legacy'),
('cmd_ferdinand_ii','Ferdinand II','advanced','conquering',9,10,2,3,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran',NULL),
('cmd_alfonso_x','Alfonso X','elite','versatility',10,11,3,0,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran',NULL),
('cmd_juan_of_austria','Juan of Austria','epic','leadership',11,5,4,1,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran','Heroic Legacy'),
('cmd_cortes','Cortes','advanced','attacking',12,6,5,2,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran',NULL),
('cmd_pizarro','Pizarro','elite','defending',13,7,6,3,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran',NULL),
('cmd_king_arthur','King Arthur','epic','gathering',6,8,2,0,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran','Heroic Legacy'),
('cmd_lancelot','Lancelot','advanced','peacekeeping',7,9,3,1,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran',NULL),
('cmd_gawain','Gawain','elite','conquering',8,10,4,2,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran',NULL),
('cmd_merlin','Merlin','epic','versatility',9,11,5,3,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran','Heroic Legacy'),
('cmd_robin_hood','Robin Hood','advanced','leadership',10,5,6,0,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran',NULL),
('cmd_alfred_the_great','Alfred the Great','elite','attacking',11,6,2,1,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran',NULL),
('cmd_aethelflaed','Aethelflaed','epic','defending',12,7,3,2,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran','Heroic Legacy'),
('cmd_harold_godwinson','Harold Godwinson','advanced','gathering',13,8,4,3,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran',NULL),
('cmd_louis_ix','Louis IX','elite','peacekeeping',6,9,5,0,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran',NULL),
('cmd_philip_augustus','Philip Augustus','epic','conquering',7,10,6,1,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran','Heroic Legacy'),
('cmd_charles_martel','Charles Martel','advanced','versatility',8,11,2,2,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran',NULL),
('cmd_joachim_murat','Joachim Murat','elite','leadership',9,5,3,3,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran',NULL),
('cmd_jean_lannes','Jean Lannes','epic','attacking',10,6,4,0,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran','Heroic Legacy'),
('cmd_ulysses_s_grant','Ulysses S. Grant','advanced','defending',11,7,5,1,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran',NULL),
('cmd_robert_e_lee','Robert E. Lee','elite','gathering',12,8,6,2,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran',NULL),
('cmd_george_washington','George Washington','epic','peacekeeping',13,9,2,3,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran','Heroic Legacy'),
('cmd_horatio_nelson','Horatio Nelson','advanced','conquering',6,10,3,0,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran',NULL),
('cmd_admiral_zheng_he','Admiral Zheng He','elite','versatility',7,11,4,1,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran',NULL),
('cmd_qin_shi_huang','Qin Shi Huang','epic','leadership',8,5,5,2,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran','Heroic Legacy'),
('cmd_emperor_taizong','Emperor Taizong','advanced','attacking',9,6,6,3,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran',NULL),
('cmd_wu_zetian','Wu Zetian','elite','defending',10,7,2,0,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran',NULL),
('cmd_yue_fei','Yue Fei','epic','gathering',11,8,3,1,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran','Heroic Legacy'),
('cmd_huo_qubing','Huo Qubing','advanced','peacekeeping',12,9,4,2,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran',NULL),
('cmd_guan_yu','Guan Yu','elite','conquering',13,10,5,3,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran',NULL),
('cmd_zhao_yun','Zhao Yun','epic','versatility',6,11,6,0,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran','Heroic Legacy'),
('cmd_lu_bu','Lu Bu','advanced','leadership',7,5,2,1,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran',NULL),
('cmd_cao_cao','Cao Cao','elite','attacking',8,6,3,2,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran',NULL),
('cmd_sima_yi','Sima Yi','epic','defending',9,7,4,3,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran','Heroic Legacy'),
('cmd_zhuge_liang','Zhuge Liang','advanced','gathering',10,8,5,0,'Tactical Insight','Battle Rhythm','War Council','Seasoned Veteran',NULL);

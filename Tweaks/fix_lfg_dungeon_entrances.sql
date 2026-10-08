-- Dungeon Finder: send groups to the FRONT entrance of Gnomeregan, Uldaman and Lower Blackrock Spire.
-- Without a row in lfg_dungeon_template the core uses "a" map entrance trigger, which can be the back entrance
-- (Gnomeregan: locked Workshop Door; Uldaman: next to the last boss; LBRS: the Upper Spire entrance).
-- Coordinates are the front-entrance areatrigger targets (324, 286, 1468). Takes effect after a world server restart.
DELETE FROM lfg_dungeon_template WHERE dungeonId IN (14, 22, 32);
INSERT INTO lfg_dungeon_template (dungeonId, name, position_x, position_y, position_z, orientation) VALUES
  (14, 'Gnomeregan',            -329.10,   -3.21, -152.85, 2.97),
  (22, 'Uldaman',               -228.86,   46.10,  -46.02, 1.57),
  (32, 'Lower Blackrock Spire',   78.35, -226.84,   49.77, 4.71);
SELECT * FROM lfg_dungeon_template WHERE dungeonId IN (14, 22, 32);

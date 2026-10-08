-- Revert fix_lfg_dungeon_entrances.sql: remove the explicit Dungeon Finder entrances for
-- Gnomeregan, Uldaman and Lower Blackrock Spire (the core falls back to a map entrance trigger again).
-- Takes effect after a world server restart.
DELETE FROM lfg_dungeon_template WHERE dungeonId IN (14, 22, 32);
SELECT COUNT(*) AS rows_left FROM lfg_dungeon_template WHERE dungeonId IN (14, 22, 32);

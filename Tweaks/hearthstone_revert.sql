-- Revert Hearthstone to default 30 minute cooldown
UPDATE item_template SET spellcategory_1 = 0, spellcategorycooldown_1 = -1 WHERE entry = 6948;

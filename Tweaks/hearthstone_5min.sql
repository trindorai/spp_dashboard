-- Hearthstone (item 6948): 5 minute cooldown instead of 30
-- Original values: spellcategory_1 = 0, spellcategorycooldown_1 = -1 (uses spell 8690 default: 1800000 ms)
UPDATE item_template SET spellcategory_1 = 1176, spellcategorycooldown_1 = 300000 WHERE entry = 6948;
SELECT entry, name, spellid_1, spellcooldown_1, spellcategory_1, spellcategorycooldown_1 FROM item_template WHERE entry = 6948;

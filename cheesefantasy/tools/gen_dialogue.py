#!/usr/bin/env python3
"""Generates game/data/dialogue/*.json (compact authoring format -> dialogue_box.gd JSON)."""
import json, os
OUT = os.path.join(os.path.dirname(__file__), "..", "game", "data", "dialogue")
os.makedirs(OUT, exist_ok=True)

def chain(lines, prefix="n", end=True):
    nodes = {}
    for i, t in enumerate(lines):
        n = {"text": t}
        if i + 1 < len(lines):
            n["next"] = f"{prefix}{i+1}"
        elif end:
            n["end"] = True
        nodes[f"{prefix}{i}"] = n
    return nodes

def save(id, speaker, model, accent, nodes, start="n0"):
    d = {"id": id, "speaker": speaker, "model": model, "accent": accent, "start": start, "nodes": nodes}
    with open(os.path.join(OUT, id + ".json"), "w") as f:
        json.dump(d, f, indent=1, ensure_ascii=False)

def simple(id, speaker, model, accent, lines, repeat=None):
    nodes = chain(lines)
    start = "n0"
    if repeat:
        nodes.update(chain(repeat, "r"))
        flag = f"talked_{id}"
        nodes["n0"]["set"] = flag
        start = [{"if": flag, "goto": "r0"}, {"goto": "n0"}]
    save(id, speaker, model, accent, nodes, start)

# ---- Main quest -----------------------------------------------------------
nodes = {}
nodes.update(chain([
 "Fennel! Thank goodness you're up. Something terrible has happened. Something... un-brie-lievable.",
 "Last night, a gang of rats crept into the Cheese Cave and stole the LAST WHEEL. A hundred years of rind, mould and patience, gone.",
 "Their leader is that rotten scoundrel, King Gorgonzolo. Wherever his gang walks, the Blue Rot creeps over my fields. Look at my poor corn!",
], "n"))
nodes["n2"].pop("end"); nodes["n2"]["next"] = "ask"
nodes["ask"] = {"text": "You're the best apprentice cheesemonger-chef this farm has ever had. (You're also the only one. But still!) Will you find the Last Wheel?",
 "choices": [
  {"text": "I'll bring it home, Farmer Gouda!", "next": "yes", "set": {"quest_started": True}, "quest": ["last_wheel", "active"], "gold": 50},
  {"text": "Rat King? Is that a real job?", "next": "lore"},
  {"text": "Can I have a snack first?", "next": "snack"}]}
nodes["lore"] = {"text": "Oh, it's real. He wears a crown of bottle caps and smells faintly of old blue cheese. And he is VERY good at squeaking dramatically.", "next": "ask"}
nodes["snack"] = {"text": "A growing kitten needs her curds, I know. Visit Chef Camembert in the farmhouse. But hurry, the Rot won't wait!", "next": "ask"}
nodes["yes"] = {"text": "That's my girl! Here, 50 gold for supplies. Talk to the folks around the farm: Granny Edam knows the cave's secrets, and Chef Camembert can teach you to cook with what you find. Cook it right and it'll melt the toughest rat!",
 "toast": "Quest started: The Last Wheel", "end": True}
nodes["rem0"] = {"text": "Any luck with the Last Wheel, Fennel? The cave is north, up the hill past the big oak. Be careful of rats, crows, and... I'm told, mould with opinions.", "next": "rem1"}
nodes["rem1"] = {"text": "Rest at a campfire if you get tired. Nothing like a toasty fire and a cheese toastie. Go on, I believe in you!", "end": True}
save("farmer_gouda", "Farmer Gouda", "npc_farmer", "#e8b04a", nodes,
     [{"if": "quest_started", "goto": "rem0"}, {"goto": "n0"}])

# ---- Villagers ------------------------------------------------------------
nodes = chain(["Ah, Fennel! Welcome to my kitchen. Mind the cauldron, it is bubbling with opinions today.",
 "Listen, cooking is the soul of fighting. A Smoked Gouda glaze makes your fire hotter. A sprig of thyme in your whey makes it gust. Mix and match at the cauldron!",
 "Bring me a rare cheese and I'll make you something that would make a rat weep with joy. Or just weep. They weep easily."])
nodes["n2"].pop("end"); nodes["n2"]["next"] = "q"
nodes["q"] = {"text": "Shall I tell you a kitchen secret?", "choices": [
  {"text": "Yes, please!", "next": "s", "set": "cook_secret"},
  {"text": "No, I'll find out the hard way.", "next": "no"}]}
nodes["s"] = {"text": "Never cook angry. Angry cheese gets grainy. Also: butter. When in doubt, more butter.", "end": True}
nodes["no"] = {"text": "Ha! A true chef. Splash first, ask questions later.", "end": True}
save("cook", "Chef Camembert", "npc_cook", "#e86a5a", nodes)

nodes = chain(["Fennel, my dear. Smell that? That's a nineteen-month Alpine, still cave-sweating.",
 "A wise cheesemonger knows: young cheeses are mild and hasty, aged cheeses are sharp and patient. Same as cats, really."])
nodes["n1"].pop("end"); nodes["n1"]["next"] = "q"
nodes["q"] = {"text": "What would you like to know about?", "choices": [
 {"text": "Tell me about the Last Wheel.", "next": "wheel"},
 {"text": "What makes a good cheese?", "next": "good"},
 {"text": "Never mind.", "next": "bye"}]}
nodes["wheel"] = {"text": "A hundred years old. They say one slice can heal a village, and one whiff can wake a sleeping giant. Gorgonzolo wants it to feed the Rot.", "next": "q"}
nodes["good"] = {"text": "Patience, a little mould, and love. Also not leaving it near rats, evidently.", "next": "q"}
nodes["bye"] = {"text": "Stay sharp, Fennel. Like a good cheddar.", "end": True}
save("cheesemonger", "Monger Havarti", "npc_cheesemonger", "#f2d56a", nodes)

nodes = chain(["Hold still, I'm measuring the squeak of your boots. Ah, this is the Mark IV Cheese-O-Matic. It slices, it dices, it occasionally explodes.",
 "I wired the windmill to the churn. Now it makes butter AND a pleasant humming noise. Mostly the humming."])
nodes["n1"].pop("end"); nodes["n1"]["next"] = "gift"
nodes["gift"] = {"text": "Oh! Take this spare gear. I made forty of them. Do not ask why.", "if": "!tinker_gift", "set": "tinker_gift", "item": ["spare_gear", 1], "toast": "Received Spare Gear", "end": True, "else": "no"}
nodes["no"] = {"text": "Come back if your gadgets break. Or if they explode. Either is fine.", "end": True}
save("tinker", "Tinker Tilsit", "npc_tinker", "#7ab6d8", nodes)

simple("kid_colby", "Little Colby", "npc_kid", "#f09a5a",
 ["I'm Colby! Like the cheese! Well, Colby-Jack. Jack is my brother. He's a rind of a different colour.",
  "I saw a rat in the corn yesterday. It was THIS big. Okay, maybe THIS big. Okay, normal rat-size. But scary!"],
 ["Did you know cows have four stomachs? I only have one. I am at a disadvantage."])
simple("kid_pip", "Pip", "npc_kid", "#9ad06a",
 ["Shh! I'm playing hide-and-seek with the chickens. They're really good at it. I haven't found one in three days.",
  "If you see Cluck Norris, don't tell him I'm here. He roundhouse-pecks."],
 ["Still hiding. Still not found. This is the best game ever."])

nodes = chain(["Come closer, dearie. Granny Edam has seen a hundred harvests and sniffed ninety-nine cheeses.",
 "The Cheese Cave runs deeper than the hill. The Last Wheel was kept in the Aging Hall, behind a door that only opens for those who know the Three Cuts.",
 "Take Madame Brie, that grand hen in the orchard, she hears the winds. Take Clover, the goat in the pasture, she is a wall of iron. And Maple, my granddaughter, she keeps the cellar. Go. Find them!"])
nodes["n2"]["set"] = {"granny_hint": True}
save("granny", "Granny Edam", "npc_granny", "#c89adb", nodes)

simple("scarecrow", "Sir Strawsworth", "npc_scarecrow", "#d8b84a",
 ["Hail, traveller! I am Sir Strawsworth, Knight of the Corn! I have guarded these fields since... a long time ago. Birds respect me. Mostly from a distance.",
  "(He doesn't move. Is he... talking? Surely it's the wind.)"],
 ["I would love to chase the crows, but, you see, I am stuck on a pole. Tragic, really."])

# ---- Party members --------------------------------------------------------
nodes = chain(["Fennel! Grandpa told me about the Last Wheel. I keep the cellar, I know every shelf in the cave.",
 "I'm coming with you. Don't argue, I've already packed. Three jars of pickles, a warm scarf, and a very sharp ladle."])
nodes["n1"]["set"] = {"met_maple": True}
save("maple", "Maple", "hero_maple", "#7fd0ee", nodes)
nodes = chain(["Darling, do mind the mud. I am Madame Brie, speckled and stately, and the finest egg-wizard in the Whey Valley.",
 "I felt a disturbance in the wind. A blue, rotten sort of draft. Yes, I shall accompany you. Do try to keep up!"])
nodes["n1"]["set"] = {"met_brie": True}
save("brie", "Madame Brie", "hero_brie", "#f5f0d8", nodes)
nodes = chain(["*clang* Oh. A kitten. Did you want something?",
 "Name's Clover. I protect this pasture with my skillet. Rats took the lunch cheese. I hold a grudge. A large, iron one.",
 "If you're heading for the cave, I'm with you. Nobody steals my cheese and lives to... not give it back."])
nodes["n2"]["set"] = {"met_clover": True}
save("clover", "Clover", "hero_clover", "#9a8a6a", nodes)

# ---- Animals --------------------------------------------------------------
simple("cow_bessie", "Bessie", "animal_cow", "#e8e0d0",
 ["Moooo. Mooo moo. (Translation: the grass is delicious today.)", "Moo. (Translation: I make the milk that makes the cheese. I am practically royalty.)"],
 ["Moooo. (Translation: you are standing in my sunbeam.)"])
simple("cow_moolissa", "Moolissa", "animal_cow", "#e8e0d0",
 ["Mooo? (Translation: have you seen my calf? Oh, there she is, eating the fence. Again.)"],
 ["Moo-ve along, dear. (She's very proud of that one.)"])
simple("pig_oinks", "Sir Oinks-a-Lot", "animal_pig", "#f2a8b0",
 ["Oink! Oink oink. (Translation: I am a truffle expert. I can smell Roquefort from three counties away.)",
  "Oink... (Translation: the rats smell like old socks and bad decisions.)"],
 ["Oink. (Mud. Mud is happiness.)"])
simple("chicken_cluck", "Cluck Norris", "animal_chicken", "#f5f5f0",
 ["BAWK! (Translation: Cluck Norris does not cross the road. The road crosses Cluck Norris.)"],
 ["Bawk. (Translation: I laid an egg yesterday. It was legendary. It's still rolling.)"])
simple("chicken_hen", "Hen Solo", "animal_chicken", "#e8d0b0",
 ["Cluck cluck. (Translation: I have a bad feeling about this coop.)", "Cluck? (Translation: Never tell me the odds of getting a good egg. The odds are scrambled.)"],
 ["Cluck. (Translation: may the Fork be with you.)"])
simple("goat_feta", "Nanny Feta", "animal_goat", "#d8d0c0",
 ["Meeeh! (Translation: I eat tin cans. And occasionally cheese wrappers. Sometimes the label is the best part.)"],
 ["Meh. (Translation: I tried to eat the fence. The fence won.)"])
simple("sheep_woolly", "Woolly Nelson", "animal_sheep", "#f0ece0",
 ["Baaah. (Translation: I am a fluffy cloud of destiny.)", "Baa? (Translation: if you count us to fall asleep, you will lose count. We keep moving.)"],
 ["Baaa. (Translation: so fluffy. So very fluffy.)"])
simple("sheep_barbara", "Baa-rbara", "animal_sheep", "#f0ece0",
 ["Baaa! (Translation: the wolf cried 'boy' once, and now nobody trusts a sheep's word. Typical.)"],
 ["Baaa. (Translation: I would like to speak to the shepherd's manager.)"])
simple("dog_wensleydale", "Captain Wensleydale", "animal_dog", "#d8a860",
 ["WOOF! (Translation: Fennel! Good kitten! Good! I have not chased a single rat today. Okay, I chased twelve. Okay, twenty.)",
  "Woof. (Translation: the rats went north, into the cave. I can smell them. They smell like betrayal and cheese rind.)"],
 ["Woof! (Translation: go get 'em! I'll guard the farm!)"])
simple("duck_quackers", "Quackers", "animal_duck", "#a8d8e8",
 ["Quack. (Translation: I am a duck. Duck pond. Duck rules. Do not ask about the ducks in the other pond. We do not speak of them.)"],
 ["Quack. (Translation: ... bread?)"])

# ---- Shrine narration -----------------------------------------------------
nodes = chain(["The Rainbow Orchard shrine glows in seven soft colours. A faint purring hums through the apple blossoms.",
 "Nine tiny paw prints are carved into the old stone. The Nine Lives Spirits, the farm's cats of ages past, sleep here."])
nodes["n1"]["set"] = {"shrine_seen": True}
save("shrine_whisper", "The Shrine", "", "#c8a8f0", nodes)
print("wrote", len(os.listdir(OUT)), "dialogues")

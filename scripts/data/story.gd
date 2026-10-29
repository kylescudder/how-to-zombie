class_name Story
## Island stories. Barea City: find the Yellow Sticker idol, then escape the city on high alert.
##
## Barea's stages (Game.story.barea):
##   "arrive"  - just landed; talk to survivors to learn where the idol is
##   "hunt"    - someone told you about the Price Slasher Megamart
##   "alert"   - the idol is taken; the whole city hunts you until you sail away
##   "escaped" - you made it off the island

const BAREA_STAGES := ["arrive", "hunt", "alert", "escaped"]

## Survivors you can talk to. `spot` names a place BareaCity puts them; lines change once the
## idol is taken. Talking to any of them (before the alert) reveals the Megamart.
const NPCS := [
	{
		"id": "marla", "name": "Captain Marla", "spot": "dock", "look": [Color(0.86, 0.68, 0.52), Color(0.2, 0.3, 0.55), Color(0.18, 0.18, 0.22)],
		"lines": [
			"You made it. Welcome to Barea City... what's left of it.",
			"Three nights ago the whole place went mad. Sirens, screaming, then the shamblers.",
			"Folk say it started at the Price Slasher Megamart, out west. Something they called the Yellow Sticker idol.",
			"Was a pound forty. Marked down to twenty-seven pence. People queued round the block for it. Then they started biting.",
			"Bring me that idol and I'll get you off this rock. I'll keep the boat warm.",
		],
		"alert": [
			"You've GOT it?! Then why are you talking to me? Every dead thing in Barea is coming!",
			"Get on a boat and get us out of here!",
		],
	},
	{
		"id": "dev", "name": "Dev (night shift)", "spot": "petrol", "look": [Color(0.55, 0.4, 0.3), Color(0.85, 0.45, 0.15), Color(0.2, 0.22, 0.3)],
		"lines": [
			"Whoa, whoa, don't shoot! I just work here. Well. Worked.",
			"Word of advice: don't shoot the cars. The alarms bring every one of them for a mile.",
			"Don't drive into 'em either. Learned that one the hard way.",
			"The army threw up roadblocks everywhere. You'll never drive across town. Squeeze through the gaps on foot.",
			"The idol? Megamart, west side. Big yellow sign. Can't miss it. Wish I could.",
		],
		"alert": [
			"The sirens! You took it, didn't you? Run east! RUN!",
		],
	},
	{
		"id": "okafor", "name": "Sgt. Okafor", "spot": "police", "look": [Color(0.42, 0.3, 0.22), Color(0.15, 0.2, 0.42), Color(0.12, 0.14, 0.22)],
		"lines": [
			"Barea PD. Or what's left of it. Three of us held this station. I'm the three.",
			"We sealed the city with roadblocks to slow them down. Didn't slow them down.",
			"There's a reason we never touched the idol. The night someone did, the whole city went on alert at once.",
			"Every infected in Barea will know the moment it moves. If you take it, don't stop. Don't look back. Get to the water.",
		],
		"alert": [
			"That's the alarm. They're all coming. I'll hold them as long as I can. GO!",
		],
	},
	{
		"id": "bex", "name": "Bex (Fire Station 7)", "spot": "fire", "look": [Color(0.95, 0.78, 0.62), Color(0.75, 0.15, 0.1), Color(0.2, 0.18, 0.15)],
		"lines": [
			"Fire Station 7. Our trucks can't get past the roadblocks either, if that makes you feel better.",
			"We've stashed supplies all over town. Check the shops and petrol stations.",
			"If the city goes on alert, the sirens won't stop until you're off the island. Keep moving and you'll live.",
		],
		"alert": [
			"Hear that? That's for you. Stay on the main road east and don't get boxed in!",
		],
	},
	{
		"id": "reg", "name": "Old Reg", "spot": "plaza", "look": [Color(0.9, 0.75, 0.65), Color(0.5, 0.45, 0.35), Color(0.3, 0.28, 0.25)],
		"lines": [
			"Sixty years I've shopped in this city. Never seen a markdown like it.",
			"A pound forty, down to twenty-seven pence. That's not a bargain, son. That's a prophecy.",
			"They built a little shrine to it in the Megamart car park. Trolleys all round it like standing stones.",
			"Whoever holds the Yellow Sticker holds the city's attention. All of it. Every last rotten eye.",
		],
		"alert": [
			"Hah! You did it! Now RUN, before they mark YOU down!",
		],
	},
]


static func npc(id: String) -> Dictionary:
	for n in NPCS:
		if n.id == id:
			return n
	return {}


static func objective(stage: String) -> String:
	match stage:
		"arrive":
			return "Barea City: talk to survivors and find the Yellow Sticker idol."
		"hunt":
			return "Find the Yellow Sticker idol at the Price Slasher Megamart (west Barea)."
		"alert":
			return "HIGH ALERT! Get back to a boat and escape Barea City!"
		"escaped":
			return "You escaped Barea City. Sail on to the next island."
	return ""

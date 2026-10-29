class_name Story
## Island stories. Barea City is a five-act run of roughly 45-50 minutes:
##
##   Act 1  "arrive"   Land at the harbour, talk to Captain Marla.
##   Act 2  "keys"     The Megamart's shutters are down; the substation that powers them is
##                     locked. Fight north-east to Barea Police HQ for the master keys. Taking
##                     them sets off the holding-cell alarm (a hold-out).
##   Act 3  "power"    Across to the north-west industrial district. Unlock Substation 4 and
##                     throw the main breaker, then hold out while the grid spins up.
##   Act 4  "megamart" South to the Price Slasher Megamart, now open. Fight through the aisles,
##                     buy the Reduced Rifle, take the Yellow Sticker idol.
##   Act 5  "alert"    The whole city hunts you. The harbour's overrun, so Marla moves to the
##                     old ferry terminal on the far (west) shore. Get everyone, and the idol,
##                     onto her boat and out to sea.
##          "escaped"  Done.

const BAREA_STAGES := ["arrive", "keys", "power", "megamart", "alert", "escaped"]

## Hold-out lengths (seconds) for the two crescendo events.
const LOCKDOWN_TIME := 60.0
const POWER_TIME := 90.0

## Survivors you can talk to. `alert` lines replace `lines` once the idol is taken. Marla's
## ferry-terminal self only appears during the escape.
const NPCS := [
	{
		"id": "marla", "name": "Captain Marla", "look": [Color(0.86, 0.68, 0.52), Color(0.2, 0.3, 0.55), Color(0.18, 0.18, 0.22)],
		"lines": [
			"You made it. Welcome to Barea City... what's left of it.",
			"Three nights ago the whole place went mad. Sirens, screaming, then the shamblers.",
			"It started at the Price Slasher Megamart, down south. Something they called the Yellow Sticker idol. Was a pound forty, marked down to twenty-seven pence.",
			"Problem is, the Megamart's shuttered. No power since Substation 4 tripped, up in the north-west industrial estate.",
			"And the substation's padlocked. Sergeant Okafor at Police HQ, north-east, has the master keys. Start there.",
			"Bring me that idol and I'll get you off this rock.",
		],
		"alert": ["What are you doing here?! Get to the ferry terminal!"],
	},
	{
		"id": "dev", "name": "Dev (night shift)", "look": [Color(0.55, 0.4, 0.3), Color(0.85, 0.45, 0.15), Color(0.2, 0.22, 0.3)],
		"lines": [
			"Whoa, whoa, don't shoot! I just work here. Well. Worked.",
			"Word of advice: don't shoot the cars. The alarms bring every one of them for a mile. Don't drive into them either.",
			"The army threw up roadblocks everywhere. You'll never drive across town. Squeeze through the gaps on foot.",
			"Police HQ's north-east, the substation's way out north-west, and the Megamart's down south. It's a long walk. Pace yourselves.",
		],
		"alert": ["The sirens! You took it, didn't you? Get to the west shore, RUN!"],
	},
	{
		"id": "okafor", "name": "Sgt. Okafor", "look": [Color(0.42, 0.3, 0.22), Color(0.15, 0.2, 0.42), Color(0.12, 0.14, 0.22)],
		"lines": [
			"Barea PD. Or what's left of it. Three of us held this station. I'm the three.",
			"Master keys for the substation? Evidence lockup, by the car park. Help yourself.",
			"Fair warning: the lockup's wired to the holding-cell alarm. The second those keys move, every infected in the district comes knocking. Dig in.",
			"And if you ever touch that idol, don't stop. Don't look back. Get to the water.",
		],
		"alert": ["That's the city siren. They're all coming. I'll hold them as long as I can. GO!"],
	},
	{
		"id": "bex", "name": "Bex (Fire Station 7)", "look": [Color(0.95, 0.78, 0.62), Color(0.75, 0.15, 0.1), Color(0.2, 0.18, 0.15)],
		"lines": [
			"Fire Station 7. Our trucks can't get past the roadblocks either, if that makes you feel better.",
			"Restarting Substation 4? The breaker takes a minute and a half to spin up the grid, and it screams the whole time. You'll have company.",
			"We've stashed supplies at the shops and petrol stations. Grab what you can between fights.",
		],
		"alert": ["Hear that? That's for you. West to the ferry terminal, and don't get boxed in!"],
	},
	{
		"id": "reg", "name": "Old Reg", "look": [Color(0.9, 0.75, 0.65), Color(0.5, 0.45, 0.35), Color(0.3, 0.28, 0.25)],
		"lines": [
			"Sixty years I've shopped in this city. Never seen a markdown like it.",
			"A pound forty, down to twenty-seven pence. That's not a bargain, son. That's a prophecy.",
			"They built a shrine to it at the back of the Megamart. Trolleys all round it like standing stones.",
			"There's a gun on the reduced stand too. Cheap as chips and twice as nasty. Won't last, mind. Nothing reduced ever does.",
		],
		"alert": ["Hah! You did it! Now RUN, before they mark YOU down!"],
	},
	{
		"id": "marla_ferry", "name": "Captain Marla", "look": [Color(0.86, 0.68, 0.52), Color(0.2, 0.3, 0.55), Color(0.18, 0.18, 0.22)],
		"lines": ["Get aboard! Everyone, and that idol!"],
		"alert": ["Get aboard! Everyone, and that idol! I'm not waiting for the whole city!"],
		"only_alert": true,
	},
]


static func npc(id: String) -> Dictionary:
	for n in NPCS:
		if n.id == id:
			return n
	return {}


## True once `stage` has been reached (or passed).
static func reached(current: String, stage: String) -> bool:
	return BAREA_STAGES.find(current) >= BAREA_STAGES.find(stage)


static func objective(stage: String) -> String:
	match stage:
		"arrive":
			return "Act 1: Talk to Captain Marla at the harbour."
		"keys":
			return "Act 2: Get the substation keys from the evidence lockup at Barea Police HQ (north-east)."
		"power":
			return "Act 3: Unlock Substation 4 (north-west industrial estate) and throw the main breaker."
		"megamart":
			return "Act 4: The Megamart is open (south). Take the Yellow Sticker idol."
		"alert":
			return "Act 5: HIGH ALERT! Get to Marla's boat at the old ferry terminal (west shore)."
		"escaped":
			return "You escaped Barea City. Sail on to the next island."
	return ""

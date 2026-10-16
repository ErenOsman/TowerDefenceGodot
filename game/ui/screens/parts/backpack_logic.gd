class_name BackpackLogic
extends RefCounted
## The Backpack's pure helpers (Backpack — Design; UI/UX mockups screens-b/backpack.html, backpack-button.html,
## upgrade-pay.html, upgrade-pay-nogold.html), no nodes and no autoloads, so they can be tested: the popup's gold row
## and token rows (which kinds show, which are dimmed, "Found in"), the button's count, and the Upgrade view's Pay
## button (amount, label, enabled, the line under it). Reads GameData.gold and GameData.tokens only (no new save data;
## the class TokenWallet keeps its name in code, the player never sees "wallet").

const Title := "Backpack"
const GoldWord := "gold"
const GoldSub := "From missions; spent on upgrades"
const TokensHead := "Tokens"
const ItemsHead := "Items"
const ItemsEmpty := "Nothing here yet."
## The Pay row's red line when the player has no gold (18 px, under the Pay button).
const NoGold := "You have no gold. Missions give gold."
## The Pay row's muted line when the gold does not cover the task: "You have 15: pays what you can."
const PartialPay := "You have %d: pays what you can."

# ------------------------------------------------------------------ the popup

## The big row's number ("240"; never negative).
static func gold_text(gold: int) -> String:
	return str(maxi(0, gold))

## The token rows, in the catalog's order: {id, name, count, count_text "×2", found "Found in: Night Watch and Patrol"
## ("" when no mission drops it), dim (×0: spent out)}. A kind never earned (no count and no earned total) is not
## listed. tokens: the catalog's TokenAssets (or anything with get_id() / get_display_name()); wallet: GameData.tokens;
## found_of: Callable(token id) -> String, the Workshop's "Found in" text (WorkshopLogic.found_in_text).
static func token_rows(tokens: Array, wallet: TokenWallet, found_of: Callable) -> Array:
	var out := []
	if wallet == null: return out
	for t in tokens:
		if t == null: continue
		var id: String = t.get_id()
		var n := wallet.count(id)
		if not ever_had(wallet, id): continue
		var where: String = str(found_of.call(id)) if found_of.is_valid() else ""
		out.append({"id": id, "name": t.get_display_name(), "count": n, "count_text": "×%d" % n,
			"found": found_line(where), "dim": n <= 0})
	return out

## Whether a token kind shows in the Backpack: owned now or earned at some point (spent-out kinds stay, dimmed).
static func ever_had(wallet: TokenWallet, token_id: String) -> bool:
	if wallet == null: return false
	return wallet.count(token_id) > 0 or int(wallet.earned.get(token_id, 0)) > 0

## "Found in: Night Watch and Patrol" ("" when no mission drops it).
static func found_line(where: String) -> String:
	return "Found in: " + where if where != "" else ""

# ------------------------------------------------------------------ the button

## The button's count ("240").
static func button_text(gold: int) -> String:
	return gold_text(gold)

## The button shows once the Camp is open (nothing to carry before).
static func button_shown(camp_unlocked: bool) -> bool:
	return camp_unlocked

## The button's tooltip body: "240 gold · 3 tokens".
static func button_tip(gold: int, wallet: TokenWallet) -> String:
	var n := wallet.total() if wallet != null else 0
	return "%d gold · %d token%s" % [maxi(0, gold), n, "" if n == 1 else "s"]

# ------------------------------------------------------------------ the Upgrade view's Pay button

## What Pay deposits: min(gold, missing) (0 with no gold or a full task).
static func pay_amount(gold: int, missing: int) -> int:
	return maxi(0, mini(gold, missing))

## The Pay button's label: "Pay 15" (the amount it will deposit); "Pay" when it can deposit nothing.
static func pay_text(gold: int, missing: int) -> String:
	var n := pay_amount(gold, missing)
	return "Pay %d" % n if n > 0 else "Pay"

## Pay is enabled while the task misses gold and the player has some.
static func pay_enabled(gold: int, missing: int) -> bool:
	return gold > 0 and missing > 0

## The line under the Pay button: {text, bad}: no gold → the red NoGold; gold short of the task → the muted
## "You have 15: pays what you can."; enough → {"text": "", …}.
static func pay_note(gold: int, missing: int) -> Dictionary:
	if missing <= 0: return {"text": "", "bad": false}
	if gold <= 0: return {"text": NoGold, "bad": true}
	if gold < missing: return {"text": PartialPay % gold, "bad": false}
	return {"text": "", "bad": false}

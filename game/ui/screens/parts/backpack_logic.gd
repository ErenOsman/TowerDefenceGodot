class_name BackpackLogic
extends RefCounted
## The Backpack's pure helpers (Backpack — Design; UI/UX mockups screens-b/backpack.html, backpack-button.html,
## upgrade-pay.html, upgrade-pay-nogold.html), no nodes and no autoloads, so they can be tested: the popup's gold row
## and token rows (which kinds show, which are dimmed; no "found in" or "from missions" texts: Eren 2026-10-16), the
## button's count, and the Upgrade view's Pay button (amount, label, enabled). Reads GameData.gold and GameData.tokens only (no new save data;
## the class TokenWallet keeps its name in code, the player never sees "wallet").

const Title := "Backpack"
const GoldWord := "gold"
const TokensHead := "Tokens"
const ItemsHead := "Items"
const ItemsEmpty := "Nothing here yet."
## The disabled Pay button's reason (its tooltip; no line under the button: Eren 2026-10-16).
const NoGold := "You have no gold."

# ------------------------------------------------------------------ the popup

## The big row's number ("240"; never negative).
static func gold_text(gold: int) -> String:
	return str(maxi(0, gold))

## The token rows, in the catalog's order: {id, name, count, count_text "×2", dim (×0: spent out)}. A kind never
## earned (no count and no earned total) is not listed. tokens: the catalog's TokenAssets (or anything with
## get_id() / get_display_name()); wallet: GameData.tokens.
static func token_rows(tokens: Array, wallet: TokenWallet) -> Array:
	var out := []
	if wallet == null: return out
	for t in tokens:
		if t == null: continue
		var id: String = t.get_id()
		var n := wallet.count(id)
		if not ever_had(wallet, id): continue
		out.append({"id": id, "name": t.get_display_name(), "count": n, "count_text": "×%d" % n, "dim": n <= 0})
	return out

## Whether a token kind shows in the Backpack: owned now or earned at some point (spent-out kinds stay, dimmed).
static func ever_had(wallet: TokenWallet, token_id: String) -> bool:
	if wallet == null: return false
	return wallet.count(token_id) > 0 or int(wallet.earned.get(token_id, 0)) > 0

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
